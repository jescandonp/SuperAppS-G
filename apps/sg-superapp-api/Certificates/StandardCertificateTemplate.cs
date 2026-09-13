using System.Globalization;
using PdfSharpCore.Drawing;

namespace Sg.SuperApp.Api.Certificates;

/// <summary>
/// Layout tabla para certificados de empleado ACTIVO, calcado del certificado real
/// dirigido a entidad financiera (referencia: CERT LUIS CARLOS YOLIS CORREA).
/// </summary>
public static class StandardCertificateTemplate
{
    private static readonly CultureInfo Money = new("es-CO");
    private static readonly string[] SpanishMonths =
    {
        "ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO",
        "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"
    };

    public static void Draw(XGraphics gfx, CertificateDocumentData data)
    {
        CertificateLetterhead.Draw(gfx);

        var titleFont = new XFont(CertificateFontResolver.FamilyName, 13, XFontStyle.Bold);
        var labelFont = new XFont(CertificateFontResolver.FamilyName, 10, XFontStyle.Bold);
        var valueFont = new XFont(CertificateFontResolver.FamilyName, 10, XFontStyle.Regular);
        var brush = XBrushes.Black;

        double y = 165;
        gfx.DrawString("EMPRESA SEGURIDAD GESTION LTDA", titleFont, brush, new XRect(0, y, 612, 20), XStringFormats.TopCenter);
        y += 18;
        gfx.DrawString("CERTIFICA", titleFont, brush, new XRect(0, y, 612, 20), XStringFormats.TopCenter);
        y += 34;

        gfx.DrawString("El siguiente trabajador labora en nuestra empresa:", valueFont, brush, new XPoint(50, y));
        y += 26;

        DrawField(gfx, labelFont, valueFont, ref y, "NOMBRE DEL TRABAJADOR", data.EmployeeFullName);
        DrawField(gfx, labelFont, valueFont, ref y, "IDENTIFICACION", data.IdentificationNumber);
        DrawField(gfx, labelFont, valueFont, ref y, "FECHA DE INGRESO", data.HireDate.ToString("dd/MM/yyyy"));
        DrawField(gfx, labelFont, valueFont, ref y, "CARGO", data.JobTitle);
        DrawField(gfx, labelFont, valueFont, ref y, "TIPO DE CONTRATO", data.ContractType ?? "NO REGISTRADO");
        DrawField(gfx, labelFont, valueFont, ref y, "SUELDO", BuildSalaryLine(data));

        y += 8;
        var addressee = string.IsNullOrWhiteSpace(data.AddressedTo) ? PurposeLabel(data.Purpose) : data.AddressedTo;
        var closing =
            $"Dirigida a {addressee}. Esta certificacion no tiene validez sin la debida verificacion a traves " +
            $"del numero de contacto institucional: (601) 6139838. Expedida en Bogota D.C a los {FormatDay(data.IssueDate)} " +
            $"dias del mes de {SpanishMonths[data.IssueDate.Month - 1]} de {data.IssueDate.Year}.";
        var closingRect = new XRect(50, y, 512, 60);
        gfx.DrawString(closing, valueFont, brush, closingRect, XStringFormats.TopLeft);
        y += MeasureWrappedHeight(gfx, valueFont, closing, 512) + 20;

        gfx.DrawString("Cordialmente,", valueFont, brush, new XPoint(50, y));
        y += 45;
        gfx.DrawString(data.SignerFullName, valueFont, brush, new XPoint(50, y));
        y += 14;
        gfx.DrawString($"{data.SignerJobTitle}.", valueFont, brush, new XPoint(50, y));
        y += 14;
        gfx.DrawString("c.c. hoja de vida", valueFont, brush, new XPoint(50, y));
        y += 22;
        gfx.DrawString($"Elaborado: {data.PreparedByFullName}", valueFont, brush, new XPoint(50, y));
        y += 14;
        gfx.DrawString("Talento Humano", valueFont, brush, new XPoint(50, y));

        CertificateSignatureStamp.DrawIfAvailable(gfx, data.SignerSignaturePath, x: 50, signatureLineY: y - 45);
    }

    private static void DrawField(XGraphics gfx, XFont labelFont, XFont valueFont, ref double y, string label, string value)
    {
        gfx.DrawString(label, labelFont, XBrushes.Black, new XPoint(50, y));
        gfx.DrawString(value, valueFont, XBrushes.Black, new XRect(230, y - 10, 330, 40), XStringFormats.TopLeft);
        y += 24;
    }

    private static string BuildSalaryLine(CertificateDocumentData data)
    {
        var parts = new List<string> { $"SALARIO BASICO ({FormatMoney(data.BaseSalary)})" };
        var transport = data.Variables.FirstOrDefault(v => v.ConceptCode == "AUXILIO_TRANSPORTE");
        var overtime = data.Variables.FirstOrDefault(v => v.ConceptCode == "EXTRAS");
        if (transport is not null)
        {
            parts.Add($"AUXILIO DE TRANSPORTE ({FormatMoney(transport.Amount)})");
        }

        if (overtime is not null)
        {
            parts.Add($"EXTRAS DE ({FormatMoney(overtime.Amount)})");
        }

        var extras = data.Variables.Where(v => v.ConceptCode != "AUXILIO_TRANSPORTE" && v.ConceptCode != "EXTRAS").ToList();
        var line = string.Join(" + ", parts);
        if (extras.Count > 0)
        {
            line += " + " + string.Join(" + ", extras.Select(v => $"{v.ConceptLabel} ({FormatMoney(v.Amount)})"));
        }

        return line;
    }

    private static string FormatMoney(decimal? amount) => amount is null ? "$0" : $"${amount.Value.ToString("N0", Money)}";

    private static string FormatDay(DateOnly date) => $"({date.Day:00})";

    private static string PurposeLabel(string purpose) => purpose switch
    {
        "ENTIDAD_FINANCIERA" => "ENTIDAD FINANCIERA",
        "CLIENTE" => "CLIENTE",
        "TRAMITE_GENERAL" => "QUIEN INTERESE",
        "INTERESADO" => "QUIEN INTERESE",
        _ => "QUIEN INTERESE"
    };

    private static double MeasureWrappedHeight(XGraphics gfx, XFont font, string text, double width)
    {
        var size = gfx.MeasureString(text, font);
        var linesEstimate = Math.Max(1, Math.Ceiling(size.Width / width));
        return linesEstimate * (font.Size + 4);
    }
}
