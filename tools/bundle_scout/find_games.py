#!/usr/bin/env python3
"""Bundle Scout: find new and upcoming Steam games like yours, with dev contact links.

Uses only Steam's public store endpoints (the same ones the store website
calls) at a polite rate. No API key needed. Python 3.8+, stdlib only.

    python3 find_games.py --profile profiles/qfs.json
    python3 find_games.py --tags "Management,Simulation" --similar 1234560,2345670 --name "My Game"
    python3 find_games.py --profile my.json --seen seen.txt   # flag games that are new since last run

A profile (JSON, see README.md) says which Steam tags to search, which tags
count toward the fit score, and which existing games are like yours (their
tags are learned into the fit score). Nothing here contacts anyone; it only
reads public store pages.
"""
import argparse
import csv
import datetime as dt
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (Bundle Scout; indie dev looking for bundle partners)"
DELAY = 1.6  # seconds between requests; appdetails allows ~200 per 5 minutes

# Tags almost every indie game has; they say little about fit, so similar-game
# learning caps them at 1.
GENERIC_TAGS = {"Indie", "Singleplayer", "Casual", "Action", "Adventure", "2D", "3D", "Early Access",
                "Free to Play", "Great Soundtrack", "Atmospheric", "Multiplayer", "Co-op", "Controller",
                "Family Friendly", "Cute", "Colorful", "Fantasy", "Story Rich", "Exploration", "First-Person",
                "Third Person", "Funny", "Simulation", "Strategy", "RPG"}

_last = 0.0


def get(url, as_json=False, retries=4):
    global _last
    for attempt in range(retries):
        wait = DELAY - (time.time() - _last)
        if wait > 0:
            time.sleep(wait)
        _last = time.time()
        req = urllib.request.Request(url, headers={
            "User-Agent": UA,
            "Accept-Language": "en-US,en;q=0.9",
            # skip the age gate on store pages
            "Cookie": "birthtime=470725201; lastagecheckage=1-0-1985; mature_content=1; wants_mature_content=1",
        })
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                body = r.read(3_000_000).decode("utf-8", "replace")
            return json.loads(body) if as_json else body
        except urllib.error.HTTPError as e:
            if e.code in (429, 502, 503):
                print(f"  HTTP {e.code}, backing off: {url}", file=sys.stderr)
                time.sleep(30 * (attempt + 1))
                continue
            return None
        except Exception:
            time.sleep(3)
    return None


def tag_ids():
    data = get("https://store.steampowered.com/tagdata/populartags/english", as_json=True) or []
    return {t["name"]: t["tagid"] for t in data}


def search(filter_name=None, sort_by=None, limit=200, tag=()):
    """Yield (appid, name, release_text) from the Steam store search."""
    out, start = [], 0
    while len(out) < limit:
        q = {"query": "", "start": start, "count": 50, "category1": 998, "infinite": 1, "cc": "us", "l": "english"}
        if tag:
            q["tags"] = ",".join(map(str, tag)) if isinstance(tag, (list, tuple)) else tag
        if filter_name:
            q["filter"] = filter_name
        if sort_by:
            q["sort_by"] = sort_by
        data = get("https://store.steampowered.com/search/results/?" + urllib.parse.urlencode(q), as_json=True)
        if not data or not data.get("results_html"):
            break
        rows = re.findall(r'<a [^>]*data-ds-appid="(\d+)"[^>]*>(.*?)</a>', data["results_html"], re.S)
        if not rows:
            break
        for appid, inner in rows:
            name = re.search(r'<span class="title">(.*?)</span>', inner, re.S)
            rel = re.search(r'search_released[^>]*>(.*?)</div>', inner, re.S)
            out.append((int(appid), html.unescape(name.group(1)).strip() if name else "",
                        html.unescape(rel.group(1)).strip() if rel else ""))
        start += 50
        if start >= int(data.get("total_count", 0)):
            break
    return out[:limit]


def app_details(appid):
    d = get(f"https://store.steampowered.com/api/appdetails?appids={appid}&cc=us&l=english", as_json=True)
    try:
        e = d[str(appid)]
        return e["data"] if e.get("success") else None
    except (TypeError, KeyError):
        return None


