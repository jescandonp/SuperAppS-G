using System.Text;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using Sg.SuperApp.Api.Contracts.Portal;

namespace Sg.SuperApp.Api.Services;

public sealed class EmployeeXlsxPrevalidationService
{
    private readonly EmployeeCsvPrevalidationService _csvService;

    public EmployeeXlsxPrevalidationService(EmployeeCsvPrevalidationService csvService)
    {
        _csvService = csvService;
    }

    public ImportPrevalidationResult Prevalidate(Stream stream, string fileName, IReadOnlySet<string> existingIdentificationKeys)
    {
        using var document = SpreadsheetDocument.Open(stream, false);
        var workbookPart = document.WorkbookPart ?? throw new InvalidDataException("El archivo XLSX no contiene un libro valido.");
        var sheet = workbookPart.Workbook.Sheets?.Elements<Sheet>().FirstOrDefault()
            ?? throw new InvalidDataException("El archivo XLSX no contiene hojas.");
        var worksheetPart = (WorksheetPart)workbookPart.GetPartById(sheet.Id!);
        var rows = worksheetPart.Worksheet.GetFirstChild<SheetData>()?.Elements<Row>().ToArray()
            ?? Array.Empty<Row>();

        if (rows.Length < 2)
        {
            throw new InvalidDataException("El archivo XLSX debe contener encabezados y al menos un registro.");
        }

        var sharedStrings = workbookPart.SharedStringTablePart?.SharedStringTable;
        var columnCount = rows.Max(row => row.Elements<Cell>().Select(cell => GetColumnIndex(cell.CellReference?.Value)).DefaultIfEmpty(0).Max()) + 1;
        var csv = new StringBuilder();
        foreach (var row in rows)
        {
            var values = Enumerable.Repeat(string.Empty, columnCount).ToArray();
            foreach (var cell in row.Elements<Cell>())
            {
                values[GetColumnIndex(cell.CellReference?.Value)] = GetCellValue(cell, sharedStrings);
            }

            csv.AppendLine(string.Join(",", values.Select(EscapeCsv)));
        }

        using var csvStream = new MemoryStream(Encoding.UTF8.GetBytes(csv.ToString()));
        return _csvService.Prevalidate(csvStream, fileName, existingIdentificationKeys);
    }

    private static string GetCellValue(Cell cell, SharedStringTable? sharedStrings)
    {
        var value = cell.CellValue?.InnerText ?? cell.InlineString?.Text?.Text ?? string.Empty;
        return cell.DataType?.Value == CellValues.SharedString && int.TryParse(value, out var index)
            ? sharedStrings?.ElementAtOrDefault(index)?.InnerText ?? string.Empty
            : value;
    }

    private static int GetColumnIndex(string? reference)
    {
        var letters = new string((reference ?? "A1").TakeWhile(char.IsLetter).ToArray());
        var index = 0;
        foreach (var letter in letters)
        {
            index = index * 26 + char.ToUpperInvariant(letter) - 'A' + 1;
        }
        return Math.Max(0, index - 1);
    }

    private static string EscapeCsv(string value) => $"\"{value.Replace("\"", "\"\"")}\"";
}
