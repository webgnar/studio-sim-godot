"""Download a Steam game's store capsules (2x sizes) from its store URL or appid.

  python3 fetch_steam_art.py https://store.steampowered.com/app/5243280/... OUT_DIR

Saves header_2x, small_capsule_2x, main_capsule_2x, hero_capsule_2x (748x896 vertical),
library_capsule_2x (600x900) and library_hero_2x into OUT_DIR as .jpg. Standard library only.
"""
import json, os, re, sys, urllib.parse, urllib.request

src, out = sys.argv[1], sys.argv[2]
m = re.search(r"/app/(\d+)", src) or re.fullmatch(r"(\d+)", src)
if not m: raise SystemExit("give a store URL or appid")
appid = int(m.group(1))
q = {"ids": [{"appid": appid}], "context": {"language": "english", "country_code": "US"},
     "data_request": {"include_assets": True}}
url = "https://api.steampowered.com/IStoreBrowseService/GetItems/v1/?input_json=" + urllib.parse.quote(json.dumps(q))
item = json.load(urllib.request.urlopen(url))["response"]["store_items"][0]
assets = item.get("assets") or {}
os.makedirs(out, exist_ok=True)
print(appid, item.get("name"))
for k, v in assets.items():
    if not k.endswith("_2x"): continue
    u = f"https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/{appid}/{v}"
    try:
        with urllib.request.urlopen(u) as r, open(f"{out}/{k}.jpg", "wb") as f: f.write(r.read())
        print("  ", k)
    except Exception as e:
        print("  ", k, "failed:", e)
