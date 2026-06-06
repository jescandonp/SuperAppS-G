using System.Globalization;
using System.Text;
using Microsoft.VisualBasic.FileIO;
using Sg.SuperApp.Api.Contracts.Portal;

namespace Sg.SuperApp.Api.Services;

public sealed class EmployeeCsvPrevalidationService
{
    private static readonly IReadOnlyDictionary<string, string[]> HeaderAliases =
        new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase)
        {
            ["identification_type"] = new[] { "tipo_identificacion", "tipo_documento" },
            ["identification_number"] = new[] { "numero_identificacion", "identificacion", "cedula", "documento" },
            ["full_name"] = new[] { "nombre_completo", "nombre", "empleado" },
            ["employment_status"] = new[] { "estado_laboral", "estado" },
            ["job_title"] = new[] { "cargo" },
            ["hire_date"] = new[] { "fecha_ingreso", "ingreso" },
            ["termination_date"] = new[] { "fecha_retiro", "retiro" },
            ["base_salary"] = new[] { "salario_base", "salario" }
        };

    public ImportPrevalidationResult Prevalidate(Stream stream, string fileName, IReadOnlySet<string> existingIdentificationKeys)
    {
        var delimiter = DetectDelimiter(stream);
        using var parser = new TextFieldParser(stream);
        parser.TextFieldType = FieldType.Delimited;
        parser.SetDelimiters(delimiter);
        parser.HasFieldsEnclosedInQuotes = true;
        parser.TrimWhiteSpace = false;

        var headers = parser.ReadFields() ?? Array.Empty<string>();
        var columns = ResolveColumns(headers);
        var mappings = BuildMappings(headers, columns);
        var requiredColumns = new[] { "identification_number", "full_name", "employment_status", "job_title", "hire_date", "base_salary" };
        if (requiredColumns.Any(required => !columns.ContainsKey(required)))
        {
            throw new InvalidDataException("El archivo no contiene la estructura minima de empleados.");
        }
        var errors = new List<ImportPrevalidationError>();
        var seenIdentificationKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var total = 0;
        var incomplete = 0;
        var duplicates = 0;
        var invalid = 0;
        var rows = new List<ImportPrevalidationRow>();

        while (!parser.EndOfData)
        {
            var rowNumber = total + 2;
            string[] fields;

            try
            {
                fields = parser.ReadFields() ?? Array.Empty<string>();
            }
            catch (MalformedLineException exception)
            {
                total++;
                invalid++;
                errors.Add(new ImportPrevalidationError(rowNumber, "fila", "FORMATO_INVALIDO", "La fila CSV no tiene un formato valido.", exception.Message));
                continue;
            }

            total++;
            var rowErrors = ValidateRow(fields, rowNumber, columns, seenIdentificationKeys, existingIdentificationKeys);
            errors.AddRange(rowErrors);
            var classification = Classify(rowErrors);
            rows.Add(BuildRow(headers, fields, columns, rowNumber, classification));

            if (classification == "DUPLICADO")
            {
                duplicates++;
            }
            else if (classification == "INCOMPLETO")
            {
                incomplete++;
            }
            else if (classification == "ERRONEO")
            {
                invalid++;
            }
        }

        return new ImportPrevalidationResult(
            fileName,
            total,
            total - incomplete - duplicates - invalid,
            incomplete,
            duplicates,
            invalid,
            errors,
            mappings,
            rows);
    }

    private static string Classify(IReadOnlyCollection<ImportPrevalidationError> errors)
    {
        if (errors.Any(error => error.ErrorType == "DUPLICADO")) return "DUPLICADO";
        if (errors.Any(error => error.ErrorType == "INCOMPLETO")) return "INCOMPLETO";
        return errors.Count > 0 ? "ERRONEO" : "VALIDO";
    }

    private static ImportPrevalidationRow BuildRow(IReadOnlyList<string> headers, IReadOnlyList<string> fields, IReadOnlyDictionary<string, int> columns, int rowNumber, string classification)
    {
        var sourcePayload = headers
            .Select((header, index) => new KeyValuePair<string, string?>(header, index < fields.Count ? fields[index] : null))
            .ToDictionary(item => item.Key, item => item.Value);
        var normalizedPayload = columns.ToDictionary(
            item => item.Key,
            item => item.Value < fields.Count ? NormalizeValue(item.Key, fields[item.Value]) : null,
            StringComparer.OrdinalIgnoreCase);
        var identificationType = normalizedPayload.GetValueOrDefault("identification_type");
        identificationType = string.IsNullOrWhiteSpace(identificationType) ? "CC" : identificationType;
        normalizedPayload["identification_type"] = identificationType;
        normalizedPayload["employment_status"] = ResolveEmploymentStatus(
            normalizedPayload.GetValueOrDefault("employment_status"),
            normalizedPayload.GetValueOrDefault("termination_date"));
        var identification = normalizedPayload.GetValueOrDefault("identification_number");

        return new ImportPrevalidationRow(rowNumber, classification, identificationType, string.IsNullOrWhiteSpace(identification) ? null : identification, normalizedPayload, sourcePayload);
    }

    private static string DetectDelimiter(Stream stream)
    {
        if (!stream.CanSeek)
        {
            return ",";
        }

        using var reader = new StreamReader(stream, Encoding.UTF8, true, 1024, leaveOpen: true);
        var header = reader.ReadLine() ?? string.Empty;
        stream.Seek(0, SeekOrigin.Begin);
        return header.Count(character => character == ';') > header.Count(character => character == ',')
            ? ";"
            : ",";
    }

    private static IReadOnlyDictionary<string, int> ResolveColumns(IReadOnlyList<string> headers)
    {
        var normalizedHeaders = headers
            .Select((header, index) => (Header: NormalizeHeader(header), Index: index))
            .ToDictionary(item => item.Header, item => item.Index, StringComparer.OrdinalIgnoreCase);

        var columns = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var aliasGroup in HeaderAliases)
        {
            var alias = aliasGroup.Value.FirstOrDefault(normalizedHeaders.ContainsKey);
            if (alias is not null)
            {
                columns[aliasGroup.Key] = normalizedHeaders[alias];
            }
        }

        return columns;
    }

    private static IReadOnlyList<ImportColumnMappingResponse> BuildMappings(IReadOnlyList<string> headers, IReadOnlyDictionary<string, int> columns)
    {
        var targetsByPosition = columns.ToDictionary(item => item.Value, item => item.Key);
        return headers.Select((header, position) => new ImportColumnMappingResponse(
            header,
            targetsByPosition.TryGetValue(position, out var targetField) ? targetField : null,
            targetsByPosition.ContainsKey(position) ? "MAPPED" : "UNMAPPED",
            position)).ToArray();
    }

    private static List<ImportPrevalidationError> ValidateRow(
        IReadOnlyList<string> fields,
        int rowNumber,
        IReadOnlyDictionary<string, int> columns,
        ISet<string> seenIdentificationKeys,
        IReadOnlySet<string> existingIdentificationKeys)
    {
        var errors = new List<ImportPrevalidationError>();
        var identificationType = GetIdentificationType(fields, columns);
        var identification = GetValue(fields, columns, "identification_number");
        var name = GetValue(fields, columns, "full_name");
        var status = ResolveEmploymentStatus(
            GetValue(fields, columns, "employment_status"),
            GetValue(fields, columns, "termination_date"));
        var jobTitle = GetValue(fields, columns, "job_title");
        var hireDate = GetValue(fields, columns, "hire_date");
        var terminationDate = GetValue(fields, columns, "termination_date");
        var salary = GetValue(fields, columns, "base_salary");

        AddRequiredError(errors, rowNumber, "numero_identificacion", identification);
        AddRequiredError(errors, rowNumber, "nombre_completo", name);
        AddRequiredError(errors, rowNumber, "estado_laboral", status);
        AddRequiredError(errors, rowNumber, "cargo", jobTitle);
        AddRequiredError(errors, rowNumber, "fecha_ingreso", hireDate);
        AddRequiredError(errors, rowNumber, "salario_base", salary);

        if (!string.IsNullOrWhiteSpace(identificationType) && identificationType is not ("CC" or "CE"))
        {
            errors.Add(new ImportPrevalidationError(rowNumber, "tipo_identificacion", "VALOR_NO_RECONOCIDO", "El tipo de identificacion debe ser CC o CE.", identificationType));
        }

        if (!string.IsNullOrWhiteSpace(identification))
        {
            var identificationKey = BuildIdentificationKey(identificationType, identification);
            if (!seenIdentificationKeys.Add(identificationKey))
            {
                errors.Add(new ImportPrevalidationError(rowNumber, "numero_identificacion", "DUPLICADO", "La identificacion esta repetida dentro del archivo.", identification));
            }
            else if (existingIdentificationKeys.Contains(identificationKey))
            {
                errors.Add(new ImportPrevalidationError(rowNumber, "numero_identificacion", "DUPLICADO", "La identificacion ya existe en el maestro de empleados.", identification));
            }
        }

        if (!string.IsNullOrWhiteSpace(status) && status is not ("ACTIVO" or "RETIRADO"))
        {
            errors.Add(new ImportPrevalidationError(rowNumber, "estado_laboral", "VALOR_NO_RECONOCIDO", "El estado laboral debe ser ACTIVO o RETIRADO.", status));
        }

        ValidateDate(errors, rowNumber, "fecha_ingreso", hireDate);
        ValidateDate(errors, rowNumber, "fecha_retiro", terminationDate);
        ValidateDateOrder(errors, rowNumber, hireDate, terminationDate);

        if (status == "RETIRADO" && string.IsNullOrWhiteSpace(terminationDate))
        {
            AddRequiredError(errors, rowNumber, "fecha_retiro", terminationDate);
        }

        if (!string.IsNullOrWhiteSpace(salary) && !TryParseSalary(salary, out _))
        {
            errors.Add(new ImportPrevalidationError(rowNumber, "salario_base", "FORMATO_INVALIDO", "El salario base debe ser numerico y mayor o igual a cero.", salary));
        }

        return errors;
    }

    private static void AddRequiredError(ICollection<ImportPrevalidationError> errors, int rowNumber, string field, string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Equals("#N/A", StringComparison.OrdinalIgnoreCase))
        {
            errors.Add(new ImportPrevalidationError(rowNumber, field, "INCOMPLETO", $"El campo {field} es obligatorio.", value));
        }
    }

    private static void ValidateDate(ICollection<ImportPrevalidationError> errors, int rowNumber, string field, string value)
    {
        if (!string.IsNullOrWhiteSpace(value) && !DateOnly.TryParse(value, CultureInfo.GetCultureInfo("es-CO"), DateTimeStyles.None, out _))
        {
            errors.Add(new ImportPrevalidationError(rowNumber, field, "FORMATO_INVALIDO", $"El campo {field} no contiene una fecha valida.", value));
        }
    }

    private static void ValidateDateOrder(ICollection<ImportPrevalidationError> errors, int rowNumber, string hireDate, string terminationDate)
    {
        var culture = CultureInfo.GetCultureInfo("es-CO");
        if (DateOnly.TryParse(hireDate, culture, DateTimeStyles.None, out var parsedHireDate)
            && DateOnly.TryParse(terminationDate, culture, DateTimeStyles.None, out var parsedTerminationDate)
            && parsedTerminationDate < parsedHireDate)
        {
            errors.Add(new ImportPrevalidationError(
                rowNumber,
                "fecha_retiro",
                "FECHA_INCONSISTENTE",
                "La fecha de retiro no puede ser anterior a la fecha de ingreso.",
                terminationDate));
        }
    }

    private static bool TryParseSalary(string value, out decimal salary)
    {
        var normalized = value.Replace("$", string.Empty).Replace(" ", string.Empty);
        return decimal.TryParse(normalized, NumberStyles.Number, CultureInfo.GetCultureInfo("es-CO"), out salary) && salary >= 0;
    }

    private static string GetValue(IReadOnlyList<string> fields, IReadOnlyDictionary<string, int> columns, string field)
    {
        return columns.TryGetValue(field, out var index) && index < fields.Count
            ? fields[index].Trim()
            : string.Empty;
    }

    private static string GetIdentificationType(IReadOnlyList<string> fields, IReadOnlyDictionary<string, int> columns)
    {
        var identificationType = GetValue(fields, columns, "identification_type").ToUpperInvariant();
        return string.IsNullOrWhiteSpace(identificationType) ? "CC" : identificationType;
    }

    public static string BuildIdentificationKey(string identificationType, string identificationNumber)
    {
        return $"{identificationType.Trim().ToUpperInvariant()}|{identificationNumber.Trim().ToUpperInvariant()}";
    }

    private static string NormalizeValue(string field, string value)
    {
        var trimmed = value.Trim();
        if (field == "base_salary" && TryParseSalary(trimmed, out var salary))
        {
            return salary.ToString("0.00", CultureInfo.InvariantCulture);
        }

        return field is "identification_type" or "employment_status"
            ? trimmed.ToUpperInvariant()
            : trimmed;
    }

    private static string ResolveEmploymentStatus(string? employmentStatus, string? terminationDate)
    {
        var normalizedStatus = employmentStatus?.Trim().ToUpperInvariant() ?? string.Empty;
        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            return normalizedStatus;
        }

        return string.IsNullOrWhiteSpace(terminationDate) ? "ACTIVO" : "RETIRADO";
    }

    private static string NormalizeHeader(string value)
    {
        var normalized = value.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        return string.Concat(normalized.Where(character => CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark))
            .Replace(" ", "_")
            .Replace("-", "_");
    }
}
