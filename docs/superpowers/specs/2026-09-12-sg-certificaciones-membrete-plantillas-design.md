# Diseño — Módulo de Certificaciones: membrete gráfico y plantillas reales (Activo / Retirado)

> Estado: **Aprobado por el usuario para especificación**
> Fecha: 2026-09-12
> Alcance: módulo de Certificaciones (`CertificatesPage.tsx` + generación de PDF en
> `PostgresPortalRepository.cs`) únicamente
> Origen: handoff `2026-09-12` (siguiente módulo tras Empleados) + dos PDF de
> referencia reales aportados por el usuario (certificado estándar dirigido a
> entidad financiera, certificado de retiro para trámite de cesantías)

## 1. Propósito y alcance

El módulo de Certificaciones genera hoy el PDF escribiendo comandos PDF
crudos a mano (`BuildCertificatePdf`, `PostgresPortalRepository.cs:5300-5361`),
sin ninguna librería. El resultado es texto plano en una sola fuente, sin
membrete gráfico, sin sellos (BASC/CONFEVIP), sin firma incrustada, y
`EscapePdfText` (líneas 5363-5379) **elimina activamente las tildes y la
ñ**, algo inaceptable en un documento formal en español.

El usuario aportó dos PDF reales que la empresa emite hoy manualmente (fuera
del sistema): un certificado laboral estándar (formato tabla, dirigido a una
entidad financiera) y un certificado de retiro (formato narrativo, con
motivo de retiro y referencia al Decreto 1562 de 2019 para cesantías). Esta
iteración lleva el motor de generación de PDF del sistema a la paridad
visual y de contenido con esos dos documentos, y aplica el mismo motor
gráfico (membrete, sellos, tildes correctas) a las otras 3 finalidades que
ya existen en el sistema (`CLIENTE`, `TRAMITE_GENERAL`, `INTERESADO`),
aunque estas últimas conserven por ahora su redacción genérica actual, ya
que no hay un documento de referencia real para ellas todavía.

**No está en alcance:** cambiar las validaciones de negocio existentes
(firmante vigente, salario base obligatorio, fecha/motivo de retiro
obligatorios) ni la puerta de aprobación de I9 (`RequireEveryRuleDecidedAsync`)
— quedan intactas. Tampoco se crea una pantalla de administración de textos
legales (se decidió dejarlos fijos en backend por ahora).

Todas las decisiones de esta sección fueron validadas una por una con el
usuario durante el brainstorming (ver historial de la sesión); se resumen
aquí para que la spec sea autocontenida.

## 2. Motor de generación de PDF: PdfSharpCore

Se reemplaza la escritura manual de PDF por **PdfSharpCore** (MIT, sin
costo ni restricción de ingresos — se descartó QuestPDF explícitamente por
la incertidumbre sobre si la empresa calificaría para su licencia gratuita
"Community", y se descartó un enfoque HTML-a-PDF con Chromium headless por
el riesgo operativo adicional en un entorno Windows que ya tiene fricciones
documentadas con rutas y ejecutables).

Nueva estructura en `apps/sg-superapp-api/Services/`:

```
Certificates/
  CertificateDocumentBuilder.cs        Orquesta: recibe los datos ya
                                        estructurados y el certificateType,
                                        elige la plantilla y produce los bytes del PDF.
  Templates/
    StandardCertificateTemplate.cs     Layout tabla — certificateType = ACTIVO
    RetirementCertificateTemplate.cs   Layout narrativo — certificateType = RETIRADO
    CertificateLetterhead.cs           Encabezado (logo SG, sellos BASC/CONFEVIP,
                                        franjas de color) y pie (dirección/tel/email)
                                        compartidos por ambas plantillas; incluye la
                                        marca de agua "SG" de fondo.
  Assets/
    sg-logo.png, basc-seal.png, confevip-seal.png
                                        Extraídos por recorte/rasterizado de los dos
                                        PDF de referencia (no existe archivo vectorial
                                        original disponible hoy). Calidad suficiente
                                        para uso interno; a reemplazar cuando el
                                        usuario consiga los archivos de marca
                                        originales (no bloquea esta iteración).
```

