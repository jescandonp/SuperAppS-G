# Certificaciones — Membrete Gráfico y Plantillas Reales Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el generador de PDF de Certificaciones (hoy comandos PDF crudos, sin membrete, sin tildes) por un motor basado en PdfSharpCore que reproduce fielmente las dos plantillas reales de la empresa (certificado ACTIVO tipo tabla, certificado RETIRADO tipo narrativo), reutilizando el membrete gráfico ya embebido en esos mismos PDF de referencia.

**Architecture:** Un módulo nuevo `apps/sg-superapp-api/Certificates/` con dos plantillas de layout (`StandardCertificateTemplate`, `RetirementCertificateTemplate`) que comparten un componente de membrete (`CertificateLetterhead`) construido con las 4 imágenes reales extraídas de los PDF de referencia. `PostgresPortalRepository` sigue siendo dueño de las validaciones de negocio; solo cambia el objeto que le pasa a la capa de PDF (de un bloque de texto libre a un modelo estructurado `CertificateDocumentData`).

**Tech Stack:** .NET 6 (backend existente), PdfSharpCore (nuevo, MIT), React 18 + TypeScript (frontend existente), PostgreSQL (sin migración de esquema).

**Spec:** `docs/superpowers/specs/2026-09-12-sg-certificaciones-membrete-plantillas-design.md`

## Global Constraints

- No se migra `employee_salary_history` ni se toca la puerta de aprobación de I9 (`RequireEveryRuleDecidedAsync`).
- No se crea pantalla de administración de textos legales — quedan fijos en backend por `purpose`.
- Los 3 campos nuevos (`addressedTo`, auxilio de transporte, extras) son opcionales; sin ellos el PDF se ve igual que con el motor actual (solo mejor presentado).
- `dotnet` no está en el PATH: usar `C:\tmp\dotnet6\dotnet.exe` con `$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"`. La ruta del repo tiene un `&` literal — usar siempre rutas completas a los ejecutables, nunca invocar por nombre.
- Frontend: `node ".\node_modules\typescript\bin\tsc" -b .` y `node ".\node_modules\vite\bin\vite.js" build` desde `apps\sg-superapp-web`.
- Credenciales de prueba: `th.sg` / `Th123456` (rol TH, único que puede generar certificados).
- El entorno de ejecución (dev y producción) es Windows — el resolutor de fuentes de PdfSharpCore puede asumir `C:\Windows\Fonts\` disponible.

---

## Task 1: Extraer y versionar los assets reales del membrete

Los dos PDF de referencia comparten el mismo membrete, embebido como 4 imágenes rasterizadas de alta resolución (no hay que recrearlas ni pedir originales — ya están ahí, en calidad completa). Este task las extrae de forma lossless y las deja versionadas en el repo.

**Files:**
- Create: `apps/sg-superapp-api/Certificates/Assets/header.jpg`
- Create: `apps/sg-superapp-api/Certificates/Assets/footer.jpg`
- Create: `apps/sg-superapp-api/Certificates/Assets/watermark.png`
- Create: `apps/sg-superapp-api/Certificates/Assets/sidebar-mark.png`
- Create: `apps/sg-superapp-api/Certificates/Assets/extract-assets.py` (script fuente, se conserva para poder re-extraer si cambia el PDF de referencia)

**Interfaces:**
- Produces: 4 archivos de imagen estáticos que el Task 2 embebe como contenido copiable al output del proyecto.

- [ ] **Step 1: Escribir el script de extracción**

```python
# apps/sg-superapp-api/Certificates/Assets/extract-assets.py
# Extrae el membrete (header, pie, marca de agua, franja lateral) directamente
# de los PDF reales de referencia, sin recompresion ni perdida de calidad.
import fitz
import os

REFERENCE_PDF = (
    r"C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\Artefactos Consultoria"
    r"\Recursos_Compartidos\Referencias\CERT LUIS CARLOS YOLIS CORREA 2.pdf"
)
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))

# xref -> nombre de archivo de salida (extension fija, NO se usa info['ext'] de
# PyMuPDF: para JPEG esa API devuelve "jpeg", no "jpg", lo que no coincidiria con
# los nombres de archivo que el resto de este plan espera).
ASSETS = {
    11: "header.jpg",
    12: "footer.jpg",
    5: "watermark.png",
    13: "sidebar-mark.png",
}

def main():
    doc = fitz.open(REFERENCE_PDF)
    for xref, file_name in ASSETS.items():
        info = doc.extract_image(xref)
        out_path = os.path.join(OUTPUT_DIR, file_name)
        with open(out_path, "wb") as f:
            f.write(info["image"])
        print(f"{file_name}: {out_path} ({len(info['image'])} bytes, {info['width']}x{info['height']})")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Instalar PyMuPDF y ejecutar el script**

```bash
python3 -m pip install --quiet pymupdf
python3 "apps/sg-superapp-api/Certificates/Assets/extract-assets.py"
```

