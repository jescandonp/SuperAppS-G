# Lee el texto de los PDF generados por CertificateRenderCheck y valida su
# contenido, sin necesitar un servidor web ni base de datos. Requiere PyMuPDF
# (pip install pymupdf).
import re
import sys

import fitz


def extract_text(path: str) -> str:
    doc = fitz.open(path)
    return "\n".join(page.get_text() for page in doc)


def check(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> int:
    if len(sys.argv) != 2:
        print("Uso: verify-certificate-render.py <directorio-de-salida>")
        return 2

    out_dir = sys.argv[1]
    failures: list[str] = []
    accent_pattern = re.compile(r"[áéíóúñÁÉÍÓÚÑ]")

    activo = extract_text(f"{out_dir}/activo.pdf")
    check("MARIA FERNANDA GUTIERREZ DE LA ESPRIELLA MONTA" in activo, "activo.pdf: falta el nombre del empleado", failures)
    check("SG-I4-99999999-000001" in activo, "activo.pdf: falta el numero de certificado", failures)
    check(bool(accent_pattern.search(activo)), "activo.pdf: no se encontro ninguna tilde/enie en el cuerpo del texto", failures)

    retirado_cesantias = extract_text(f"{out_dir}/retirado-cesantias.pdf")
    check("ORLANDO ESTEBAN CADENA LONDO" in retirado_cesantias, "retirado-cesantias.pdf: falta el nombre del empleado", failures)
    check("SG-I4-99999999-000002" in retirado_cesantias, "retirado-cesantias.pdf: falta el numero de certificado", failures)
    check("1562" in retirado_cesantias, "retirado-cesantias.pdf: falta la referencia al Decreto 1562 de 2019", failures)
    check("NICA VEZ" in retirado_cesantias, "retirado-cesantias.pdf: falta el disclaimer de emision unica", failures)
    check(bool(accent_pattern.search(retirado_cesantias)), "retirado-cesantias.pdf: no se encontro ninguna tilde/enie en el cuerpo del texto", failures)

    retirado_tramite = extract_text(f"{out_dir}/retirado-tramite-general.pdf")
    check("1562" not in retirado_tramite, "retirado-tramite-general.pdf: el Decreto 1562 aparecio en un certificado que NO es de cesantias", failures)
    check("NICA VEZ" in retirado_tramite, "retirado-tramite-general.pdf: falta el disclaimer de emision unica (debe aparecer en TODO retirado, sin importar el proposito)", failures)

    if failures:
        for failure in failures:
            print(f"CERTIFICATE RENDER FAIL: {failure}")
        return 1

    print("CERTIFICATE RENDER PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
