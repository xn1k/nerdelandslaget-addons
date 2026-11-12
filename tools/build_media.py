"""Builds the suite's textures from the source logos in the project root.

  emblem.png      256x256  the NL emblem (minimap button, addon icon, window badge)
  emblem_64.png    64x64   a smaller emblem for the minimap button
  wordmark.png   1024x512  NERDE-LANDSLAGET at its own 800x273 in the top-left corner
                           (padded to powers of two; the addon crops it with texcoords)
  role_*.png      128x128  tank / healer / damage icons, cut from art/role-icons.png
  role_*_32.png    32x32   the same, pre-shrunk for the small icons in list rows

art/role-icons.png is the three icons in a row on transparency (made with Nano Banana 2.1 on
fal.ai from the emblem as a style reference, then keyed off magenta).

Run: python tools/build_media.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Nerdelandslaget" / "Media"
OUT.mkdir(parents=True, exist_ok=True)

emblem = Image.open(ROOT / "nl-emblem-logo.png").convert("RGBA")
if emblem.size != (256, 256):
    emblem = emblem.resize((256, 256), Image.LANCZOS)
emblem.save(OUT / "emblem.png")
emblem.resize((64, 64), Image.LANCZOS).save(OUT / "emblem_64.png")

word = Image.open(ROOT / "nl-logo-outline-upscaled.png").convert("RGBA")
canvas = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
canvas.paste(word, (0, 0))
canvas.save(OUT / "wordmark.png")
print("wordmark", word.size, "-> texcoords", word.size[0] / 1024, word.size[1] / 512)

# Role icons: three in a row, each cut out of its own third, trimmed, centred on a square
# with a little margin, then scaled down (power-of-two sizes for the client).
roles = Image.open(ROOT / "art" / "role-icons.png").convert("RGBA")
third = roles.width // 3
for i, name in enumerate(("tank", "healer", "damage")):
    cell = roles.crop((i * third, 0, (i + 1) * third, roles.height))
    cell = cell.crop(cell.getbbox())
    side = int(max(cell.size) * 1.06)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
    square.resize((128, 128), Image.LANCZOS).save(OUT / f"role_{name}.png")
    square.resize((32, 32), Image.LANCZOS).save(OUT / f"role_{name}_32.png")
    print("role", name, cell.size)