Expected: imprime 4 líneas, una por asset, cada una con su ruta y tamaño en bytes. Deben aparecer los 4 archivos en `apps/sg-superapp-api/Certificates/Assets/`: `header.jpg` (~53 KB), `footer.jpg` (~30 KB), `watermark.png` (~8 KB), `sidebar-mark.png` (~1 KB).

- [ ] **Step 3: Verificar visualmente los 4 archivos extraídos**

Abre cada uno de los 4 archivos en un visor de imágenes (o pide que se lean como imagen). Confirma:
- `header.jpg`: logo "SG SEGURIDAD GESTION LTDA", texto de servicios, sellos BASC y CONFEVIP, franjas superiores gris/naranja.
- `footer.jpg`: franja naranja + franja gris oscura con "Centro de Operaciones...", email, dirección.
- `watermark.png`: escudo "SG" en gris, con transparencia (canal alfa).
- `sidebar-mark.png`: imagen pequeña y angosta (texto regulatorio rotado).

Si alguno no corresponde, el script tomó el xref equivocado — no continuar hasta confirmar visualmente los 4.

- [ ] **Step 4: Commit**

```bash
git add apps/sg-superapp-api/Certificates/Assets/
git commit -m "feat(certificados): extraer assets reales del membrete desde los PDF de referencia"
```

---

## Task 2: Dependencia PdfSharpCore + resolutor de fuentes con acentos

Agrega la librería de PDF y resuelve el problema de las tildes/ñ (hoy eliminadas por `EscapePdfText`). PdfSharpCore no descubre fuentes del sistema automáticamente: hay que registrar un `IFontResolver` explícito.

**Files:**
- Modify: `apps/sg-superapp-api/sg-superapp-api.csproj`
- Create: `apps/sg-superapp-api/Certificates/CertificateFontResolver.cs`

**Interfaces:**
- Produces: `CertificateFontResolver` (clase estática auxiliar `EnsureRegistered()`) — usada por el Task 6 (`CertificateDocumentBuilder`) antes de crear cualquier `PdfDocument`.
- Produces: constante pública `CertificateFontResolver.FamilyName = "CertificateBody"` — nombre de familia que usarán las plantillas al crear `XFont`.

- [ ] **Step 1: Agregar el paquete NuGet**

```xml
<!-- apps/sg-superapp-api/sg-superapp-api.csproj -->
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RootNamespace>Sg.SuperApp.Api</RootNamespace>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="DocumentFormat.OpenXml" Version="3.0.2" />
    <PackageReference Include="Npgsql" Version="6.0.10" />
    <PackageReference Include="PdfSharpCore" Version="1.3.65" />
  </ItemGroup>
  <ItemGroup>
    <Content Include="Certificates\Assets\**\*.*">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
  </ItemGroup>
</Project>
```

- [ ] **Step 2: Escribir el resolutor de fuentes**

```csharp
// apps/sg-superapp-api/Certificates/CertificateFontResolver.cs
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
```

- [ ] **Step 3: Compilar**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: `Build succeeded.` — confirma que el paquete se restauró y el nuevo archivo compila (aunque todavía no lo use nadie).

- [ ] **Step 4: Commit**

```bash
git add apps/sg-superapp-api/sg-superapp-api.csproj apps/sg-superapp-api/Certificates/CertificateFontResolver.cs
git commit -m "feat(certificados): agregar PdfSharpCore y resolutor de fuentes con acentos"
```

---

## Task 3: Componente de membrete compartido (`CertificateLetterhead`) y sello de firma (`CertificateSignatureStamp`)

Dibuja las 4 imágenes del Task 1 sobre una página en blanco, en las posiciones exactas que ya tenían dentro del PDF original (medidas en puntos, extraídas con PyMuPDF — no son estimaciones). Incluye también `CertificateSignatureStamp`: no depende de las plantillas de contenido (Tasks 5/6), solo de PdfSharpCore, así que se crea aquí para que el proyecto compile limpio en cada task siguiente en vez de quedar roto hasta el Task 7.

**Files:**
- Create: `apps/sg-superapp-api/Certificates/CertificateLetterhead.cs`
- Create: `apps/sg-superapp-api/Certificates/CertificateSignatureStamp.cs`
- Test: `apps/sg-superapp-api/Certificates/Assets/letterhead-smoke-test.ps1` (script de humo standalone, no requiere BD ni API corriendo)

**Interfaces:**
- Consumes: `CertificateFontResolver.EnsureRegistered()` (Task 2).
- Produces: `CertificateLetterhead.Draw(XGraphics gfx)` — usada por Task 5 y Task 6 antes de dibujar el contenido de cada plantilla.
- Produces: `CertificateSignatureStamp.DrawIfAvailable(XGraphics gfx, string? signaturePath, double x, double signatureLineY)` — usada por Task 5 y Task 6.

