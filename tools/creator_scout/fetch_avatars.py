#!/usr/bin/env python3
"""Download each queued channel's avatar as a small JPEG for the review page.

    python3 fetch_avatars.py results.json queue.txt thumbs
"""
import io
import json
import os
import re
import sys
import time
import urllib.request

from PIL import Image

src, queue, out = sys.argv[1:4]
rows = {r["channel_id"]: r for r in json.load(open(src, encoding="utf-8"))["rows"]}
os.makedirs(out, exist_ok=True)
for cid in open(queue).read().split():
    dst = os.path.join(out, f"{cid}.jpg")
    url = (rows.get(cid) or {}).get("avatar")
    if os.path.exists(dst) or not url:
        continue
    url = re.sub(r"=s\d+", "=s128", url)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=20) as r:
            img = Image.open(io.BytesIO(r.read())).convert("RGB")
        img.thumbnail((96, 96))
        img.save(dst, "JPEG", quality=82, optimize=True)
    except Exception as e:
        print("miss", cid, e)
    time.sleep(0.1)
