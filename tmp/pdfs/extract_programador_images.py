from pathlib import Path
from pypdf import PdfReader

pdf = Path(r"C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\Artefactos Consultoria\Grabaciones\6e8020ae-66fa-4922-a72b-138c6f25201a_Programador.pdf")
out = Path(__file__).parent / "programador-images"
out.mkdir(parents=True, exist_ok=True)

reader = PdfReader(str(pdf))
for page_number, page in enumerate(reader.pages, start=1):
    for image_number, image in enumerate(page.images, start=1):
        target = out / f"page-{page_number:02d}-image-{image_number:02d}-{image.name}"
        target.write_bytes(image.data)
        print(target, len(image.data))
