# DIAN Facturas PDF MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local MVP that reads an Excel file with CUFE/UUID values, consults the public DIAN document portal, downloads invoice PDFs, and writes an execution report.

**Architecture:** A Python command-line tool under `dian-facturas/` reads configuration from `config.yaml`, processes `entrada/entrada_facturas.xlsx`, automates the DIAN portal with Playwright, stores PDFs in local folders, and generates a new Excel report with result, error, and summary sheets. The first release is manual execution; a later task adds a Windows Task Scheduler script.

**Tech Stack:** Python 3.11+, Playwright, openpyxl, PyYAML, pytest, PowerShell.

---

## Scope

### In Scope

- Local execution from `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`.
- Base folder: `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas`.
- Excel input with one row per invoice.
- Required input columns: `ID`, `CUFE_UUID`, `ORIGEN`.
- Optional input columns: `PROVEEDOR_CLIENTE`, `NIT`, `FECHA_FACTURA`, `NUMERO_FACTURA`, `VALOR_ESPERADO`.
- Query by `CUFE_UUID` in `https://catalogo-vpfe.dian.gov.co/User/SearchDocument`.
- Download PDF only.
- No business validation against NIT, value, date, or issuer.
- If the PDF already exists, omit download and mark `YA_EXISTE`.
- Generate a new Excel output file.
- Include separate sheets: `Resultado`, `Errores_Pendientes`, `Resumen`.
- Save execution logs.

### Out of Scope

- Official SOAP integration with DIAN web services.
- Provider technology integration.
- XML download.
- RADIAN events or certificate of existence.
- Captcha solving or bypassing access controls.
- Bulk processing beyond the current estimated load of around 125 invoices per run.
- Multi-user web application.

## Decisions

- Start with a script, not a GUI.
- Use Playwright because the DIAN portal is a dynamic web page and downloads must be controlled.
- Keep `config.yaml` editable so the base folder can change later.
- Use a new output workbook instead of editing the original input workbook.
- Use a second sheet for all rows that need manual review.
- Keep the first pilot manually triggered before adding scheduled execution.

## Folder Structure

Create this structure:

```text
dian-facturas/
  README.md
  requirements.txt
  config.yaml
  entrada/
    entrada_facturas.xlsx
  descargas/
    recibidas/
    emitidas/
  reportes/
  logs/
  scripts/
    run.ps1
    create_sample_excel.ps1
    install.ps1
    schedule-task.ps1
  src/
    dian_facturas/
      __init__.py
      __main__.py
      cli.py
      config.py
      excel_io.py
      file_naming.py
      dian_portal.py
      processor.py
      reporting.py
      logging_setup.py
  tests/
    test_config.py
    test_excel_io.py
    test_file_naming.py
    test_processor.py
```

## Excel Contract

### Input Sheet

Default sheet name:

```text
Facturas
```

Required columns:

```text
ID
CUFE_UUID
ORIGEN
```

Allowed values for `ORIGEN`:

```text
RECIBIDA
EMITIDA
```

Optional columns:

```text
PROVEEDOR_CLIENTE
NIT
FECHA_FACTURA
NUMERO_FACTURA
VALOR_ESPERADO
```

### Output Workbook

Output path pattern:

```text
dian-facturas/reportes/resultado_descarga_facturas_YYYYMMDD_HHMMSS.xlsx
```

Sheet `Resultado` columns:

```text
ID
CUFE_UUID
ORIGEN
PROVEEDOR_CLIENTE
NIT
FECHA_FACTURA
NUMERO_FACTURA
VALOR_ESPERADO
ESTADO_PROCESO
FECHA_CONSULTA
PDF_DESCARGADO
RUTA_ARCHIVO
OBSERVACION
INTENTOS
```

Sheet `Errores_Pendientes` includes rows where `ESTADO_PROCESO` is one of:

```text
NO_ENCONTRADO
ERROR_PORTAL
ERROR_DESCARGA
CUFE_INVALIDO
PENDIENTE
CAPTCHA_REQUERIDO
```

Sheet `Resumen` includes:

```text
fecha_ejecucion
total_filas
descargados
ya_existian
no_encontrados
errores_portal
errores_descarga
cufe_invalidos
captcha_requerido
pendientes_revision
carpeta_descargas
archivo_entrada
archivo_resultado
```

## Status Values

Use these exact values:

```text
DESCARGADO
YA_EXISTE
NO_ENCONTRADO
ERROR_PORTAL
ERROR_DESCARGA
CUFE_INVALIDO
PENDIENTE
CAPTCHA_REQUERIDO
```

## PDF Naming

Use this pattern:

