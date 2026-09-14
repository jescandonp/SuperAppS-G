using PdfSharpCore.Drawing;
using PdfSharpCore.Pdf;

namespace Sg.SuperApp.Api.Certificates;

public static class CertificateDocumentBuilder
{
    public static byte[] Build(CertificateDocumentData data)
    {
        CertificateFontResolver.EnsureRegistered();

        using var document = new PdfDocument();
        var page = document.AddPage();
        page.Size = PdfSharpCore.PageSize.Letter;

        using var gfx = XGraphics.FromPdfPage(page);
        if (data.CertificateType == "RETIRADO")
        {
            RetirementCertificateTemplate.Draw(gfx, data);
        }
        else
        {
            StandardCertificateTemplate.Draw(gfx, data);
        }

        using var stream = new MemoryStream();
        document.Save(stream, closeStream: false);
        return stream.ToArray();
    }
}
