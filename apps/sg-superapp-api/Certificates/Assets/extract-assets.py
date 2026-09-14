# apps/sg-superapp-api/Certificates/Assets/extract-assets.py
# Extrae el membrete (header, pie, marca de agua, franja lateral) directamente
# de los PDF reales de referencia, sin recompresion ni perdida de calidad.
import fitz
import io
import os

from PIL import Image

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
    13: "sidebar-mark.png",
}

# xref 5 (watermark) es un caso especial: PyMuPDF reporta que esta imagen tiene
# una soft mask asociada (info["smask"] == 6), pero doc.extract_image(5) NO la
# fusiona en los bytes devueltos -- entrega un PNG RGBA con el canal alfa
# uniformemente en 255 (opaco) y el RGB subyacente en negro (0,0,0) donde
# deberia haber transparencia. Al dibujarse casi a tamano de pagina en
# CertificateLetterhead.Draw, eso pinta un rectangulo negro solido que tapa el
# certificado. Hay que componer manualmente la imagen base con su soft mask.
WATERMARK_XREF = 5
WATERMARK_FILE = "watermark.png"

def extract_simple_assets():
    doc = fitz.open(REFERENCE_PDF)
    for xref, file_name in ASSETS.items():
        info = doc.extract_image(xref)
        out_path = os.path.join(OUTPUT_DIR, file_name)
        with open(out_path, "wb") as f:
            f.write(info["image"])
        print(f"{file_name}: {out_path} ({len(info['image'])} bytes, {info['width']}x{info['height']})")

def extract_watermark():
    doc = fitz.open(REFERENCE_PDF)
    base_info = doc.extract_image(WATERMARK_XREF)
    smask_xref = base_info["smask"]
    mask_info = doc.extract_image(smask_xref)

    base_img = Image.open(io.BytesIO(base_info["image"])).convert("RGB")
    mask_img = Image.open(io.BytesIO(mask_info["image"])).convert("L")

    if mask_img.size != base_img.size:
        mask_img = mask_img.resize(base_img.size)

    base_img.putalpha(mask_img)

    out_path = os.path.join(OUTPUT_DIR, WATERMARK_FILE)
    base_img.save(out_path)
    print(f"{WATERMARK_FILE}: {out_path} ({base_img.width}x{base_img.height}, alpha compuesto desde smask xref {smask_xref})")

def main():
    extract_simple_assets()
    extract_watermark()

if __name__ == "__main__":
    main()
