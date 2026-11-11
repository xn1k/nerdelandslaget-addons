"""Builds the suite's textures from the source logos in the project root.

  emblem.png      256x256  the NL emblem (minimap button, addon icon, window badge)
  emblem_64.png    64x64   a smaller emblem for the minimap button
  wordmark.png   1024x512  NERDE-LANDSLAGET at its own 800x273 in the top-left corner
                           (padded to powers of two; the addon crops it with texcoords)

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
