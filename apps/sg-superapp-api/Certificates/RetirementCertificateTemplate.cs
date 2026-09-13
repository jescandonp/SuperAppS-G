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

    public static void Draw(XGraphics gfx, CertificateDocumentData data)
    {
        CertificateLetterhead.Draw(gfx);

        var titleFont = new XFont(CertificateFontResolver.FamilyName, 12, XFontStyle.Bold);
        var boldFont = new XFont(CertificateFontResolver.FamilyName, 10, XFontStyle.Bold);
        var bodyFont = new XFont(CertificateFontResolver.FamilyName, 10, XFontStyle.Regular);
        var underlineFont = new XFont(CertificateFontResolver.FamilyName, 9, XFontStyle.BoldItalic);
        var brush = XBrushes.Black;
        var bodyRect = new XRect(50, 0, 512, 700);

        double y = 165;
        gfx.DrawString("EL SUSCRITO SUBGERENTE DE SEGURIDAD GESTION LTDA.", titleFont, brush, new XRect(0, y, 612, 18), XStringFormats.TopCenter);
        y += 16;
        gfx.DrawString("NIT: 900.033.333-4", titleFont, brush, new XRect(0, y, 612, 18), XStringFormats.TopCenter);
        y += 34;
        gfx.DrawString("CERTIFICA:", titleFont, brush, new XRect(0, y, 612, 18), XStringFormats.TopCenter);
        y += 34;

        var terminationDate = data.TerminationDate ?? data.HireDate;
        var mainParagraph =
            $"Que el señor(a) {data.EmployeeFullName}, identificado(a) con la cedula de ciudadania No " +
            $"{data.IdentificationNumber}, laboro en nuestra empresa desde el dia {data.HireDate:dd/MM/yyyy} hasta " +
            $"el dia {terminationDate:dd/MM/yyyy} desempeñando el cargo de ({data.JobTitle}).";
        y = DrawParagraph(gfx, bodyFont, brush, bodyRect, y, mainParagraph);
        y += 4;

        gfx.DrawString($"MOTIVO DE RETIRO: {data.TerminationReason ?? "NO REGISTRADO"}.", boldFont, brush, new XPoint(50, y));
        y += 26;

        var issuanceParagraph =
            $"La presente certificacion se expide en Bogota D.C; a solicitud del interesado a los ({data.IssueDate.Day:00}) " +
            $"dias del mes de {SpanishMonthsLower[data.IssueDate.Month - 1]} de {data.IssueDate.Year}. Exonerando a la " +
            "empresa de expedir certificaciones posteriores a la fecha.";
        y = DrawParagraph(gfx, bodyFont, brush, bodyRect, y, issuanceParagraph);
        y += 10;

        if (data.Purpose == "CESANTIAS")
        {
            var legalParagraph = "Dando cumplimiento al Decreto No. 1562 de 2019 esta carta es valida para el retiro de las cesantias.";
            y = DrawParagraph(gfx, bodyFont, brush, bodyRect, y, legalParagraph);
            y += 10;
        }

        var verificationParagraph =
            "Esta certificacion no tiene validez sin la debida verificacion a traves del numero de contacto institucional: (601) 6139838.";
        y = DrawParagraph(gfx, bodyFont, brush, bodyRect, y, verificationParagraph);
        y += 20;

        gfx.DrawString("Cordialmente;", bodyFont, brush, new XPoint(50, y));
        y += 45;
        gfx.DrawString($"{data.SignerFullName}.", bodyFont, brush, new XPoint(50, y));
        y += 14;
        gfx.DrawString(data.SignerJobTitle, bodyFont, brush, new XPoint(50, y));
        y += 14;
        gfx.DrawString("c.c. hoja de vida", bodyFont, brush, new XPoint(50, y));
        y += 16;
        gfx.DrawString(
            "CONSERVAR ORIGINAL Y COPIA DE ESTE DOCUMENTO, YA QUE SE EMITE POR UNA UNICA VEZ.",
            underlineFont, brush, new XRect(50, y, 512, 26), XStringFormats.TopLeft);
        y += 30;
        gfx.DrawString($"Elaborado: {data.PreparedByFullName}", bodyFont, brush, new XPoint(50, y));
        y += 14;
        gfx.DrawString("Talento Humano", bodyFont, brush, new XPoint(50, y));

        CertificateSignatureStamp.DrawIfAvailable(gfx, data.SignerSignaturePath, x: 50, signatureLineY: y - 59);
    }

    private static double DrawParagraph(XGraphics gfx, XFont font, XBrush brush, XRect rect, double y, string text)
    {
        var box = new XRect(rect.X, y, rect.Width, 80);
        gfx.DrawString(text, font, brush, box, XStringFormats.TopLeft);
        var size = gfx.MeasureString(text, font);
        var lines = Math.Max(1, Math.Ceiling(size.Width / rect.Width));
        return y + lines * (font.Size + 5) + 4;
    }
}
