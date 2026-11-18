#!/usr/bin/env python3
"""Add developer-page follower counts to a results.json from an older scan.

    python3 dev_followers.py results.json            # fills dev_followers / dev_page in place

Scans made before find_games.py checked developer pages have no
dev_followers, so make_outreach.py can't leave out the big developers.
This looks up just that (two Steam requests per game, developer pages are
cached), without redoing the whole scan.
"""
import json
import sys

from find_games import dev_followers, dev_pages, get

path = sys.argv[1] if len(sys.argv) > 1 else "results.json"
data = json.load(open(path, encoding="utf-8"))
todo = [r for r in data["rows"] if r.get("dev_followers") in (None, "") and not r.get("dev_page")]
for i, r in enumerate(todo, 1):
    urls = dev_pages(get(f"https://store.steampowered.com/app/{r['appid']}/?cc=us&l=english") or "")
    n = dev_followers(urls)
    r["dev_page"] = urls[0] if urls else ""
    r["dev_followers"] = "" if n is None else n
    print(f"[{i}/{len(todo)}] {r['name']}: {r['dev_followers'] if r['dev_followers'] != '' else '?'}", file=sys.stderr)
    if i % 25 == 0:
        json.dump(data, open(path, "w", encoding="utf-8"), indent=1)
json.dump(data, open(path, "w", encoding="utf-8"), indent=1)
