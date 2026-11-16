"""Build partner halves from separate key art + transparent logo (logo over cover-cropped art).
  python3 compose_partner_half.py ART LOGO OUTDIR [--cx 0.5]
Writes OUTDIR/<size>.png at each partner-half size, for make_bundle_art.py --partner-for."""
import sys, os
from PIL import Image
HALVES = {"bundle_header": (707, 464), "header_capsule": (460, 430), "small_capsule": (231, 174),
          "main_capsule": (616, 706), "vertical_capsule": (748, 448)}
art, logo, out = Image.open(sys.argv[1]).convert("RGB"), Image.open(sys.argv[2]).convert("RGBA"), sys.argv[3]
cx = float(sys.argv[sys.argv.index("--cx") + 1]) if "--cx" in sys.argv else 0.5
os.makedirs(out, exist_ok=True)
for name, (w, h) in HALVES.items():
    s = max(w / art.width, h / art.height)
    big = art.resize((round(art.width * s), round(art.height * s)), Image.LANCZOS)
    ox = round(min(max(big.width * cx - w / 2, 0), big.width - w))
    oy = round((big.height - h) / 2)
    im = big.crop((ox, oy, ox + w, oy + h))
    small = name == "small_capsule"
    lw = w * (0.96 if small else 0.88)
    lw = min(lw, h * (0.92 if small else 0.55) * logo.width / logo.height)
    lg = logo.resize((round(lw), round(lw * logo.height / logo.width)), Image.LANCZOS)
    y = (h - lg.height) // 2 if small else round(h * 0.05)
    im.paste(lg, ((w - lg.width) // 2, y), lg)
    im.save(f"{out}/{name}.png")
