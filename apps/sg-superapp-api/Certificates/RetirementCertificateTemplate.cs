using PdfSharpCore.Drawing;

namespace Sg.SuperApp.Api.Certificates;

/// <summary>
/// Layout narrativo para certificados de empleado RETIRADO, calcado del certificado
/// real de retiro (referencia: CERT RETIRADO ORLANDO ESTEBAN CADENA LONDOÑO).
/// </summary>
public static class RetirementCertificateTemplate
{
    private static readonly string[] SpanishMonthsLower =
    {
        "enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
    };

    private const double BodyX = CertificateTextLayout.ContentX;
    private const double BodyWidth = CertificateTextLayout.ContentWidth;

    /// <summary>
    /// Espacio en blanco entre "Cordialmente;" y el nombre del firmante. Debe ser mayor
    /// que los 40pt de alto que dibuja <see cref="CertificateSignatureStamp"/> mas holgura,
    /// para que la imagen de firma no se monte sobre ninguno de los dos textos.
    /// </summary>
    private const double SignatureGap = 58;

    private const double SignatureToNameGap = 18;

    public static void Draw(XGraphics gfx, CertificateDocumentData data)
    {
        CertificateLetterhead.Draw(gfx);

        var titleFont = new XFont(CertificateFontResolver.FamilyName, 12, XFontStyle.Bold);
        var boldFont = new XFont(CertificateFontResolver.FamilyName, 10, XFontStyle.Bold);
        var bodyFont = new XFont(CertificateFontResolver.FamilyName, 10, XFontStyle.Regular);
        var underlineFont = new XFont(CertificateFontResolver.FamilyName, 9, XFontStyle.BoldItalic);
        var numberFont = new XFont(CertificateFontResolver.FamilyName, 8, XFontStyle.Regular);
        var brush = XBrushes.Black;
        var lineHeight = CertificateTextLayout.LineHeightFor(bodyFont);

        double y = 165;
        gfx.DrawString("EL SUSCRITO SUBGERENTE DE SEGURIDAD GESTION LTDA.", titleFont, brush, new XRect(0, y, 612, 18), XStringFormats.TopCenter);
        y += 16;
        gfx.DrawString("NIT: 900.033.333-4", titleFont, brush, new XRect(0, y, 612, 18), XStringFormats.TopCenter);
        y += 18;
        gfx.DrawString(
            $"No. {data.CertificateNumber}",
            numberFont,
            brush,
            new XRect(BodyX, y, BodyWidth, 12),
            XStringFormats.TopRight);
        y += 16;
        gfx.DrawString("CERTIFICA:", titleFont, brush, new XRect(0, y, 612, 18), XStringFormats.TopCenter);
        y += 34;

        var identificationPhrase = IdentificationPhrase(data.IdentificationType);
        var terminationText = data.TerminationDate is { } termination
            ? termination.ToString("dd/MM/yyyy")
            : "FECHA NO REGISTRADA";
        var mainParagraph =
            $"Que el señor(a) {data.EmployeeFullName}, identificado(a) con la {identificationPhrase} No {data.IdentificationNumber}, laboró en nuestra empresa desde el día {data.HireDate:dd/MM/yyyy} hasta el día {terminationText} desempeñando el cargo de ({data.JobTitle}).";
        y = CertificateTextLayout.DrawWrapped(gfx, bodyFont, brush, BodyX, y, BodyWidth, mainParagraph, lineHeight);
        y += 8;

        gfx.DrawString($"MOTIVO DE RETIRO: {data.TerminationReason ?? "NO REGISTRADO"}.", boldFont, brush, new XPoint(BodyX, y));
        y += 26;

        var monthNameLower = SpanishMonthsLower[data.IssueDate.Month - 1];
        var issuanceParagraph =
            $"La presente certificación se expide en Bogotá D.C; a solicitud del interesado a los ({data.IssueDate.Day:00}) días del mes de {monthNameLower} de {data.IssueDate.Year}. Exonerando a la empresa de expedir certificaciones posteriores a la fecha.";
        y = CertificateTextLayout.DrawWrapped(gfx, bodyFont, brush, BodyX, y, BodyWidth, issuanceParagraph, lineHeight);
        y += 10;

        if (data.Purpose == "CESANTIAS")
        {
            const string legalParagraph =
                "Dando cumplimiento al Decreto No. 1562 de 2019 esta carta es válida para el retiro de las cesantías";
            y = CertificateTextLayout.DrawWrapped(gfx, bodyFont, brush, BodyX, y, BodyWidth, legalParagraph, lineHeight);
            y += 10;
        }

        const string verificationParagraph =
            "Esta certificación no tiene validez sin la debida verificación a través del número de contacto institucional: (601) 6139838.";
        y = CertificateTextLayout.DrawWrapped(gfx, bodyFont, brush, BodyX, y, BodyWidth, verificationParagraph, lineHeight);
        y += 20;

        gfx.DrawString("Cordialmente;", bodyFont, brush, new XPoint(BodyX, y));
        var signatureLineY = y + SignatureGap;
        y = signatureLineY + SignatureToNameGap;

        gfx.DrawString($"{data.SignerFullName}.", bodyFont, brush, new XPoint(BodyX, y));
        y += 14;
        gfx.DrawString(data.SignerJobTitle, bodyFont, brush, new XPoint(BodyX, y));
        y += 14;
        gfx.DrawString("c.c. hoja de vida", bodyFont, brush, new XPoint(BodyX, y));
        y += 20;
        y = CertificateTextLayout.DrawWrapped(
            gfx,
            underlineFont,
            brush,
            BodyX,
            y,
            BodyWidth,
            "CONSERVAR ORIGINAL Y COPIA DE ESTE DOCUMENTO, YA QUE SE EMITE POR UNA ÚNICA VEZ.",
            CertificateTextLayout.LineHeightFor(underlineFont));
        y += 16;
        gfx.DrawString($"Elaborado: {data.PreparedByFullName}", bodyFont, brush, new XPoint(BodyX, y));
        y += 14;
        gfx.DrawString("Talento Humano", bodyFont, brush, new XPoint(BodyX, y));

        CertificateSignatureStamp.DrawIfAvailable(gfx, data.SignerSignaturePath, x: BodyX, signatureLineY: signatureLineY);
    }

    /// <summary>
    /// Frase del documento de identidad segun el tipo registrado. Ante un codigo no
    /// reconocido se usa "cédula de ciudadanía" (el caso abrumadoramente mayoritario en
    /// esta empresa) en lugar de fallar.
    /// </summary>
    private static string IdentificationPhrase(string? identificationType) =>
        (identificationType ?? string.Empty).Trim().ToUpperInvariant() switch
        {
            "" or "CC" => "cédula de ciudadanía",
            "CE" => "cédula de extranjería",
            "PA" or "PASAPORTE" => "pasaporte",
            _ => "cédula de ciudadanía"
        };
}