`PdfSharpCore` se agrega como paquete NuGet en
`apps/sg-superapp-api/sg-superapp-api.csproj`.

`BuildCertificatePreviewAsync` (`PostgresPortalRepository.cs:1922-2121`) —
la lógica de negocio y validaciones — **no cambia**. Cambia el contrato de
lo que le pasa a la capa de PDF: hoy arma un único bloque de texto libre
(`PreviewContent`); en adelante construye además un objeto estructurado
(nombre, identificación, cargo, fechas, desglose salarial, dirigido a,
elaborado por, firmante, purpose, certificateType) para que cada plantilla
ubique cada dato en su posición del layout en vez de imprimir un párrafo
plano. `PreviewContent` se mantiene para la previsualización en texto que
ya usa el frontend antes de generar el PDF final.

`EscapePdfText` se elimina: PdfSharpCore admite UTF-8 con la fuente correcta
sin normalizar ni quitar diacríticos.

`template_version` (columna existente en `labor_certificates`) pasa de
`I4-MVP-1` a `I4-MVP-2` para los certificados generados con el nuevo motor,
de forma que el histórico ya emitido con el motor anterior quede
identificable y no se reprocese.

## 3. Contenido por tipo y finalidad

El layout (tabla vs. narrativo) sigue derivándose automáticamente de
`certificateType`, tal como ya ocurre hoy (`PostgresPortalRepository.cs:2039`)
— el usuario no elige el tipo, solo el `purpose`:

- **ACTIVO → `StandardCertificateTemplate`**: bloque de campos (nombre,
  identificación, fecha de ingreso, cargo, tipo de contrato, sueldo
  desglosado), "Dirigida a [addressedTo o texto genérico del purpose]",
  línea de verificación telefónica institucional, firma.
- **RETIRADO → `RetirementCertificateTemplate`**: párrafo narrativo (nombre,
  identificación, fecha ingreso, fecha de retiro, cargo, motivo de retiro),
  "CONSERVAR ORIGINAL Y COPIA... SE EMITE POR UNA ÚNICA VEZ" (aplica a
  **todo** certificado RETIRADO, es política de emisión única de la
  empresa, no depende del purpose), firma.

Dentro de cada layout, `purpose` solo agrega o cambia fragmentos de texto:

| Purpose | Efecto |
|---|---|
| `ENTIDAD_FINANCIERA` | Usa `addressedTo` si viene informado; si no, texto genérico "ENTIDAD FINANCIERA" (como hoy) |
| `CESANTIAS` | Agrega el bloque legal "Dando cumplimiento al Decreto No. 1562 de 2019 esta carta es válida para el retiro de las cesantías" |
| `CLIENTE`, `TRAMITE_GENERAL`, `INTERESADO` | Conservan la redacción genérica actual (`PostgresPortalRepository.cs:2063-2071`), ahora dentro del membrete nuevo — sin plantilla de referencia real todavía |

**Desglose salarial (solo aplica a certificados ACTIVO):** se agregan dos
campos opcionales en el momento de generar el certificado —
`transportAllowanceAmount` (auxilio de transporte) y `overtimeAmount`
(extras) — que el usuario TH llena caso a caso. No se toca
`employee_salary_history` ni se migra histórico; si se dejan vacíos, el PDF
muestra únicamente el salario base como hoy.

**Dirigido a:** campo de texto libre opcional `addressedTo` en el
formulario, solo relevante cuando `purpose = ENTIDAD_FINANCIERA` (para las
demás finalidades el texto es fijo por diseño).

**Elaborado por:** se toma automáticamente del usuario TH autenticado que
genera el certificado (nombre y cargo de su perfil; si no tiene cargo
registrado, se imprime solo el nombre). No requiere campo nuevo en el
formulario ni tabla nueva.

