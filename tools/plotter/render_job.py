#!/usr/bin/env python3
"""Draws what the plotter paints for a job (tools/plotter/plot_job.gd output):
every colour's strokes at the marker's width, in painting order, so later
stickers cover earlier ones. Optional side-by-side with the game's own render.

  render_job.py plotted.json out.png [px_per_mm] [game.png]
"""
import json, sys
from PIL import Image, ImageDraw

d = json.load(open(sys.argv[1]))
out = sys.argv[2]
out_k = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
k = out_k * 3  # drawn 3x bigger and scaled down, so stroke widths and overlaps come out true
W, H = d["canvas_mm"]
w = max(1, round(d["marker_mm"] * k))
im = Image.new("RGB", (round(W * k), round(H * k)), "white")
dr = ImageDraw.Draw(im)
for L in d["layers"]:
    c = "#" + L["color"]
    for ln in L["lines"]:
        pts = [(ln[i] * k, ln[i + 1] * k) for i in range(0, len(ln), 2)]
        if len(pts) == 1:
            pts.append(pts[0])
        dr.line(pts, fill=c, width=w, joint="curve")
        r = w / 2
        for p in (pts[0], pts[-1]):
            dr.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=c)
im = im.resize((round(W * out_k), round(H * out_k)), Image.LANCZOS)
im.save(out)
print(out, im.size)
