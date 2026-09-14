using PdfSharpCore.Drawing;

namespace Sg.SuperApp.Api.Certificates;

/// <summary>
/// Ajuste de linea real compartido por ambas plantillas. PdfSharpCore NO hace
/// word-wrap dentro de <see cref="XGraphics.DrawString(string, XFont, XBrush, XRect, XStringFormat)"/>:
/// dibuja una sola linea y deja que el sobrante se salga de la pagina. Aqui se parte
/// el texto en lineas midiendo de verdad con MeasureString y se devuelve la posicion
/// vertical exacta despues de la ultima linea dibujada, para que el seguimiento de "y"
/// en las plantillas sea exacto y no una estimacion por proporcion de ancho.
/// </summary>
public static class CertificateTextLayout
{
    /// <summary>Margen izquierdo del area de contenido (en puntos).</summary>
    public const double ContentX = 50;

    /// <summary>Ancho utilizable del area de contenido: de x=50 a x=562 en pagina Letter.</summary>
    public const double ContentWidth = 512;

    /// <summary>
    /// Unico criterio de interlineado del modulo (antes habia dos estimaciones divergentes:
    /// font.Size + 4 y font.Size + 5).
    /// </summary>
    public static double LineHeightFor(XFont font) => font.Size + 5;

    /// <summary>
    /// Parte <paramref name="text"/> en lineas que quepan en <paramref name="maxWidth"/> usando
    /// mediciones reales (MeasureString), dibuja cada linea alineada a la izquierda empezando en
    /// (<paramref name="x"/>, <paramref name="y"/>) y devuelve la posicion vertical inmediatamente
    /// debajo de la ultima linea dibujada.
    /// </summary>
    public static double DrawWrapped(
        XGraphics gfx,
        XFont font,
        XBrush brush,
        double x,
        double y,
        double maxWidth,
        string text,
        double lineHeight)
    {
        foreach (var line in WrapLines(gfx, font, maxWidth, text))
        {
            gfx.DrawString(line, font, brush, new XPoint(x, y));
            y += lineHeight;
        }

        return y;
    }

    /// <summary>
    /// Variante que usa el interlineado estandar de <see cref="LineHeightFor"/>.
    /// </summary>
    public static double DrawWrapped(
        XGraphics gfx,
        XFont font,
        XBrush brush,
        double x,
        double y,
        double maxWidth,
        string text)
        => DrawWrapped(gfx, font, brush, x, y, maxWidth, text, LineHeightFor(font));

    private static List<string> WrapLines(XGraphics gfx, XFont font, double maxWidth, string text)
    {
        var lines = new List<string>();
        if (string.IsNullOrWhiteSpace(text))
        {
            return lines;
        }

        var words = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var current = string.Empty;

        foreach (var word in words)
        {
            var candidate = current.Length == 0 ? word : $"{current} {word}";
            if (gfx.MeasureString(candidate, font).Width <= maxWidth || current.Length == 0)
            {
                current = candidate;
            }
            else
            {
                lines.Add(current);
                current = word;
            }
        }

        if (current.Length > 0)
        {
            lines.Add(current);
        }

        return lines;
    }
}
