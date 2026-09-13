using PdfSharpCore.Drawing;

namespace Sg.SuperApp.Api.Certificates;

/// <summary>
/// Membrete compartido por ambas plantillas de certificado. Las posiciones (en puntos,
/// origen superior-izquierdo) corresponden exactamente a donde estaban estas mismas
/// imagenes dentro de los PDF reales de referencia — no son estimaciones visuales.
/// </summary>
public static class CertificateLetterhead
{
    private static readonly string AssetsDirectory = Path.Combine(AppContext.BaseDirectory, "Certificates", "Assets");

    public static void Draw(XGraphics gfx)
    {
        DrawImage(gfx, "header.jpg", 0, 0, 612, 140.65);
        DrawImage(gfx, "footer.jpg", 0, 695.55, 612, 96.45);
        DrawImage(gfx, "watermark.png", 25.9, 160.3, 528.75, 609.75);
        DrawRotatedSidebarMark(gfx);
    }

    private static void DrawImage(XGraphics gfx, string fileName, double x, double y, double width, double height)
    {
        var path = Path.Combine(AssetsDirectory, fileName);
        using var image = XImage.FromFile(path);
        gfx.DrawImage(image, x, y, width, height);
    }

    private static void DrawRotatedSidebarMark(XGraphics gfx)
    {
        var path = Path.Combine(AssetsDirectory, "sidebar-mark.png");
        using var image = XImage.FromFile(path);

        // El asset original mide 188x9 px pero se pinta rotado 90 grados para verse
        // como una franja vertical angosta de 7.9x137.73 puntos junto al margen izquierdo.
        gfx.Save();
        gfx.TranslateTransform(20.19, 612.29);
        gfx.RotateTransform(-90);
        gfx.DrawImage(image, 0, 0, 137.73, 7.9);
        gfx.Restore();
    }
}
