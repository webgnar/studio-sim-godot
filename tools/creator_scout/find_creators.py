#!/usr/bin/env python3
"""Find small YouTube channels that would fit your game, and every public way to reach them.

    python3 find_creators.py --profile profiles/studio_sim.json --out results

Searches YouTube the way a viewer would (recent videos of games like yours,
topic searches, channel searches), then opens each channel it finds: About
page (subscribers, description, links, country), and its latest uploads. It
keeps channels in the profile's subscriber range that posted recently, and
scores them by how well their videos match your game.

Reads only public YouTube pages through YouTube's own web API (no API key, no
sign-in). It never contacts anyone. Python 3.8+, standard library only.
"""
import argparse
import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

API = "https://www.youtube.com/youtubei/v1/"
CLIENT = {"clientName": "WEB", "clientVersion": "2.20251101.00.00", "hl": "en", "gl": "US"}
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"

# Search filters (YouTube's "sp" parameter)
SP_VIDEO_MONTH = "EgQIBBAB"   # videos uploaded this month
SP_VIDEO_YEAR = "EgQIBRAB"    # videos uploaded this year
SP_VIDEO = "EgIQAQ%3D%3D"     # any video
SP_CHANNEL = "EgIQAg%3D%3D"   # channels

DELAY = 0.35


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def call(ep, body, tries=4):
    data = json.dumps({"context": {"client": CLIENT}, **body}).encode()
    for i in range(tries):
        try:
            req = urllib.request.Request(API + ep + "?prettyPrint=false", data=data,
                                         headers={"Content-Type": "application/json", "User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                out = json.load(r)
            time.sleep(DELAY)
            return out
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ConnectionError) as e:
            wait = 3 * (2 ** i)
            log(f"  {ep} failed ({e}), retry in {wait}s")
            time.sleep(wait)
    return {}


def get_html(url, tries=3):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "en-US,en;q=0.9"})
            with urllib.request.urlopen(req, timeout=30) as r:
                out = r.read().decode("utf-8", "replace")
            time.sleep(DELAY)
            return out
        except Exception as e:
            log(f"  GET {url} failed ({e})")
            time.sleep(3 * (2 ** i))
    return ""


def find_all(o, key, out=None):
    out = [] if out is None else out
    if isinstance(o, dict):
        if key in o:
            out.append(o[key])
        for v in o.values():
            find_all(v, key, out)
    elif isinstance(o, list):
        for v in o:
            find_all(v, key, out)
    return out


def text(o):
    if not o:
        return ""
    if isinstance(o, str):
        return o
    if "simpleText" in o:
        return o["simpleText"]
    if "runs" in o:
        return "".join(r.get("text", "") for r in o["runs"])
    if "content" in o:
        return o["content"]
    return ""


def parse_count(s):
    """'1.2K subscribers' -> 1200, '61 subscribers' -> 61, '1,234 views' -> 1234."""
    if not s:
        return None
    s = s.replace(",", "").strip()
    if s.lower().startswith("no "):
        return 0
    m = re.match(r"([\d.]+)\s*([KMB])?", s, re.I)
    if not m:
        return None
    n = float(m.group(1))
    mult = {"k": 1e3, "m": 1e6, "b": 1e9}.get((m.group(2) or "").lower(), 1)
    return int(round(n * mult))


def parse_age_days(s):
    """'3 weeks ago' / 'Streamed 2 days ago' -> days."""
    if not s:
        return None
    m = re.search(r"(\d+)\s*(second|minute|hour|day|week|month|year)", s)
    if not m:
        return None
    n = int(m.group(1))
    return n * {"second": 0, "minute": 0, "hour": 0, "day": 1, "week": 7, "month": 30, "year": 365}[m.group(2)]


# ---------- search ----------

def search(query, sp, pages):
    """Yield (kind, item) for videos and channels in the results."""
    d = call("search", {"query": query, "params": sp})
    for page in range(pages):
        for v in find_all(d, "videoRenderer"):
            owner = (v.get("ownerText") or {}).get("runs") or [{}]
            cid = (owner[0].get("navigationEndpoint") or {}).get("browseEndpoint", {}).get("browseId")
            if cid:
                yield "video", {"channel_id": cid, "channel": owner[0].get("text", ""), "title": text(v.get("title")),
                                "video_id": v.get("videoId"), "views": parse_count(text(v.get("viewCountText"))),
                                "age_days": parse_age_days(text(v.get("publishedTimeText")))}
        for c in find_all(d, "channelRenderer"):
            # In channel results YouTube puts the @handle in subscriberCountText and the subscriber count in videoCountText.
            subs_txt = text(c.get("videoCountText"))
            yield "channel", {"channel_id": c.get("channelId"), "channel": text(c.get("title")),
                              "subs": parse_count(subs_txt) if "subscriber" in subs_txt else None}
        toks = [t["token"] for t in find_all(d, "continuationCommand") if t.get("request") == "CONTINUATION_REQUEST_TYPE_SEARCH"]
        if page + 1 >= pages or not toks:
            break
        d = call("search", {"continuation": toks[0]})