def followers(appid):
    xml = get(f"https://steamcommunity.com/games/{appid}/memberslistxml/?xml=1")
    m = re.search(r"<memberCount>(\d+)</memberCount>", xml or "")
    return int(m.group(1)) if m else None


def review_count(appid):
    d = get(f"https://store.steampowered.com/appreviews/{appid}?json=1&language=all&purchase_type=all&num_per_page=0", as_json=True)
    try:
        return int(d["query_summary"]["total_reviews"])
    except (TypeError, KeyError, ValueError):
        return None


SOCIAL = {
    "x": r"(?:twitter\.com|x\.com)/(?!share|intent|home)[A-Za-z0-9_]+",
    "bluesky": r"bsky\.app/profile/[^\s\"'<>?]+",
    "discord": r"discord\.(?:gg|com/invite)/[A-Za-z0-9-]+",
    "youtube": r"youtube\.com/(?:@|c/|channel/|user/)[^\s\"'<>?]+",
    "tiktok": r"tiktok\.com/@[^\s\"'<>?]+",
    "instagram": r"instagram\.com/[A-Za-z0-9_.]+",
    "itch": r"[a-z0-9-]+\.itch\.io",
    "presskit": r"[^\s\"'<>]*(?:presskit|press-kit|press_kit|dopresskit)[^\s\"'<>]*",
}


def store_page(appid):
    """Social links devs add to their store page, plus the store's user tags."""
    page = get(f"https://store.steampowered.com/app/{appid}/?cc=us&l=english") or ""
    tags = [html.unescape(t).strip() for t in re.findall(r'class="app_tag"[^>]*>\s*([^<]+?)\s*<', page)]
    urls = [urllib.parse.unquote(u) for u in re.findall(r"linkfilter/\?u=([^\"'&]+)", page)]
    urls += re.findall(r'href="(https?://[^"]+)"', page)
    found = {}
    for key, pat in SOCIAL.items():
        for u in urls:
            m = re.search(pat, u, re.I)
            if m and "steampowered" not in u and "valvesoftware" not in u:
                found.setdefault(key, "https://" + m.group(0).split("://")[-1])
                break
    return found, [t for t in tags if t != "+"]


def website_emails(url):
    if not url:
        return []
    page = get(url, retries=1) or ""
    emails = set(re.findall(r"mailto:([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})", page))
    emails |= set(re.findall(r"\b([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.(?:com|net|org|io|games|gg|dev|co|de|fr|uk|jp|br))\b", page))
    return sorted(e for e in emails if not e.lower().endswith((".png", ".jpg")) and "sentry" not in e.lower())[:3]


def parse_date(text):
    for fmt in ("%b %d, %Y", "%d %b, %Y", "%B %d, %Y", "%b %Y", "%B %Y", "%Y"):
        try:
            return dt.datetime.strptime(text.strip(), fmt).date()
        except ValueError:
            pass
    return None


COLS = ["new", "fit_score", "fit_tags", "name", "release", "released", "has_demo", "followers", "wishlist_rank",
        "reviews", "developer", "publisher", "self_published", "indie", "support_email", "website_emails", "website",
        "x", "bluesky", "discord", "youtube", "tiktok", "instagram", "itch", "presskit", "support_url", "store_url",
        "source", "tags", "short_description", "header_image", "appid"]


