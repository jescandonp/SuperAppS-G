using PdfSharpCore.Drawing;

namespace Sg.SuperApp.Api.Certificates;

/// <summary>
/// Incrusta la imagen de firma escaneada del firmante activo sobre la linea de firma,
/// si el firmante tiene una ruta de imagen configurada y el archivo existe. Si no,
/// no dibuja nada y el documento queda igual que hoy (espacio en blanco para firma fisica).
/// </summary>
public static class CertificateSignatureStamp
{
    private static string SignaturesDirectory =>
        Environment.GetEnvironmentVariable("SG_CERTIFICATE_SIGNATURES_DIR")
        is { Length: > 0 } configured
            ? configured
            : Path.Combine(AppContext.BaseDirectory, "certificate-signatures");

    public static void DrawIfAvailable(XGraphics gfx, string? signaturePath, double x, double signatureLineY)
    {
        var resolved = Resolve(signaturePath);
        if (resolved is null)
        {
            return;
        }

        using var image = XImage.FromFile(resolved);
        var height = 40.0;
        var width = height * image.PixelWidth / image.PixelHeight;
        gfx.DrawImage(image, x, signatureLineY - height, width, height);
    }

    private static string? Resolve(string? signaturePath)
    {
        if (string.IsNullOrWhiteSpace(signaturePath))
        {
            return null;
        }

        var resolved = Path.IsPathRooted(signaturePath)
            ? signaturePath
            : Path.Combine(SignaturesDirectory, signaturePath);
        return File.Exists(resolved) ? resolved : null;
    }
}