```text
ORIGEN_NIT_NUMEROFACTURA_CUFE.pdf
```

Normalize missing values:

```text
NIT -> SIN-NIT
NUMERO_FACTURA -> SIN-NUMERO
```

Example:

```text
RECIBIDA_900123456_FV123_8c2f....pdf
EMITIDA_SIN-NIT_SIN-NUMERO_8c2f....pdf
```

If `ORIGEN` is `RECIBIDA`, save under:

```text
dian-facturas/descargas/recibidas/
```

If `ORIGEN` is `EMITIDA`, save under:

```text
dian-facturas/descargas/emitidas/
```

---

## Task 1: Project Skeleton

**Files:**
- Create: `dian-facturas/README.md`
- Create: `dian-facturas/requirements.txt`
- Create: `dian-facturas/config.yaml`
- Create: `dian-facturas/src/dian_facturas/__init__.py`
- Create: `dian-facturas/src/dian_facturas/__main__.py`
- Create: `dian-facturas/scripts/install.ps1`
- Create directories listed in Folder Structure.

- [ ] **Step 1: Create folders**

Run:

```powershell
New-Item -ItemType Directory -Force -Path dian-facturas, dian-facturas\entrada, dian-facturas\descargas, dian-facturas\descargas\recibidas, dian-facturas\descargas\emitidas, dian-facturas\reportes, dian-facturas\logs, dian-facturas\scripts, dian-facturas\src, dian-facturas\src\dian_facturas, dian-facturas\tests
```

Expected: all folders exist under `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas`.

- [ ] **Step 2: Add dependencies**

Create `dian-facturas/requirements.txt`:

```text
openpyxl==3.1.5
playwright==1.49.1
PyYAML==6.0.2
pytest==8.3.4
```

- [ ] **Step 3: Add default configuration**

Create `dian-facturas/config.yaml`:

```yaml
base_dir: "C:\\Users\\jmep2\\Downloads\\AgenIALab\\ProyectoS&G\\dian-facturas"
input_file: "entrada\\entrada_facturas.xlsx"
input_sheet: "Facturas"
portal_url: "https://catalogo-vpfe.dian.gov.co/User/SearchDocument"
headless: false
timeout_ms: 45000
slow_mo_ms: 100
max_attempts: 2
captcha_wait_seconds: 90
download_dirs:
  RECIBIDA: "descargas\\recibidas"
  EMITIDA: "descargas\\emitidas"
report_dir: "reportes"
log_dir: "logs"
```

- [ ] **Step 4: Add installation script**

Create `dian-facturas/scripts/install.ps1`:

```powershell
$ErrorActionPreference = "Stop"
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m playwright install chromium
```

- [ ] **Step 5: Add README**

Create `dian-facturas/README.md` with:

```markdown
# DIAN Facturas PDF

Herramienta local para consultar facturas por CUFE/UUID en el portal publico de la DIAN y descargar la representacion grafica en PDF.

## Uso piloto

1. Editar `entrada/entrada_facturas.xlsx`.
2. Ejecutar `scripts/run.ps1`.
3. Revisar PDFs en `descargas/`.
4. Revisar el resultado en `reportes/`.

## Columnas obligatorias

- `ID`
- `CUFE_UUID`
- `ORIGEN`

`ORIGEN` debe ser `RECIBIDA` o `EMITIDA`.
```

---

## Task 2: Configuration Loader

**Files:**
- Create: `dian-facturas/src/dian_facturas/config.py`
- Test: `dian-facturas/tests/test_config.py`

- [ ] **Step 1: Write tests**

Create `dian-facturas/tests/test_config.py`:

```python
from pathlib import Path

from dian_facturas.config import AppConfig, load_config


def test_load_config_resolves_paths(tmp_path):
    config_file = tmp_path / "config.yaml"
    config_file.write_text(
        """
base_dir: "{base_dir}"
input_file: "entrada\\\\entrada_facturas.xlsx"
input_sheet: "Facturas"
portal_url: "https://catalogo-vpfe.dian.gov.co/User/SearchDocument"
headless: false
timeout_ms: 45000
slow_mo_ms: 100
max_attempts: 2
captcha_wait_seconds: 90
download_dirs:
  RECIBIDA: "descargas\\\\recibidas"
  EMITIDA: "descargas\\\\emitidas"
report_dir: "reportes"
log_dir: "logs"
""".format(base_dir=str(tmp_path).replace("\\", "\\\\"))
    )

    config = load_config(config_file)

    assert isinstance(config, AppConfig)
    assert config.input_path == tmp_path / "entrada" / "entrada_facturas.xlsx"
    assert config.report_dir == tmp_path / "reportes"
    assert config.download_dirs["RECIBIDA"] == tmp_path / "descargas" / "recibidas"
```