- [ ] **Step 1: Escribir `CertificateLetterhead`**

```csharp
// apps/sg-superapp-api/Certificates/CertificateLetterhead.cs
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
```

- [ ] **Step 2: Escribir el sello de firma**

```csharp
// apps/sg-superapp-api/Certificates/CertificateSignatureStamp.cs
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
```

- [ ] **Step 3: Escribir un smoke test standalone (sin BD, sin API)**

```powershell
# apps/sg-superapp-api/Certificates/Assets/letterhead-smoke-test.ps1
# Genera un PDF de una sola pagina solo con el membrete, para verificar visualmente
# que las 4 imagenes quedan bien ubicadas antes de construir el contenido encima.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$projectPath = Join-Path $repoRoot 'apps/sg-superapp-api/sg-superapp-api.csproj'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sg-cert-letterhead-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

$env:DOTNET_CLI_HOME = 'C:\tmp\dotnet-home'
& 'C:\tmp\dotnet6\dotnet.exe' build $projectPath --output $tempRoot | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Output 'LETTERHEAD SMOKE FAIL: build error'
    exit 1
}

Write-Output 'LETTERHEAD SMOKE PASS: build succeeded, assets copied'
Write-Output "Assets en: $(Join-Path $tempRoot 'Certificates/Assets')"
Get-ChildItem (Join-Path $tempRoot 'Certificates/Assets') | ForEach-Object { Write-Output " - $($_.Name)" }
```

- [ ] **Step 4: Ejecutar el smoke test**

```powershell
powershell -File "apps/sg-superapp-api/Certificates/Assets/letterhead-smoke-test.ps1"
```

Expected: `LETTERHEAD SMOKE PASS` y el listado de los 4 archivos de assets junto al binario compilado (confirma que `CopyToOutputDirectory` del Task 2 funciona).

- [ ] **Step 5: Commit**

```bash
git add apps/sg-superapp-api/Certificates/CertificateLetterhead.cs apps/sg-superapp-api/Certificates/CertificateSignatureStamp.cs apps/sg-superapp-api/Certificates/Assets/letterhead-smoke-test.ps1
git commit -m "feat(certificados): componente de membrete compartido y sello de firma incrustada"
```

---

## Task 4: Modelo de datos estructurado y cambios de contrato (`AddressedTo`, firma, elaborado por)

Antes de escribir las plantillas de contenido, se necesita el modelo estructurado que van a consumir, y los tres huecos de datos identificados en la spec: `AddressedTo` (dirigido a), `SignerSignaturePath` (hoy no viaja hasta el PDF) y el nombre de quien genera (elaborado por).

**Files:**
- Create: `apps/sg-superapp-api/Certificates/CertificateDocumentData.cs`
- Modify: `apps/sg-superapp-api/Contracts/Portal/CertificatePreviewRequest.cs`
- Modify: `apps/sg-superapp-api/Contracts/Portal/CertificatePreviewResponse.cs`
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:2031-2119` (`BuildCertificatePreviewAsync`)
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:5241-5263` (`BuildCertificatePreviewError`)

**Interfaces:**
- Produces: `CertificateDocumentData` (record) — consumido por Task 5, 6 y 7.
- Produces: `CertificatePreviewRequest.AddressedTo` (string?, opcional) — consumido por el frontend (Task 8).
- Produces: `CertificatePreviewResponse.AddressedTo` y `CertificatePreviewResponse.SignerSignaturePath` (string?) — consumidos por `PersistGeneratedCertificateAsync` (Task 7).

- [ ] **Step 1: Crear el modelo estructurado**

```csharp
// apps/sg-superapp-api/Certificates/CertificateDocumentData.cs
using Sg.SuperApp.Api.Contracts.Portal;

namespace Sg.SuperApp.Api.Certificates;

public sealed record CertificateDocumentData(
    string CertificateNumber,
    string CertificateType,
    string Purpose,
    DateOnly IssueDate,
    string EmployeeFullName,
    string IdentificationType,
    string IdentificationNumber,
    DateOnly HireDate,
    DateOnly? TerminationDate,
    string? TerminationReason,
    string JobTitle,
    string? ContractType,
    decimal? BaseSalary,
    string? AddressedTo,
    IReadOnlyList<CertificateVariableResponse> Variables,
    string SignerFullName,
    string SignerJobTitle,
    string? SignerSignaturePath,
    string PreparedByFullName);
```

- [ ] **Step 2: Agregar `AddressedTo` a los contratos**

```csharp
// apps/sg-superapp-api/Contracts/Portal/CertificatePreviewRequest.cs
namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CertificatePreviewRequest(
    long EmployeeId,
    string Purpose,
    string IssueDate,
    IReadOnlyList<CertificateVariableRequest> Variables,
    string? AddressedTo = null);
```

