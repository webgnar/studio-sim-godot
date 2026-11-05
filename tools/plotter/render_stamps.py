#!/usr/bin/env python3
"""Composites a job's stamps from the sticker PNGs (what the game shows), for
comparing with what the plotter paints (render_job.py).

  render_stamps.py job.json out.png [px_per_mm]
"""
import json, os, sys
from PIL import Image

repo = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
job = json.load(open(sys.argv[1]))
k = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
W, H = job["canvas_mm"]
im = Image.new("RGBA", (round(W * k), round(H * k)), "white")
cache = {}
for s in job["stamps"]:
    sid = s["sticker"]
    if sid not in cache:
        cache[sid] = Image.open(os.path.join(repo, "sprites", "painting layers", sid + ".png")).convert("RGBA")
    src = cache[sid]
    f = s["size"] * k / max(src.size)
    st = src.resize((max(1, round(src.size[0] * f)), max(1, round(src.size[1] * f))), Image.LANCZOS)
    st = st.rotate(-s["rot"], resample=Image.BICUBIC, expand=True)
    im.alpha_composite(st, (round(s["x"] * k - st.size[0] / 2), round(s["y"] * k - st.size[1] / 2)))
im.convert("RGB").save(sys.argv[2])