def write_outputs(rows, out, today, meta):
    rows = sorted(rows, key=lambda r: (r["fit_score"], r["followers"] or 0), reverse=True)
    with open(out + ".csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLS, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    with open(out + ".json", "w", encoding="utf-8") as f:
        json.dump({"generated": today.isoformat(), **meta, "rows": rows}, f, indent=1)


def load_profile(args):
    prof = {}
    if args.profile:
        with open(args.profile, encoding="utf-8") as f:
            prof = json.load(f)
    if args.name:
        prof["name"] = args.name
    if args.tags:
        prof["search_tags"] = [t.strip() for t in args.tags.split(",") if t.strip()]
    if args.similar:
        prof["similar_games"] = [int(a) for a in re.findall(r"\d+", args.similar)]
    if args.our_appid:
        prof["our_appid"] = args.our_appid
    if not prof.get("search_tags") and not prof.get("extra_searches"):
        sys.exit("Give --profile or --tags: which Steam tags to search (e.g. --tags Platformer)")
    prof.setdefault("name", "our game")
    return prof


def learn_weights(appids, max_weight=8):
    """Weight each tag by how high it sits on the similar games' store pages
    (Steam lists the most-voted tags first) and how many of them share it."""
    score, seen_names = {}, []
    for appid in appids:
        d = app_details(appid)
        seen_names.append(d.get("name") if d else str(appid))
        _, tags = store_page(appid)
        for i, t in enumerate(tags[:20]):
            score[t] = score.get(t, 0) + (20 - i) / 20
    if not score:
        return {}, seen_names
    top = max(score.values())
    out = {}
    for t, v in score.items():
        w = round(max_weight * v / top)
        if t in GENERIC_TAGS:
            w = min(w, 1)
        if w > 0:
            out[t] = w
    return out, seen_names


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--profile", help="JSON profile (see README.md and profiles/)")
    ap.add_argument("--name", help="your game's name (overrides the profile)")
    ap.add_argument("--tags", help="comma-separated Steam tags that every searched game must have (overrides the profile)")
    ap.add_argument("--similar", help="comma-separated Steam appids of games like yours (overrides the profile)")
    ap.add_argument("--our-appid", type=int, help="your game's appid, left out of the results")
    ap.add_argument("--max-upcoming", type=int, default=150, help="top N upcoming games by wishlist popularity")
    ap.add_argument("--max-soon", type=int, default=100, help="next N games by release date")
    ap.add_argument("--recent-days", type=int, default=60, help="also include games released in the last N days (0 = off)")
    ap.add_argument("--max-recent", type=int, default=150)
    ap.add_argument("--max-extra", type=int, default=50, help="results per extra search")
    ap.add_argument("--min-followers", type=int, default=0)
    ap.add_argument("--min-fit", type=int, default=0, help="drop games whose fit score is below this")
    ap.add_argument("--no-website", action="store_true", help="skip fetching dev websites for emails (faster)")
    ap.add_argument("--seen", help="file of appids from earlier runs; new games are flagged and the file is updated")
    ap.add_argument("--out", default="results", help="output file prefix (writes .csv and .json)")
    args = ap.parse_args()
    prof = load_profile(args)
    today = dt.date.today()

    ids = tag_ids()
    def resolve(names):
        missing = [n for n in names if n not in ids]
        if missing:
            print(f"Unknown Steam tag(s): {', '.join(missing)} (check spelling on store.steampowered.com/tag/browse)", file=sys.stderr)
            return None
        return [ids[n] for n in names]

    weights = {}
    similar = prof.get("similar_games") or []
    if similar:
        print(f"Learning fit tags from {len(similar)} similar game(s)...", file=sys.stderr)
        weights, names = learn_weights(similar)
        print("  " + ", ".join(names), file=sys.stderr)
    weights.update(prof.get("fit_weights") or {})  # hand-set weights win
    if not weights:
        weights = {t: 3 for t in prof.get("search_tags", [])}
    print("Fit weights: " + ", ".join(f"{t} {w}" for t, w in sorted(weights.items(), key=lambda kv: -kv[1])), file=sys.stderr)

    cands = {}
    base = resolve(prof.get("search_tags") or [])
    if base:
        label = " + ".join(prof["search_tags"])
        print(f"Searching popular upcoming {label}...", file=sys.stderr)
        for rank, (appid, name, rel) in enumerate(search("popularwishlist", limit=args.max_upcoming, tag=base), 1):
            cands[appid] = {"appid": appid, "name": name, "release": rel, "wishlist_rank": rank, "source": "upcoming (popular)"}
        print(f"Searching soonest upcoming {label}...", file=sys.stderr)
        for appid, name, rel in search("comingsoon", limit=args.max_soon, tag=base):
            cands.setdefault(appid, {"appid": appid, "name": name, "release": rel, "wishlist_rank": "", "source": "upcoming (soonest)"})
        if args.recent_days:
            print("Searching recent releases...", file=sys.stderr)
            for appid, name, rel in search(sort_by="Released_DESC", limit=args.max_recent, tag=base):
                d = parse_date(rel)
                if d and d > today:
                    continue
                if d and (today - d).days > args.recent_days:
                    break
                cands.setdefault(appid, {"appid": appid, "name": name, "release": rel, "wishlist_rank": "", "source": "recent release"})
    for extra in prof.get("extra_searches") or []:
        names, label = extra["tags"], extra.get("label") or " + ".join(extra["tags"])
        tags = resolve(names)
        if not tags:
            print(f"Skipping search {label}", file=sys.stderr)
            continue
        print(f"Searching {label} (upcoming + recent)...", file=sys.stderr)
        for appid, name, rel in search("comingsoon", limit=args.max_extra, tag=tags):
            cands.setdefault(appid, {"appid": appid, "name": name, "release": rel, "wishlist_rank": "", "source": f"upcoming ({label})"})
        for appid, name, rel in search(sort_by="Released_DESC", limit=args.max_extra, tag=tags):
            d = parse_date(rel)
            if d and d <= today and (today - d).days <= max(args.recent_days, 180):
                cands.setdefault(appid, {"appid": appid, "name": name, "release": rel, "wishlist_rank": "", "source": f"recent ({label})"})
    for a in [prof.get("our_appid")] + list(prof.get("exclude_appids") or []) + list(similar):
        cands.pop(a, None)

    seen = set()
    if args.seen:
        try:
            seen = {int(x) for x in open(args.seen).read().split() if x.strip().isdigit()}
        except FileNotFoundError:
            pass

    meta = {"profile": {k: prof.get(k) for k in ("name", "our_appid", "report_title", "report_blurb", "outreach")},
            "weights": weights}
    rows = []
    total = len(cands)
    for i, c in enumerate(cands.values(), 1):
        print(f"[{i}/{total}] {c['name']}", file=sys.stderr)
        d = app_details(c["appid"])
        if not d or d.get("type") != "game":
            continue
        links, tags = store_page(c["appid"])
        fit = sum(weights.get(t, 0) for t in tags)
        if fit < args.min_fit:
            continue
        devs, pubs = d.get("developers") or [], d.get("publishers") or []
        genres = [g["description"] for g in d.get("genres", [])]
        support = d.get("support_info") or {}
        released = not (d.get("release_date") or {}).get("coming_soon", True)
        c.update({
            "release": (d.get("release_date") or {}).get("date") or c["release"],
            "released": "yes" if released else "no",
            "developer": ", ".join(devs),
            "publisher": ", ".join(pubs),
            "self_published": "yes" if devs and set(devs) == set(pubs) else "no",
            "indie": "yes" if "Indie" in genres else "no",
            "followers": followers(c["appid"]),
            "reviews": review_count(c["appid"]) if released else "",
            "store_url": f"https://store.steampowered.com/app/{c['appid']}/",
            "website": d.get("website") or "",
            "support_email": support.get("email") or "",
            "support_url": support.get("url") or "",
            "has_demo": "yes" if d.get("demos") else "no",
            "header_image": d.get("header_image") or "",
            "short_description": html.unescape(d.get("short_description") or "")[:200],
            "new": "" if not args.seen else ("NEW" if c["appid"] not in seen else ""),
        })
        if (c["followers"] or 0) < args.min_followers:
            continue
        c["tags"] = ", ".join(tags[:12])
        c["fit_score"] = fit
        c["fit_tags"] = ", ".join(t for t in tags if weights.get(t, 0) >= 3)
        for k in SOCIAL:
            c[k] = links.get(k, "")
        site_emails = [] if args.no_website else website_emails(c["website"])
        c["website_emails"] = " ".join(e for e in site_emails if e != c["support_email"])
        rows.append(c)
        if len(rows) % 25 == 0:
            write_outputs(rows, args.out, today, meta)  # partial results survive a timeout

    write_outputs(rows, args.out, today, meta)
    if args.seen:
        with open(args.seen, "w") as f:
            f.write("\n".join(str(a) for a in sorted(seen | {r["appid"] for r in rows})) + "\n")
    print(f"Wrote {len(rows)} games to {args.out}.csv and {args.out}.json", file=sys.stderr)


if __name__ == "__main__":
    main()
