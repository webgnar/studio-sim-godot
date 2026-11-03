#!/usr/bin/env python3
"""Download each queued game's Steam header image as a small JPEG.

    python3 fetch_thumbs.py queue.txt thumbs
"""
import io
import json
import os
import sys
import time
import urllib.request

from PIL import Image



def header_urls(appid):
    # Newer apps keep their header under a hashed path, so ask the store API for it.
    try:
        api = f"https://store.steampowered.com/api/appdetails?appids={appid}&filters=basic"
        with urllib.request.urlopen(urllib.request.Request(api, headers={"User-Agent": "Mozilla/5.0"}), timeout=20) as r:
            url = json.load(r)[str(appid)]["data"]["header_image"]
        time.sleep(1.5)
        yield url
    except Exception as e:
        print("no header_image", appid, e)
    yield f"https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{appid}/header.jpg"


queue, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for appid in open(queue).read().split():
    dst = os.path.join(out, f"{appid}.jpg")
    if os.path.exists(dst):
        continue
    for url in header_urls(appid):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=20) as r:
                img = Image.open(io.BytesIO(r.read())).convert("RGB")
            img.thumbnail((368, 172))
            img.save(dst, "JPEG", quality=78, optimize=True)
            print("ok", appid)
            break
        except Exception as e:
            print("miss", appid, url, e)
    time.sleep(0.3)