```csharp
// apps/sg-superapp-api/Contracts/Portal/CertificatePreviewResponse.cs
namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CertificatePreviewResponse(
    long EmployeeId,
    string CertificateType,
    string Purpose,
    string IssueDate,
    string EmployeeFullName,
    string IdentificationType,
    string IdentificationNumber,
    string HireDate,
    string? TerminationDate,
    string? TerminationReason,
    string JobTitle,
    string? ContractType,
    decimal? BaseSalary,
    long SignerId,
    string SignerFullName,
    string SignerJobTitle,
    IReadOnlyList<CertificateVariableResponse> Variables,
    string PreviewContent,
    IReadOnlyDictionary<string, object?> Snapshot,
    string? AddressedTo = null,
    string? SignerSignaturePath = null);
```

- [ ] **Step 3: Propagar `AddressedTo` y `SignerSignaturePath` en `BuildCertificatePreviewAsync`**

En `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`, dentro de `BuildCertificatePreviewAsync` (reemplaza el bloque `2079-2119`):

```csharp
        var addressedTo = string.IsNullOrWhiteSpace(request.AddressedTo) ? null : request.AddressedTo.Trim();

        var snapshot = new Dictionary<string, object?>
        {
            ["employeeId"] = employeeId,
            ["employeeFullName"] = fullName,
            ["identificationType"] = identificationType,
            ["identificationNumber"] = identificationNumber,
            ["employmentStatus"] = employmentStatus,
            ["jobTitle"] = jobTitle,
            ["hireDate"] = hireDate,
            ["terminationDate"] = terminationDate,
            ["terminationReason"] = terminationReason,
            ["contractType"] = contractType,
            ["baseSalary"] = baseSalary,
            ["purpose"] = purpose,
            ["issueDate"] = request.IssueDate,
            ["signerId"] = signer.Id,
            ["signerFullName"] = signer.FullName,
            ["signerJobTitle"] = signer.JobTitle,
            ["addressedTo"] = addressedTo,
            ["variables"] = certificateType == "ACTIVO" ? variables : Array.Empty<CertificateVariableResponse>()
        };

        return new CertificatePreviewResponse(
            employeeId,
            certificateType,
            purpose,
            request.IssueDate,
            fullName,
            identificationType,
            identificationNumber,
            hireDate,
            terminationDate,
            terminationReason,
            jobTitle,
            contractType,
            certificateType == "ACTIVO" ? baseSalary : null,
            signer.Id,
            signer.FullName,
            signer.JobTitle,
            certificateType == "ACTIVO" ? variables : Array.Empty<CertificateVariableResponse>(),
            string.Join("\n", previewLines),
            snapshot,
            addressedTo,
            signer.SignaturePath);
```

- [ ] **Step 4: Ajustar `BuildCertificatePreviewError`**

En `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:5241-5263`, el constructor posicional ya no necesita cambios porque `AddressedTo` y `SignerSignaturePath` tienen `= null` por defecto en la posición final del record — pero como es un record posicional, hay que confirmar que la llamada existente (17 argumentos posicionales) sigue compilando sin pasar los 2 nuevos. Si el compilador se queja de argumentos insuficientes, usar sintaxis con nombre para los dos nuevos:

```csharp
    private static CertificatePreviewResponse BuildCertificatePreviewError(string code)
    {
        return new CertificatePreviewResponse(
            0,
            code,
            string.Empty,
            string.Empty,
            string.Empty,
            string.Empty,
            string.Empty,
            string.Empty,
            null,
            null,
            string.Empty,
            null,
            null,
            0,
            string.Empty,
            string.Empty,
            Array.Empty<CertificateVariableResponse>(),
            string.Empty,
            new Dictionary<string, object?>(),
            AddressedTo: null,
            SignerSignaturePath: null);
    }
```

- [ ] **Step 5: Compilar**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: `Build succeeded.` (todavía nadie usa `CertificateDocumentData`, pero los contratos y `BuildCertificatePreviewAsync` ya compilan con los campos nuevos).

- [ ] **Step 6: Commit**

```bash
git add apps/sg-superapp-api/Certificates/CertificateDocumentData.cs apps/sg-superapp-api/Contracts/Portal/CertificatePreviewRequest.cs apps/sg-superapp-api/Contracts/Portal/CertificatePreviewResponse.cs apps/sg-superapp-api/Services/PostgresPortalRepository.cs
git commit -m "feat(certificados): agregar AddressedTo y SignerSignaturePath al contrato de preview"
```

---

## Task 5: Plantilla ACTIVO (`StandardCertificateTemplate`) — layout tabla

Reproduce el certificado estándar (dirigido a entidad financiera), con el desglose de sueldo tomado de `Variables` por código de concepto.

**Files:**
- Create: `apps/sg-superapp-api/Certificates/StandardCertificateTemplate.cs`