- [ ] **Step 2: Implement config loader**

Create `dian-facturas/src/dian_facturas/config.py`:

```python
from dataclasses import dataclass
from pathlib import Path

import yaml


@dataclass(frozen=True)
class AppConfig:
    base_dir: Path
    input_file: str
    input_sheet: str
    portal_url: str
    headless: bool
    timeout_ms: int
    slow_mo_ms: int
    max_attempts: int
    download_dirs: dict[str, Path]
    report_dir: Path
    log_dir: Path

    @property
    def input_path(self) -> Path:
        return self.base_dir / self.input_file


def load_config(path: str | Path) -> AppConfig:
    config_path = Path(path)
    data = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    base_dir = Path(data["base_dir"])
    return AppConfig(
        base_dir=base_dir,
        input_file=data["input_file"],
        input_sheet=data["input_sheet"],
        portal_url=data["portal_url"],
        headless=bool(data["headless"]),
        timeout_ms=int(data["timeout_ms"]),
        slow_mo_ms=int(data["slow_mo_ms"]),
        max_attempts=int(data["max_attempts"]),
        download_dirs={key: base_dir / value for key, value in data["download_dirs"].items()},
        report_dir=base_dir / data["report_dir"],
        log_dir=base_dir / data["log_dir"],
    )
```

- [ ] **Step 3: Run test**

Run:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\.venv\Scripts\python.exe -m pytest tests\test_config.py -v
```

Expected: `1 passed`.

---

## Task 3: Excel Input and Output Model

**Files:**
- Create: `dian-facturas/src/dian_facturas/excel_io.py`
- Test: `dian-facturas/tests/test_excel_io.py`
- Create: `dian-facturas/scripts/create_sample_excel.ps1`

- [ ] **Step 1: Define tests**

Create `dian-facturas/tests/test_excel_io.py`:

```python
from pathlib import Path

from openpyxl import Workbook

from dian_facturas.excel_io import InvoiceRow, read_invoice_rows


def test_read_invoice_rows_accepts_required_columns(tmp_path: Path):
    workbook_path = tmp_path / "entrada_facturas.xlsx"
    wb = Workbook()
    ws = wb.active
    ws.title = "Facturas"
    ws.append(["ID", "CUFE_UUID", "ORIGEN"])
    ws.append([1, "abc123", "RECIBIDA"])
    wb.save(workbook_path)

    rows = read_invoice_rows(workbook_path, "Facturas")

    assert rows == [
        InvoiceRow(
            row_number=2,
            invoice_id="1",
            cufe_uuid="abc123",
            origen="RECIBIDA",
            proveedor_cliente="",
            nit="",
            fecha_factura="",
            numero_factura="",
            valor_esperado="",
        )
    ]


def test_read_invoice_rows_marks_invalid_origin(tmp_path: Path):
    workbook_path = tmp_path / "entrada_facturas.xlsx"
    wb = Workbook()
    ws = wb.active
    ws.title = "Facturas"
    ws.append(["ID", "CUFE_UUID", "ORIGEN"])
    ws.append([1, "abc123", "OTRA"])
    wb.save(workbook_path)

    rows = read_invoice_rows(workbook_path, "Facturas")

    assert rows[0].is_valid is False
    assert "ORIGEN invalido" in rows[0].validation_error
```

- [ ] **Step 2: Implement Excel reader**

Create `dian-facturas/src/dian_facturas/excel_io.py`:

```python
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from openpyxl import load_workbook


REQUIRED_COLUMNS = ["ID", "CUFE_UUID", "ORIGEN"]
OPTIONAL_COLUMNS = ["PROVEEDOR_CLIENTE", "NIT", "FECHA_FACTURA", "NUMERO_FACTURA", "VALOR_ESPERADO"]
VALID_ORIGINS = {"RECIBIDA", "EMITIDA"}


@dataclass(frozen=True)
class InvoiceRow:
    row_number: int
    invoice_id: str
    cufe_uuid: str
    origen: str
    proveedor_cliente: str
    nit: str
    fecha_factura: str
    numero_factura: str
    valor_esperado: str
    is_valid: bool = True
    validation_error: str = ""


