using PdfSharpCore.Fonts;

namespace Sg.SuperApp.Api.Certificates;

/// <summary>
/// PdfSharpCore no lee fuentes del sistema operativo por si solo; este resolutor
/// mapea la familia "CertificateBody" a Arial/Arial Bold de Windows, que cubren
/// tildes y ñ correctamente (a diferencia del EscapePdfText anterior, que las eliminaba).
/// </summary>
public sealed class CertificateFontResolver : IFontResolver
{
    public const string FamilyName = "CertificateBody";

    private const string RegularPath = @"C:\Windows\Fonts\arial.ttf";
    private const string BoldPath = @"C:\Windows\Fonts\arialbd.ttf";

    public string DefaultFontName => FamilyName;

    private static readonly object InitLock = new();
    private static bool _registered;

    public static void EnsureRegistered()
    {
        if (_registered)
        {
            return;
        }

        lock (InitLock)
        {
            if (_registered)
            {
                return;
            }

            GlobalFontSettings.FontResolver = new CertificateFontResolver();
            _registered = true;
        }
    }

    public byte[] GetFont(string faceName)
    {
        var path = faceName == "CertificateBody#Bold" ? BoldPath : RegularPath;
        return File.ReadAllBytes(path);
    }

    public FontResolverInfo ResolveTypeface(string familyName, bool isBold, bool isItalic)
    {
        var faceName = isBold ? "CertificateBody#Bold" : "CertificateBody";
        return new FontResolverInfo(faceName);
    }
}
