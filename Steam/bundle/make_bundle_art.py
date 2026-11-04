"""Steam bundle art: your game on one half, a partner game on the other, in every Steamworks bundle size.

  python3 make_bundle_art.py --out OUT_DIR --ours DEFAULT_IMG[:box] \
      [--ours-for SIZE=IMG[:box] ...] --partner SLUG=IMG:box [--partner ...] \
      [--partner-for SLUG.SIZE=IMG:box ...]

box = x0,y0,x1,y1 in that image's own pixels: the area that must stay fully in frame (a partner's title
lettering; for your own art, the logo/characters you can't lose). Leave it off to just cover-crop.
SIZE is one of: bundle_header header_capsule small_capsule main_capsule vertical_capsule.
Writes OUT_DIR/<size>.png (your half + grey placeholder) and OUT_DIR/<slug>/<size>.png per partner.
Needs Pillow.
"""
import argparse, os
from PIL import Image, ImageDraw, ImageFont

SIZES = {"bundle_header": (1414, 464), "header_capsule": (920, 430), "small_capsule": (462, 174),
         "main_capsule": (1232, 706), "vertical_capsule": (748, 896)}
STACKED = {"vertical_capsule"}  # yours on top, partner below; every other size splits left/right


def split(name, W, H):
    """-> (your half size, partner half size, partner offset)"""
    if name in STACKED:
        h = H // 2; return (W, h), (W, H - h), (0, h)
    w = W // 2; return (w, H), (W - w, H), (w, 0)


def panel(src, must, pw, ph, margin):
    """Fill pw x ph with src: scale to cover and crop, keeping `must` centred and in frame.
    If `must` can't fit at cover scale, shrink until it fits, then stretch the short axis to fill.
    Never blurs, never letterboxes."""
    iw, ih = src.size
    s = max(pw / iw, ph / ih)
    sx = sy = s
    if must is None:  # no box: plain centred cover-crop
        must = (0, 0, iw, ih)
    elif (must[2] - must[0]) * s > pw * margin or (must[3] - must[1]) * s > ph * margin:
        mw, mh = must[2] - must[0], must[3] - must[1]
        sx = sy = min(s, pw * margin / mw, ph * margin / mh)
        if iw * sx < pw: sx = pw / iw
        if ih * sy < ph: sy = ph / ih
    big = src.resize((max(pw, round(iw * sx)), max(ph, round(ih * sy))), Image.LANCZOS)
    cx, cy = (must[0] + must[2]) / 2 * sx, (must[1] + must[3]) / 2 * sy
    ox = round(min(max(cx - pw / 2, 0), big.width - pw))
    oy = round(min(max(cy - ph / 2, 0), big.height - ph))
    return big.crop((ox, oy, ox + pw, oy + ph))


def parse(spec, need_box=False):
    path, box = (spec.rsplit(":", 1) + [None])[:2] if ":" in spec else (spec, None)
    if box and not all(v.strip().lstrip("-").isdigit() for v in box.split(",")):
        path, box = spec, None  # a ':' that was part of the path
    if need_box and not box:
        raise SystemExit(f"{spec}: give the title box as IMG:x0,y0,x1,y1")
    return path, (tuple(int(v) for v in box.split(",")) if box else None)


ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--ours", required=True, help="IMG[:box] used for any size without --ours-for")
ap.add_argument("--ours-for", action="append", default=[], help="SIZE=IMG[:box]")
ap.add_argument("--partner", action="append", default=[], help="SLUG=IMG:box")
ap.add_argument("--partner-for", action="append", default=[], help="SLUG.SIZE=IMG:box (per-size partner art)")
a = ap.parse_args()

ours = {n: parse(a.ours) for n in SIZES}
for spec in a.ours_for:
    n, rest = spec.split("=", 1)
    if n not in SIZES: raise SystemExit(f"unknown size {n}")
    ours[n] = parse(rest)

os.makedirs(a.out, exist_ok=True)
halves = {}
for name, (W, H) in SIZES.items():
    (ow, oh), (pw, ph), po = split(name, W, H)
    path, box = ours[name]
    src = Image.open(path).convert("RGB")
    halves[name] = src if src.size == (ow, oh) else panel(src, box, ow, oh, 1.0)
    tmpl = Image.new("RGB", (W, H), (40, 40, 48)); tmpl.paste(halves[name], (0, 0))
    d = ImageDraw.Draw(tmpl)
    try: fnt = ImageFont.truetype("DejaVuSans-Bold.ttf", max(10, min(ph // 8, pw // 9)))
    except OSError: fnt = ImageFont.load_default()
    d.multiline_text((po[0] + pw // 2, po[1] + ph // 2), "PARTNER GAME\nART HERE", font=fnt,
                     fill=(150, 150, 160), anchor="mm", align="center")
    tmpl.save(f"{a.out}/{name}.png")

per = {}
for spec in a.partner_for:
    key, rest = spec.split("=", 1)
    slug, n = key.split(".", 1)
    if n not in SIZES: raise SystemExit(f"unknown size {n}")
    per[(slug, n)] = parse(rest, need_box=True)
for spec in a.partner:
    slug, rest = spec.split("=", 1)
    default = parse(rest, need_box=True)
    os.makedirs(f"{a.out}/{slug}", exist_ok=True)
    for name, (W, H) in SIZES.items():
        _, (pw, ph), po = split(name, W, H)
        path, box = per.get((slug, name), default)
        src = Image.open(path).convert("RGB")
        im = Image.new("RGB", (W, H)); im.paste(halves[name], (0, 0))
        im.paste(src if src.size == (pw, ph) else panel(src, box, pw, ph, 0.94), po)
        im.save(f"{a.out}/{slug}/{name}.png")
    print(slug, "->", f"{a.out}/{slug}/")
