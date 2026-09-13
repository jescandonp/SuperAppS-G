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