# ---------- channel details ----------

LINK_KINDS = [("x", r"(twitter\.com|x\.com)/"), ("bluesky", r"bsky\.app/"), ("discord", r"discord\.(gg|com)/"),
              ("twitch", r"twitch\.tv/"), ("tiktok", r"tiktok\.com/"), ("instagram", r"instagram\.com/"),
              ("kofi", r"ko-fi\.com/"), ("patreon", r"patreon\.com/"), ("linktree", r"(linktr\.ee|beacons\.ai|carrd\.co)/")]
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")


def real_url(link_vm):
    for run in (link_vm.get("link") or {}).get("commandRuns", []):
        url = (run.get("onTap", {}).get("innertubeCommand", {}).get("urlEndpoint") or {}).get("url", "")
        m = re.search(r"[?&]q=([^&]+)", url)
        if m:
            return urllib.request.unquote(m.group(1))
        if url:
            return url
    c = text(link_vm.get("link"))
    return ("https://" + c) if c and not c.startswith("http") else c


def channel_about(cid, lo=0, hi=10 ** 12):
    """About panel: description, subscribers, views, joined, country, links, hidden business email.
    Channels whose header subscriber count is outside lo..hi skip the About request."""
    html = get_html(f"https://www.youtube.com/channel/{cid}/about")
    m = re.search(r"var ytInitialData = (\{.*?\});</script>", html)
    init = json.loads(m.group(1)) if m else {}
    header_subs = next((parse_count(text(p.get("text"))) for p in find_all(init.get("header"), "metadataParts")
                        for p in p if "subscriber" in text(p.get("text"))), None)
    toks = re.findall(r'"continuationCommand":\{"token":"([^"]*)","request":"CONTINUATION_REQUEST_TYPE_BROWSE"', html)
    about = None
    if header_subs is None or lo <= header_subs <= hi:
        for t in toks[:3]:
            vm = find_all(call("browse", {"continuation": t}), "aboutChannelViewModel")
            if vm:
                about = vm[0]
                break
    meta = (init.get("metadata") or {}).get("channelMetadataRenderer") or {}
    tabs = {}
    for tr in find_all(init, "tabRenderer"):
        be = (tr.get("endpoint") or {}).get("browseEndpoint") or {}
        if tr.get("title") and be.get("params"):
            tabs[tr["title"]] = be["params"]
    info = {
        "title": meta.get("title", ""),
        "handle": (meta.get("vanityChannelUrl") or "").rsplit("/", 1)[-1],
        "keywords": meta.get("keywords", ""),
        "avatar": ((meta.get("avatar") or {}).get("thumbnails") or [{}])[0].get("url", ""),
        "family_safe": meta.get("isFamilySafe"),
        "tabs": tabs,
    }
    if about:
        info.update({
            "description": about.get("description", ""),
            "subs": parse_count(about.get("subscriberCountText")),
            "total_views": parse_count(about.get("viewCountText")),
            "video_count": parse_count(about.get("videoCountText")),
            "joined": text(about.get("joinedDateText")).replace("Joined ", ""),
            "country": about.get("country", ""),
            "business_email": "signInForBusinessEmail" in about,
            "links": [real_url(l["channelExternalLinkViewModel"]) for l in about.get("links", []) if "channelExternalLinkViewModel" in l],
        })
    else:
        info.update({"description": meta.get("description", ""), "subs": header_subs, "links": []})
    return info


def channel_videos(cid, tab_params, limit=30):
    d = call("browse", {"browseId": cid, "params": tab_params})
    vids = []
    for l in find_all(d, "lockupViewModel"):
        md = ((l.get("metadata") or {}).get("lockupMetadataViewModel") or {})
        parts = [text(p.get("text")) for r in find_all(md, "metadataRows") for row in r for p in row.get("metadataParts", [])]
        views = next((parse_count(p) for p in parts if "view" in p), None)
        age = next((parse_age_days(p) for p in parts if "ago" in p), None)
        vids.append({"title": text(md.get("title")), "video_id": l.get("contentId"), "views": views, "age_days": age})
    for v in find_all(d, "videoRenderer"):
        vids.append({"title": text(v.get("title")), "video_id": v.get("videoId"),
                     "views": parse_count(text(v.get("viewCountText"))), "age_days": parse_age_days(text(v.get("publishedTimeText")))})
    return vids[:limit]


# ---------- scoring ----------

