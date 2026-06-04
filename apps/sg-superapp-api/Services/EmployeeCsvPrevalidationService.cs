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
            ["identification_number"] = new[] { "numero_identificacion", "identificacion", "cedula", "documento" },
            ["full_name"] = new[] { "nombre_completo", "nombre", "empleado" },
            ["employment_status"] = new[] { "estado_laboral", "estado" },
            ["job_title"] = new[] { "cargo" },
            ["hire_date"] = new[] { "fecha_ingreso", "ingreso" },
            ["termination_date"] = new[] { "fecha_retiro", "retiro" },
            ["base_salary"] = new[] { "salario_base", "salario" }
        };

    public ImportPrevalidationResult Prevalidate(Stream stream, string fileName, IReadOnlySet<string> existingIdentifications)
    {
        var delimiter = DetectDelimiter(stream);
        using var parser = new TextFieldParser(stream);
        parser.TextFieldType = FieldType.Delimited;
        parser.SetDelimiters(delimiter);
        parser.HasFieldsEnclosedInQuotes = true;
        parser.TrimWhiteSpace = true;

        var headers = parser.ReadFields() ?? Array.Empty<string>();
        var columns = ResolveColumns(headers);
        var errors = new List<ImportPrevalidationError>();
        var seenIdentifications = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var total = 0;
        var incomplete = 0;
        var duplicates = 0;
        var invalid = 0;

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
            var rowErrors = ValidateRow(fields, rowNumber, columns, seenIdentifications, existingIdentifications);
            errors.AddRange(rowErrors);

            if (rowErrors.Any(error => error.ErrorType == "DUPLICADO"))
            {
                duplicates++;
            }
            else if (rowErrors.Any(error => error.ErrorType == "INCOMPLETO"))
            {
                incomplete++;
            }
            else if (rowErrors.Count > 0)
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
            errors);
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

    private static List<ImportPrevalidationError> ValidateRow(
        IReadOnlyList<string> fields,
        int rowNumber,
        IReadOnlyDictionary<string, int> columns,
        ISet<string> seenIdentifications,
        IReadOnlySet<string> existingIdentifications)
    {
        var errors = new List<ImportPrevalidationError>();
        var identification = GetValue(fields, columns, "identification_number");
        var name = GetValue(fields, columns, "full_name");
        var status = GetValue(fields, columns, "employment_status").ToUpperInvariant();
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

        if (!string.IsNullOrWhiteSpace(identification))
        {
            if (!seenIdentifications.Add(identification))
            {
                errors.Add(new ImportPrevalidationError(rowNumber, "numero_identificacion", "DUPLICADO", "La identificacion esta repetida dentro del archivo.", identification));
            }
            else if (existingIdentifications.Contains(identification))
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

        if (status == "RETIRADO" && string.IsNullOrWhiteSpace(terminationDate))
        {
            AddRequiredError(errors, rowNumber, "fecha_retiro", terminationDate);
        }

        if (!string.IsNullOrWhiteSpace(salary) && !TryParseSalary(salary))
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

    private static bool TryParseSalary(string value)
    {
        var normalized = value.Replace("$", string.Empty).Replace(" ", string.Empty);
        return decimal.TryParse(normalized, NumberStyles.Number, CultureInfo.GetCultureInfo("es-CO"), out var salary) && salary >= 0;
    }

    private static string GetValue(IReadOnlyList<string> fields, IReadOnlyDictionary<string, int> columns, string field)
    {
        return columns.TryGetValue(field, out var index) && index < fields.Count
            ? fields[index].Trim()
            : string.Empty;
    }

    private static string NormalizeHeader(string value)
    {
        var normalized = value.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        return string.Concat(normalized.Where(character => CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark))
            .Replace(" ", "_")
            .Replace("-", "_");
    }
}
