using Npgsql;
using NpgsqlTypes;
using System.Text;
using System.Text.Json;
using Sg.SuperApp.Api.Configuration;
using Sg.SuperApp.Api.Contracts.Auth;
using Sg.SuperApp.Api.Contracts.Portal;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class PostgresPortalRepository
{
    private sealed class TrainingComplianceSummaryAccumulator
    {
        public TrainingComplianceSummaryAccumulator(long employeeId, string identificationNumber, string fullName, string employmentStatus, string jobTitle, string? currentPositionName)
        {
            EmployeeId = employeeId;
            IdentificationNumber = identificationNumber;
            FullName = fullName;
            EmploymentStatus = employmentStatus;
            JobTitle = jobTitle;
            CurrentPositionName = currentPositionName;
        }

        public long EmployeeId { get; }
        public string IdentificationNumber { get; }
        public string FullName { get; }
        public string EmploymentStatus { get; }
        public string JobTitle { get; }
        public string? CurrentPositionName { get; }
        public int BlockingExpiredRequirementsCount { get; set; }
        public string WorstComplianceStatus { get; set; } = "AL_DIA";
        public int ActiveRequirementsCount { get; set; }

        public TrainingComplianceSummaryResponse ToResponse(DateTimeOffset calculatedAt)
        {
            return new TrainingComplianceSummaryResponse(
                EmployeeId,
                IdentificationNumber,
                FullName,
                EmploymentStatus,
                JobTitle,
                CurrentPositionName,
                BlockingExpiredRequirementsCount > 0 ? "NO_HABILITADO" : "HABILITADO",
                BlockingExpiredRequirementsCount,
                WorstComplianceStatus,
                ActiveRequirementsCount,
                calculatedAt);
        }
    }

    private static readonly IReadOnlyDictionary<string, (string Label, string Description, string Status)> ModuleCatalog =
        new Dictionary<string, (string Label, string Description, string Status)>(StringComparer.OrdinalIgnoreCase)
        {
            ["DASHBOARD"] = ("Dashboard", "Vista inicial del piloto.", "Disponible"),
            ["EMPLOYEES"] = ("Empleados / Guardas", "Consulta inicial del maestro de empleados I2.", "Disponible"),
            ["POSITIONS"] = ("Puestos de Servicio", "Listado y detalle inicial I3.", "Disponible"),
            ["COURSES"] = ("Cursos y Acreditaciones", "Pendiente implementacion en I5.", "Pendiente"),
            ["CERTIFICATES"] = ("Certificaciones", "Firmantes y certificados laborales I4.", "Disponible"),
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

    public async Task<IReadOnlyList<EmployeeSummaryResponse>> GetEmployeesAsync(string? search, string? status, string? jobTitle, string? completeness, bool includeSalary, CancellationToken cancellationToken = default)
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
              and (@completeness is null
                or (upper(@completeness) = 'INCOMPLETO' and e.record_status = 'INCOMPLETO')
                or (upper(@completeness) = 'COMPLETO' and e.record_status <> 'INCOMPLETO'))
            order by e.full_name;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();
        command.Parameters.Add("jobTitle", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(jobTitle) ? DBNull.Value : jobTitle.Trim();
        command.Parameters.Add("completeness", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(completeness) ? DBNull.Value : completeness.Trim().ToUpperInvariant();

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

    public async Task<IReadOnlyList<ServicePositionResponse>> GetServicePositionsAsync(string? search, string? status, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                sp.id,
                sp.code,
                sp.name,
                sp.client_text,
                sp.location_text,
                sp.status,
                sp.notes,
                sp.created_at,
                sp.updated_at,
                count(epa.id) filter (where epa.status = 'VIGENTE')::int as active_assignments_count
            from service_positions sp
            left join employee_position_assignments epa on epa.position_id = sp.id
            where (@search is null
                or sp.name ilike '%' || @search || '%'
                or sp.code ilike '%' || @search || '%'
                or sp.client_text ilike '%' || @search || '%')
              and (@status is null or sp.status = @status)
            group by sp.id
            order by sp.name;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();

        var positions = new List<ServicePositionResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            positions.Add(ReadServicePosition(reader));
        }

        return positions;
    }

    public async Task<ServicePositionResponse?> GetServicePositionByIdAsync(long positionId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                sp.id,
                sp.code,
                sp.name,
                sp.client_text,
                sp.location_text,
                sp.status,
                sp.notes,
                sp.created_at,
                sp.updated_at,
                count(epa.id) filter (where epa.status = 'VIGENTE')::int as active_assignments_count
            from service_positions sp
            left join employee_position_assignments epa on epa.position_id = sp.id
            where sp.id = @positionId
            group by sp.id
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("positionId", positionId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? ReadServicePosition(reader) : null;
    }

    public async Task<IReadOnlyList<CertificateSignerResponse>> GetCertificateSignersAsync(string? status, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select id, full_name, job_title, signature_path, valid_from, valid_to, status, notes, created_at, updated_at
            from certificate_signers
            where (@status is null or status = @status)
            order by status, valid_from desc, full_name;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();

        var signers = new List<CertificateSignerResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            signers.Add(ReadCertificateSigner(reader));
        }

        return signers;
    }

    public async Task<CertificateSignerResponse?> GetCertificateSignerByIdAsync(long signerId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select id, full_name, job_title, signature_path, valid_from, valid_to, status, notes, created_at, updated_at
            from certificate_signers
            where id = @signerId
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("signerId", signerId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? ReadCertificateSigner(reader) : null;
    }

    public async Task<IReadOnlyList<TrainingRequirementTypeResponse>> GetTrainingRequirementTypesAsync(string? search, string? status, string? category, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select id, code, name, category, validity_days, is_service_required, status, notes, created_at, updated_at
            from training_requirement_types
            where (@search is null
                or name ilike '%' || @search || '%'
                or code ilike '%' || @search || '%')
              and (@status is null or status = @status)
              and (@category is null or category = @category)
            order by status, category, name;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();
        command.Parameters.Add("category", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(category) ? DBNull.Value : category.Trim().ToUpperInvariant();

        var types = new List<TrainingRequirementTypeResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            types.Add(ReadTrainingRequirementType(reader));
        }

        return types;
    }

    public async Task<TrainingRequirementTypeResponse?> GetTrainingRequirementTypeByIdAsync(long typeId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select id, code, name, category, validity_days, is_service_required, status, notes, created_at, updated_at
            from training_requirement_types
            where id = @typeId
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("typeId", typeId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? ReadTrainingRequirementType(reader) : null;
    }

    public async Task<TrainingRequirementTypeResponse> CreateTrainingRequirementTypeAsync(UpsertTrainingRequirementTypeRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string insertSql = @"
            insert into training_requirement_types (code, name, category, validity_days, is_service_required, notes)
            values (@code, @name, @category, @validityDays, @isServiceRequired, @notes)
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(insertSql, connection, transaction);
        AddTrainingRequirementTypeParameters(command, request);
        var id = (long)(await command.ExecuteScalarAsync(cancellationToken)
            ?? throw new InvalidOperationException("No fue posible crear el tipo de curso/acreditacion."));
        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, "TRAINING_TYPE_CREATED", "TRAINING_TYPE", id.ToString(), "jsonb_build_object('code', @code, 'name', @name, 'category', @category, 'validityDays', @validityDays, 'isServiceRequired', @isServiceRequired)", AddTrainingRequirementTypeAuditParameters(request), cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return (await GetTrainingRequirementTypeByIdAsync(id, cancellationToken))!;
    }

    public async Task<TrainingRequirementTypeResponse?> UpdateTrainingRequirementTypeAsync(long typeId, UpsertTrainingRequirementTypeRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string updateSql = @"
            update training_requirement_types
            set code = @code,
                name = @name,
                category = @category,
                validity_days = @validityDays,
                is_service_required = @isServiceRequired,
                notes = @notes,
                updated_at = now()
            where id = @typeId
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(updateSql, connection, transaction);
        command.Parameters.AddWithValue("typeId", typeId);
        AddTrainingRequirementTypeParameters(command, request);
        var updatedId = await command.ExecuteScalarAsync(cancellationToken);
        if (updatedId is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, "TRAINING_TYPE_UPDATED", "TRAINING_TYPE", typeId.ToString(), "jsonb_build_object('code', @code, 'name', @name, 'category', @category, 'validityDays', @validityDays, 'isServiceRequired', @isServiceRequired)", AddTrainingRequirementTypeAuditParameters(request), cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return await GetTrainingRequirementTypeByIdAsync(typeId, cancellationToken);
    }

    public async Task<TrainingRequirementTypeResponse?> InactivateTrainingRequirementTypeAsync(long typeId, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            update training_requirement_types
            set status = 'INACTIVO',
                updated_at = now()
            where id = @typeId
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("typeId", typeId);
        var updatedId = await command.ExecuteScalarAsync(cancellationToken);
        if (updatedId is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, "TRAINING_TYPE_INACTIVATED", "TRAINING_TYPE", typeId.ToString(), "'{}'::jsonb", null, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return await GetTrainingRequirementTypeByIdAsync(typeId, cancellationToken);
    }

    public async Task<(string Code, TrainingRecordResponse? Record)> CreateEmployeeTrainingRecordAsync(long employeeId, CreateTrainingRecordRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string employeeExistsSql = "select exists (select 1 from employees where id = @employeeId);";
        const string typeSql = @"
            select id, name, category, validity_days, status
            from training_requirement_types
            where id = @typeId
            limit 1;";
        const string insertSql = @"
            insert into employee_training_records (
                employee_id,
                requirement_type_id,
                completed_at,
                expires_at,
                support_path,
                notes,
                created_by
            )
            values (
                @employeeId,
                @typeId,
                @completedAt,
                @expiresAt,
                @supportPath,
                @notes,
                @createdBy
            )
            returning id;";

        var completedAt = DateOnly.Parse(request.CompletedAt);

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using (var employeeCommand = new NpgsqlCommand(employeeExistsSql, connection, transaction))
        {
            employeeCommand.Parameters.AddWithValue("employeeId", employeeId);
            var employeeExists = (bool)(await employeeCommand.ExecuteScalarAsync(cancellationToken) ?? false);
            if (!employeeExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return ("EMPLOYEE_NOT_FOUND", null);
            }
        }

        string typeName;
        string typeCategory;
        int? validityDays;
        string typeStatus;
        await using (var typeCommand = new NpgsqlCommand(typeSql, connection, transaction))
        {
            typeCommand.Parameters.AddWithValue("typeId", request.RequirementTypeId);
            await using var reader = await typeCommand.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return ("TYPE_NOT_FOUND", null);
            }

            typeName = reader.GetString(reader.GetOrdinal("name"));
            typeCategory = reader.GetString(reader.GetOrdinal("category"));
            validityDays = reader.IsDBNull(reader.GetOrdinal("validity_days")) ? null : reader.GetInt32(reader.GetOrdinal("validity_days"));
            typeStatus = reader.GetString(reader.GetOrdinal("status"));
        }

        if (typeStatus != "ACTIVO")
        {
            await transaction.RollbackAsync(cancellationToken);
            return ("INACTIVE_TYPE", null);
        }

        DateOnly expiresAt;
        if (validityDays.HasValue)
        {
            expiresAt = completedAt.AddDays(validityDays.Value);
        }
        else if (string.IsNullOrWhiteSpace(request.ExpiresAt) || !DateOnly.TryParse(request.ExpiresAt, out expiresAt))
        {
            await transaction.RollbackAsync(cancellationToken);
            return ("MISSING_EXPIRY", null);
        }

        if (expiresAt < completedAt)
        {
            await transaction.RollbackAsync(cancellationToken);
            return ("INVALID_DATE", null);
        }

        await using var insertCommand = new NpgsqlCommand(insertSql, connection, transaction);
        insertCommand.Parameters.AddWithValue("employeeId", employeeId);
        insertCommand.Parameters.AddWithValue("typeId", request.RequirementTypeId);
        insertCommand.Parameters.AddWithValue("completedAt", completedAt.ToDateTime(TimeOnly.MinValue));
        insertCommand.Parameters.AddWithValue("expiresAt", expiresAt.ToDateTime(TimeOnly.MinValue));
        insertCommand.Parameters.Add("supportPath", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.SupportPath) ? DBNull.Value : request.SupportPath.Trim();
        insertCommand.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
        insertCommand.Parameters.AddWithValue("createdBy", actorUsername);
        var recordId = (long)(await insertCommand.ExecuteScalarAsync(cancellationToken)
            ?? throw new InvalidOperationException("No fue posible crear la renovacion."));

        await InsertAuditLogAsync(
            connection,
            transaction,
            actorUserId,
            actorUsername,
            "TRAINING_RECORD_CREATED",
            "EMPLOYEE_TRAINING_RECORD",
            recordId.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "jsonb_build_object('employeeId', @employeeId, 'requirementTypeId', @typeId, 'completedAt', @completedAtText, 'expiresAt', @expiresAtText, 'typeName', @typeName, 'typeCategory', @typeCategory, 'notes', @notes)",
            command =>
            {
                command.Parameters.AddWithValue("employeeId", employeeId);
                command.Parameters.AddWithValue("typeId", request.RequirementTypeId);
                command.Parameters.AddWithValue("completedAtText", completedAt.ToString("yyyy-MM-dd"));
                command.Parameters.AddWithValue("expiresAtText", expiresAt.ToString("yyyy-MM-dd"));
                command.Parameters.AddWithValue("typeName", typeName);
                command.Parameters.AddWithValue("typeCategory", typeCategory);
                command.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
            },
            cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return ("CREATED", await GetEmployeeTrainingRecordByIdAsync(recordId, cancellationToken));
    }

    public async Task<TrainingRecordResponse?> InactivateEmployeeTrainingRecordAsync(long recordId, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            update employee_training_records
            set status = 'INACTIVO',
                updated_at = now()
            where id = @recordId
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("recordId", recordId);
        var updatedId = await command.ExecuteScalarAsync(cancellationToken);
        if (updatedId is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, "TRAINING_RECORD_INACTIVATED", "EMPLOYEE_TRAINING_RECORD", recordId.ToString(System.Globalization.CultureInfo.InvariantCulture), "'{}'::jsonb", null, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return await GetEmployeeTrainingRecordByIdAsync(recordId, cancellationToken);
    }

    public async Task<TrainingRecordResponse?> GetEmployeeTrainingRecordByIdAsync(long recordId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                etr.id,
                etr.employee_id,
                etr.requirement_type_id,
                trt.name as requirement_type_name,
                trt.category as requirement_category,
                etr.completed_at,
                etr.expires_at,
                etr.support_path,
                etr.notes,
                etr.status,
                etr.created_by,
                etr.created_at,
                etr.updated_at
            from employee_training_records etr
            join training_requirement_types trt on trt.id = etr.requirement_type_id
            where etr.id = @recordId
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("recordId", recordId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? ReadTrainingRecord(reader) : null;
    }

    public async Task<TrainingServiceEnablementResponse?> GetTrainingServiceEnablementAsync(long employeeId, CancellationToken cancellationToken = default)
    {
        const string employeeExistsSql = "select exists (select 1 from employees where id = @employeeId);";
        const string requiredRecordsSql = @"
            select etr.expires_at
            from employee_training_records etr
            join training_requirement_types trt on trt.id = etr.requirement_type_id
            where etr.employee_id = @employeeId
              and etr.status = 'ACTIVO'
              and trt.status = 'ACTIVO'
              and trt.is_service_required = true;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using (var employeeCommand = new NpgsqlCommand(employeeExistsSql, connection))
        {
            employeeCommand.Parameters.AddWithValue("employeeId", employeeId);
            var employeeExists = (bool)(await employeeCommand.ExecuteScalarAsync(cancellationToken) ?? false);
            if (!employeeExists)
            {
                return null;
            }
        }

        var blockingExpiredRequirementsCount = 0;
        await using (var recordsCommand = new NpgsqlCommand(requiredRecordsSql, connection))
        {
            recordsCommand.Parameters.AddWithValue("employeeId", employeeId);
            await using var reader = await recordsCommand.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                var expiresAt = DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("expires_at")));
                var compliance = TrainingComplianceStatusCalculator.Calculate(expiresAt, DateOnly.FromDateTime(DateTime.Today));
                if (compliance.Status == "VENCIDO")
                {
                    blockingExpiredRequirementsCount++;
                }
            }
        }

        return new TrainingServiceEnablementResponse(
            employeeId,
            blockingExpiredRequirementsCount > 0 ? "NO_HABILITADO" : "HABILITADO",
            blockingExpiredRequirementsCount,
            DateTimeOffset.UtcNow);
    }

    public async Task<IReadOnlyList<TrainingComplianceSummaryResponse>> GetTrainingComplianceSummariesAsync(string? search, long? typeId, string? complianceStatus, string? enablementStatus, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                e.id as employee_id,
                e.identification_number,
                e.full_name,
                e.employment_status,
                e.job_title,
                current_position.position_name as current_position_name,
                etr.expires_at,
                trt.is_service_required
            from employees e
            join employee_training_records etr on etr.employee_id = e.id
            join training_requirement_types trt on trt.id = etr.requirement_type_id
            left join lateral (
                select sp.name as position_name
                from employee_position_assignments epa
                join service_positions sp on sp.id = epa.position_id
                where epa.employee_id = e.id
                  and epa.status = 'VIGENTE'
                order by epa.start_date desc, epa.id desc
                limit 1
            ) current_position on true
            where etr.status = 'ACTIVO'
              and trt.status = 'ACTIVO'
              and (@search is null
                or e.identification_number ilike '%' || @search || '%'
                or e.full_name ilike '%' || @search || '%')
              and (@typeId is null or trt.id = @typeId)
            order by e.full_name, e.id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("typeId", NpgsqlDbType.Bigint).Value = typeId.HasValue ? typeId.Value : DBNull.Value;

        var summaries = new Dictionary<long, TrainingComplianceSummaryAccumulator>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var employeeId = reader.GetInt64(reader.GetOrdinal("employee_id"));
            if (!summaries.TryGetValue(employeeId, out var summary))
            {
                summary = new TrainingComplianceSummaryAccumulator(
                    employeeId,
                    reader.GetString(reader.GetOrdinal("identification_number")),
                    reader.GetString(reader.GetOrdinal("full_name")),
                    reader.GetString(reader.GetOrdinal("employment_status")),
                    reader.GetString(reader.GetOrdinal("job_title")),
                    reader.IsDBNull(reader.GetOrdinal("current_position_name")) ? null : reader.GetString(reader.GetOrdinal("current_position_name")));
                summaries.Add(employeeId, summary);
            }

            var expiresAt = DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("expires_at")));
            var compliance = TrainingComplianceStatusCalculator.Calculate(expiresAt, DateOnly.FromDateTime(DateTime.Today));
            summary.ActiveRequirementsCount++;
            if (GetComplianceSeverity(compliance.Status) > GetComplianceSeverity(summary.WorstComplianceStatus))
            {
                summary.WorstComplianceStatus = compliance.Status;
            }

            if (reader.GetBoolean(reader.GetOrdinal("is_service_required")) && compliance.Status == "VENCIDO")
            {
                summary.BlockingExpiredRequirementsCount++;
            }
        }

        var normalizedComplianceStatus = string.IsNullOrWhiteSpace(complianceStatus) ? null : complianceStatus.Trim().ToUpperInvariant();
        var normalizedEnablementStatus = string.IsNullOrWhiteSpace(enablementStatus) ? null : enablementStatus.Trim().ToUpperInvariant();
        var calculatedAt = DateTimeOffset.UtcNow;

        return summaries.Values
            .Select(summary => summary.ToResponse(calculatedAt))
            .Where(summary => normalizedComplianceStatus is null || summary.WorstComplianceStatus == normalizedComplianceStatus)
            .Where(summary => normalizedEnablementStatus is null || summary.ServiceEnablementStatus == normalizedEnablementStatus)
            .OrderBy(summary => summary.FullName)
            .ToList();
    }

    public async Task<TrainingComplianceDetailResponse?> GetTrainingComplianceDetailAsync(long employeeId, CancellationToken cancellationToken = default)
    {
        const string employeeSql = @"
            select
                e.id,
                e.identification_type,
                e.identification_number,
                e.full_name,
                e.employment_status,
                e.job_title,
                current_position.position_id,
                current_position.position_name,
                current_position.position_code,
                current_position.client_text,
                current_position.start_date
            from employees e
            left join lateral (
                select epa.position_id, sp.name as position_name, sp.code as position_code, sp.client_text, epa.start_date
                from employee_position_assignments epa
                join service_positions sp on sp.id = epa.position_id
                where epa.employee_id = e.id
                  and epa.status = 'VIGENTE'
                order by epa.start_date desc, epa.id desc
                limit 1
            ) current_position on true
            where e.id = @employeeId
            limit 1;";
        const string recordsSql = @"
            select
                etr.id,
                etr.employee_id,
                etr.requirement_type_id,
                trt.name as requirement_type_name,
                trt.category as requirement_category,
                etr.completed_at,
                etr.expires_at,
                etr.support_path,
                etr.notes,
                etr.status,
                etr.created_by,
                etr.created_at,
                etr.updated_at
            from employee_training_records etr
            join training_requirement_types trt on trt.id = etr.requirement_type_id
            where etr.employee_id = @employeeId
            order by
                case when etr.status = 'ACTIVO' then 0 else 1 end,
                etr.expires_at desc,
                etr.id desc;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        TrainingComplianceEmployeeResponse employee;
        TrainingCurrentPositionResponse? currentPosition = null;
        await using (var employeeCommand = new NpgsqlCommand(employeeSql, connection))
        {
            employeeCommand.Parameters.AddWithValue("employeeId", employeeId);
            await using var employeeReader = await employeeCommand.ExecuteReaderAsync(cancellationToken);
            if (!await employeeReader.ReadAsync(cancellationToken))
            {
                return null;
            }

            employee = new TrainingComplianceEmployeeResponse(
                employeeReader.GetInt64(employeeReader.GetOrdinal("id")),
                employeeReader.GetString(employeeReader.GetOrdinal("identification_type")),
                employeeReader.GetString(employeeReader.GetOrdinal("identification_number")),
                employeeReader.GetString(employeeReader.GetOrdinal("full_name")),
                employeeReader.GetString(employeeReader.GetOrdinal("employment_status")),
                employeeReader.GetString(employeeReader.GetOrdinal("job_title")));

            if (!employeeReader.IsDBNull(employeeReader.GetOrdinal("position_id")))
            {
                currentPosition = new TrainingCurrentPositionResponse(
                    employeeReader.GetInt64(employeeReader.GetOrdinal("position_id")),
                    employeeReader.GetString(employeeReader.GetOrdinal("position_name")),
                    employeeReader.IsDBNull(employeeReader.GetOrdinal("position_code")) ? null : employeeReader.GetString(employeeReader.GetOrdinal("position_code")),
                    employeeReader.IsDBNull(employeeReader.GetOrdinal("client_text")) ? null : employeeReader.GetString(employeeReader.GetOrdinal("client_text")),
                    employeeReader.GetDateTime(employeeReader.GetOrdinal("start_date")).ToString("yyyy-MM-dd"));
            }
        }

        var history = new List<TrainingRecordResponse>();
        await using (var recordsCommand = new NpgsqlCommand(recordsSql, connection))
        {
            recordsCommand.Parameters.AddWithValue("employeeId", employeeId);
            await using var recordsReader = await recordsCommand.ExecuteReaderAsync(cancellationToken);
            while (await recordsReader.ReadAsync(cancellationToken))
            {
                history.Add(ReadTrainingRecord(recordsReader));
            }
        }

        var enablement = await GetTrainingServiceEnablementAsync(employeeId, cancellationToken)
            ?? new TrainingServiceEnablementResponse(employeeId, "HABILITADO", 0, DateTimeOffset.UtcNow);
        return new TrainingComplianceDetailResponse(
            employee,
            currentPosition,
            enablement,
            history.Where(record => record.Status == "ACTIVO").ToList(),
            history);
    }

    public async Task<CertificateSignerResponse> CreateCertificateSignerAsync(UpsertCertificateSignerRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string insertSql = @"
            insert into certificate_signers (full_name, job_title, signature_path, valid_from, valid_to, notes)
            values (@fullName, @jobTitle, @signaturePath, @validFrom, @validTo, @notes)
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(insertSql, connection, transaction);
        AddCertificateSignerParameters(command, request);
        var id = (long)(await command.ExecuteScalarAsync(cancellationToken)
            ?? throw new InvalidOperationException("No fue posible crear el firmante."));
        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, "CERTIFICATE_SIGNER_CREATED", "CERTIFICATE_SIGNER", id.ToString(), "jsonb_build_object('fullName', @fullName, 'jobTitle', @jobTitle)", AddCertificateSignerAuditParameters(request), cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return (await GetCertificateSignerByIdAsync(id, cancellationToken))!;
    }

    public async Task<CertificateSignerResponse?> UpdateCertificateSignerAsync(long signerId, UpsertCertificateSignerRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string updateSql = @"
            update certificate_signers
            set full_name = @fullName,
                job_title = @jobTitle,
                signature_path = @signaturePath,
                valid_from = @validFrom,
                valid_to = @validTo,
                notes = @notes,
                updated_at = now()
            where id = @signerId
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(updateSql, connection, transaction);
        command.Parameters.AddWithValue("signerId", signerId);
        AddCertificateSignerParameters(command, request);
        var updatedId = await command.ExecuteScalarAsync(cancellationToken);
        if (updatedId is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, "CERTIFICATE_SIGNER_UPDATED", "CERTIFICATE_SIGNER", signerId.ToString(), "jsonb_build_object('fullName', @fullName, 'jobTitle', @jobTitle)", AddCertificateSignerAuditParameters(request), cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return await GetCertificateSignerByIdAsync(signerId, cancellationToken);
    }

    public async Task<CertificateSignerResponse?> InactivateCertificateSignerAsync(long signerId, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            update certificate_signers
            set status = 'INACTIVO',
                updated_at = now()
            where id = @signerId
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("signerId", signerId);
        var updatedId = await command.ExecuteScalarAsync(cancellationToken);
        if (updatedId is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, "CERTIFICATE_SIGNER_INACTIVATED", "CERTIFICATE_SIGNER", signerId.ToString(), "'{}'::jsonb", null, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return await GetCertificateSignerByIdAsync(signerId, cancellationToken);
    }

    public async Task<CertificatePreviewResponse?> BuildCertificatePreviewAsync(CertificatePreviewRequest request, CancellationToken cancellationToken = default)
    {
        var issueDate = DateOnly.Parse(request.IssueDate).ToDateTime(TimeOnly.MinValue);
        const string employeeSql = @"
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
                salary.base_salary_amount
            from employees e
            left join lateral (
                select esh.base_salary_amount
                from employee_salary_history esh
                where esh.employee_id = e.id
                  and esh.effective_from <= @issueDate
                  and (esh.effective_to is null or esh.effective_to >= @issueDate)
                order by esh.effective_from desc
                limit 1
            ) salary on true
            where e.id = @employeeId
            limit 1;";
        const string signerSql = @"
            select id, full_name, job_title, signature_path, valid_from, valid_to, status, notes, created_at, updated_at
            from certificate_signers
            where status = 'ACTIVO'
              and valid_from <= @issueDate
              and (valid_to is null or valid_to >= @issueDate)
            order by valid_from desc, id desc
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var employeeCommand = new NpgsqlCommand(employeeSql, connection);
        employeeCommand.Parameters.AddWithValue("employeeId", request.EmployeeId);
        employeeCommand.Parameters.AddWithValue("issueDate", issueDate);

        long employeeId;
        string identificationType;
        string identificationNumber;
        string fullName;
        string employmentStatus;
        string jobTitle;
        string hireDate;
        string? terminationDate;
        string? terminationReason;
        string? contractType;
        decimal? baseSalary;

        await using (var reader = await employeeCommand.ExecuteReaderAsync(cancellationToken))
        {
            if (!await reader.ReadAsync(cancellationToken))
            {
                return null;
            }

            employeeId = reader.GetInt64(reader.GetOrdinal("id"));
            identificationType = reader.GetString(reader.GetOrdinal("identification_type"));
            identificationNumber = reader.GetString(reader.GetOrdinal("identification_number"));
            fullName = reader.GetString(reader.GetOrdinal("full_name"));
            employmentStatus = reader.GetString(reader.GetOrdinal("employment_status"));
            jobTitle = reader.GetString(reader.GetOrdinal("job_title"));
            hireDate = reader.GetDateTime(reader.GetOrdinal("hire_date")).ToString("yyyy-MM-dd");
            terminationDate = reader.IsDBNull(reader.GetOrdinal("termination_date")) ? null : reader.GetDateTime(reader.GetOrdinal("termination_date")).ToString("yyyy-MM-dd");
            terminationReason = reader.IsDBNull(reader.GetOrdinal("termination_reason")) ? null : reader.GetString(reader.GetOrdinal("termination_reason"));
            contractType = reader.IsDBNull(reader.GetOrdinal("contract_type")) ? null : reader.GetString(reader.GetOrdinal("contract_type"));
            baseSalary = reader.IsDBNull(reader.GetOrdinal("base_salary_amount")) ? null : reader.GetDecimal(reader.GetOrdinal("base_salary_amount"));
        }

        if (employmentStatus is not ("ACTIVO" or "RETIRADO"))
        {
            return BuildCertificatePreviewError("EMPLOYEE_NOT_ACTIVE");
        }

        if (employmentStatus == "ACTIVO" && !baseSalary.HasValue)
        {
            return BuildCertificatePreviewError("MISSING_BASE_SALARY");
        }

        if (employmentStatus == "RETIRADO" && string.IsNullOrWhiteSpace(terminationDate))
        {
            return BuildCertificatePreviewError("MISSING_TERMINATION_DATE");
        }

        if (employmentStatus == "RETIRADO" && string.IsNullOrWhiteSpace(terminationReason))
        {
            return BuildCertificatePreviewError("MISSING_TERMINATION_REASON");
        }

        CertificateSignerResponse? signer;
        await using (var signerCommand = new NpgsqlCommand(signerSql, connection))
        {
            signerCommand.Parameters.AddWithValue("issueDate", issueDate);
            await using var reader = await signerCommand.ExecuteReaderAsync(cancellationToken);
            signer = await reader.ReadAsync(cancellationToken) ? ReadCertificateSigner(reader) : null;
        }

        if (signer is null)
        {
            return BuildCertificatePreviewError("MISSING_ACTIVE_SIGNER");
        }

        var purpose = request.Purpose.Trim().ToUpperInvariant();
        var variables = request.Variables
            .Select(variable => new CertificateVariableResponse(
                variable.ConceptCode.Trim().ToUpperInvariant(),
                variable.ConceptLabel.Trim(),
                variable.Amount,
                string.IsNullOrWhiteSpace(variable.Notes) ? null : variable.Notes.Trim()))
            .ToList();
        var certificateType = employmentStatus == "RETIRADO" ? "RETIRADO" : "ACTIVO";
        var previewLines = certificateType == "RETIRADO"
            ? new List<string>
            {
                $"Certificacion laboral retirada para {fullName}",
                $"{identificationType} {identificationNumber}",
                $"Ingreso: {hireDate}",
                $"Retiro: {terminationDate}",
                $"Cargo desempenado: {jobTitle}",
                $"Motivo de retiro: {terminationReason}",
                $"Destino/proposito: {purpose}",
                $"Firmante: {signer.FullName} - {signer.JobTitle}"
            }
            : new List<string>
            {
                $"Certificacion laboral para {fullName}",
                $"{identificationType} {identificationNumber}",
                $"Ingreso: {hireDate}",
                $"Cargo: {jobTitle}",
                $"Salario base: {baseSalary!.Value:0.00}",
                $"Destino/proposito: {purpose}",
                $"Firmante: {signer.FullName} - {signer.JobTitle}"
            };

        if (certificateType == "RETIRADO" && purpose == "CESANTIAS")
        {
            previewLines.Add("Incluye referencia para tramite de cesantias.");
        }

        if (certificateType == "RETIRADO" && purpose == "INTERESADO")
        {
            previewLines.Add("Expedida a solicitud del interesado.");
        }

        if (certificateType == "ACTIVO" && variables.Count > 0)
        {
            previewLines.Add("Variables manuales:");
            previewLines.AddRange(variables.Select(variable => $"{variable.ConceptLabel}: {variable.Amount:0.00}"));
        }

        var snapshot = new Dictionary<string, object?>
        {
            ["employeeId"] = employeeId,
            ["employeeFullName"] = fullName,
            ["identificationType"] = identificationType,
            ["identificationNumber"] = identificationNumber,
            ["employmentStatus"] = employmentStatus,
            ["jobTitle"] = jobTitle,
            ["hireDate"] = hireDate,
            ["terminationDate"] = terminationDate,
            ["terminationReason"] = terminationReason,
            ["contractType"] = contractType,
            ["baseSalary"] = baseSalary,
            ["purpose"] = purpose,
            ["issueDate"] = request.IssueDate,
            ["signerId"] = signer.Id,
            ["signerFullName"] = signer.FullName,
            ["signerJobTitle"] = signer.JobTitle,
            ["variables"] = certificateType == "ACTIVO" ? variables : Array.Empty<CertificateVariableResponse>()
        };

        return new CertificatePreviewResponse(
            employeeId,
            certificateType,
            purpose,
            request.IssueDate,
            fullName,
            identificationType,
            identificationNumber,
            hireDate,
            terminationDate,
            terminationReason,
            jobTitle,
            contractType,
            certificateType == "ACTIVO" ? baseSalary : null,
            signer.Id,
            signer.FullName,
            signer.JobTitle,
            certificateType == "ACTIVO" ? variables : Array.Empty<CertificateVariableResponse>(),
            string.Join("\n", previewLines),
            snapshot);
    }

    public async Task<LaborCertificateResponse> PersistGeneratedCertificateAsync(CertificatePreviewResponse preview, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string nextIdSql = "select nextval(pg_get_serial_sequence('labor_certificates', 'id'));";
        const string insertCertificateSql = @"
            insert into labor_certificates (
                id, certificate_number, employee_id, signer_id, certificate_type, purpose, status,
                snapshot_payload, preview_content, pdf_path, template_version, created_by,
                approved_by, approved_at, generated_at
            )
            values (
                @id, @certificateNumber, @employeeId, @signerId, @certificateType, @purpose, 'GENERADA',
                @snapshotPayload::jsonb, @previewContent, @pdfPath, @templateVersion, @createdBy,
                @approvedBy, now(), now()
            )
            returning created_at, approved_at, generated_at;";
        const string insertVariableSql = @"
            insert into labor_certificate_variables (certificate_id, concept_code, concept_label, amount, notes)
            values (@certificateId, @conceptCode, @conceptLabel, @amount, @notes);";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        long id;
        await using (var nextIdCommand = new NpgsqlCommand(nextIdSql, connection, transaction))
        {
            id = (long)(await nextIdCommand.ExecuteScalarAsync(cancellationToken)
                ?? throw new InvalidOperationException("No fue posible generar consecutivo de certificado."));
        }

        var templateVersion = "I4-MVP-1";
        var certificateNumber = $"SG-I4-{DateTime.UtcNow:yyyyMMdd}-{id:000000}";
        var snapshot = new Dictionary<string, object?>(preview.Snapshot, StringComparer.OrdinalIgnoreCase)
        {
            ["certificateNumber"] = certificateNumber,
            ["templateVersion"] = templateVersion,
            ["approvedBy"] = actorUsername,
            ["generatedBy"] = actorUsername
        };
        var pdfFileName = $"{certificateNumber}.pdf";
        var pdfPath = GetCertificatePdfPath(pdfFileName);
        Directory.CreateDirectory(Path.GetDirectoryName(pdfPath)!);
        await File.WriteAllBytesAsync(pdfPath, BuildCertificatePdf(preview, certificateNumber), cancellationToken);

        DateTimeOffset createdAt;
        DateTimeOffset approvedAt;
        DateTimeOffset generatedAt;
        try
        {
            await using (var insertCommand = new NpgsqlCommand(insertCertificateSql, connection, transaction))
            {
                insertCommand.Parameters.AddWithValue("id", id);
                insertCommand.Parameters.AddWithValue("certificateNumber", certificateNumber);
                insertCommand.Parameters.AddWithValue("employeeId", preview.EmployeeId);
                insertCommand.Parameters.AddWithValue("signerId", preview.SignerId);
                insertCommand.Parameters.AddWithValue("certificateType", preview.CertificateType);
                insertCommand.Parameters.AddWithValue("purpose", preview.Purpose);
                insertCommand.Parameters.Add("snapshotPayload", NpgsqlDbType.Jsonb).Value = JsonSerializer.Serialize(snapshot);
                insertCommand.Parameters.AddWithValue("previewContent", preview.PreviewContent);
                insertCommand.Parameters.AddWithValue("pdfPath", pdfPath);
                insertCommand.Parameters.AddWithValue("templateVersion", templateVersion);
                insertCommand.Parameters.AddWithValue("createdBy", actorUsername);
                insertCommand.Parameters.AddWithValue("approvedBy", actorUsername);

                await using var reader = await insertCommand.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    throw new InvalidOperationException("No fue posible crear el certificado laboral.");
                }

                createdAt = new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at")));
                approvedAt = new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("approved_at")));
                generatedAt = new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("generated_at")));
            }

            foreach (var variable in preview.Variables)
            {
                await using var variableCommand = new NpgsqlCommand(insertVariableSql, connection, transaction);
                variableCommand.Parameters.AddWithValue("certificateId", id);
                variableCommand.Parameters.AddWithValue("conceptCode", variable.ConceptCode);
                variableCommand.Parameters.AddWithValue("conceptLabel", variable.ConceptLabel);
                variableCommand.Parameters.AddWithValue("amount", variable.Amount);
                variableCommand.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(variable.Notes) ? DBNull.Value : variable.Notes;
                await variableCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            await InsertAuditLogAsync(
                connection,
                transaction,
                actorUserId,
                actorUsername,
                "LABOR_CERTIFICATE_GENERATED",
                "LABOR_CERTIFICATE",
                id.ToString(System.Globalization.CultureInfo.InvariantCulture),
                "jsonb_build_object('certificateNumber', @certificateNumber, 'employeeId', @employeeId, 'certificateType', @certificateType)",
                command =>
                {
                    command.Parameters.AddWithValue("certificateNumber", certificateNumber);
                    command.Parameters.AddWithValue("employeeId", preview.EmployeeId);
                    command.Parameters.AddWithValue("certificateType", preview.CertificateType);
                },
                cancellationToken);

            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            if (File.Exists(pdfPath))
            {
                File.Delete(pdfPath);
            }

            throw;
        }

        return new LaborCertificateResponse(
            id,
            certificateNumber,
            preview.EmployeeId,
            preview.SignerId,
            preview.CertificateType,
            preview.Purpose,
            "GENERADA",
            preview.IssueDate,
            preview.EmployeeFullName,
            preview.SignerFullName,
            preview.PreviewContent,
            pdfFileName,
            templateVersion,
            actorUsername,
            actorUsername,
            createdAt,
            approvedAt,
            generatedAt,
            snapshot);
    }

    public async Task<IReadOnlyList<LaborCertificateResponse>> GetCertificatesAsync(long? employeeId, string? type, string? status, string? from, string? to, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select id, certificate_number, employee_id, signer_id, certificate_type, purpose, status,
                   snapshot_payload::text as snapshot_payload, preview_content, pdf_path, template_version,
                   created_by, approved_by, created_at, approved_at, generated_at
            from labor_certificates
            where (@employeeId::bigint is null or employee_id = @employeeId)
              and (@type::text is null or certificate_type = @type)
              and (@status::text is null or status = @status)
              and (@from::date is null or created_at::date >= @from)
              and (@to::date is null or created_at::date <= @to)
            order by created_at desc, id desc
            limit 200;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("employeeId", NpgsqlDbType.Bigint).Value = employeeId.HasValue ? employeeId.Value : DBNull.Value;
        command.Parameters.Add("type", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(type) ? DBNull.Value : type;
        command.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status;
        command.Parameters.Add("from", NpgsqlDbType.Date).Value = string.IsNullOrWhiteSpace(from) ? DBNull.Value : DateOnly.Parse(from).ToDateTime(TimeOnly.MinValue);
        command.Parameters.Add("to", NpgsqlDbType.Date).Value = string.IsNullOrWhiteSpace(to) ? DBNull.Value : DateOnly.Parse(to).ToDateTime(TimeOnly.MinValue);

        var certificates = new List<LaborCertificateResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            certificates.Add(ReadLaborCertificate(reader, reader.GetInt64(reader.GetOrdinal("id")), reader.GetString(reader.GetOrdinal("status"))));
        }

        return certificates;
    }

    public async Task<LaborCertificateResponse?> GetCertificateByIdAsync(long certificateId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select id, certificate_number, employee_id, signer_id, certificate_type, purpose, status,
                   snapshot_payload::text as snapshot_payload, preview_content, pdf_path, template_version,
                   created_by, approved_by, created_at, approved_at, generated_at
            from labor_certificates
            where id = @certificateId
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("certificateId", certificateId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken)
            ? ReadLaborCertificate(reader, reader.GetInt64(reader.GetOrdinal("id")), reader.GetString(reader.GetOrdinal("status")))
            : null;
    }

    public async Task<(string FileName, string FilePath)?> GetCertificateDownloadAsync(long certificateId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select certificate_number, pdf_path
            from labor_certificates
            where id = @certificateId
              and status in ('GENERADA', 'ANULADA')
              and pdf_path is not null
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("certificateId", certificateId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var certificateNumber = reader.GetString(reader.GetOrdinal("certificate_number"));
        var pdfPath = reader.GetString(reader.GetOrdinal("pdf_path"));
        return ($"{certificateNumber}.pdf", pdfPath);
    }

    public async Task<LaborCertificateResponse?> AnnulCertificateAsync(long certificateId, string reason, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string selectSql = @"
            select certificate_number, employee_id, signer_id, certificate_type, purpose, status,
                   snapshot_payload::text as snapshot_payload, preview_content, pdf_path, template_version,
                   created_by, approved_by, created_at, approved_at, generated_at
            from labor_certificates
            where id = @certificateId
              and status = 'GENERADA'
            for update;";
        const string updateSql = @"
            update labor_certificates
            set status = 'ANULADA',
                annulment_reason = @reason,
                annulled_by = @actorUsername,
                annulled_at = now(),
                updated_at = now()
            where id = @certificateId;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        LaborCertificateResponse? certificate;
        await using (var selectCommand = new NpgsqlCommand(selectSql, connection, transaction))
        {
            selectCommand.Parameters.AddWithValue("certificateId", certificateId);
            await using var reader = await selectCommand.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                return null;
            }

            certificate = ReadLaborCertificate(reader, certificateId, "ANULADA");
        }

        await using (var updateCommand = new NpgsqlCommand(updateSql, connection, transaction))
        {
            updateCommand.Parameters.AddWithValue("certificateId", certificateId);
            updateCommand.Parameters.AddWithValue("reason", reason.Trim());
            updateCommand.Parameters.AddWithValue("actorUsername", actorUsername);
            await updateCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await InsertAuditLogAsync(
            connection,
            transaction,
            actorUserId,
            actorUsername,
            "LABOR_CERTIFICATE_ANNULLED",
            "LABOR_CERTIFICATE",
            certificateId.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "jsonb_build_object('previousStatus', 'GENERADA', 'status', 'ANULADA', 'reason', @reason, 'certificateNumber', @certificateNumber)",
            command =>
            {
                command.Parameters.AddWithValue("reason", reason.Trim());
                command.Parameters.AddWithValue("certificateNumber", certificate.CertificateNumber);
            },
            cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return certificate;
    }

    public async Task<IReadOnlyList<LaborCertificateHistoryResponse>> GetCertificateHistoryAsync(long certificateId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select event_type, actor_username, created_at, detail::text as detail
            from audit_log
            where entity_type = 'LABOR_CERTIFICATE'
              and entity_id = @certificateId
            order by created_at;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("certificateId", certificateId.ToString(System.Globalization.CultureInfo.InvariantCulture));
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var history = new List<LaborCertificateHistoryResponse>();
        while (await reader.ReadAsync(cancellationToken))
        {
            history.Add(new LaborCertificateHistoryResponse(
                reader.GetString(reader.GetOrdinal("event_type")),
                reader.GetString(reader.GetOrdinal("actor_username")),
                new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
                JsonSerializer.Deserialize<Dictionary<string, object?>>(reader.GetString(reader.GetOrdinal("detail"))) ?? new Dictionary<string, object?>()));
        }

        return history;
    }

    public async Task<ServicePositionResponse> CreateServicePositionAsync(UpsertServicePositionRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string insertSql = @"
            insert into service_positions (code, name, client_text, location_text, notes)
            values (@code, @name, @clientText, @locationText, @notes)
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var insertCommand = new NpgsqlCommand(insertSql, connection, transaction);
        AddServicePositionParameters(insertCommand, request);
        var id = (long)(await insertCommand.ExecuteScalarAsync(cancellationToken)
            ?? throw new InvalidOperationException("No fue posible crear el puesto de servicio."));
        await InsertAuditLogAsync(
            connection,
            transaction,
            actorUserId,
            actorUsername,
            "SERVICE_POSITION_CREATED",
            "SERVICE_POSITION",
            id.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "jsonb_build_object('code', @code, 'name', @name, 'status', 'ACTIVO', 'client_text', @clientText, 'location_text', @locationText)",
            command => AddServicePositionAuditParameters(command, request),
            cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await GetServicePositionByIdAsync(id, cancellationToken)
            ?? throw new InvalidOperationException("No fue posible leer el puesto de servicio creado.");
    }

    public async Task<ServicePositionResponse?> UpdateServicePositionAsync(long positionId, UpsertServicePositionRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string selectSql = @"
            select code, name, client_text, location_text, status, notes
            from service_positions
            where id = @positionId
            for update;";
        const string sql = @"
            update service_positions
            set code = @code,
                name = @name,
                client_text = @clientText,
                location_text = @locationText,
                notes = @notes,
                updated_at = now()
            where id = @positionId
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        string? previousCode;
        string previousName;
        string? previousClientText;
        string? previousLocationText;
        string previousStatus;
        string? previousNotes;
        await using (var selectCommand = new NpgsqlCommand(selectSql, connection, transaction))
        {
            selectCommand.Parameters.AddWithValue("positionId", positionId);
            await using var reader = await selectCommand.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }

            previousCode = reader.IsDBNull(reader.GetOrdinal("code")) ? null : reader.GetString(reader.GetOrdinal("code"));
            previousName = reader.GetString(reader.GetOrdinal("name"));
            previousClientText = reader.IsDBNull(reader.GetOrdinal("client_text")) ? null : reader.GetString(reader.GetOrdinal("client_text"));
            previousLocationText = reader.IsDBNull(reader.GetOrdinal("location_text")) ? null : reader.GetString(reader.GetOrdinal("location_text"));
            previousStatus = reader.GetString(reader.GetOrdinal("status"));
            previousNotes = reader.IsDBNull(reader.GetOrdinal("notes")) ? null : reader.GetString(reader.GetOrdinal("notes"));
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("positionId", positionId);
        AddServicePositionParameters(command, request);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        if (result is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        await InsertAuditLogAsync(
            connection,
            transaction,
            actorUserId,
            actorUsername,
            "SERVICE_POSITION_UPDATED",
            "SERVICE_POSITION",
            positionId.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "jsonb_build_object('previous_code', @previousCode, 'previous_name', @previousName, 'previous_client_text', @previousClientText, 'previous_location_text', @previousLocationText, 'previous_status', @previousStatus, 'previous_notes', @previousNotes, 'code', @code, 'name', @name, 'client_text', @clientText, 'location_text', @locationText, 'status', @status, 'notes', @notes)",
            auditCommand =>
            {
                auditCommand.Parameters.Add("previousCode", NpgsqlDbType.Text).Value = previousCode is null ? DBNull.Value : previousCode;
                auditCommand.Parameters.AddWithValue("previousName", previousName);
                auditCommand.Parameters.Add("previousClientText", NpgsqlDbType.Text).Value = previousClientText is null ? DBNull.Value : previousClientText;
                auditCommand.Parameters.Add("previousLocationText", NpgsqlDbType.Text).Value = previousLocationText is null ? DBNull.Value : previousLocationText;
                auditCommand.Parameters.AddWithValue("previousStatus", previousStatus);
                auditCommand.Parameters.Add("previousNotes", NpgsqlDbType.Text).Value = previousNotes is null ? DBNull.Value : previousNotes;
                AddServicePositionAuditParameters(auditCommand, request);
                auditCommand.Parameters.AddWithValue("status", previousStatus);
            },
            cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await GetServicePositionByIdAsync((long)result, cancellationToken);
    }

    public async Task<ServicePositionResponse?> InactivateServicePositionAsync(long positionId, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string selectSql = @"
            select status
            from service_positions
            where id = @positionId
            for update;";
        const string sql = @"
            update service_positions
            set status = 'INACTIVO',
                updated_at = now()
            where id = @positionId
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        string previousStatus;
        await using (var selectCommand = new NpgsqlCommand(selectSql, connection, transaction))
        {
            selectCommand.Parameters.AddWithValue("positionId", positionId);
            var currentStatus = await selectCommand.ExecuteScalarAsync(cancellationToken) as string;
            if (currentStatus is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }

            previousStatus = currentStatus;
        }

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("positionId", positionId);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        if (result is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        await InsertAuditLogAsync(
            connection,
            transaction,
            actorUserId,
            actorUsername,
            "SERVICE_POSITION_INACTIVATED",
            "SERVICE_POSITION",
            positionId.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "jsonb_build_object('previous_status', @previousStatus, 'status', 'INACTIVO')",
            auditCommand => auditCommand.Parameters.AddWithValue("previousStatus", previousStatus),
            cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await GetServicePositionByIdAsync((long)result, cancellationToken);
    }

    public async Task<IReadOnlyList<PositionAssignmentResponse>> GetEmployeePositionAssignmentsAsync(long employeeId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                epa.id,
                epa.employee_id,
                epa.position_id,
                sp.name as position_name,
                sp.code as position_code,
                sp.client_text,
                epa.start_date,
                epa.end_date,
                epa.status,
                epa.change_reason,
                epa.notes,
                epa.created_by,
                epa.created_at,
                epa.updated_at
            from employee_position_assignments epa
            join service_positions sp on sp.id = epa.position_id
            where epa.employee_id = @employeeId
            order by epa.start_date desc, epa.id desc;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("employeeId", employeeId);

        var assignments = new List<PositionAssignmentResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            assignments.Add(ReadPositionAssignment(reader));
        }

        return assignments;
    }

    public async Task<IReadOnlyList<PositionAssignmentResponse>> GetPositionAssignmentsAsync(long positionId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                epa.id,
                epa.employee_id,
                epa.position_id,
                sp.name as position_name,
                sp.code as position_code,
                sp.client_text,
                epa.start_date,
                epa.end_date,
                epa.status,
                epa.change_reason,
                epa.notes,
                epa.created_by,
                epa.created_at,
                epa.updated_at
            from employee_position_assignments epa
            join service_positions sp on sp.id = epa.position_id
            where epa.position_id = @positionId
            order by
                case when epa.status = 'VIGENTE' then 0 else 1 end,
                epa.start_date desc,
                epa.id desc;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("positionId", positionId);

        var assignments = new List<PositionAssignmentResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            assignments.Add(ReadPositionAssignment(reader));
        }

        return assignments;
    }

    public async Task<PositionAssignmentResponse?> GetPositionAssignmentByIdAsync(long assignmentId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                epa.id,
                epa.employee_id,
                epa.position_id,
                sp.name as position_name,
                sp.code as position_code,
                sp.client_text,
                epa.start_date,
                epa.end_date,
                epa.status,
                epa.change_reason,
                epa.notes,
                epa.created_by,
                epa.created_at,
                epa.updated_at
            from employee_position_assignments epa
            join service_positions sp on sp.id = epa.position_id
            where epa.id = @assignmentId
            limit 1;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("assignmentId", assignmentId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? ReadPositionAssignment(reader) : null;
    }

    public async Task<string> CreatePositionAssignmentAsync(long employeeId, CreatePositionAssignmentRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string employeeExistsSql = "select exists(select 1 from employees where id = @employeeId);";
        const string positionStatusSql = "select status from service_positions where id = @positionId;";
        const string insertSql = @"
            insert into employee_position_assignments (
                employee_id, position_id, start_date, status, change_reason, notes, created_by
            )
            values (
                @employeeId, @positionId, @startDate, 'VIGENTE', @changeReason, @notes, @createdBy
            )
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using (var employeeCommand = new NpgsqlCommand(employeeExistsSql, connection, transaction))
        {
            employeeCommand.Parameters.AddWithValue("employeeId", employeeId);
            if ((bool)(await employeeCommand.ExecuteScalarAsync(cancellationToken) ?? false) is false)
            {
                await transaction.RollbackAsync(cancellationToken);
                return "EMPLOYEE_NOT_FOUND";
            }
        }

        await using (var positionCommand = new NpgsqlCommand(positionStatusSql, connection, transaction))
        {
            positionCommand.Parameters.AddWithValue("positionId", request.PositionId);
            var status = await positionCommand.ExecuteScalarAsync(cancellationToken) as string;
            if (status is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return "POSITION_NOT_FOUND";
            }
            if (status != "ACTIVO")
            {
                await transaction.RollbackAsync(cancellationToken);
                return "INACTIVE_POSITION";
            }
        }

        try
        {
            await using var insertCommand = new NpgsqlCommand(insertSql, connection, transaction);
            insertCommand.Parameters.AddWithValue("employeeId", employeeId);
            insertCommand.Parameters.AddWithValue("positionId", request.PositionId);
            insertCommand.Parameters.AddWithValue("startDate", DateOnly.Parse(request.StartDate).ToDateTime(TimeOnly.MinValue));
            insertCommand.Parameters.Add("changeReason", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.ChangeReason) ? DBNull.Value : request.ChangeReason.Trim();
            insertCommand.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
            insertCommand.Parameters.AddWithValue("createdBy", actorUsername);
            var assignmentId = (long)(await insertCommand.ExecuteScalarAsync(cancellationToken)
                ?? throw new InvalidOperationException("No fue posible crear la asignacion."));
            await InsertAuditLogAsync(
                connection,
                transaction,
                actorUserId,
                actorUsername,
                "POSITION_ASSIGNMENT_CREATED",
                "POSITION_ASSIGNMENT",
                assignmentId.ToString(System.Globalization.CultureInfo.InvariantCulture),
                "jsonb_build_object('employee_id', @employeeId, 'position_id', @positionId, 'start_date', @startDateText, 'status', 'VIGENTE', 'change_reason', @changeReason, 'notes', @notes)",
                auditCommand =>
                {
                    auditCommand.Parameters.AddWithValue("employeeId", employeeId);
                    auditCommand.Parameters.AddWithValue("positionId", request.PositionId);
                    auditCommand.Parameters.AddWithValue("startDateText", request.StartDate);
                    auditCommand.Parameters.Add("changeReason", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.ChangeReason) ? DBNull.Value : request.ChangeReason.Trim();
                    auditCommand.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
                },
                cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return assignmentId.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }
        catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            await transaction.RollbackAsync(cancellationToken);
            return "ACTIVE_ASSIGNMENT_EXISTS";
        }
    }

    public async Task<string> FinalizePositionAssignmentAsync(long assignmentId, FinalizePositionAssignmentRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string selectSql = @"
            select employee_id, position_id, start_date, end_date, status
            from employee_position_assignments
            where id = @assignmentId
            for update;";
        const string updateSql = @"
            update employee_position_assignments
            set end_date = @endDate,
                status = 'FINALIZADA',
                change_reason = coalesce(@changeReason, change_reason),
                notes = coalesce(@notes, notes),
                updated_at = now()
            where id = @assignmentId
            returning id;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        long employeeId;
        long positionId;
        DateTime startDate;
        DateTime? previousEndDate;
        string status;
        await using (var selectCommand = new NpgsqlCommand(selectSql, connection, transaction))
        {
            selectCommand.Parameters.AddWithValue("assignmentId", assignmentId);
            await using var reader = await selectCommand.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return "NOT_FOUND";
            }

            employeeId = reader.GetInt64(reader.GetOrdinal("employee_id"));
            positionId = reader.GetInt64(reader.GetOrdinal("position_id"));
            startDate = reader.GetDateTime(reader.GetOrdinal("start_date"));
            previousEndDate = reader.IsDBNull(reader.GetOrdinal("end_date")) ? null : reader.GetDateTime(reader.GetOrdinal("end_date"));
            status = reader.GetString(reader.GetOrdinal("status"));
        }

        if (status != "VIGENTE")
        {
            await transaction.RollbackAsync(cancellationToken);
            return "INVALID_STATE";
        }

        var endDate = DateOnly.Parse(request.EndDate).ToDateTime(TimeOnly.MinValue);
        if (endDate < startDate)
        {
            await transaction.RollbackAsync(cancellationToken);
            return "INVALID_DATE";
        }

        await using var updateCommand = new NpgsqlCommand(updateSql, connection, transaction);
        updateCommand.Parameters.AddWithValue("assignmentId", assignmentId);
        updateCommand.Parameters.AddWithValue("endDate", endDate);
        updateCommand.Parameters.Add("changeReason", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.ChangeReason) ? DBNull.Value : request.ChangeReason.Trim();
        updateCommand.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
        await updateCommand.ExecuteScalarAsync(cancellationToken);
        await InsertAuditLogAsync(
            connection,
            transaction,
            actorUserId,
            actorUsername,
            "POSITION_ASSIGNMENT_FINALIZED",
            "POSITION_ASSIGNMENT",
            assignmentId.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "jsonb_build_object('employee_id', @employeeId, 'position_id', @positionId, 'previous_status', @previousStatus, 'previous_end_date', @previousEndDate, 'end_date', @endDateText, 'status', 'FINALIZADA', 'change_reason', @changeReason, 'notes', @notes)",
            auditCommand =>
            {
                auditCommand.Parameters.AddWithValue("employeeId", employeeId);
                auditCommand.Parameters.AddWithValue("positionId", positionId);
                auditCommand.Parameters.AddWithValue("previousStatus", status);
                auditCommand.Parameters.Add("previousEndDate", NpgsqlDbType.Text).Value = previousEndDate is null ? DBNull.Value : previousEndDate.Value.ToString("yyyy-MM-dd");
                auditCommand.Parameters.AddWithValue("endDateText", request.EndDate);
                auditCommand.Parameters.Add("changeReason", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.ChangeReason) ? DBNull.Value : request.ChangeReason.Trim();
                auditCommand.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
            },
            cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return "FINALIZED";
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
                current_assignment.position_id as current_service_position_id,
                current_assignment.position_name as current_service_position_name,
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
            left join lateral (
                select epa.position_id, sp.name as position_name
                from employee_position_assignments epa
                join service_positions sp on sp.id = epa.position_id
                where epa.employee_id = e.id
                  and epa.status = 'VIGENTE'
                order by epa.start_date desc, epa.id desc
                limit 1
            ) current_assignment on true
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

        var employee = new EmployeeDetailResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetString(reader.GetOrdinal("identification_type")),
            reader.GetString(reader.GetOrdinal("identification_number")),
            reader.GetString(reader.GetOrdinal("full_name")),
            reader.GetString(reader.GetOrdinal("employment_status")),
            reader.GetString(reader.GetOrdinal("job_title")),
            reader.IsDBNull(reader.GetOrdinal("hire_date"))
                ? null
                : reader.GetDateTime(reader.GetOrdinal("hire_date")).ToString("yyyy-MM-dd"),
            reader.IsDBNull(reader.GetOrdinal("termination_date"))
                ? null
                : reader.GetDateTime(reader.GetOrdinal("termination_date")).ToString("yyyy-MM-dd"),
            reader.IsDBNull(reader.GetOrdinal("termination_reason"))
                ? null
                : reader.GetString(reader.GetOrdinal("termination_reason")),
            reader.IsDBNull(reader.GetOrdinal("contract_type"))
                ? null
                : reader.GetString(reader.GetOrdinal("contract_type")),
            reader.IsDBNull(reader.GetOrdinal("current_service_position_text"))
                ? null
                : reader.GetString(reader.GetOrdinal("current_service_position_text")),
            reader.IsDBNull(reader.GetOrdinal("current_service_position_id"))
                ? null
                : reader.GetInt64(reader.GetOrdinal("current_service_position_id")),
            reader.IsDBNull(reader.GetOrdinal("current_service_position_name"))
                ? null
                : reader.GetString(reader.GetOrdinal("current_service_position_name")),
            reader.IsDBNull(reader.GetOrdinal("notes"))
                ? null
                : reader.GetString(reader.GetOrdinal("notes")),
            reader.GetString(reader.GetOrdinal("record_status")),
            !includeSalary || reader.IsDBNull(reader.GetOrdinal("base_salary_amount"))
                ? null
                : reader.GetDecimal(reader.GetOrdinal("base_salary_amount")),
            !includeSalary || reader.IsDBNull(reader.GetOrdinal("effective_from"))
                ? null
                : reader.GetDateTime(reader.GetOrdinal("effective_from")).ToString("yyyy-MM-dd"),
            !includeSalary || reader.IsDBNull(reader.GetOrdinal("effective_to"))
                ? null
                : reader.GetDateTime(reader.GetOrdinal("effective_to")).ToString("yyyy-MM-dd"),
            !includeSalary || reader.IsDBNull(reader.GetOrdinal("salary_source"))
                ? "DESCONOCIDA"
                : reader.GetString(reader.GetOrdinal("salary_source")),
            Array.Empty<EmployeeChangeResponse>());

        await reader.CloseAsync();
        var changeHistory = await GetEmployeeChangeHistoryAsync(connection, employeeId, cancellationToken);
        return employee with { ChangeHistory = changeHistory };
    }

    private static async Task<IReadOnlyList<EmployeeChangeResponse>> GetEmployeeChangeHistoryAsync(NpgsqlConnection connection, long employeeId, CancellationToken cancellationToken)
    {
        const string sql = @"
            select id, actor_username, field_name, previous_value, new_value, changed_at
            from employee_change_log
            where employee_id = @employeeId
            order by changed_at desc, id desc
            limit 50;";

        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("employeeId", employeeId);

        var changes = new List<EmployeeChangeResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            changes.Add(new EmployeeChangeResponse(
                reader.GetInt64(reader.GetOrdinal("id")),
                reader.GetString(reader.GetOrdinal("actor_username")),
                reader.GetString(reader.GetOrdinal("field_name")),
                reader.IsDBNull(reader.GetOrdinal("previous_value")) ? null : reader.GetString(reader.GetOrdinal("previous_value")),
                reader.IsDBNull(reader.GetOrdinal("new_value")) ? null : reader.GetString(reader.GetOrdinal("new_value")),
                new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("changed_at")))));
        }

        return changes;
    }

    public async Task<bool> UpdateEmployeeAsync(long employeeId, UpdateEmployeeRequest request, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string selectSql = @"
            select full_name, employment_status, job_title, hire_date, termination_date, termination_reason, contract_type, notes
            from employees
            where id = @employeeId
            for update;";

        const string updateSql = @"
            update employees
            set full_name = @fullName,
                employment_status = @employmentStatus,
                job_title = @jobTitle,
                hire_date = @hireDate,
                termination_date = @terminationDate,
                termination_reason = @terminationReason,
                contract_type = @contractType,
                notes = @notes,
                source = 'MANUAL',
                updated_at = now()
            where id = @employeeId;";

        const string auditSql = @"
            insert into employee_change_log (employee_id, actor_username, field_name, previous_value, new_value)
            values (@employeeId, @actorUsername, @fieldName, @previousValue, @newValue);";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        string currentFullName;
        string currentEmploymentStatus;
        string currentJobTitle;
        DateOnly currentHireDate;
        DateOnly? currentTerminationDate;
        string? currentTerminationReason;
        string? currentContractType;
        string? currentNotes;
        await using (var selectCommand = new NpgsqlCommand(selectSql, connection, transaction))
        {
            selectCommand.Parameters.AddWithValue("employeeId", employeeId);
            await using var reader = await selectCommand.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return false;
            }

            currentFullName = reader.GetString(reader.GetOrdinal("full_name"));
            currentEmploymentStatus = reader.GetString(reader.GetOrdinal("employment_status"));
            currentJobTitle = reader.GetString(reader.GetOrdinal("job_title"));
            currentHireDate = DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("hire_date")));
            currentTerminationDate = reader.IsDBNull(reader.GetOrdinal("termination_date")) ? null : DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("termination_date")));
            currentTerminationReason = reader.IsDBNull(reader.GetOrdinal("termination_reason")) ? null : reader.GetString(reader.GetOrdinal("termination_reason"));
            currentContractType = reader.IsDBNull(reader.GetOrdinal("contract_type")) ? null : reader.GetString(reader.GetOrdinal("contract_type"));
            currentNotes = reader.IsDBNull(reader.GetOrdinal("notes")) ? null : reader.GetString(reader.GetOrdinal("notes"));
        }

        var fullName = request.FullName.Trim();
        var jobTitle = request.JobTitle.Trim();
        var hireDate = DateOnly.Parse(request.HireDate);
        var terminationDate = string.IsNullOrWhiteSpace(request.TerminationDate) ? (DateOnly?)null : DateOnly.Parse(request.TerminationDate);
        var terminationReason = string.IsNullOrWhiteSpace(request.TerminationReason) ? null : request.TerminationReason.Trim();
        var contractType = string.IsNullOrWhiteSpace(request.ContractType) ? null : request.ContractType.Trim();
        var notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim();
        if (terminationDate.HasValue && terminationDate < hireDate)
        {
            throw new ArgumentException("Termination date cannot be before hire date.");
        }

        var changes = new (string FieldName, string? PreviousValue, string? NewValue)[]
        {
            ("full_name", currentFullName, fullName),
            ("employment_status", currentEmploymentStatus, request.EmploymentStatus),
            ("job_title", currentJobTitle, jobTitle),
            ("hire_date", currentHireDate.ToString("yyyy-MM-dd"), hireDate.ToString("yyyy-MM-dd")),
            ("termination_date", currentTerminationDate?.ToString("yyyy-MM-dd"), terminationDate?.ToString("yyyy-MM-dd")),
            ("termination_reason", currentTerminationReason, terminationReason),
            ("contract_type", currentContractType, contractType),
            ("notes", currentNotes, notes)
        }.Where(change => !string.Equals(change.PreviousValue, change.NewValue, StringComparison.Ordinal)).ToArray();

        await using (var updateCommand = new NpgsqlCommand(updateSql, connection, transaction))
        {
            updateCommand.Parameters.AddWithValue("employeeId", employeeId);
            updateCommand.Parameters.AddWithValue("fullName", fullName);
            updateCommand.Parameters.AddWithValue("employmentStatus", request.EmploymentStatus);
            updateCommand.Parameters.AddWithValue("jobTitle", jobTitle);
            updateCommand.Parameters.AddWithValue("hireDate", hireDate.ToDateTime(TimeOnly.MinValue));
            updateCommand.Parameters.Add("terminationDate", NpgsqlDbType.Date).Value = terminationDate.HasValue ? terminationDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value;
            updateCommand.Parameters.Add("terminationReason", NpgsqlDbType.Text).Value = terminationReason is null ? DBNull.Value : terminationReason;
            updateCommand.Parameters.Add("contractType", NpgsqlDbType.Text).Value = contractType is null ? DBNull.Value : contractType;
            updateCommand.Parameters.Add("notes", NpgsqlDbType.Text).Value = notes is null ? DBNull.Value : notes;
            await updateCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        foreach (var change in changes)
        {
            await using var auditCommand = new NpgsqlCommand(auditSql, connection, transaction);
            auditCommand.Parameters.AddWithValue("employeeId", employeeId);
            auditCommand.Parameters.AddWithValue("actorUsername", actorUsername);
            auditCommand.Parameters.AddWithValue("fieldName", change.FieldName);
            auditCommand.Parameters.Add("previousValue", NpgsqlDbType.Text).Value = change.PreviousValue is null ? DBNull.Value : change.PreviousValue;
            auditCommand.Parameters.Add("newValue", NpgsqlDbType.Text).Value = change.NewValue is null ? DBNull.Value : change.NewValue;
            await auditCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        if (request.CurrentBaseSalary.HasValue && DateOnly.TryParse(request.SalaryEffectiveFrom, out var salaryEffectiveFrom))
        {
            await VersionEmployeeSalaryAsync(connection, transaction, employeeId, request.CurrentBaseSalary.Value, salaryEffectiveFrom, actorUsername, cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return true;
    }

    private static async Task VersionEmployeeSalaryAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, long employeeId, decimal newSalary, DateOnly effectiveFrom, string actorUsername, CancellationToken cancellationToken)
    {
        const string currentSql = @"
            select base_salary_amount, effective_from
            from employee_salary_history
            where employee_id = @employeeId and effective_to is null
            for update;";
        const string closeSql = "update employee_salary_history set effective_to = @effectiveTo where employee_id = @employeeId and effective_to is null;";
        const string insertSql = @"
            insert into employee_salary_history (employee_id, base_salary_amount, effective_from, source)
            values (@employeeId, @newSalary, @effectiveFrom, 'MANUAL');";
        const string auditSql = @"
            insert into employee_change_log (employee_id, actor_username, field_name, previous_value, new_value)
            values (@employeeId, @actorUsername, 'base_salary_amount', @previousValue, @newValue);";

        decimal? currentSalary = null;
        DateOnly? currentEffectiveFrom = null;
        await using (var currentCommand = new NpgsqlCommand(currentSql, connection, transaction))
        {
            currentCommand.Parameters.AddWithValue("employeeId", employeeId);
            await using var reader = await currentCommand.ExecuteReaderAsync(cancellationToken);
            if (await reader.ReadAsync(cancellationToken))
            {
                currentSalary = reader.GetDecimal(reader.GetOrdinal("base_salary_amount"));
                currentEffectiveFrom = DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("effective_from")));
            }
        }

        if (currentSalary == newSalary)
        {
            return;
        }
        if (currentEffectiveFrom.HasValue && effectiveFrom <= currentEffectiveFrom.Value)
        {
            throw new ArgumentException("New salary effective date must be after current salary start.");
        }

        if (currentEffectiveFrom.HasValue)
        {
            await using var closeCommand = new NpgsqlCommand(closeSql, connection, transaction);
            closeCommand.Parameters.AddWithValue("employeeId", employeeId);
            closeCommand.Parameters.AddWithValue("effectiveTo", effectiveFrom.AddDays(-1).ToDateTime(TimeOnly.MinValue));
            await closeCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var insertCommand = new NpgsqlCommand(insertSql, connection, transaction))
        {
            insertCommand.Parameters.AddWithValue("employeeId", employeeId);
            insertCommand.Parameters.AddWithValue("newSalary", newSalary);
            insertCommand.Parameters.AddWithValue("effectiveFrom", effectiveFrom.ToDateTime(TimeOnly.MinValue));
            await insertCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await using var auditCommand = new NpgsqlCommand(auditSql, connection, transaction);
        auditCommand.Parameters.AddWithValue("employeeId", employeeId);
        auditCommand.Parameters.AddWithValue("actorUsername", actorUsername);
        auditCommand.Parameters.Add("previousValue", NpgsqlDbType.Text).Value = currentSalary?.ToString() ?? (object)DBNull.Value;
        auditCommand.Parameters.AddWithValue("newValue", newSalary.ToString());
        await auditCommand.ExecuteNonQueryAsync(cancellationToken);
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

    public async Task<IReadOnlyList<ImportBatchRowResponse>> GetImportBatchRowsAsync(long batchId, string? classification, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select
                id,
                row_number,
                classification,
                identification_type,
                identification_number,
                normalized_payload::text,
                source_payload::text
            from import_batch_rows
            where import_batch_id = @batchId
              and (@classification is null or classification = @classification)
            order by row_number;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("batchId", batchId);
        command.Parameters.Add("classification", NpgsqlDbType.Text).Value = classification is null ? DBNull.Value : classification;

        var rows = new List<ImportBatchRowResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new ImportBatchRowResponse(
                reader.GetInt64(reader.GetOrdinal("id")),
                reader.GetInt32(reader.GetOrdinal("row_number")),
                reader.GetString(reader.GetOrdinal("classification")),
                reader.GetString(reader.GetOrdinal("identification_type")),
                reader.IsDBNull(reader.GetOrdinal("identification_number")) ? null : reader.GetString(reader.GetOrdinal("identification_number")),
                JsonSerializer.Deserialize<Dictionary<string, string?>>(reader.GetString(reader.GetOrdinal("normalized_payload"))) ?? new Dictionary<string, string?>(),
                JsonSerializer.Deserialize<Dictionary<string, string?>>(reader.GetString(reader.GetOrdinal("source_payload"))) ?? new Dictionary<string, string?>()));
        }

        return rows;
    }

    public async Task<string> CancelImportBatchAsync(long batchId, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string selectSql = "select status from import_batches where id = @batchId for update;";
        const string updateSql = "update import_batches set status = 'CANCELADA' where id = @batchId;";
        const string auditSql = @"
            insert into audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail)
            values (@actorUserId, @actorUsername, 'IMPORT_CANCELLED', 'IMPORT_BATCH', @entityId, 'SUCCESS', jsonb_build_object('previous_status', @previousStatus));";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using var selectCommand = new NpgsqlCommand(selectSql, connection, transaction);
        selectCommand.Parameters.AddWithValue("batchId", batchId);
        var status = await selectCommand.ExecuteScalarAsync(cancellationToken) as string;
        if (status is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return "NOT_FOUND";
        }

        if (status is not ("PREVALIDADA" or "CON_ERRORES"))
        {
            await transaction.RollbackAsync(cancellationToken);
            return "INVALID_STATE";
        }

        await using var updateCommand = new NpgsqlCommand(updateSql, connection, transaction);
        updateCommand.Parameters.AddWithValue("batchId", batchId);
        await updateCommand.ExecuteNonQueryAsync(cancellationToken);

        await using var auditCommand = new NpgsqlCommand(auditSql, connection, transaction);
        auditCommand.Parameters.AddWithValue("actorUserId", actorUserId);
        auditCommand.Parameters.AddWithValue("actorUsername", actorUsername);
        auditCommand.Parameters.AddWithValue("entityId", batchId.ToString());
        auditCommand.Parameters.AddWithValue("previousStatus", status);
        await auditCommand.ExecuteNonQueryAsync(cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return "CANCELLED";
    }

    public async Task<string> ConfirmImportBatchAsync(long batchId, long actorUserId, string actorUsername, CancellationToken cancellationToken = default)
    {
        const string selectBatchSql = "select status from import_batches where id = @batchId for update;";
        const string selectRowsSql = @"
            select normalized_payload::text
            from import_batch_rows
            where import_batch_id = @batchId and classification = 'VALIDO'
            order by row_number;";
        const string insertEmployeeSql = @"
            insert into employees (
                identification_type, identification_number, full_name, employment_status,
                job_title, hire_date, termination_date, record_status, source
            )
            values (
                @identificationType, @identificationNumber, @fullName, @employmentStatus,
                @jobTitle, @hireDate, @terminationDate, 'ACTIVO', 'IMPORT'
            )
            returning id;";
        const string insertSalarySql = @"
            insert into employee_salary_history (employee_id, base_salary_amount, effective_from, source)
            values (@employeeId, @baseSalary, @effectiveFrom, 'IMPORT');";
        const string updateBatchSql = "update import_batches set status = 'IMPORTADA', imported_at = now() where id = @batchId;";
        const string auditSql = @"
            insert into audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail)
            values (@actorUserId, @actorUsername, 'IMPORT_CONFIRMED', 'IMPORT_BATCH', @entityId, 'SUCCESS', jsonb_build_object('imported_records', @importedRecords));";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using var selectBatchCommand = new NpgsqlCommand(selectBatchSql, connection, transaction);
        selectBatchCommand.Parameters.AddWithValue("batchId", batchId);
        var status = await selectBatchCommand.ExecuteScalarAsync(cancellationToken) as string;
        if (status is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return "NOT_FOUND";
        }
        if (status is not ("PREVALIDADA" or "CON_ERRORES"))
        {
            await transaction.RollbackAsync(cancellationToken);
            return "INVALID_STATE";
        }

        var payloads = new List<Dictionary<string, string?>>();
        await using (var rowsCommand = new NpgsqlCommand(selectRowsSql, connection, transaction))
        {
            rowsCommand.Parameters.AddWithValue("batchId", batchId);
            await using var reader = await rowsCommand.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                payloads.Add(JsonSerializer.Deserialize<Dictionary<string, string?>>(reader.GetString(0))
                    ?? throw new InvalidOperationException("La fila staging no contiene un payload normalizado valido."));
            }
        }

        foreach (var payload in payloads)
        {
            var hireDate = DateOnly.Parse(payload["hire_date"]!);
            var terminationDate = string.IsNullOrWhiteSpace(payload.GetValueOrDefault("termination_date"))
                ? (DateOnly?)null
                : DateOnly.Parse(payload["termination_date"]!);

            await using var employeeCommand = new NpgsqlCommand(insertEmployeeSql, connection, transaction);
            employeeCommand.Parameters.AddWithValue("identificationType", payload["identification_type"]!);
            employeeCommand.Parameters.AddWithValue("identificationNumber", payload["identification_number"]!);
            employeeCommand.Parameters.AddWithValue("fullName", payload["full_name"]!);
            employeeCommand.Parameters.AddWithValue("employmentStatus", payload["employment_status"]!);
            employeeCommand.Parameters.AddWithValue("jobTitle", payload["job_title"]!);
            employeeCommand.Parameters.AddWithValue("hireDate", hireDate.ToDateTime(TimeOnly.MinValue));
            employeeCommand.Parameters.Add("terminationDate", NpgsqlDbType.Date).Value = terminationDate.HasValue ? terminationDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value;
            var employeeId = (long)(await employeeCommand.ExecuteScalarAsync(cancellationToken)
                ?? throw new InvalidOperationException("No fue posible crear el empleado importado."));

            await using var salaryCommand = new NpgsqlCommand(insertSalarySql, connection, transaction);
            salaryCommand.Parameters.AddWithValue("employeeId", employeeId);
            salaryCommand.Parameters.AddWithValue("baseSalary", decimal.Parse(payload["base_salary"]!, System.Globalization.CultureInfo.InvariantCulture));
            salaryCommand.Parameters.AddWithValue("effectiveFrom", hireDate.ToDateTime(TimeOnly.MinValue));
            await salaryCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await using var updateBatchCommand = new NpgsqlCommand(updateBatchSql, connection, transaction);
        updateBatchCommand.Parameters.AddWithValue("batchId", batchId);
        await updateBatchCommand.ExecuteNonQueryAsync(cancellationToken);

        await using var auditCommand = new NpgsqlCommand(auditSql, connection, transaction);
        auditCommand.Parameters.AddWithValue("actorUserId", actorUserId);
        auditCommand.Parameters.AddWithValue("actorUsername", actorUsername);
        auditCommand.Parameters.AddWithValue("entityId", batchId.ToString());
        auditCommand.Parameters.AddWithValue("importedRecords", payloads.Count);
        await auditCommand.ExecuteNonQueryAsync(cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return "IMPORTED";
    }

    public async Task<IReadOnlySet<string>> GetExistingIdentificationKeysAsync(CancellationToken cancellationToken = default)
    {
        const string sql = "select identification_type, identification_number from employees;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);

        var identifications = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            identifications.Add(EmployeeCsvPrevalidationService.BuildIdentificationKey(reader.GetString(0), reader.GetString(1)));
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
        const string insertMappingSql = @"
            insert into import_column_mappings (import_batch_id, source_header, target_field, mapping_status, source_position)
            values (@batchId, @sourceHeader, @targetField, @mappingStatus, @sourcePosition);";
        const string insertRowSql = @"
            insert into import_batch_rows (
                import_batch_id, row_number, classification, identification_type,
                identification_number, normalized_payload, source_payload
            )
            values (
                @batchId, @rowNumber, @classification, @identificationType,
                @identificationNumber, @normalizedPayload::jsonb, @sourcePayload::jsonb
            )
            returning id;";

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

        var rowIds = new Dictionary<int, long>();
        foreach (var row in result.Rows)
        {
            await using var rowCommand = new NpgsqlCommand(insertRowSql, connection, transaction);
            rowCommand.Parameters.AddWithValue("batchId", batchId);
            rowCommand.Parameters.AddWithValue("rowNumber", row.RowNumber);
            rowCommand.Parameters.AddWithValue("classification", row.Classification);
            rowCommand.Parameters.AddWithValue("identificationType", row.IdentificationType);
            rowCommand.Parameters.Add("identificationNumber", NpgsqlDbType.Text).Value = row.IdentificationNumber is null ? DBNull.Value : row.IdentificationNumber;
            rowCommand.Parameters.AddWithValue("normalizedPayload", JsonSerializer.Serialize(row.NormalizedPayload));
            rowCommand.Parameters.AddWithValue("sourcePayload", JsonSerializer.Serialize(row.SourcePayload));
            rowIds[row.RowNumber] = (long)(await rowCommand.ExecuteScalarAsync(cancellationToken)
                ?? throw new InvalidOperationException("No fue posible persistir la fila staging."));
        }

        foreach (var error in result.Errors)
        {
            await using var errorCommand = new NpgsqlCommand(insertErrorSql, connection, transaction);
            errorCommand.Parameters.AddWithValue("batchId", batchId);
            errorCommand.Parameters.AddWithValue("rowNumber", error.RowNumber);
            errorCommand.Parameters.AddWithValue("fieldName", error.FieldName);
            errorCommand.Parameters.AddWithValue("errorType", error.ErrorType);
            errorCommand.Parameters.AddWithValue("message", error.Message);
            errorCommand.Parameters.AddWithValue("originalValue", error.OriginalValue is null ? DBNull.Value : error.OriginalValue);
            errorCommand.CommandText = errorCommand.CommandText.Replace(
                "original_value\n            )",
                "original_value,\n                import_batch_row_id\n            )").Replace(
                "@originalValue\n            );",
                "@originalValue,\n                @rowId\n            );");
            errorCommand.Parameters.AddWithValue("rowId", rowIds[error.RowNumber]);
            await errorCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        foreach (var mapping in result.Mappings)
        {
            await using var mappingCommand = new NpgsqlCommand(insertMappingSql, connection, transaction);
            mappingCommand.Parameters.AddWithValue("batchId", batchId);
            mappingCommand.Parameters.AddWithValue("sourceHeader", mapping.SourceHeader);
            mappingCommand.Parameters.Add("targetField", NpgsqlDbType.Text).Value = mapping.TargetField is null ? DBNull.Value : mapping.TargetField;
            mappingCommand.Parameters.AddWithValue("mappingStatus", mapping.MappingStatus);
            mappingCommand.Parameters.AddWithValue("sourcePosition", mapping.SourcePosition);
            await mappingCommand.ExecuteNonQueryAsync(cancellationToken);
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

    public async Task<IReadOnlyList<ImportColumnMappingResponse>> GetImportColumnMappingsAsync(long batchId, CancellationToken cancellationToken = default)
    {
        const string sql = @"
            select source_header, target_field, mapping_status, source_position
            from import_column_mappings
            where import_batch_id = @batchId
            order by source_position;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("batchId", batchId);

        var mappings = new List<ImportColumnMappingResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            mappings.Add(new ImportColumnMappingResponse(
                reader.GetString(reader.GetOrdinal("source_header")),
                reader.IsDBNull(reader.GetOrdinal("target_field")) ? null : reader.GetString(reader.GetOrdinal("target_field")),
                reader.GetString(reader.GetOrdinal("mapping_status")),
                reader.GetInt32(reader.GetOrdinal("source_position"))));
        }

        return mappings;
    }

    private static void AddServicePositionParameters(NpgsqlCommand command, UpsertServicePositionRequest request)
    {
        command.Parameters.Add("code", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Code) ? DBNull.Value : request.Code.Trim();
        command.Parameters.AddWithValue("name", request.Name.Trim());
        command.Parameters.Add("clientText", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.ClientText) ? DBNull.Value : request.ClientText.Trim();
        command.Parameters.Add("locationText", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.LocationText) ? DBNull.Value : request.LocationText.Trim();
        command.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
    }

    private static void AddServicePositionAuditParameters(NpgsqlCommand command, UpsertServicePositionRequest request)
    {
        command.Parameters.Add("code", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Code) ? DBNull.Value : request.Code.Trim();
        command.Parameters.AddWithValue("name", request.Name.Trim());
        command.Parameters.Add("clientText", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.ClientText) ? DBNull.Value : request.ClientText.Trim();
        command.Parameters.Add("locationText", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.LocationText) ? DBNull.Value : request.LocationText.Trim();
        command.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
    }

    private static void AddCertificateSignerParameters(NpgsqlCommand command, UpsertCertificateSignerRequest request)
    {
        command.Parameters.AddWithValue("fullName", request.FullName.Trim());
        command.Parameters.AddWithValue("jobTitle", request.JobTitle.Trim());
        command.Parameters.Add("signaturePath", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.SignaturePath) ? DBNull.Value : request.SignaturePath.Trim();
        command.Parameters.AddWithValue("validFrom", DateOnly.Parse(request.ValidFrom).ToDateTime(TimeOnly.MinValue));
        command.Parameters.Add("validTo", NpgsqlDbType.Date).Value = string.IsNullOrWhiteSpace(request.ValidTo) ? DBNull.Value : DateOnly.Parse(request.ValidTo).ToDateTime(TimeOnly.MinValue);
        command.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
    }

    private static Action<NpgsqlCommand> AddCertificateSignerAuditParameters(UpsertCertificateSignerRequest request)
    {
        return command =>
        {
            command.Parameters.AddWithValue("fullName", request.FullName.Trim());
            command.Parameters.AddWithValue("jobTitle", request.JobTitle.Trim());
        };
    }

    public Task<long> CreateSchedulingClientAsync(UpsertSchedulingClientRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        InsertSchedulingConfigurationAsync(
            "insert into clients(code,name,status) values (@code,@name,@status) returning id",
            "SCHEDULING_CLIENT_CREATED", "SCHEDULING_CLIENT",
            command =>
            {
                command.Parameters.AddWithValue("code", request.Code.Trim());
                command.Parameters.AddWithValue("name", request.Name.Trim());
                command.Parameters.AddWithValue("status", request.Status.Trim().ToUpperInvariant());
            }, actorUserId, actorUsername, cancellationToken);

    public Task<long> CreateSchedulingProjectAsync(UpsertSchedulingProjectRequest request, DateOnly effectiveFrom, DateOnly? effectiveTo, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        InsertSchedulingConfigurationAsync(
            "insert into service_projects(client_id,code,name,effective_from,effective_to,status) values (@clientId,@code,@name,@effectiveFrom,@effectiveTo,@status) returning id",
            "SCHEDULING_PROJECT_CREATED", "SCHEDULING_PROJECT",
            command =>
            {
                command.Parameters.AddWithValue("clientId", request.ClientId);
                command.Parameters.AddWithValue("code", request.Code.Trim());
                command.Parameters.AddWithValue("name", request.Name.Trim());
                command.Parameters.AddWithValue("effectiveFrom", effectiveFrom);
                command.Parameters.Add("effectiveTo", NpgsqlDbType.Date).Value = effectiveTo.HasValue ? effectiveTo.Value : DBNull.Value;
                command.Parameters.AddWithValue("status", request.Status.Trim().ToUpperInvariant());
            }, actorUserId, actorUsername, cancellationToken);

    public Task<long> CreateCoverageRuleAsync(UpsertCoverageRuleRequest request, TimeOnly startsAt, TimeOnly endsAt, DateOnly effectiveFrom, DateOnly? effectiveTo, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        InsertSchedulingConfigurationAsync(
            "insert into position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,effective_to,status) values (@positionId,@templateId,@weekdayScope,@startsAt,@endsAt,@quantity,@effectiveFrom,@effectiveTo,@status) returning id",
            "COVERAGE_RULE_CREATED", "POSITION_COVERAGE_RULE",
            command =>
            {
                command.Parameters.AddWithValue("positionId", request.PositionId);
                command.Parameters.AddWithValue("templateId", request.TemplateId);
                command.Parameters.AddWithValue("weekdayScope", request.WeekdayScope.Trim());
                command.Parameters.AddWithValue("startsAt", startsAt);
                command.Parameters.AddWithValue("endsAt", endsAt);
                command.Parameters.AddWithValue("quantity", request.RequiredGuards);
                command.Parameters.AddWithValue("effectiveFrom", effectiveFrom);
                command.Parameters.Add("effectiveTo", NpgsqlDbType.Date).Value = effectiveTo.HasValue ? effectiveTo.Value : DBNull.Value;
                command.Parameters.AddWithValue("status", request.Status.Trim().ToUpperInvariant());
            }, actorUserId, actorUsername, cancellationToken);

    public Task<long> CreateAvailabilityExceptionAsync(UpsertAvailabilityExceptionRequest request, DateTimeOffset startsAt, DateTimeOffset endsAt, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        InsertSchedulingConfigurationAsync(
            "insert into employee_availability_exceptions(employee_id,starts_at,ends_at,kind,blocking,reason,created_by) values (@employeeId,@startsAt,@endsAt,@kind,@blocking,@reason,@createdBy) returning id",
            "AVAILABILITY_CREATED", "EMPLOYEE_AVAILABILITY_EXCEPTION",
            command =>
            {
                command.Parameters.AddWithValue("employeeId", request.EmployeeId);
                command.Parameters.AddWithValue("startsAt", startsAt.ToUniversalTime());
                command.Parameters.AddWithValue("endsAt", endsAt.ToUniversalTime());
                command.Parameters.AddWithValue("kind", request.Kind.Trim());
                command.Parameters.AddWithValue("blocking", request.Blocking);
                command.Parameters.AddWithValue("reason", request.Reason.Trim());
                command.Parameters.AddWithValue("createdBy", actorUsername);
            }, actorUserId, actorUsername, cancellationToken);

    public Task<long> CreatePositionRequirementAsync(UpsertPositionRequirementRequest request, DateOnly? resolutionDueDate, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        InsertSchedulingConfigurationAsync(
            "insert into position_requirements(position_id,requirement_type_id,severity,resolution_due_date) values (@positionId,@requirementTypeId,@severity,@resolutionDueDate) returning id",
            "POSITION_REQUIREMENT_CREATED", "POSITION_REQUIREMENT",
            command =>
            {
                command.Parameters.AddWithValue("positionId", request.PositionId);
                command.Parameters.AddWithValue("requirementTypeId", request.RequirementTypeId);
                command.Parameters.AddWithValue("severity", request.Severity.Trim().ToUpperInvariant());
                command.Parameters.Add("resolutionDueDate", NpgsqlDbType.Date).Value = resolutionDueDate.HasValue ? resolutionDueDate.Value : DBNull.Value;
            }, actorUserId, actorUsername, cancellationToken);

    public async Task<SchedulingClientResponse?> GetSchedulingClientAsync(long id, CancellationToken cancellationToken = default)
    {
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("select id,code,name,status from clients where id=@id", connection);
        command.Parameters.AddWithValue("id", id);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken)
            ? new SchedulingClientResponse(reader.GetInt64(0), reader.GetString(1), reader.GetString(2), reader.GetString(3)) : null;
    }

    public async Task<long> PersistScheduleRecommendationAsync(
        ScheduleRecommendationRequest request,
        ScheduleRecommendationResult result,
        CancellationToken cancellationToken = default)
    {
        if (request.ScheduleVersionId is null)
            throw new ArgumentException("La version de programacion es obligatoria para persistir la corrida.");

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using (var existing = new NpgsqlCommand(
            "select id from schedule_generation_runs where idempotency_key=@key", connection, transaction))
        {
            existing.Parameters.AddWithValue("key", request.IdempotencyKey.Trim());
            var existingId = await existing.ExecuteScalarAsync(cancellationToken);
            if (existingId is not null)
            {
                await transaction.CommitAsync(cancellationToken);
                return (long)existingId;
            }
        }

        long runId;
        await using (var createRun = new NpgsqlCommand(@"
            insert into schedule_generation_runs(schedule_version_id,idempotency_key,status,started_at)
            values (@versionId,@key,'EN_COLA',NOW()) returning id", connection, transaction))
        {
            createRun.Parameters.AddWithValue("versionId", request.ScheduleVersionId.Value);
            createRun.Parameters.AddWithValue("key", request.IdempotencyKey.Trim());
            runId = (long)(await createRun.ExecuteScalarAsync(cancellationToken)
                ?? throw new InvalidOperationException("No fue posible crear la corrida I9."));
        }

        await using (var processing = new NpgsqlCommand(
            "update schedule_generation_runs set status='PROCESANDO' where id=@id", connection, transaction))
        {
            processing.Parameters.AddWithValue("id", runId);
            await processing.ExecuteNonQueryAsync(cancellationToken);
        }

        var sourceSnapshot = JsonSerializer.Serialize(new { shifts = request.Shifts });
        var parametersSnapshot = JsonSerializer.Serialize(request.Weights);
        await using (var snapshot = new NpgsqlCommand(@"
            update schedule_versions
               set source_snapshot=@source::jsonb,
                   parameters_snapshot=@parameters::jsonb
             where id=@versionId and status <> 'PUBLICADA'", connection, transaction))
        {
            snapshot.Parameters.AddWithValue("source", sourceSnapshot);
            snapshot.Parameters.AddWithValue("parameters", parametersSnapshot);
            snapshot.Parameters.AddWithValue("versionId", request.ScheduleVersionId.Value);
            if (await snapshot.ExecuteNonQueryAsync(cancellationToken) != 1)
                throw new InvalidOperationException("La version no existe o ya fue publicada.");
        }

        foreach (var assignment in result.Assignments)
        {
            await using var insertAssignment = new NpgsqlCommand(@"
                insert into schedule_assignments(
                    schedule_version_id,required_shift_id,employee_id,status,score,reasons)
                values (@versionId,@shiftId,@employeeId,@status,@score,@reasons::jsonb)", connection, transaction);
            insertAssignment.Parameters.AddWithValue("versionId", request.ScheduleVersionId.Value);
            insertAssignment.Parameters.AddWithValue("shiftId", assignment.RequiredShiftId);
            insertAssignment.Parameters.Add("employeeId", NpgsqlDbType.Bigint).Value = assignment.EmployeeId.HasValue ? assignment.EmployeeId.Value : DBNull.Value;
            insertAssignment.Parameters.AddWithValue("status", assignment.Status);
            insertAssignment.Parameters.Add("score", NpgsqlDbType.Numeric).Value = assignment.Score.HasValue ? assignment.Score.Value : DBNull.Value;
            insertAssignment.Parameters.AddWithValue("reasons", JsonSerializer.Serialize(assignment.RankingReasons));
            await insertAssignment.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var complete = new NpgsqlCommand(@"
            update schedule_generation_runs
               set status=@status, completed_at=NOW()
             where id=@id", connection, transaction))
        {
            complete.Parameters.AddWithValue("status", result.Status);
            complete.Parameters.AddWithValue("id", runId);
            await complete.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return runId;
    }

    public async Task<SchedulingProjectResponse?> GetSchedulingProjectAsync(long id, CancellationToken cancellationToken = default)
    {
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("select id,client_id,code,name,effective_from,effective_to,status from service_projects where id=@id", connection);
        command.Parameters.AddWithValue("id", id);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new SchedulingProjectResponse(reader.GetInt64(0), reader.GetInt64(1), reader.GetString(2), reader.GetString(3),
            reader.GetFieldValue<DateOnly>(4).ToString("yyyy-MM-dd"), reader.IsDBNull(5) ? null : reader.GetFieldValue<DateOnly>(5).ToString("yyyy-MM-dd"), reader.GetString(6));
    }

    public async Task<CoverageRuleResponse?> GetCoverageRuleAsync(long id, CancellationToken cancellationToken = default)
    {
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("select id,position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,effective_to,status from position_coverage_rules where id=@id", connection);
        command.Parameters.AddWithValue("id", id);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new CoverageRuleResponse(reader.GetInt64(0), reader.GetInt64(1), reader.GetInt64(2), reader.GetString(3),
            reader.GetFieldValue<TimeOnly>(4).ToString("HH:mm"), reader.GetFieldValue<TimeOnly>(5).ToString("HH:mm"), reader.GetInt32(6),
            reader.GetFieldValue<DateOnly>(7).ToString("yyyy-MM-dd"), reader.IsDBNull(8) ? null : reader.GetFieldValue<DateOnly>(8).ToString("yyyy-MM-dd"), reader.GetString(9));
    }

    public async Task<AvailabilityExceptionResponse?> GetAvailabilityExceptionAsync(long id, CancellationToken cancellationToken = default)
    {
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("select id,employee_id,starts_at,ends_at,kind,blocking,reason,status from employee_availability_exceptions where id=@id", connection);
        command.Parameters.AddWithValue("id", id);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new AvailabilityExceptionResponse(reader.GetInt64(0), reader.GetInt64(1), reader.GetFieldValue<DateTimeOffset>(2).ToString("O"),
            reader.GetFieldValue<DateTimeOffset>(3).ToString("O"), reader.GetString(4), reader.GetBoolean(5), reader.GetString(6), reader.GetString(7));
    }

    public async Task<PositionRequirementResponse?> GetPositionRequirementAsync(long id, CancellationToken cancellationToken = default)
    {
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("select id,position_id,requirement_type_id,severity,resolution_due_date,status from position_requirements where id=@id", connection);
        command.Parameters.AddWithValue("id", id);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new PositionRequirementResponse(reader.GetInt64(0), reader.GetInt64(1), reader.GetInt64(2), reader.GetString(3),
            reader.IsDBNull(4) ? null : reader.GetFieldValue<DateOnly>(4).ToString("yyyy-MM-dd"), reader.GetString(5));
    }

    public Task<bool> UpdateSchedulingClientAsync(long id, UpsertSchedulingClientRequest request, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        UpdateSchedulingConfigurationAsync("update clients set code=@code,name=@name,status=@status,updated_at=now() where id=@id returning id", "SCHEDULING_CLIENT_UPDATED", "SCHEDULING_CLIENT", id,
            c => { c.Parameters.AddWithValue("code", request.Code.Trim()); c.Parameters.AddWithValue("name", request.Name.Trim()); c.Parameters.AddWithValue("status", request.Status.Trim().ToUpperInvariant()); }, actorUserId, actorUsername, cancellationToken);

    public Task<bool> UpdateSchedulingProjectAsync(long id, UpsertSchedulingProjectRequest request, DateOnly effectiveFrom, DateOnly? effectiveTo, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        UpdateSchedulingConfigurationAsync("update service_projects set client_id=@clientId,code=@code,name=@name,effective_from=@effectiveFrom,effective_to=@effectiveTo,status=@status,updated_at=now() where id=@id returning id", "SCHEDULING_PROJECT_UPDATED", "SCHEDULING_PROJECT", id,
            c => { c.Parameters.AddWithValue("clientId", request.ClientId); c.Parameters.AddWithValue("code", request.Code.Trim()); c.Parameters.AddWithValue("name", request.Name.Trim()); c.Parameters.AddWithValue("effectiveFrom", effectiveFrom); c.Parameters.Add("effectiveTo", NpgsqlDbType.Date).Value=effectiveTo.HasValue?effectiveTo.Value:DBNull.Value; c.Parameters.AddWithValue("status", request.Status.Trim().ToUpperInvariant()); }, actorUserId, actorUsername, cancellationToken);

    public Task<bool> UpdateCoverageRuleAsync(long id, UpsertCoverageRuleRequest request, TimeOnly startsAt, TimeOnly endsAt, DateOnly effectiveFrom, DateOnly? effectiveTo, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        UpdateSchedulingConfigurationAsync("update position_coverage_rules set position_id=@positionId,template_id=@templateId,weekday_scope=@weekdayScope,starts_at=@startsAt,ends_at=@endsAt,required_quantity=@quantity,effective_from=@effectiveFrom,effective_to=@effectiveTo,status=@status,updated_at=now() where id=@id returning id", "COVERAGE_RULE_UPDATED", "POSITION_COVERAGE_RULE", id,
            c => { c.Parameters.AddWithValue("positionId", request.PositionId); c.Parameters.AddWithValue("templateId", request.TemplateId); c.Parameters.AddWithValue("weekdayScope", request.WeekdayScope.Trim()); c.Parameters.AddWithValue("startsAt", startsAt); c.Parameters.AddWithValue("endsAt", endsAt); c.Parameters.AddWithValue("quantity", request.RequiredGuards); c.Parameters.AddWithValue("effectiveFrom", effectiveFrom); c.Parameters.Add("effectiveTo", NpgsqlDbType.Date).Value=effectiveTo.HasValue?effectiveTo.Value:DBNull.Value; c.Parameters.AddWithValue("status", request.Status.Trim().ToUpperInvariant()); }, actorUserId, actorUsername, cancellationToken);

    public Task<bool> UpdateAvailabilityExceptionAsync(long id, UpsertAvailabilityExceptionRequest request, DateTimeOffset from, DateTimeOffset to, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        UpdateSchedulingConfigurationAsync("update employee_availability_exceptions set employee_id=@employeeId,starts_at=@startsAt,ends_at=@endsAt,kind=@kind,blocking=@blocking,reason=@reason,updated_at=now() where id=@id returning id", "AVAILABILITY_UPDATED", "EMPLOYEE_AVAILABILITY_EXCEPTION", id,
            c => { c.Parameters.AddWithValue("employeeId", request.EmployeeId); c.Parameters.AddWithValue("startsAt", from.ToUniversalTime()); c.Parameters.AddWithValue("endsAt", to.ToUniversalTime()); c.Parameters.AddWithValue("kind", request.Kind.Trim()); c.Parameters.AddWithValue("blocking", request.Blocking); c.Parameters.AddWithValue("reason", request.Reason.Trim()); }, actorUserId, actorUsername, cancellationToken);

    public Task<bool> UpdatePositionRequirementAsync(long id, UpsertPositionRequirementRequest request, DateOnly? dueDate, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) =>
        UpdateSchedulingConfigurationAsync("update position_requirements set position_id=@positionId,requirement_type_id=@requirementTypeId,severity=@severity,resolution_due_date=@dueDate,updated_at=now() where id=@id returning id", "POSITION_REQUIREMENT_UPDATED", "POSITION_REQUIREMENT", id,
            c => { c.Parameters.AddWithValue("positionId", request.PositionId); c.Parameters.AddWithValue("requirementTypeId", request.RequirementTypeId); c.Parameters.AddWithValue("severity", request.Severity.Trim().ToUpperInvariant()); c.Parameters.Add("dueDate", NpgsqlDbType.Date).Value=dueDate.HasValue?dueDate.Value:DBNull.Value; }, actorUserId, actorUsername, cancellationToken);

    public Task<bool> InactivateSchedulingClientAsync(long id, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) => InactivateSchedulingConfigurationAsync("clients", "SCHEDULING_CLIENT_INACTIVATED", "SCHEDULING_CLIENT", id, actorUserId, actorUsername, cancellationToken);
    public Task<bool> InactivateSchedulingProjectAsync(long id, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) => InactivateSchedulingConfigurationAsync("service_projects", "SCHEDULING_PROJECT_INACTIVATED", "SCHEDULING_PROJECT", id, actorUserId, actorUsername, cancellationToken);
    public Task<bool> InactivateCoverageRuleAsync(long id, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) => InactivateSchedulingConfigurationAsync("position_coverage_rules", "COVERAGE_RULE_INACTIVATED", "POSITION_COVERAGE_RULE", id, actorUserId, actorUsername, cancellationToken);
    public Task<bool> InactivateAvailabilityExceptionAsync(long id, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) => InactivateSchedulingConfigurationAsync("employee_availability_exceptions", "AVAILABILITY_INACTIVATED", "EMPLOYEE_AVAILABILITY_EXCEPTION", id, actorUserId, actorUsername, cancellationToken);
    public Task<bool> InactivatePositionRequirementAsync(long id, long actorUserId, string actorUsername, CancellationToken cancellationToken = default) => InactivateSchedulingConfigurationAsync("position_requirements", "POSITION_REQUIREMENT_INACTIVATED", "POSITION_REQUIREMENT", id, actorUserId, actorUsername, cancellationToken);

    private async Task<bool> UpdateSchedulingConfigurationAsync(string sql, string eventType, string entityType, long id, Action<NpgsqlCommand> addParameters, long actorUserId, string actorUsername, CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("id", id);
        addParameters(command);
        var updated = await command.ExecuteScalarAsync(cancellationToken) is not null;
        if (!updated) { await transaction.RollbackAsync(cancellationToken); return false; }
        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, eventType, entityType, id.ToString(), "'{}'::jsonb", null, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return true;
    }

    private Task<bool> InactivateSchedulingConfigurationAsync(string table, string eventType, string entityType, long id, long actorUserId, string actorUsername, CancellationToken cancellationToken) =>
        UpdateSchedulingConfigurationAsync($"update {table} set status='INACTIVO',updated_at=now() where id=@id returning id", eventType, entityType, id, _ => { }, actorUserId, actorUsername, cancellationToken);

    private async Task<long> InsertSchedulingConfigurationAsync(
        string insertSql,
        string eventType,
        string entityType,
        Action<NpgsqlCommand> addParameters,
        long actorUserId,
        string actorUsername,
        CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(insertSql, connection, transaction);
        addParameters(command);
        var id = (long)(await command.ExecuteScalarAsync(cancellationToken)
            ?? throw new InvalidOperationException("No fue posible guardar la configuracion I9."));
        await InsertAuditLogAsync(connection, transaction, actorUserId, actorUsername, eventType, entityType,
            id.ToString(System.Globalization.CultureInfo.InvariantCulture), "'{}'::jsonb", null, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return id;
    }

    private static void AddTrainingRequirementTypeParameters(NpgsqlCommand command, UpsertTrainingRequirementTypeRequest request)
    {
        command.Parameters.Add("code", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Code) ? DBNull.Value : request.Code.Trim();
        command.Parameters.AddWithValue("name", request.Name.Trim());
        command.Parameters.AddWithValue("category", request.Category.Trim().ToUpperInvariant());
        command.Parameters.Add("validityDays", NpgsqlDbType.Integer).Value = request.ValidityDays.HasValue ? request.ValidityDays.Value : DBNull.Value;
        command.Parameters.AddWithValue("isServiceRequired", request.IsServiceRequired);
        command.Parameters.Add("notes", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Notes) ? DBNull.Value : request.Notes.Trim();
    }

    private static Action<NpgsqlCommand> AddTrainingRequirementTypeAuditParameters(UpsertTrainingRequirementTypeRequest request)
    {
        return command =>
        {
            command.Parameters.Add("code", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(request.Code) ? DBNull.Value : request.Code.Trim();
            command.Parameters.AddWithValue("name", request.Name.Trim());
            command.Parameters.AddWithValue("category", request.Category.Trim().ToUpperInvariant());
            command.Parameters.Add("validityDays", NpgsqlDbType.Integer).Value = request.ValidityDays.HasValue ? request.ValidityDays.Value : DBNull.Value;
            command.Parameters.AddWithValue("isServiceRequired", request.IsServiceRequired);
        };
    }

    private static async Task InsertAuditLogAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        long actorUserId,
        string actorUsername,
        string eventType,
        string entityType,
        string entityId,
        string detailExpressionSql,
        Action<NpgsqlCommand>? addDetailParameters,
        CancellationToken cancellationToken)
    {
        var sql = $@"
            insert into audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail)
            values (@actorUserId, @actorUsername, @eventType, @entityType, @entityId, 'SUCCESS', {detailExpressionSql});";

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("actorUserId", actorUserId);
        command.Parameters.AddWithValue("actorUsername", actorUsername);
        command.Parameters.AddWithValue("eventType", eventType);
        command.Parameters.AddWithValue("entityType", entityType);
        command.Parameters.AddWithValue("entityId", entityId);
        addDetailParameters?.Invoke(command);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static ServicePositionResponse ReadServicePosition(NpgsqlDataReader reader)
    {
        return new ServicePositionResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.IsDBNull(reader.GetOrdinal("code")) ? null : reader.GetString(reader.GetOrdinal("code")),
            reader.GetString(reader.GetOrdinal("name")),
            reader.IsDBNull(reader.GetOrdinal("client_text")) ? null : reader.GetString(reader.GetOrdinal("client_text")),
            reader.IsDBNull(reader.GetOrdinal("location_text")) ? null : reader.GetString(reader.GetOrdinal("location_text")),
            reader.GetString(reader.GetOrdinal("status")),
            reader.IsDBNull(reader.GetOrdinal("notes")) ? null : reader.GetString(reader.GetOrdinal("notes")),
            reader.GetInt32(reader.GetOrdinal("active_assignments_count")),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("updated_at"))));
    }

    private static CertificateSignerResponse ReadCertificateSigner(NpgsqlDataReader reader)
    {
        return new CertificateSignerResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetString(reader.GetOrdinal("full_name")),
            reader.GetString(reader.GetOrdinal("job_title")),
            reader.IsDBNull(reader.GetOrdinal("signature_path")) ? null : reader.GetString(reader.GetOrdinal("signature_path")),
            reader.GetDateTime(reader.GetOrdinal("valid_from")).ToString("yyyy-MM-dd"),
            reader.IsDBNull(reader.GetOrdinal("valid_to")) ? null : reader.GetDateTime(reader.GetOrdinal("valid_to")).ToString("yyyy-MM-dd"),
            reader.GetString(reader.GetOrdinal("status")),
            reader.IsDBNull(reader.GetOrdinal("notes")) ? null : reader.GetString(reader.GetOrdinal("notes")),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("updated_at"))));
    }

    private static TrainingRequirementTypeResponse ReadTrainingRequirementType(NpgsqlDataReader reader)
    {
        return new TrainingRequirementTypeResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.IsDBNull(reader.GetOrdinal("code")) ? null : reader.GetString(reader.GetOrdinal("code")),
            reader.GetString(reader.GetOrdinal("name")),
            reader.GetString(reader.GetOrdinal("category")),
            reader.IsDBNull(reader.GetOrdinal("validity_days")) ? null : reader.GetInt32(reader.GetOrdinal("validity_days")),
            reader.GetBoolean(reader.GetOrdinal("is_service_required")),
            reader.GetString(reader.GetOrdinal("status")),
            reader.IsDBNull(reader.GetOrdinal("notes")) ? null : reader.GetString(reader.GetOrdinal("notes")),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("updated_at"))));
    }

    private static TrainingRecordResponse ReadTrainingRecord(NpgsqlDataReader reader)
    {
        var expiresAt = DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal("expires_at")));
        var compliance = TrainingComplianceStatusCalculator.Calculate(expiresAt, DateOnly.FromDateTime(DateTime.Today));

        return new TrainingRecordResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetInt64(reader.GetOrdinal("employee_id")),
            reader.GetInt64(reader.GetOrdinal("requirement_type_id")),
            reader.GetString(reader.GetOrdinal("requirement_type_name")),
            reader.GetString(reader.GetOrdinal("requirement_category")),
            reader.GetDateTime(reader.GetOrdinal("completed_at")).ToString("yyyy-MM-dd"),
            expiresAt.ToString("yyyy-MM-dd"),
            compliance.Status,
            compliance.DaysUntilExpiry,
            reader.IsDBNull(reader.GetOrdinal("support_path")) ? null : reader.GetString(reader.GetOrdinal("support_path")),
            reader.IsDBNull(reader.GetOrdinal("notes")) ? null : reader.GetString(reader.GetOrdinal("notes")),
            reader.GetString(reader.GetOrdinal("status")),
            reader.GetString(reader.GetOrdinal("created_by")),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("updated_at"))));
    }

    private static int GetComplianceSeverity(string status)
    {
        return status switch
        {
            "VENCIDO" => 5,
            "CRITICO" => 4,
            "PREVENTIVO" => 3,
            "INFORMATIVO" => 2,
            "AL_DIA" => 1,
            _ => 0
        };
    }

    private static CertificatePreviewResponse BuildCertificatePreviewError(string code)
    {
        return new CertificatePreviewResponse(
            0,
            code,
            string.Empty,
            string.Empty,
            string.Empty,
            string.Empty,
            string.Empty,
            string.Empty,
            null,
            null,
            string.Empty,
            null,
            null,
            0,
            string.Empty,
            string.Empty,
            Array.Empty<CertificateVariableResponse>(),
            string.Empty,
            new Dictionary<string, object?>());
    }

    private static LaborCertificateResponse ReadLaborCertificate(NpgsqlDataReader reader, long id, string status)
    {
        var snapshot = JsonSerializer.Deserialize<Dictionary<string, object?>>(reader.GetString(reader.GetOrdinal("snapshot_payload")))
            ?? new Dictionary<string, object?>();
        return new LaborCertificateResponse(
            id,
            reader.GetString(reader.GetOrdinal("certificate_number")),
            reader.GetInt64(reader.GetOrdinal("employee_id")),
            reader.GetInt64(reader.GetOrdinal("signer_id")),
            reader.GetString(reader.GetOrdinal("certificate_type")),
            reader.GetString(reader.GetOrdinal("purpose")),
            status,
            snapshot.TryGetValue("issueDate", out var issueDate) ? issueDate?.ToString() ?? string.Empty : string.Empty,
            snapshot.TryGetValue("employeeFullName", out var employeeFullName) ? employeeFullName?.ToString() ?? string.Empty : string.Empty,
            snapshot.TryGetValue("signerFullName", out var signerFullName) ? signerFullName?.ToString() ?? string.Empty : string.Empty,
            reader.IsDBNull(reader.GetOrdinal("preview_content")) ? string.Empty : reader.GetString(reader.GetOrdinal("preview_content")),
            Path.GetFileName(reader.IsDBNull(reader.GetOrdinal("pdf_path")) ? string.Empty : reader.GetString(reader.GetOrdinal("pdf_path"))),
            reader.GetString(reader.GetOrdinal("template_version")),
            reader.GetString(reader.GetOrdinal("created_by")),
            reader.IsDBNull(reader.GetOrdinal("approved_by")) ? null : reader.GetString(reader.GetOrdinal("approved_by")),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
            reader.IsDBNull(reader.GetOrdinal("approved_at")) ? null : new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("approved_at"))),
            reader.IsDBNull(reader.GetOrdinal("generated_at")) ? null : new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("generated_at"))),
            snapshot);
    }

    private static string GetCertificatePdfPath(string fileName)
    {
        var configuredDirectory = Environment.GetEnvironmentVariable("SG_CERTIFICATES_PDF_DIR");
        var directory = string.IsNullOrWhiteSpace(configuredDirectory)
            ? Path.Combine(AppContext.BaseDirectory, "generated-certificates")
            : configuredDirectory;
        return Path.Combine(directory, fileName);
    }

    private static byte[] BuildCertificatePdf(CertificatePreviewResponse preview, string certificateNumber)
    {
        var contentLines = new[]
        {
            "S&G Seguridad y Gestion",
            $"Certificado laboral {certificateNumber}",
            $"Tipo: {preview.CertificateType}",
            $"Fecha de expedicion: {preview.IssueDate}",
            string.Empty,
            preview.PreviewContent,
            string.Empty,
            $"Firmante: {preview.SignerFullName} - {preview.SignerJobTitle}"
        };
        var textCommands = new StringBuilder();
        var y = 760;
        foreach (var rawLine in string.Join("\n", contentLines).Split('\n'))
        {
            textCommands.Append("BT /F1 10 Tf 50 ")
                .Append(y)
                .Append(" Td (")
                .Append(EscapePdfText(rawLine))
                .AppendLine(") Tj ET");
            y -= 16;
        }

        var stream = textCommands.ToString();
        var objects = new List<string>
        {
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
            $"<< /Length {Encoding.ASCII.GetByteCount(stream)} >>\nstream\n{stream}endstream"
        };

        var pdf = new StringBuilder();
        pdf.AppendLine("%PDF-1.4");
        var offsets = new List<int> { 0 };
        foreach (var item in objects.Select((value, index) => (value, index)))
        {
            offsets.Add(Encoding.ASCII.GetByteCount(pdf.ToString()));
            pdf.Append(item.index + 1).AppendLine(" 0 obj");
            pdf.AppendLine(item.value);
            pdf.AppendLine("endobj");
        }

        var xrefOffset = Encoding.ASCII.GetByteCount(pdf.ToString());
        pdf.AppendLine("xref");
        pdf.Append("0 ").Append(objects.Count + 1).AppendLine();
        pdf.AppendLine("0000000000 65535 f ");
        foreach (var offset in offsets.Skip(1))
        {
            pdf.Append(offset.ToString("0000000000", System.Globalization.CultureInfo.InvariantCulture)).AppendLine(" 00000 n ");
        }

        pdf.AppendLine("trailer");
        pdf.Append("<< /Size ").Append(objects.Count + 1).AppendLine(" /Root 1 0 R >>");
        pdf.AppendLine("startxref");
        pdf.AppendLine(xrefOffset.ToString(System.Globalization.CultureInfo.InvariantCulture));
        pdf.AppendLine("%%EOF");
        return Encoding.ASCII.GetBytes(pdf.ToString());
    }

    private static string EscapePdfText(string value)
    {
        return value
            .Normalize(NormalizationForm.FormD)
            .Where(c => System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c) != System.Globalization.UnicodeCategory.NonSpacingMark)
            .Aggregate(new StringBuilder(), (builder, c) =>
            {
                return c switch
                {
                    '(' => builder.Append("\\("),
                    ')' => builder.Append("\\)"),
                    '\\' => builder.Append("\\\\"),
                    _ when c < 32 || c > 126 => builder.Append(' '),
                    _ => builder.Append(c)
                };
            })
            .ToString();
    }

    private static PositionAssignmentResponse ReadPositionAssignment(NpgsqlDataReader reader)
    {
        return new PositionAssignmentResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetInt64(reader.GetOrdinal("employee_id")),
            reader.GetInt64(reader.GetOrdinal("position_id")),
            reader.GetString(reader.GetOrdinal("position_name")),
            reader.IsDBNull(reader.GetOrdinal("position_code")) ? null : reader.GetString(reader.GetOrdinal("position_code")),
            reader.IsDBNull(reader.GetOrdinal("client_text")) ? null : reader.GetString(reader.GetOrdinal("client_text")),
            reader.GetDateTime(reader.GetOrdinal("start_date")).ToString("yyyy-MM-dd"),
            reader.IsDBNull(reader.GetOrdinal("end_date")) ? null : reader.GetDateTime(reader.GetOrdinal("end_date")).ToString("yyyy-MM-dd"),
            reader.GetString(reader.GetOrdinal("status")),
            reader.IsDBNull(reader.GetOrdinal("change_reason")) ? null : reader.GetString(reader.GetOrdinal("change_reason")),
            reader.IsDBNull(reader.GetOrdinal("notes")) ? null : reader.GetString(reader.GetOrdinal("notes")),
            reader.IsDBNull(reader.GetOrdinal("created_by")) ? null : reader.GetString(reader.GetOrdinal("created_by")),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("updated_at"))));
    }
}
