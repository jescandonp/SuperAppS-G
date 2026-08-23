from pathlib import Path
from PIL import Image, ImageDraw

source = Path(__file__).parent / "programador-images"
files = sorted(source.glob("*.png"))
thumbs = []
for path in files:
    image = Image.open(path).convert("RGB")
    image.thumbnail((520, 350))
    thumbs.append((path.name, image.copy()))

cell_w, cell_h = 550, 400
cols = 2
rows = (len(thumbs) + cols - 1) // cols
sheet = Image.new("RGB", (cell_w * cols, cell_h * rows), "white")
draw = ImageDraw.Draw(sheet)
for index, (name, image) in enumerate(thumbs):
    x = (index % cols) * cell_w
    y = (index // cols) * cell_h
    draw.text((x + 10, y + 8), name, fill="black")
    sheet.paste(image, (x + 10, y + 35))

target = Path(__file__).parent / "programador-contact-sheet.png"
sheet.save(target)
print(target)