def _clean(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def read_invoice_rows(path: str | Path, sheet_name: str) -> list[InvoiceRow]:
    workbook = load_workbook(path)
    worksheet = workbook[sheet_name]
    headers = [_clean(cell.value).upper() for cell in worksheet[1]]
    index = {name: pos for pos, name in enumerate(headers)}

    missing = [column for column in REQUIRED_COLUMNS if column not in index]
    if missing:
        raise ValueError(f"Faltan columnas obligatorias: {', '.join(missing)}")

    rows: list[InvoiceRow] = []
    for row_number, row in enumerate(worksheet.iter_rows(min_row=2, values_only=True), start=2):
        raw = {column: _clean(row[index[column]]) if column in index and index[column] < len(row) else "" for column in REQUIRED_COLUMNS + OPTIONAL_COLUMNS}
        validation_error = ""
        is_valid = True
        if not raw["CUFE_UUID"]:
            is_valid = False
            validation_error = "CUFE_UUID vacio"
        elif raw["ORIGEN"] not in VALID_ORIGINS:
            is_valid = False
            validation_error = "ORIGEN invalido"

        rows.append(
            InvoiceRow(
                row_number=row_number,
                invoice_id=raw["ID"],
                cufe_uuid=raw["CUFE_UUID"],
                origen=raw["ORIGEN"],
                proveedor_cliente=raw["PROVEEDOR_CLIENTE"],
                nit=raw["NIT"],
                fecha_factura=raw["FECHA_FACTURA"],
                numero_factura=raw["NUMERO_FACTURA"],
                valor_esperado=raw["VALOR_ESPERADO"],
                is_valid=is_valid,
                validation_error=validation_error,
            )
        )
    return rows
```

- [ ] **Step 3: Add sample Excel script**

Create `dian-facturas/scripts/create_sample_excel.ps1`:

```powershell
$ErrorActionPreference = "Stop"
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\.venv\Scripts\python.exe -c "from openpyxl import Workbook; wb=Workbook(); ws=wb.active; ws.title='Facturas'; ws.append(['ID','CUFE_UUID','ORIGEN','PROVEEDOR_CLIENTE','NIT','FECHA_FACTURA','NUMERO_FACTURA','VALOR_ESPERADO']); ws.append(['1','PEGAR_CUFE_REAL_AQUI','RECIBIDA','','','','','']); wb.save('entrada/entrada_facturas.xlsx')"
```

- [ ] **Step 4: Run tests**

Run:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\.venv\Scripts\python.exe -m pytest tests\test_excel_io.py -v
```

Expected: `2 passed`.

---

## Task 4: File Naming

**Files:**
- Create: `dian-facturas/src/dian_facturas/file_naming.py`
- Test: `dian-facturas/tests/test_file_naming.py`

- [ ] **Step 1: Write tests**

Create `dian-facturas/tests/test_file_naming.py`:

```python
from dian_facturas.excel_io import InvoiceRow
from dian_facturas.file_naming import pdf_file_name


def test_pdf_file_name_uses_origin_nit_number_and_cufe():
    row = InvoiceRow(2, "1", "abc123", "RECIBIDA", "", "900.123.456-7", "", "FV-001", "")

    assert pdf_file_name(row) == "RECIBIDA_9001234567_FV-001_abc123.pdf"


def test_pdf_file_name_uses_missing_value_tokens():
    row = InvoiceRow(2, "1", "abc123", "EMITIDA", "", "", "", "", "")

    assert pdf_file_name(row) == "EMITIDA_SIN-NIT_SIN-NUMERO_abc123.pdf"
```

- [ ] **Step 2: Implement naming**

Create `dian-facturas/src/dian_facturas/file_naming.py`:

```python
import re

from dian_facturas.excel_io import InvoiceRow


def _safe(value: str, fallback: str) -> str:
    clean = value.strip()
    if not clean:
        return fallback
    clean = re.sub(r"[^\w.-]+", "-", clean, flags=re.ASCII)
    return clean.strip("-") or fallback


def _safe_nit(value: str) -> str:
    clean = re.sub(r"[^0-9A-Za-z]+", "", value.strip())
    return clean or "SIN-NIT"


def pdf_file_name(row: InvoiceRow) -> str:
    return f"{_safe(row.origen, 'SIN-ORIGEN')}_{_safe_nit(row.nit)}_{_safe(row.numero_factura, 'SIN-NUMERO')}_{_safe(row.cufe_uuid, 'SIN-CUFE')}.pdf"
```

- [ ] **Step 3: Run tests**

Run:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\.venv\Scripts\python.exe -m pytest tests\test_file_naming.py -v
```

Expected: `2 passed`.

---

## Task 5: DIAN Portal Automation Adapter

**Files:**
- Create: `dian-facturas/src/dian_facturas/dian_portal.py`

- [ ] **Step 1: Implement portal result model and browser adapter**

Create `dian-facturas/src/dian_facturas/dian_portal.py`:

```python
from dataclasses import dataclass
from pathlib import Path

from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import sync_playwright


@dataclass(frozen=True)
class PortalDownloadResult:
    status: str
    downloaded_path: Path | None
    observation: str


class DianPortalClient:
    def __init__(self, portal_url: str, headless: bool, timeout_ms: int, slow_mo_ms: int):
        self.portal_url = portal_url
        self.headless = headless
        self.timeout_ms = timeout_ms
        self.slow_mo_ms = slow_mo_ms
        self._playwright = None
        self._browser = None
        self._context = None
        self._page = None

    def __enter__(self):
        self._playwright = sync_playwright().start()
        self._browser = self._playwright.chromium.launch(headless=self.headless, slow_mo=self.slow_mo_ms)
        self._context = self._browser.new_context(accept_downloads=True)
        self._page = self._context.new_page()
        self._page.set_default_timeout(self.timeout_ms)
        return self

    def __exit__(self, exc_type, exc, tb):
        if self._context:
            self._context.close()
        if self._browser:
            self._browser.close()
        if self._playwright:
            self._playwright.stop()

    def download_pdf(self, cufe_uuid: str, target_path: Path) -> PortalDownloadResult:
        page = self._page
        if page is None:
            raise RuntimeError("DianPortalClient must be used as a context manager")

        try:
            page.goto(self.portal_url, wait_until="domcontentloaded")
            input_box = page.get_by_label("CUFE o UUID")
            input_box.fill(cufe_uuid)
            page.get_by_role("button", name="Buscar").click()

            no_result = page.get_by_text("No se encontraron", exact=False)
            pdf_link = page.get_by_role("link", name="Descargar PDF")

            try:
                pdf_link.wait_for(timeout=12000)
            except PlaywrightTimeoutError:
                if no_result.count() > 0:
                    return PortalDownloadResult("NO_ENCONTRADO", None, "La DIAN no retorno resultado para el CUFE/UUID")
                return PortalDownloadResult("ERROR_PORTAL", None, "No se encontro enlace de descarga PDF")

            with page.expect_download() as download_info:
                pdf_link.click()
            download = download_info.value
            target_path.parent.mkdir(parents=True, exist_ok=True)
            download.save_as(target_path)
            return PortalDownloadResult("DESCARGADO", target_path, "PDF descargado correctamente")
        except PlaywrightTimeoutError as exc:
            return PortalDownloadResult("ERROR_PORTAL", None, f"Tiempo de espera agotado: {exc}")
        except Exception as exc:
            return PortalDownloadResult("ERROR_DESCARGA", None, str(exc))
```

- [ ] **Step 2: Manual selector verification**

Run once with a known real CUFE in visible browser mode after the rest of the CLI exists. If the DIAN portal uses different labels or button names, adjust these selectors:

```python
page.get_by_label("CUFE o UUID")
page.get_by_role("button", name="Buscar")
page.get_by_role("link", name="Descargar PDF")
```

Expected: a PDF is downloaded for a known valid CUFE.

---

## Task 6: Processor

**Files:**
- Create: `dian-facturas/src/dian_facturas/processor.py`
- Test: `dian-facturas/tests/test_processor.py`

- [ ] **Step 1: Write processor tests with fake portal**

Create `dian-facturas/tests/test_processor.py`:

```python
from pathlib import Path

from dian_facturas.excel_io import InvoiceRow
from dian_facturas.processor import ProcessResult, process_rows


class FakePortal:
    def download_pdf(self, cufe_uuid: str, target_path: Path):
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_bytes(b"%PDF-1.4 fake")
        return ProcessResult(
            invoice_id="1",
            cufe_uuid=cufe_uuid,
            origen="RECIBIDA",
            proveedor_cliente="",
            nit="",
            fecha_factura="",
            numero_factura="",
            valor_esperado="",
            estado_proceso="DESCARGADO",
            fecha_consulta="2026-05-16T00:00:00",
            pdf_descargado="SI",
            ruta_archivo=str(target_path),
            observacion="PDF descargado correctamente",
            intentos=1,
        )


def test_process_rows_marks_existing_file(tmp_path):
    row = InvoiceRow(2, "1", "abc123", "RECIBIDA", "", "", "", "", "")
    target = tmp_path / "recibidas" / "RECIBIDA_SIN-NIT_SIN-NUMERO_abc123.pdf"
    target.parent.mkdir(parents=True)
    target.write_bytes(b"existing")

    results = process_rows([row], FakePortal(), {"RECIBIDA": tmp_path / "recibidas"}, max_attempts=2)

    assert results[0].estado_proceso == "YA_EXISTE"
    assert results[0].pdf_descargado == "SI"


def test_process_rows_marks_invalid_row(tmp_path):
    row = InvoiceRow(2, "1", "", "RECIBIDA", "", "", "", "", "", is_valid=False, validation_error="CUFE_UUID vacio")

    results = process_rows([row], FakePortal(), {"RECIBIDA": tmp_path / "recibidas"}, max_attempts=2)

    assert results[0].estado_proceso == "CUFE_INVALIDO"
    assert results[0].observacion == "CUFE_UUID vacio"
```

- [ ] **Step 2: Implement processor**

Create `dian-facturas/src/dian_facturas/processor.py`:

```python
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from dian_facturas.dian_portal import PortalDownloadResult
from dian_facturas.excel_io import InvoiceRow
from dian_facturas.file_naming import pdf_file_name


@dataclass(frozen=True)
class ProcessResult:
    invoice_id: str
    cufe_uuid: str
    origen: str
    proveedor_cliente: str
    nit: str
    fecha_factura: str
    numero_factura: str
    valor_esperado: str
    estado_proceso: str
    fecha_consulta: str
    pdf_descargado: str
    ruta_archivo: str
    observacion: str
    intentos: int


def _now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _base_result(row: InvoiceRow, status: str, pdf_descargado: str, ruta_archivo: str, observation: str, attempts: int) -> ProcessResult:
    return ProcessResult(
        invoice_id=row.invoice_id,
        cufe_uuid=row.cufe_uuid,
        origen=row.origen,
        proveedor_cliente=row.proveedor_cliente,
        nit=row.nit,
        fecha_factura=row.fecha_factura,
        numero_factura=row.numero_factura,
        valor_esperado=row.valor_esperado,
        estado_proceso=status,
        fecha_consulta=_now_iso(),
        pdf_descargado=pdf_descargado,
        ruta_archivo=ruta_archivo,
        observacion=observation,
        intentos=attempts,
    )


def process_rows(rows: list[InvoiceRow], portal_client, download_dirs: dict[str, Path], max_attempts: int) -> list[ProcessResult]:
    results: list[ProcessResult] = []
    for row in rows:
        if not row.is_valid:
            results.append(_base_result(row, "CUFE_INVALIDO", "NO", "", row.validation_error, 0))
            continue

        target_dir = download_dirs[row.origen]
        target_path = target_dir / pdf_file_name(row)
        if target_path.exists():
            results.append(_base_result(row, "YA_EXISTE", "SI", str(target_path), "PDF ya existia, se omitio descarga", 0))
            continue

        last_result: PortalDownloadResult | None = None
        for attempt in range(1, max_attempts + 1):
            last_result = portal_client.download_pdf(row.cufe_uuid, target_path)
            if last_result.status in {"DESCARGADO", "NO_ENCONTRADO"}:
                break

        if last_result is None:
            results.append(_base_result(row, "PENDIENTE", "NO", "", "No se ejecuto consulta", 0))
            continue

        results.append(
            _base_result(
                row,
                last_result.status,
                "SI" if last_result.downloaded_path else "NO",
                str(last_result.downloaded_path) if last_result.downloaded_path else "",
                last_result.observation,
                attempt,
            )
        )
    return results
```

- [ ] **Step 3: Adjust fake test**

If the fake portal currently returns `ProcessResult`, replace it with a fake object compatible with `PortalDownloadResult`:

```python
from dian_facturas.dian_portal import PortalDownloadResult


class FakePortal:
    def download_pdf(self, cufe_uuid: str, target_path: Path):
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_bytes(b"%PDF-1.4 fake")
        return PortalDownloadResult("DESCARGADO", target_path, "PDF descargado correctamente")
```

- [ ] **Step 4: Run tests**

Run:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\.venv\Scripts\python.exe -m pytest tests\test_processor.py -v
```

Expected: `2 passed`.

---

## Task 7: Report Writer

**Files:**
- Create: `dian-facturas/src/dian_facturas/reporting.py`

- [ ] **Step 1: Implement report writer**

Create `dian-facturas/src/dian_facturas/reporting.py`:

```python
from datetime import datetime
from pathlib import Path

from openpyxl import Workbook

from dian_facturas.processor import ProcessResult


RESULT_HEADERS = [
    "ID",
    "CUFE_UUID",
    "ORIGEN",
    "PROVEEDOR_CLIENTE",
    "NIT",
    "FECHA_FACTURA",
    "NUMERO_FACTURA",
    "VALOR_ESPERADO",
    "ESTADO_PROCESO",
    "FECHA_CONSULTA",
    "PDF_DESCARGADO",
    "RUTA_ARCHIVO",
    "OBSERVACION",
    "INTENTOS",
]

ERROR_STATUSES = {"NO_ENCONTRADO", "ERROR_PORTAL", "ERROR_DESCARGA", "CUFE_INVALIDO", "PENDIENTE"}


def _row(result: ProcessResult) -> list[str | int]:
    return [
        result.invoice_id,
        result.cufe_uuid,
        result.origen,
        result.proveedor_cliente,
        result.nit,
        result.fecha_factura,
        result.numero_factura,
        result.valor_esperado,
        result.estado_proceso,
        result.fecha_consulta,
        result.pdf_descargado,
        result.ruta_archivo,
        result.observacion,
        result.intentos,
    ]


def write_report(results: list[ProcessResult], report_dir: Path, input_file: Path, download_root: Path) -> Path:
    report_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M")
    output_path = report_dir / f"resultado_descarga_facturas_{timestamp}.xlsx"

    wb = Workbook()
    ws = wb.active
    ws.title = "Resultado"
    ws.append(RESULT_HEADERS)
    for result in results:
        ws.append(_row(result))

    err = wb.create_sheet("Errores_Pendientes")
    err.append(RESULT_HEADERS)
    for result in results:
        if result.estado_proceso in ERROR_STATUSES:
            err.append(_row(result))

    summary = wb.create_sheet("Resumen")
    counts = {status: sum(1 for item in results if item.estado_proceso == status) for status in sorted({item.estado_proceso for item in results})}
    summary_rows = [
        ("fecha_ejecucion", datetime.now().isoformat(timespec="seconds")),
        ("total_filas", len(results)),
        ("descargados", counts.get("DESCARGADO", 0)),
        ("ya_existian", counts.get("YA_EXISTE", 0)),
        ("no_encontrados", counts.get("NO_ENCONTRADO", 0)),
        ("errores_portal", counts.get("ERROR_PORTAL", 0)),
        ("errores_descarga", counts.get("ERROR_DESCARGA", 0)),
        ("cufe_invalidos", counts.get("CUFE_INVALIDO", 0)),
        ("pendientes_revision", sum(1 for item in results if item.estado_proceso in ERROR_STATUSES)),
        ("carpeta_descargas", str(download_root)),
        ("archivo_entrada", str(input_file)),
        ("archivo_resultado", str(output_path)),
    ]
    for key, value in summary_rows:
        summary.append([key, value])

    wb.save(output_path)
    return output_path
```

- [ ] **Step 2: Manual report check**

After the CLI exists, run with one invalid CUFE and one sample row. Open the output workbook and verify:

```text
Resultado has all rows.
Errores_Pendientes has only errors or pending rows.
Resumen has totals.
```

---

## Task 8: CLI and Run Script

**Files:**
- Create: `dian-facturas/src/dian_facturas/cli.py`
- Modify: `dian-facturas/src/dian_facturas/__main__.py`
- Create: `dian-facturas/src/dian_facturas/logging_setup.py`
- Create: `dian-facturas/scripts/run.ps1`

- [ ] **Step 1: Implement logging setup**

Create `dian-facturas/src/dian_facturas/logging_setup.py`:

```python
import logging
from datetime import datetime
from pathlib import Path


def setup_logging(log_dir: Path) -> Path:
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"ejecucion_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.FileHandler(log_path, encoding="utf-8"),
            logging.StreamHandler(),
        ],
    )
    return log_path
```

- [ ] **Step 2: Implement CLI**

Create `dian-facturas/src/dian_facturas/cli.py`:

```python
import argparse
import logging
from pathlib import Path

from dian_facturas.config import load_config
from dian_facturas.dian_portal import DianPortalClient
from dian_facturas.excel_io import read_invoice_rows
from dian_facturas.logging_setup import setup_logging
from dian_facturas.processor import process_rows
from dian_facturas.reporting import write_report


def main() -> int:
    parser = argparse.ArgumentParser(description="Descarga PDFs de facturas desde el portal DIAN por CUFE/UUID.")
    parser.add_argument("--config", default="config.yaml", help="Ruta del archivo config.yaml")
    args = parser.parse_args()

    config = load_config(Path(args.config))
    log_path = setup_logging(config.log_dir)
    logging.info("Inicio proceso DIAN facturas")
    logging.info("Log: %s", log_path)
    logging.info("Entrada: %s", config.input_path)

    rows = read_invoice_rows(config.input_path, config.input_sheet)
    logging.info("Filas leidas: %s", len(rows))

    with DianPortalClient(config.portal_url, config.headless, config.timeout_ms, config.slow_mo_ms) as portal:
        results = process_rows(rows, portal, config.download_dirs, config.max_attempts)

    download_root = config.base_dir / "descargas"
    report_path = write_report(results, config.report_dir, config.input_path, download_root)
    logging.info("Reporte generado: %s", report_path)
    logging.info("Fin proceso DIAN facturas")
    return 0
```

- [ ] **Step 3: Wire module entrypoint**

Create `dian-facturas/src/dian_facturas/__main__.py`:

```python
from dian_facturas.cli import main


raise SystemExit(main())
```

- [ ] **Step 4: Add run script**

Create `dian-facturas/scripts/run.ps1`:

```powershell
$ErrorActionPreference = "Stop"
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
$env:PYTHONPATH = "src"
.\.venv\Scripts\python.exe -m dian_facturas --config config.yaml
```

- [ ] **Step 5: Run dry pilot with invalid CUFE**

Run:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\scripts\create_sample_excel.ps1
.\scripts\run.ps1
```

Expected:

```text
Browser opens.
Portal receives the CUFE from the sample Excel.
Report is created under reportes.
No PDF is downloaded for the placeholder CUFE.
```

---

## Task 9: Real Pilot Verification

**Files:**
- No code changes unless selectors need adjustment.

- [ ] **Step 1: Prepare pilot input**

Create or edit:

```text
C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas\entrada\entrada_facturas.xlsx
```

Use 5 to 10 real CUFE/UUID values:

```text
ID | CUFE_UUID | ORIGEN
1  | <CUFE_REAL_1> | RECIBIDA
2  | <CUFE_REAL_2> | EMITIDA
```

- [ ] **Step 2: Run pilot**

Run:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\scripts\run.ps1
```

Expected:

```text
Valid CUFE/UUID rows produce downloaded PDF files.
Rows that cannot be found appear in Errores_Pendientes.
Rows with already downloaded PDFs are marked YA_EXISTE on a second run.
```

- [ ] **Step 3: Validate output manually**

Check:

```text
dian-facturas\descargas\recibidas
dian-facturas\descargas\emitidas
dian-facturas\reportes
dian-facturas\logs
```

Acceptance:

```text
At least one valid real CUFE downloads a PDF.
Second execution does not download the same PDF again.
Reporte has Resultado, Errores_Pendientes, Resumen.
Log captures start, input file, row count, report path, and finish.
```

---

## Task 10: Scheduled Execution Option

**Files:**
- Create: `dian-facturas/scripts/schedule-task.ps1`

- [ ] **Step 1: Add scheduler script**

Create `dian-facturas/scripts/schedule-task.ps1`:

```powershell
$ErrorActionPreference = "Stop"

$taskName = "S&G DIAN Facturas PDF"
$scriptPath = "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas\scripts\run.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8:00AM
$description = "Descarga PDFs de facturas DIAN desde Excel por CUFE/UUID."

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description $description -Force
```

- [ ] **Step 2: Document scheduler usage**

Append to `dian-facturas/README.md`:

```markdown
## Ejecucion programada

Para crear una tarea semanal de Windows:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\scripts\schedule-task.ps1
```

La programacion inicial queda semanal, lunes 8:00 a. m. Para el proceso real quincenal, ajustar la tarea desde el Programador de tareas de Windows o crear dos disparadores mensuales segun la regla operativa de S&G.
```

---

## Verification Commands

Use these commands after implementation:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\dian-facturas"
.\scripts\install.ps1
$env:PYTHONPATH = "src"
.\.venv\Scripts\python.exe -m pytest tests -v
.\scripts\create_sample_excel.ps1
.\scripts\run.ps1
```

Expected:

```text
All unit tests pass.
Sample Excel exists.
Run creates a report workbook.
Run creates a log file.
No code crashes when the sample CUFE is invalid.
```

## Operational Notes

- Keep `headless: false` during the pilot so the operator can see portal behavior.
- Change `headless: true` only after 2 or 3 successful real runs.
- If the DIAN portal changes labels or button text, update `dian_portal.py` selectors.
- If DIAN adds captcha or bot controls, pause full automation and evaluate an official channel or provider.
- If Cloudflare Turnstile appears, the pilot can only continue as semi-automatic: the operator must complete browser validation during the configured wait window.
- Keep the Excel batch size around 125 rows per run during the pilot.
- Do not store passwords or certificates in this MVP; the public portal path does not require them.

## Implementation Readiness

This plan is ready for implementation once there is at least one real CUFE/UUID for pilot verification. The build can start with the sample Excel and invalid CUFE, but real PDF download acceptance requires real input data.