**Interfaces:**
- Consumes: `CertificateDocumentData` (Task 4), `CertificateLetterhead.Draw` y `CertificateSignatureStamp.DrawIfAvailable` (Task 3).
- Produces: `StandardCertificateTemplate.Draw(XGraphics gfx, CertificateDocumentData data)` — usada por Task 7 (`CertificateDocumentBuilder`).

- [ ] **Step 1: Escribir la plantilla**

```csharp
// apps/sg-superapp-api/Certificates/StandardCertificateTemplate.cs
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
```

- [ ] **Step 2: Compilar**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: `Build succeeded.` — `CertificateLetterhead` y `CertificateSignatureStamp` ya existen desde el Task 3, así que este archivo compila limpio sin dejar el proyecto roto.

- [ ] **Step 3: Commit**

```bash
git add apps/sg-superapp-api/Certificates/StandardCertificateTemplate.cs
git commit -m "feat(certificados): plantilla de layout tabla para certificado ACTIVO"
```

---

## Task 6: Plantilla RETIRADO (`RetirementCertificateTemplate`) — layout narrativo

Reproduce el certificado de retiro, incluyendo el bloque legal del Decreto 1562 de 2019 (solo si `purpose == CESANTIAS`) y el disclaimer de emisión única (siempre, para todo certificado RETIRADO).

**Files:**
- Create: `apps/sg-superapp-api/Certificates/RetirementCertificateTemplate.cs`

**Interfaces:**
- Consumes: `CertificateDocumentData` (Task 4), `CertificateLetterhead.Draw` y `CertificateSignatureStamp.DrawIfAvailable` (Task 3).
- Produces: `RetirementCertificateTemplate.Draw(XGraphics gfx, CertificateDocumentData data)` — usada por Task 7 (`CertificateDocumentBuilder`).

- [ ] **Step 1: Escribir la plantilla**

```csharp
// apps/sg-superapp-api/Certificates/RetirementCertificateTemplate.cs
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
```

- [ ] **Step 2: Compilar**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: `Build succeeded.` — `CertificateLetterhead` y `CertificateSignatureStamp` ya existen desde el Task 3, así que este archivo compila limpio sin dejar el proyecto roto.

- [ ] **Step 3: Commit**

```bash
git add apps/sg-superapp-api/Certificates/RetirementCertificateTemplate.cs
git commit -m "feat(certificados): plantilla de layout narrativo para certificado RETIRADO"
```

---

## Task 7: Firma incrustada, orquestador (`CertificateDocumentBuilder`) y eliminación del generador anterior

Junta las dos plantillas en un único punto de entrada, incrusta la firma escaneada cuando existe, y reemplaza el uso de `BuildCertificatePdf`/`EscapePdfText` en `PostgresPortalRepository`.

**Files:**
- Create: `apps/sg-superapp-api/Certificates/CertificateDocumentBuilder.cs`
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:2122-2257` (`PersistGeneratedCertificateAsync`)
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:5291-5379` (elimina `BuildCertificatePdf` y `EscapePdfText`, conserva `GetCertificatePdfPath`)

**Interfaces:**
- Consumes: `StandardCertificateTemplate.Draw`, `RetirementCertificateTemplate.Draw` (Tasks 5, 6).
- Produces: `CertificateDocumentBuilder.Build(CertificateDocumentData data) : byte[]` — reemplaza `BuildCertificatePdf(preview, certificateNumber)`.
- Produces: `PersistGeneratedCertificateAsync(CertificatePreviewResponse preview, long actorUserId, string actorUsername, string actorFullName, CancellationToken)` — gana el parámetro `actorFullName`.

- [ ] **Step 1: Verificar que `CertificateSignatureStamp.cs` ya existe (creado en el Task 3)**

```bash
test -f "apps/sg-superapp-api/Certificates/CertificateSignatureStamp.cs" && echo "OK: ya existe, no se recrea"
```

Expected: `OK: ya existe, no se recrea`. No se toca este archivo en este task — ya fue creado y commiteado en el Task 3 junto con `CertificateLetterhead`.

- [ ] **Step 2: Escribir el orquestador**

```csharp
// apps/sg-superapp-api/Certificates/CertificateDocumentBuilder.cs
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
```

- [ ] **Step 3: Reemplazar `BuildCertificatePdf`/`EscapePdfText` por `CertificateDocumentBuilder` en `PostgresPortalRepository.cs`**

Elimina por completo `BuildCertificatePdf` y `EscapePdfText` (líneas 5300-5379). En `PersistGeneratedCertificateAsync` (líneas 2122-2257), aplica estos cambios:

