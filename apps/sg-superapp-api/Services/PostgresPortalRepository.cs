using Npgsql;
using NpgsqlTypes;
using Sg.SuperApp.Api.Configuration;
using Sg.SuperApp.Api.Contracts.Auth;
using Sg.SuperApp.Api.Contracts.Portal;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class PostgresPortalRepository
{
    private static readonly IReadOnlyDictionary<string, (string Label, string Description, string Status)> ModuleCatalog =
        new Dictionary<string, (string Label, string Description, string Status)>(StringComparer.OrdinalIgnoreCase)
        {
            ["DASHBOARD"] = ("Dashboard", "Vista inicial del piloto.", "Disponible"),
            ["EMPLOYEES"] = ("Empleados / Guardas", "Consulta inicial del maestro de empleados I2.", "Disponible"),
            ["POSITIONS"] = ("Puestos de Servicio", "Pendiente implementacion en I3.", "Pendiente"),
            ["COURSES"] = ("Cursos y Acreditaciones", "Pendiente implementacion en I5.", "Pendiente"),
            ["CERTIFICATIONS"] = ("Certificaciones", "Pendiente implementacion en I4.", "Pendiente"),
            ["ALERTS"] = ("Alertas", "Pendiente implementacion en I6.", "Pendiente"),
            ["NOTIFICATIONS"] = ("Notificaciones", "Bandeja shell de I1.", "Disponible"),
            ["IMPORTS"] = ("Cargas de Datos", "Historial y prevalidacion CSV inicial I2.", "Disponible"),
            ["SETTINGS"] = ("Configuracion", "Administracion base del piloto.", "Disponible"),
            ["NOVEDADES"] = ("Novedades", "Proximamente / En diseno para incrementos futuros.", "Pendiente")
        };

    private readonly string _connectionString;

    public PostgresPortalRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Postgres")
            ?? throw new InvalidOperationException("Connection string 'Postgres' not configured.");
    }

    public async Task<bool> CanConnectAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = new NpgsqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<LoginResponse?> AuthenticateAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                u.id,
                u.full_name,
                u.username,
                u.is_active,
                u.last_login_at,
                r.code as role_code
            from app_users u
            join user_roles ur on ur.user_id = u.id
            join roles r on r.id = ur.role_id
            where lower(u.username) = lower(@username)
              and u.password_hash = crypt(@password, u.password_hash)
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("username", request.Username);
        command.Parameters.AddWithValue("password", request.Password);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var profile = new UserProfileResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetString(reader.GetOrdinal("full_name")),
            reader.GetString(reader.GetOrdinal("username")),
            reader.GetString(reader.GetOrdinal("role_code")),
            reader.GetBoolean(reader.GetOrdinal("is_active")),
            reader.IsDBNull(reader.GetOrdinal("last_login_at"))
                ? null
                : new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("last_login_at"))));

        if (!profile.IsActive)
        {
            return new LoginResponse(false, "El usuario no se encuentra activo. Contacte al administrador.", null, null);
        }

        await reader.CloseAsync();
        var token = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32));
        const string sessionSql = @"
            insert into app_sessions (token_hash, user_id, expires_at)
            values (encode(digest(@token, 'sha256'), 'hex'), @userId, NOW() + INTERVAL '30 minutes');";

        await using var sessionCommand = new NpgsqlCommand(sessionSql, connection);
        sessionCommand.Parameters.AddWithValue("token", token);
        sessionCommand.Parameters.AddWithValue("userId", profile.Id);
        await sessionCommand.ExecuteNonQueryAsync(cancellationToken);

        return new LoginResponse(true, "Autenticado.", token, profile);
    }

    public async Task<UserProfileResponse?> GetSessionUserAsync(string token, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select u.id, u.full_name, u.username, u.is_active, u.last_login_at, r.code as role_code
            from app_sessions s
            join app_users u on u.id = s.user_id
            join user_roles ur on ur.user_id = u.id
            join roles r on r.id = ur.role_id
            where s.token_hash = encode(digest(@token, 'sha256'), 'hex')
              and s.revoked_at is null
              and s.expires_at > NOW()
              and u.is_active = true
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("token", token);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new UserProfileResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetString(reader.GetOrdinal("full_name")),
            reader.GetString(reader.GetOrdinal("username")),
            reader.GetString(reader.GetOrdinal("role_code")),
            reader.GetBoolean(reader.GetOrdinal("is_active")),
            reader.IsDBNull(reader.GetOrdinal("last_login_at"))
                ? null
                : new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("last_login_at"))));
    }

    public async Task<bool> HasPermissionAsync(long userId, string moduleCode, string actionCode, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select exists (
                select 1
                from user_roles ur
                join role_permissions rp on rp.role_id = ur.role_id
                where ur.user_id = @userId
                  and upper(rp.module_code) = upper(@moduleCode)
                  and upper(rp.action_code) = upper(@actionCode)
                  and rp.allowed = true
            );";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("userId", userId);
        command.Parameters.AddWithValue("moduleCode", moduleCode);
        command.Parameters.AddWithValue("actionCode", actionCode);
        return (bool)(await command.ExecuteScalarAsync(cancellationToken) ?? false);
    }

    public async Task<UserProfileResponse?> GetCurrentUserAsync(string username, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                u.id,
                u.full_name,
                u.username,
                u.is_active,
                u.last_login_at,
                r.code as role_code
            from app_users u
            join user_roles ur on ur.user_id = u.id
            join roles r on r.id = ur.role_id
            where lower(u.username) = lower(@username)
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("username", username);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new UserProfileResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetString(reader.GetOrdinal("full_name")),
            reader.GetString(reader.GetOrdinal("username")),
            reader.GetString(reader.GetOrdinal("role_code")),
            reader.GetBoolean(reader.GetOrdinal("is_active")),
            reader.IsDBNull(reader.GetOrdinal("last_login_at"))
                ? null
                : new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("last_login_at"))));
    }

    public async Task<IReadOnlyList<PortalModuleResponse>> GetModulesAsync(string roleCode, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select distinct rp.module_code
            from role_permissions rp
            join roles r on r.id = rp.role_id
            where upper(r.code) = upper(@roleCode)
              and rp.allowed = true
            order by rp.module_code;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("roleCode", roleCode);

        var modules = new List<PortalModuleResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var moduleCode = reader.GetString(0).ToUpperInvariant();
            if (ModuleCatalog.TryGetValue(moduleCode, out var metadata))
            {
                modules.Add(new PortalModuleResponse(
                    moduleCode.ToLowerInvariant(),
                    metadata.Label,
                    metadata.Description,
                    true,
                    metadata.Status));
            }
        }

        return modules;
    }

    public async Task<IReadOnlyList<NotificationResponse>> GetNotificationsAsync(string username, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select id, target_type, target_key, title, body, status, created_at
            from notification_items
            where lower(target_key) = lower(@username)
               or upper(target_key) = 'ADMIN'
            order by created_at desc;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("username", username);

        var items = new List<NotificationResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new NotificationResponse(
                reader.GetInt64(reader.GetOrdinal("id")),
                reader.GetString(reader.GetOrdinal("target_type")),
                reader.GetString(reader.GetOrdinal("target_key")),
                reader.GetString(reader.GetOrdinal("title")),
                reader.GetString(reader.GetOrdinal("body")),
                reader.GetString(reader.GetOrdinal("status")),
                new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at")))));
        }

        return items;
    }

    public async Task<IReadOnlyList<EmployeeSummaryResponse>> GetEmployeesAsync(string? search, string? status, string? jobTitle, bool includeSalary, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                e.id,
                e.identification_type,
                e.identification_number,
                e.full_name,
                e.employment_status,
                e.job_title,
                e.record_status,
                e.current_service_position_text,
                salary.base_salary_amount
            from employees e
            left join lateral (
                select esh.base_salary_amount
                from employee_salary_history esh
                where esh.employee_id = e.id
                order by esh.effective_from desc
                limit 1
            ) salary on true
            where (@search is null
                or e.identification_number ilike '%' || @search || '%'
                or e.full_name ilike '%' || @search || '%')
              and (@status is null or upper(e.employment_status) = upper(@status))
              and (@jobTitle is null or e.job_title ilike '%' || @jobTitle || '%')
            order by e.full_name;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();
        command.Parameters.Add("jobTitle", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(jobTitle) ? DBNull.Value : jobTitle.Trim();

        var employees = new List<EmployeeSummaryResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            employees.Add(new EmployeeSummaryResponse(
                reader.GetInt64(reader.GetOrdinal("id")),
                reader.GetString(reader.GetOrdinal("identification_type")),
                reader.GetString(reader.GetOrdinal("identification_number")),
                reader.GetString(reader.GetOrdinal("full_name")),
                reader.GetString(reader.GetOrdinal("employment_status")),
                reader.GetString(reader.GetOrdinal("job_title")),
                reader.GetString(reader.GetOrdinal("record_status")),
                !includeSalary || reader.IsDBNull(reader.GetOrdinal("base_salary_amount"))
                    ? null
                    : reader.GetDecimal(reader.GetOrdinal("base_salary_amount")),
                reader.IsDBNull(reader.GetOrdinal("current_service_position_text"))
                    ? null
                    : reader.GetString(reader.GetOrdinal("current_service_position_text"))));
        }

        return employees;
    }

    public async Task<EmployeeDetailResponse?> GetEmployeeByIdAsync(long employeeId, bool includeSalary, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                e.id,
                e.identification_type,
                e.identification_number,
                e.full_name,
                e.employment_status,
                e.job_title,
                e.hire_date,
                e.termination_date,
                e.termination_reason,
                e.contract_type,
                e.current_service_position_text,
                e.notes,
                e.record_status,
                salary.base_salary_amount,
                salary.effective_from,
                salary.effective_to,
                salary.source as salary_source
            from employees e
            left join lateral (
                select esh.base_salary_amount, esh.effective_from, esh.effective_to, esh.source
                from employee_salary_history esh
                where esh.employee_id = e.id
                order by esh.effective_from desc
                limit 1
            ) salary on true
            where e.id = @employeeId
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("employeeId", employeeId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new EmployeeDetailResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetString(reader.GetOrdinal("identification_type")),
            reader.GetString(reader.GetOrdinal("identification_number")),
            reader.GetString(reader.GetOrdinal("full_name")),
            reader.GetString(reader.GetOrdinal("employment_status")),
            reader.GetString(reader.GetOrdinal("job_title")),
            reader.IsDBNull(reader.GetOrdinal("hire_date"))
                ? null
                : DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("hire_date"))),
            reader.IsDBNull(reader.GetOrdinal("termination_date"))
                ? null
                : DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("termination_date"))),
            reader.IsDBNull(reader.GetOrdinal("termination_reason"))
                ? null
                : reader.GetString(reader.GetOrdinal("termination_reason")),
            reader.IsDBNull(reader.GetOrdinal("contract_type"))
                ? null
                : reader.GetString(reader.GetOrdinal("contract_type")),
            reader.IsDBNull(reader.GetOrdinal("current_service_position_text"))
                ? null
                : reader.GetString(reader.GetOrdinal("current_service_position_text")),
            reader.IsDBNull(reader.GetOrdinal("notes"))
                ? null
                : reader.GetString(reader.GetOrdinal("notes")),
            reader.GetString(reader.GetOrdinal("record_status")),
            !includeSalary || reader.IsDBNull(reader.GetOrdinal("base_salary_amount"))
                ? null
                : reader.GetDecimal(reader.GetOrdinal("base_salary_amount")),
            !includeSalary || reader.IsDBNull(reader.GetOrdinal("effective_from"))
                ? null
                : DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("effective_from"))),
            !includeSalary || reader.IsDBNull(reader.GetOrdinal("effective_to"))
                ? null
                : DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("effective_to"))),
            !includeSalary || reader.IsDBNull(reader.GetOrdinal("salary_source"))
                ? "DESCONOCIDA"
                : reader.GetString(reader.GetOrdinal("salary_source")));
    }

    public async Task<IReadOnlyList<ImportBatchSummaryResponse>> GetImportBatchesAsync(CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                id,
                load_type,
                file_name,
                uploaded_by,
                status,
                total_records,
                valid_records,
                incomplete_records,
                duplicate_records,
                invalid_records,
                created_at,
                imported_at
            from import_batches
            order by created_at desc;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);

        var batches = new List<ImportBatchSummaryResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            batches.Add(new ImportBatchSummaryResponse(
                reader.GetInt64(reader.GetOrdinal("id")),
                reader.GetString(reader.GetOrdinal("load_type")),
                reader.GetString(reader.GetOrdinal("file_name")),
                reader.GetString(reader.GetOrdinal("uploaded_by")),
                reader.GetString(reader.GetOrdinal("status")),
                reader.GetInt32(reader.GetOrdinal("total_records")),
                reader.GetInt32(reader.GetOrdinal("valid_records")),
                reader.GetInt32(reader.GetOrdinal("incomplete_records")),
                reader.GetInt32(reader.GetOrdinal("duplicate_records")),
                reader.GetInt32(reader.GetOrdinal("invalid_records")),
                new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
                reader.IsDBNull(reader.GetOrdinal("imported_at"))
                    ? null
                    : new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("imported_at")))));
        }

        return batches;
    }

    public async Task<IReadOnlyList<ImportBatchErrorResponse>> GetImportBatchErrorsAsync(long batchId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                id,
                row_number,
                field_name,
                error_type,
                message,
                original_value
            from import_batch_errors
            where import_batch_id = @batchId
            order by row_number, field_name;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("batchId", batchId);

        var errors = new List<ImportBatchErrorResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            errors.Add(new ImportBatchErrorResponse(
                reader.GetInt64(reader.GetOrdinal("id")),
                reader.GetInt32(reader.GetOrdinal("row_number")),
                reader.GetString(reader.GetOrdinal("field_name")),
                reader.GetString(reader.GetOrdinal("error_type")),
                reader.GetString(reader.GetOrdinal("message")),
                reader.IsDBNull(reader.GetOrdinal("original_value"))
                    ? null
                    : reader.GetString(reader.GetOrdinal("original_value"))));
        }

        return errors;
    }

    public async Task<IReadOnlySet<string>> GetExistingIdentificationNumbersAsync(CancellationToken cancellationToken = default)
    {
        const string sql = "select identification_number from employees;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);

        var identifications = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            identifications.Add(reader.GetString(0));
        }

        return identifications;
    }

    public async Task<ImportPrevalidationResponse> SaveImportPrevalidationAsync(
        ImportPrevalidationResult result,
        string uploadedBy,
        CancellationToken cancellationToken = default)
    {
        const string insertBatchSql = @"
            insert into import_batches (
                load_type,
                file_name,
                uploaded_by,
                status,
                total_records,
                valid_records,
                incomplete_records,
                duplicate_records,
                invalid_records
            )
            values (
                'EMPLEADOS',
                @fileName,
                @uploadedBy,
                @status,
                @totalRecords,
                @validRecords,
                @incompleteRecords,
                @duplicateRecords,
                @invalidRecords
            )
            returning id;";

        const string insertErrorSql = @"
            insert into import_batch_errors (
                import_batch_id,
                row_number,
                field_name,
                error_type,
                message,
                original_value
            )
            values (
                @batchId,
                @rowNumber,
                @fieldName,
                @errorType,
                @message,
                @originalValue
            );";

        var status = result.Errors.Count == 0 ? "PREVALIDADA" : "CON_ERRORES";
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using var batchCommand = new NpgsqlCommand(insertBatchSql, connection, transaction);
        batchCommand.Parameters.AddWithValue("fileName", result.FileName);
        batchCommand.Parameters.AddWithValue("uploadedBy", uploadedBy);
        batchCommand.Parameters.AddWithValue("status", status);
        batchCommand.Parameters.AddWithValue("totalRecords", result.TotalRecords);
        batchCommand.Parameters.AddWithValue("validRecords", result.ValidRecords);
        batchCommand.Parameters.AddWithValue("incompleteRecords", result.IncompleteRecords);
        batchCommand.Parameters.AddWithValue("duplicateRecords", result.DuplicateRecords);
        batchCommand.Parameters.AddWithValue("invalidRecords", result.InvalidRecords);
        var batchId = (long)(await batchCommand.ExecuteScalarAsync(cancellationToken)
            ?? throw new InvalidOperationException("No fue posible crear el lote de prevalidacion."));

        foreach (var error in result.Errors)
        {
            await using var errorCommand = new NpgsqlCommand(insertErrorSql, connection, transaction);
            errorCommand.Parameters.AddWithValue("batchId", batchId);
            errorCommand.Parameters.AddWithValue("rowNumber", error.RowNumber);
            errorCommand.Parameters.AddWithValue("fieldName", error.FieldName);
            errorCommand.Parameters.AddWithValue("errorType", error.ErrorType);
            errorCommand.Parameters.AddWithValue("message", error.Message);
            errorCommand.Parameters.AddWithValue("originalValue", error.OriginalValue is null ? DBNull.Value : error.OriginalValue);
            await errorCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);

        return new ImportPrevalidationResponse(
            batchId,
            status,
            result.FileName,
            result.TotalRecords,
            result.ValidRecords,
            result.IncompleteRecords,
            result.DuplicateRecords,
            result.InvalidRecords);
    }
}
