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

        XImage image;
        try
        {
            image = XImage.FromFile(resolved);
        }
        catch (Exception)
        {
            // Firma corrupta o ilegible: el certificado se emite igual, con el espacio
            // en blanco para firma fisica, en vez de convertirse en un error 500.
            return;
        }

        using (image)
        {
            var height = 40.0;
            var width = height * image.PixelWidth / image.PixelHeight;
            gfx.DrawImage(image, x, signatureLineY - height, width, height);
        }
    }

    private static string? Resolve(string? signaturePath)
    {
        if (string.IsNullOrWhiteSpace(signaturePath))
        {
            return null;
        }

        string resolved;
        if (Path.IsPathRooted(signaturePath))
        {
            resolved = signaturePath;
        }
        else
        {
            // Ruta relativa: debe quedar dentro del directorio de firmas despues de
            // normalizar, para que un "..\..\algo" no pueda leer archivos arbitrarios.
            var baseDirectory = Path.GetFullPath(SignaturesDirectory);
            var baseWithSeparator = baseDirectory.EndsWith(Path.DirectorySeparatorChar)
                ? baseDirectory
                : baseDirectory + Path.DirectorySeparatorChar;

            string candidate;
            try
            {
                candidate = Path.GetFullPath(Path.Combine(baseDirectory, signaturePath));
            }
            catch (Exception)
            {
                return null;
            }

            if (!candidate.StartsWith(baseWithSeparator, StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            resolved = candidate;
        }

        return File.Exists(resolved) ? resolved : null;
    }
}