```csharp
    public async Task<LaborCertificateResponse> PersistGeneratedCertificateAsync(CertificatePreviewResponse preview, long actorUserId, string actorUsername, string actorFullName, CancellationToken cancellationToken = default)
    {
        // ... (sin cambios hasta la linea que arma "snapshot")

        var templateVersion = "I4-MVP-2";
        var certificateNumber = $"SG-I4-{DateTime.UtcNow:yyyyMMdd}-{id:000000}";
        var snapshot = new Dictionary<string, object?>(preview.Snapshot, StringComparer.OrdinalIgnoreCase)
        {
            ["certificateNumber"] = certificateNumber,
            ["templateVersion"] = templateVersion,
            ["approvedBy"] = actorUsername,
            ["generatedBy"] = actorUsername,
            ["preparedByFullName"] = actorFullName
        };

        var documentData = new CertificateDocumentData(
            certificateNumber,
            preview.CertificateType,
            preview.Purpose,
            DateOnly.Parse(preview.IssueDate),
            preview.EmployeeFullName,
            preview.IdentificationType,
            preview.IdentificationNumber,
            DateOnly.Parse(preview.HireDate),
            preview.TerminationDate is null ? null : DateOnly.Parse(preview.TerminationDate),
            preview.TerminationReason,
            preview.JobTitle,
            preview.ContractType,
            preview.BaseSalary,
            preview.AddressedTo,
            preview.Variables,
            preview.SignerFullName,
            preview.SignerJobTitle,
            preview.SignerSignaturePath,
            actorFullName);

        var pdfFileName = $"{certificateNumber}.pdf";
        var pdfPath = GetCertificatePdfPath(pdfFileName);
        Directory.CreateDirectory(Path.GetDirectoryName(pdfPath)!);
        await File.WriteAllBytesAsync(pdfPath, CertificateDocumentBuilder.Build(documentData), cancellationToken);

        // ... (el resto del metodo sigue igual: transaccion, insert, audit log, return)
```

Nota: la línea local `var templateVersion = "I4-MVP-1";` original queda reemplazada por `"I4-MVP-2"` (ver arriba) — es el único cambio de ese tipo en el método, el resto de `insertCertificateSql`, el `insert` de variables y el `InsertAuditLogAsync` no se tocan.

- [ ] **Step 4: Actualizar el endpoint que llama a `PersistGeneratedCertificateAsync`**

```csharp
// apps/sg-superapp-api/Endpoints/PortalEndpoints.cs:1137
            var certificate = await repository.PersistGeneratedCertificateAsync(preview!, userContext.User!.Id, userContext.User.Username, userContext.User.FullName, cancellationToken);
```

- [ ] **Step 5: Compilar**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: `Build succeeded.` con 0 errores — este es el primer build limpio de todo el módulo `Certificates/` completo.

- [ ] **Step 6: Commit**

```bash
git add apps/sg-superapp-api/Certificates/CertificateDocumentBuilder.cs apps/sg-superapp-api/Services/PostgresPortalRepository.cs apps/sg-superapp-api/Endpoints/PortalEndpoints.cs
git commit -m "feat(certificados): reemplazar generador de PDF crudo por CertificateDocumentBuilder"
```

---

## Task 8: Frontend — campos nuevos en el formulario de generación

Agrega "Dirigido a", "Auxilio de transporte" y "Extras" al formulario, reutilizando el arreglo `variables` ya existente en el contrato (sin tocar el backend otra vez).

**Files:**
- Modify: `apps/sg-superapp-web/src/types/portal.ts:433-460`
- Modify: `apps/sg-superapp-web/src/features/certificates/CertificatesPage.tsx`

**Interfaces:**
- Consumes: `CertificatePreviewRequest.addressedTo` y `CertificatePreview.addressedTo` (Task 4, ya reflejados 1:1 en JSON por `System.Text.Json`).

- [ ] **Step 1: Extender los tipos**

```typescript
// apps/sg-superapp-web/src/types/portal.ts:433-438
export interface CertificatePreviewRequest {
  employeeId: number;
  purpose: CertificatePurpose;
  issueDate: string;
  variables: CertificateVariableRequest[];
  addressedTo?: string | null;
}
```

```typescript
// apps/sg-superapp-web/src/types/portal.ts:440-460 (agregar un campo a la interfaz existente)
export interface CertificatePreview {
  employeeId: number;
  certificateType: CertificateType;
  purpose: CertificatePurpose;
  issueDate: string;
  employeeFullName: string;
  identificationType: string;
  identificationNumber: string;
  hireDate: string;
  terminationDate: string | null;
  terminationReason: string | null;
  jobTitle: string;
  contractType: string | null;
  baseSalary: number | null;
  signerId: number;
  signerFullName: string;
  signerJobTitle: string;
  variables: CertificateVariable[];
  previewContent: string;
  snapshot: Record<string, unknown>;
  addressedTo: string | null;
}
```

- [ ] **Step 2: Agregar estado y campos al formulario**

En `apps/sg-superapp-web/src/features/certificates/CertificatesPage.tsx`, junto a los demás `useState` del formulario (después de la línea 57, `variableAmount`):

