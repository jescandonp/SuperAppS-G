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

    private const double LabelX = CertificateTextLayout.ContentX;
    private const double ValueX = 230;
    private const double ValueWidth = 330;
    private const double FieldSpacing = 24;

    /// <summary>
    /// Espacio en blanco entre "Cordialmente," y el nombre del firmante. Debe ser mayor
    /// que los 40pt de alto que dibuja <see cref="CertificateSignatureStamp"/> mas holgura,
    /// para que la imagen de firma no se monte sobre ninguno de los dos textos.
    /// </summary>
    private const double SignatureGap = 58;

    private const double SignatureToNameGap = 18;

    public static void Draw(XGraphics gfx, CertificateDocumentData data)
    {
        CertificateLetterhead.Draw(gfx);

        var titleFont = new XFont(CertificateFontResolver.FamilyName, 13, XFontStyle.Bold);
        var labelFont = new XFont(CertificateFontResolver.FamilyName, 10, XFontStyle.Bold);
        var valueFont = new XFont(CertificateFontResolver.FamilyName, 10, XFontStyle.Regular);
        var numberFont = new XFont(CertificateFontResolver.FamilyName, 8, XFontStyle.Regular);
        var brush = XBrushes.Black;
        var lineHeight = CertificateTextLayout.LineHeightFor(valueFont);

        double y = 165;
        gfx.DrawString("EMPRESA SEGURIDAD GESTION LTDA", titleFont, brush, new XRect(0, y, 612, 20), XStringFormats.TopCenter);
        y += 18;
        gfx.DrawString("CERTIFICA", titleFont, brush, new XRect(0, y, 612, 20), XStringFormats.TopCenter);
        y += 18;

        gfx.DrawString(
            $"No. {data.CertificateNumber}",
            numberFont,
            brush,
            new XRect(CertificateTextLayout.ContentX, y, CertificateTextLayout.ContentWidth, 12),
            XStringFormats.TopRight);
        y += 22;

        gfx.DrawString("El siguiente trabajador labora en nuestra empresa:", valueFont, brush, new XPoint(LabelX, y));
        y += 26;

        DrawField(gfx, labelFont, valueFont, ref y, "NOMBRE DEL TRABAJADOR", data.EmployeeFullName);
        DrawField(gfx, labelFont, valueFont, ref y, "IDENTIFICACION", data.IdentificationNumber);
        DrawField(gfx, labelFont, valueFont, ref y, "FECHA DE INGRESO", data.HireDate.ToString("dd/MM/yyyy"));
        DrawField(gfx, labelFont, valueFont, ref y, "CARGO", data.JobTitle);
        DrawField(gfx, labelFont, valueFont, ref y, "TIPO DE CONTRATO", data.ContractType ?? "NO REGISTRADO");
        DrawWrappedField(gfx, labelFont, valueFont, ref y, "SUELDO", BuildSalaryLine(data), lineHeight);

        y += 8;
        var addressee = string.IsNullOrWhiteSpace(data.AddressedTo) ? PurposeLabel(data.Purpose) : data.AddressedTo;
        var monthName = SpanishMonths[data.IssueDate.Month - 1];
        var closing =
            $"Dirigida a {addressee}. Esta certificación no tiene validez sin la debida verificación a través del número de contacto institucional: (601) 6139838. Expedida en Bogotá D.C a los ({data.IssueDate.Day:00}) días del mes de {monthName} de {data.IssueDate.Year}.";
        y = CertificateTextLayout.DrawWrapped(
            gfx, valueFont, brush, CertificateTextLayout.ContentX, y, CertificateTextLayout.ContentWidth, closing, lineHeight);
        y += 20;

        gfx.DrawString("Cordialmente,", valueFont, brush, new XPoint(LabelX, y));
        var signatureLineY = y + SignatureGap;
        y = signatureLineY + SignatureToNameGap;

        gfx.DrawString(data.SignerFullName, valueFont, brush, new XPoint(LabelX, y));
        y += 14;
        gfx.DrawString($"{data.SignerJobTitle}.", valueFont, brush, new XPoint(LabelX, y));
        y += 14;
        gfx.DrawString("c.c. hoja de vida", valueFont, brush, new XPoint(LabelX, y));
        y += 22;
        gfx.DrawString($"Elaborado: {data.PreparedByFullName}", valueFont, brush, new XPoint(LabelX, y));
        y += 14;
        gfx.DrawString("Talento Humano", valueFont, brush, new XPoint(LabelX, y));

        CertificateSignatureStamp.DrawIfAvailable(gfx, data.SignerSignaturePath, x: LabelX, signatureLineY: signatureLineY);
    }

    private static void DrawField(XGraphics gfx, XFont labelFont, XFont valueFont, ref double y, string label, string value)
    {
        gfx.DrawString(label, labelFont, XBrushes.Black, new XPoint(LabelX, y));
        gfx.DrawString(value, valueFont, XBrushes.Black, new XPoint(ValueX, y));
        y += FieldSpacing;
    }

    /// <summary>
    /// Igual que <see cref="DrawField"/> pero el valor puede desbordar la columna: se parte en
    /// varias lineas y "y" avanza segun las lineas realmente dibujadas.
    /// </summary>
    private static void DrawWrappedField(
        XGraphics gfx, XFont labelFont, XFont valueFont, ref double y, string label, string value, double lineHeight)
    {
        gfx.DrawString(label, labelFont, XBrushes.Black, new XPoint(LabelX, y));
        var afterValue = CertificateTextLayout.DrawWrapped(
            gfx, valueFont, XBrushes.Black, ValueX, y, ValueWidth, value, lineHeight);
        y = Math.Max(y + FieldSpacing, afterValue + (FieldSpacing - lineHeight));
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

    private static string PurposeLabel(string purpose) => purpose switch
    {
        "ENTIDAD_FINANCIERA" => "ENTIDAD FINANCIERA",
        "CLIENTE" => "CLIENTE",
        "CESANTIAS" => "EL FONDO DE CESANTIAS",
        "TRAMITE_GENERAL" => "QUIEN INTERESE",
        "INTERESADO" => "QUIEN INTERESE",
        _ => "QUIEN INTERESE"
    };
}