**Firma:** si el firmante activo vigente tiene `signature_path` cargado
(campo ya existente en `certificate_signers`, hoy sin usar al renderizar),
`CertificateDocumentBuilder` incrusta esa imagen sobre la línea de firma; si
el firmante no tiene imagen cargada todavía, se deja el espacio en blanco
(comportamiento actual), para no bloquear a firmantes ya configurados sin
firma escaneada.

## 4. Persistencia — reutilizar `snapshot_payload`, sin migración de esquema

`labor_certificates` ya tiene una columna `snapshot_payload JSONB` que se
serializa al generar y se deserializa al reconstruir el PDF
(`PostgresPortalRepository.cs:5267`). Los tres campos nuevos
(`addressedTo`, `transportAllowanceAmount`, `overtimeAmount`) se agregan
como claves adicionales dentro de ese mismo JSON — **no se necesita
migración de base de datos**. Quedan en el histórico del certificado ya
emitido, tal como todos los demás campos del snapshot.

## 5. Frontend — `CertificatesPage.tsx`

Se agregan 3 campos opcionales al formulario "Nueva certificación"
(líneas ~466-515), todos con valor por defecto vacío:

- **Dirigido a** (texto libre) — se muestra solo cuando `purpose ===
  "ENTIDAD_FINANCIERA"`.
- **Auxilio de transporte** (numérico) y **Extras** (numérico) — se
  muestran solo cuando el empleado seleccionado tiene `employmentStatus =
  ACTIVO` (no aplican al layout de retiro).

Ningún campo nuevo es obligatorio; el resto del formulario (empleado,
purpose, fecha de expedición) no cambia. El panel de Firmantes (522-579) no
cambia de UI — la firma escaneada ya se sube ahí vía `signature_path`, solo
se activa su uso en el render del PDF.

## 6. Verificación y rollout

- **Build:** `C:\tmp\dotnet6\dotnet.exe build` (backend) y
  `node ".\node_modules\typescript\bin\tsc" -b .` + `vite build` (frontend),
  con rutas completas por el `&` literal en la ruta del repo.
- **Verificador nuevo:** `scripts/dev/Verify-SgSuperAppCertificatesTemplate.ps1`,
  siguiendo el patrón de dos fases usado en los verificadores de I9 (estática:
  existen las plantillas/assets nuevos y ya no existe `EscapePdfText`;
  ejecutable: genera un certificado ACTIVO/ENTIDAD_FINANCIERA y uno
  RETIRADO/CESANTIAS contra el backend local autenticado como `th.sg`, y
  valida que el PDF resultante contenga las cadenas de texto esperadas —
  nombre, cédula, tildes correctas, bloque legal cuando aplica).
- **Verificación visual manual:** generar ambos certificados desde la UI
  (`Start-SgSuperAppWeb.ps1`, no `Start-SgSuperAppLocal.ps1`, para ver los
  cambios con HMR real) y comparar el PDF resultante contra los dos PDF de
  referencia.
- **Sin impacto en el piloto real:** los campos nuevos son opcionales y
  viven en `snapshot_payload` por certificado; no se toca
  `employee_salary_history` ni certificados ya generados con el motor
  anterior — el histórico del piloto de 30 días ya cargado no se ve
  afectado.

## 7. Riesgos y seguimientos explícitos

- El membrete gráfico se extrae como imagen rasterizada de los dos PDF de
  referencia (no hay original vectorial); calidad aceptable para uso
  interno, pendiente de reemplazo cuando el usuario consiga los archivos de
  marca reales (logo, sellos) — el propio usuario mencionó que los buscará.
  El sitio público (`seguridadgestionltda.com`) tiene una identidad visual
  distinta (logo negro/amarillo, sin sellos BASC/CONFEVIP) y no sirve como
  fuente para este membrete.
- Las finalidades `CLIENTE`, `TRAMITE_GENERAL` e `INTERESADO` quedan con
  redacción genérica dentro del nuevo diseño gráfico — si en una iteración
  futura aparece un documento de referencia real para alguna de ellas, se
  ajusta el texto sin tocar el motor de renderizado.