STOP_EN = {"the", "and", "my", "a", "of", "to", "in", "is", "i", "this", "you", "game", "games", "let's", "play", "with", "first", "new", "it", "for"}


def englishness(texts):
    words = re.findall(r"[^\W\d_]+'?[^\W\d_]*", " ".join(texts).lower())
    if not words:
        return 0.0
    latin = sum(1 for w in words if re.fullmatch(r"[a-z']+", w))
    hits = sum(1 for w in words if w in STOP_EN)
    return (latin / len(words)) * min(1.0, 8 * hits / len(words))


def score(ch, prof, game_names):
    reasons, pts = [], 0.0
    titles = [v["title"] for v in ch["videos"]]
    blob_titles = " \n".join(titles).lower()
    blob_about = (ch.get("description", "") + " " + ch.get("keywords", "") + " " + ch.get("title", "")).lower()

    # Played games like ours (strongest signal)
    played = sorted({g for g in game_names if g.lower() in blob_titles or any(g.lower() in f.lower() for f in ch["found_titles"])})
    if played:
        p = min(len(played), 6) * prof.get("played_similar_points", 4)
        pts += p
        reasons.append("played " + ", ".join(played[:6]))

    for kw, w in prof.get("keyword_weights", {}).items():
        k = kw.lower()
        n_t = sum(1 for t in titles if re.search(r"\b" + re.escape(k), t.lower()))
        in_about = bool(re.search(r"\b" + re.escape(k), blob_about))
        if n_t or in_about:
            p = w * (min(n_t, 4) / 2 + (1 if in_about else 0))
            pts += p
            reasons.append(kw)
    for kw, w in prof.get("penalty_keywords", {}).items():
        k = kw.lower()
        n_t = sum(1 for t in titles if k in t.lower())
        if n_t >= max(2, len(titles) // 3) or k in blob_about:
            pts -= w
            reasons.append("-" + kw)

    # Activity and engagement
    ages = [v["age_days"] for v in ch["videos"] if v.get("age_days") is not None]
    last = min(ages) if ages else None
    ch["last_upload_days"] = last
    recent = [v for v in ch["videos"] if v.get("age_days") is not None and v["age_days"] <= 90]
    ch["uploads_90d"] = len(recent)
    if last is not None:
        if last <= 14:
            pts += 4
        elif last <= 30:
            pts += 2
    pts += min(len(recent), 12) / 4
    views = sorted(v["views"] for v in ch["videos"][:15] if v.get("views") is not None)
    med = views[len(views) // 2] if views else None
    ch["median_views"] = med
    if med is not None and ch.get("subs"):
        ratio = med / max(ch["subs"], 1)
        ch["views_per_sub"] = round(ratio, 2)
        if ratio >= 0.5:
            pts += 3
            reasons.append("good views for size")
        elif ratio >= 0.2:
            pts += 1.5
    contact = bool(ch.get("emails")) or ch.get("business_email") or any(ch.get(k) for k in ("x", "bluesky", "discord"))
    if ch.get("emails"):
        pts += 2
    ch["fit_score"] = round(pts, 1)
    ch["fit_reasons"] = ", ".join(reasons)
    ch["played"] = ", ".join(played)
    ch["reachable"] = "yes" if contact else "no"


def main():
    global DELAY
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True)
    ap.add_argument("--out", default="results")
    ap.add_argument("--pages", type=int, default=2, help="result pages per search")
    ap.add_argument("--max-searches", type=int, default=0, help="stop after this many searches (quick test)")
    ap.add_argument("--max-channels", type=int, default=0, help="open at most this many channels (quick test)")
    ap.add_argument("--delay", type=float, default=DELAY)
    ap.add_argument("--cache", default="cache.json", help="channel details cache, so a rerun skips channels already opened")
    args = ap.parse_args()
    DELAY = args.delay
    prof = json.load(open(args.profile, encoding="utf-8"))
    lo, hi = prof.get("min_subs", 20), prof.get("max_subs", 500)
    active_days = prof.get("active_days", 60)
    exclude = set(prof.get("exclude_channels", []))

    game_names = list(dict.fromkeys(prof.get("similar_games", []) + prof.get("small_similar_games", [])))
    searches = []
    for g in prof.get("similar_games", []):
        searches.append((g, SP_VIDEO_YEAR, "played " + g))
    for g in prof.get("small_similar_games", []):
        searches.append((g, SP_VIDEO, "played " + g))
    for q in prof.get("topic_queries", []):
        searches.append((q, SP_VIDEO_MONTH, "topic: " + q))
    for q in prof.get("channel_queries", []):
        searches.append((q, SP_CHANNEL, "channel search: " + q))
    if args.max_searches:
        searches = searches[:args.max_searches]

    found = {}
    for i, (q, sp, label) in enumerate(searches, 1):
        n = 0
        for kind, it in search(q, sp, args.pages):
            cid = it["channel_id"]
            if not cid or cid in exclude:
                continue
            c = found.setdefault(cid, {"channel_id": cid, "channel": it["channel"], "found_via": [], "found_titles": [], "search_subs": None})
            if label not in c["found_via"]:
                c["found_via"].append(label)
            if kind == "video" and it["title"] not in c["found_titles"]:
                c["found_titles"].append(it["title"])
            if kind == "channel" and it.get("subs") is not None:
                c["search_subs"] = it["subs"]
            n += 1
        log(f"[{i}/{len(searches)}] {label}: {n} hits, {len(found)} channels so far")

    cache = json.load(open(args.cache)) if os.path.exists(args.cache) else {}
    # Channels whose subscriber count we already know from channel search and is out of range can be skipped.
    todo = [c for c in found.values() if c["search_subs"] is None or lo <= c["search_subs"] <= hi]
    # Open the most-found channels first, so a capped run still gets the best leads.
    todo.sort(key=lambda c: -len(c["found_via"]))
    if args.max_channels:
        todo = todo[:args.max_channels]
    log(f"Opening {len(todo)} of {len(found)} channels")

    rows = []
    for i, c in enumerate(todo, 1):
        cid = c["channel_id"]
        if cid in cache:
            info = cache[cid]
        else:
            info = channel_about(cid, lo, hi)
            info["videos"] = []
            if info.get("subs") is not None and lo <= info["subs"] <= hi:
                for tab in ("Videos", "Live"):
                    if tab in info["tabs"]:
                        info["videos"] += channel_videos(cid, info["tabs"][tab])
                info["videos"].sort(key=lambda v: v["age_days"] if v.get("age_days") is not None else 99999)
            cache[cid] = info
            if i % 25 == 0:
                json.dump(cache, open(args.cache, "w"))
        subs = info.get("subs")
        if subs is None or not (lo <= subs <= hi):
            continue
        ch = {**c, **{k: v for k, v in info.items() if k != "tabs"}}
        ages = [v["age_days"] for v in ch["videos"] if v.get("age_days") is not None]
        if not ages or min(ages) > active_days:
            continue
        titles = [v["title"] for v in ch["videos"]] + [ch.get("description", "")]
        ch["english"] = round(englishness(titles), 2)
        if prof.get("english_only", True) and ch["english"] < prof.get("min_english", 0.25):
            continue
        emails = sorted(set(e.rstrip(".") for e in EMAIL_RE.findall(ch.get("description", ""))))
        ch["emails"] = " ".join(emails)
        for kind, pat in LINK_KINDS:
            ch[kind] = next((l for l in ch.get("links", []) if re.search(pat, l, re.I)), "")
        ch["website"] = next((l for l in ch.get("links", []) if not any(re.search(p, l, re.I) for _, p in LINK_KINDS)
                              and "youtube.com" not in l and "steam" not in l), "")
        score(ch, prof, game_names)
        if ch["fit_score"] < prof.get("min_fit", 0):
            continue
        ch["url"] = f"https://www.youtube.com/channel/{cid}"
        ch["about_url"] = (f"https://www.youtube.com/{ch['handle']}/about" if ch.get("handle") else ch["url"] + "/about")
        rows.append(ch)
        if i % 20 == 0:
            log(f"  opened {i}/{len(todo)}, {len(rows)} kept")
    json.dump(cache, open(args.cache, "w"))

    rows.sort(key=lambda r: -r["fit_score"])
    json.dump({"profile": prof, "searches": len(searches), "channels_seen": len(found), "rows": rows},
              open(args.out + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    cols = ["fit_score", "channel", "handle", "subs", "last_upload_days", "uploads_90d", "median_views", "views_per_sub",
            "played", "fit_reasons", "emails", "business_email", "x", "bluesky", "discord", "twitch", "tiktok", "instagram",
            "website", "country", "english", "url", "about_url", "latest_videos", "found_via"]
    with open(args.out + ".csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for r in rows:
            r2 = {**r, "latest_videos": " | ".join(v["title"] for v in r["videos"][:5]), "found_via": "; ".join(r["found_via"]),
                  "business_email": "yes" if r.get("business_email") else ""}
            w.writerow([r2.get(c, "") if r2.get(c) is not None else "" for c in cols])
    log(f"Kept {len(rows)} channels ({sum(1 for r in rows if r['emails'])} with an email in the description, "
        f"{sum(1 for r in rows if r.get('business_email'))} with an email behind YouTube's sign-in). Wrote {args.out}.csv/.json")


if __name__ == "__main__":
    main()