```typescript
  const [addressedTo, setAddressedTo] = useState("");
  const [transportAllowance, setTransportAllowance] = useState("");
  const [overtimeAmount, setOvertimeAmount] = useState("");
```

- [ ] **Step 3: Construir el arreglo de variables con los 3 conceptos posibles**

Reemplaza el bloque de `variables` en `runPreview` (líneas 214-221):

```typescript
      const variables = [
        variableLabel.trim() && variableAmount
          ? {
              conceptCode: variableLabel.trim().toUpperCase().replace(/\s+/g, "_"),
              conceptLabel: variableLabel.trim(),
              amount: Number(variableAmount),
              notes: null
            }
          : null,
        transportAllowance
          ? { conceptCode: "AUXILIO_TRANSPORTE", conceptLabel: "Auxilio de transporte", amount: Number(transportAllowance), notes: null }
          : null,
        overtimeAmount
          ? { conceptCode: "EXTRAS", conceptLabel: "Extras", amount: Number(overtimeAmount), notes: null }
          : null
      ].filter((variable): variable is NonNullable<typeof variable> => variable !== null);
```

Y agrega `addressedTo: addressedTo.trim() || null` al objeto pasado a `previewCertificate` (línea 222-227):

```typescript
      const result = await previewCertificate({
        employeeId: Number(selectedEmployeeId),
        purpose,
        issueDate,
        variables,
        addressedTo: addressedTo.trim() || null
      });
```

- [ ] **Step 4: Propagar `addressedTo` al generar**

En `generateCertificate` (líneas 247-252):

```typescript
      const generated = await approveGenerateCertificate({
        employeeId: preview.employeeId,
        purpose: preview.purpose,
        issueDate: preview.issueDate,
        variables: preview.variables,
        addressedTo: preview.addressedTo
      });
```

- [ ] **Step 5: Agregar los campos visibles al formulario**

En el `certificate-form-grid` (después del bloque "Variable opcional", línea 495-499):

```tsx
            <label>
              Dirigido a
              <input
                value={addressedTo}
                onChange={(event) => setAddressedTo(event.target.value)}
                placeholder="Ej: BANCOLOMBIA (opcional)"
              />
            </label>
            <label>
              Auxilio de transporte
              <input
                value={transportAllowance}
                onChange={(event) => setTransportAllowance(event.target.value)}
                type="number"
                min="0"
                placeholder="Valor (opcional)"
              />
            </label>
            <label>
              Extras
              <input
                value={overtimeAmount}
                onChange={(event) => setOvertimeAmount(event.target.value)}
                type="number"
                min="0"
                placeholder="Valor (opcional)"
              />
            </label>
```

- [ ] **Step 6: Compilar el frontend**

```bash
node "apps/sg-superapp-web/node_modules/typescript/bin/tsc" -b apps/sg-superapp-web
```

Expected: sin salida (0 errores de tipos). Si `previewCertificate`/`approveGenerateCertificate` marcan error de tipo por `addressedTo`, confirma que `portalApi.ts:534-540` sigue tipando el parámetro como `CertificatePreviewRequest` (no requiere cambios de código, solo se beneficia del tipo ya extendido).

- [ ] **Step 7: Commit**

```bash
git add apps/sg-superapp-web/src/types/portal.ts apps/sg-superapp-web/src/features/certificates/CertificatesPage.tsx
git commit -m "feat(certificados): campos Dirigido a, auxilio de transporte y extras en el formulario"
```

---

## Task 9: Verificador PowerShell y verificación visual manual

Cierra la iteración con el verificador de dos fases (estático + ejecutable) que sigue el patrón ya usado en los verificadores de I9, y la comparación visual final contra los dos PDF de referencia.

**Files:**
- Create: `scripts/dev/Verify-SgSuperAppCertificatesTemplate.ps1`

**Interfaces:**
- Consumes: todos los archivos creados en las Tasks 1-8 (los valida por presencia/patrón, no los reimplementa).

- [ ] **Step 1: Escribir la fase estática del verificador**

```powershell
# scripts/dev/Verify-SgSuperAppCertificatesTemplate.ps1
[CmdletBinding()]
param([string]$RepositoryRoot)

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }

$certificatesDir = Join-Path $repoRoot 'apps\sg-superapp-api\Certificates'
$repositoryPath = Join-Path $repoRoot 'apps\sg-superapp-api\Services\PostgresPortalRepository.cs'
$csprojPath = Join-Path $repoRoot 'apps\sg-superapp-api\sg-superapp-api.csproj'
$frontendPath = Join-Path $repoRoot 'apps\sg-superapp-web\src\features\certificates\CertificatesPage.tsx'
$failures = [System.Collections.Generic.List[string]]::new()

$requiredFiles = @(
    (Join-Path $certificatesDir 'CertificateLetterhead.cs'),
    (Join-Path $certificatesDir 'CertificateDocumentBuilder.cs'),
    (Join-Path $certificatesDir 'CertificateDocumentData.cs'),
    (Join-Path $certificatesDir 'StandardCertificateTemplate.cs'),
    (Join-Path $certificatesDir 'RetirementCertificateTemplate.cs'),
    (Join-Path $certificatesDir 'CertificateSignatureStamp.cs'),
    (Join-Path $certificatesDir 'CertificateFontResolver.cs'),
    (Join-Path $certificatesDir 'Assets\header.jpg'),
    (Join-Path $certificatesDir 'Assets\footer.jpg'),
    (Join-Path $certificatesDir 'Assets\watermark.png')
)
foreach ($required in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        $failures.Add("Missing required file: $required")
    }
}

if ($failures.Count -eq 0) {
    $repositoryContent = Get-Content -LiteralPath $repositoryPath -Raw
    if ($repositoryContent -match 'BuildCertificatePdf\s*\(') {
        $failures.Add('PostgresPortalRepository still calls the old BuildCertificatePdf')
    }
    if ($repositoryContent -match 'EscapePdfText') {
        $failures.Add('EscapePdfText (accent-stripping) was not removed')
    }
    if ($repositoryContent -notmatch 'CertificateDocumentBuilder\.Build\s*\(') {
        $failures.Add('PostgresPortalRepository does not call CertificateDocumentBuilder.Build')
    }
    if ($repositoryContent -notmatch '"I4-MVP-2"') {
        $failures.Add('templateVersion was not bumped to I4-MVP-2')
    }

    $csprojContent = Get-Content -LiteralPath $csprojPath -Raw
    if ($csprojContent -notmatch 'PackageReference Include="PdfSharpCore"') {
        $failures.Add('sg-superapp-api.csproj is missing the PdfSharpCore package reference')
    }

    $frontendContent = Get-Content -LiteralPath $frontendPath -Raw
    foreach ($fieldCheck in @('addressedTo', 'AUXILIO_TRANSPORTE', 'EXTRAS')) {
        if ($frontendContent -notmatch [regex]::Escape($fieldCheck)) {
            $failures.Add("CertificatesPage.tsx is missing reference to '$fieldCheck'")
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "CERTIFICATES TEMPLATE FAIL: $failure" }
    exit 1
}
Write-Output 'CERTIFICATES TEMPLATE STATIC PASS'
```

- [ ] **Step 2: Ejecutar la fase estática**

```powershell
powershell -File "scripts/dev/Verify-SgSuperAppCertificatesTemplate.ps1"
```

Expected: `CERTIFICATES TEMPLATE STATIC PASS`. Si falla, corregir el hallazgo específico antes de continuar (no seguir con la fase ejecutable con la fase estática en rojo).

- [ ] **Step 3: Build completo del backend**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: `Build succeeded.`

- [ ] **Step 4: Build completo del frontend**

```bash
node "apps/sg-superapp-web/node_modules/typescript/bin/tsc" -b apps/sg-superapp-web
node "apps/sg-superapp-web/node_modules/vite/bin/vite.js" build --config apps/sg-superapp-web/vite.config.ts
```

Expected: ambos comandos terminan sin errores.

- [ ] **Step 5: Verificación visual manual — comparar contra los dos PDF de referencia**

Con el servidor local levantado (`Start-SgSuperAppWeb.ps1`, no `Start-SgSuperAppLocal.ps1`, para ver los cambios con HMR real), autenticado como `th.sg`/`Th123456`:

1. Genera un certificado para un empleado ACTIVO con `purpose = ENTIDAD_FINANCIERA`, llenando "Dirigido a" y los dos campos de sueldo opcionales. Descarga el PDF y compáralo visualmente contra `CERT LUIS CARLOS YOLIS CORREA 2.pdf`: membrete, sellos, desglose de sueldo, tildes correctas.
2. Genera un certificado para un empleado RETIRADO con `purpose = CESANTIAS`. Descarga el PDF y compáralo contra `membrete actual CERT RETIRADO ORLANDO ESTEBAN CADENA LONDOÑO 3.pdf`: bloque de motivo de retiro, texto del Decreto 1562, disclaimer de emisión única.
3. Si algún firmante activo tiene `signaturePath` configurado con un archivo real en `SG_CERTIFICATE_SIGNATURES_DIR` (o `certificate-signatures/` junto al ejecutable), confirma que la firma aparece incrustada sobre la línea; si no tiene archivo, confirma que el PDF se ve igual que antes (espacio en blanco, sin errores).

Expected: ambos PDF descargados coinciden en estructura y contenido con sus referencias, sin tildes eliminadas, sin errores en consola del navegador ni en el log del backend.

- [ ] **Step 6: Commit**

```bash
git add scripts/dev/Verify-SgSuperAppCertificatesTemplate.ps1
git commit -m "test(certificados): verificador de plantillas reales (estatico + build)"
```
