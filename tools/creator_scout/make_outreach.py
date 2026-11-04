#!/usr/bin/env python3
"""Build the creator review page from the JSON that find_creators.py wrote.

    python3 make_outreach.py results.json outreach.html --top 300 --write-queue queue.txt

Each day the page shows a few channels (best fit first) with their recent
videos and every way to reach them. You check the channel, paste the email
from its About page, adjust the one line about their video, and Approve.
Approved creators feed the daily send job (send_daily.py); the page itself
never sends anything and never holds Steam keys. Status lives in the
artifact's database (collection "creators") when published with `db`.
"""
import argparse
import html as _html
import json
import re

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--top", type=int, default=300)
ap.add_argument("--write-queue", help="save the chosen channel ids here (feed it to fetch_avatars.py)")
args = ap.parse_args()

data = json.load(open(args.src, encoding="utf-8"))
prof = data.get("profile") or {}
o = prof.get("outreach") or {}
rows = [r for r in data["rows"] if r.get("emails") or r.get("business_email") or r.get("x") or r.get("bluesky") or r.get("discord")]
rows = rows[:args.top]
if args.write_queue:
    open(args.write_queue, "w").write("\n".join(r["channel_id"] for r in rows) + "\n")


def creator_name(r):
    t = re.split(r"\s+[-|–—:]\s+", r.get("title") or r.get("channel") or "")[0].strip()
    return t or r.get("channel") or "there"


def best_video(r, games):
    vids = r.get("videos") or []
    for v in vids:
        if any(g.lower() in v["title"].lower() for g in games):
            return v
    for t in r.get("found_titles") or []:
        if any(g.lower() in t.lower() for g in games):
            return {"title": t, "video_id": None}
    return vids[0] if vids else None


queue = []
for r in rows:
    played = [g.strip() for g in (r.get("played") or "").split(",") if g.strip()]
    v = best_video(r, played)
    title = re.sub(r"\s+", " ", v["title"]).strip() if v else ""
    queue.append({
        "id": r["channel_id"], "name": r.get("title") or r.get("channel"), "creator": creator_name(r),
        "handle": r.get("handle", ""), "subs": r.get("subs"), "last": r.get("last_upload_days"),
        "uploads90": r.get("uploads_90d"), "median": r.get("median_views"), "fit": r.get("fit_score"),
        "why": r.get("fit_reasons", ""), "played": r.get("played", ""), "country": r.get("country", ""),
        "url": r.get("url"), "about": r.get("about_url"), "emails": r.get("emails", ""),
        "bizEmail": bool(r.get("business_email")),
        "links": {k: r.get(k) for k in ("x", "bluesky", "discord", "twitch", "tiktok", "instagram", "website") if r.get(k)},
        "desc": (r.get("description") or "")[:260],
        "videos": [{"t": x["title"], "id": x.get("video_id"), "views": x.get("views"), "age": x.get("age_days")} for x in (r.get("videos") or [])[:5]],
        "line": f'I came across your video "{title}".' if title else "I came across your channel.",
    })
payload = json.dumps(queue, ensure_ascii=False).replace("</", "<\\/")
CFG = json.dumps({"title": o.get("title") or "Creator Outreach",
                  "subject": o.get("subject") or "Steam key for you",
                  "example": o.get("personal_example") or ""}, ensure_ascii=False).replace("</", "<\\/")

PAGE = r"""<title>__TITLE__</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bungee&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: today's channels as wide cards (channel facts left, approval form right), then the approved queue and the log */
:root {
  --bg: #f1eff4; --panel: #ffffff; --ink: #17151c; --muted: #625d6e; --line: #dcd8e3;
  --accent: #5b2bd6; --accent-soft: #ece5fd; --hot: #c2410c; --hot-soft: #fdeadf; --ok: #15803d; --ok-soft: #dcf3e3; --yt: #d22a2a;
  --display: "Bungee", "Arial Black", Impact, sans-serif;
  --body: "IBM Plex Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Menlo, Consolas, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #131118; --panel: #1c1a23; --ink: #ebe8f0; --muted: #a09aab; --line: #2e2a37;
  --accent: #a58bff; --accent-soft: #2c2350; --hot: #fb923c; --hot-soft: #3a2416; --ok: #4ade80; --ok-soft: #173322; --yt: #ff6b6b; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #131118; --panel: #1c1a23; --ink: #ebe8f0; --muted: #a09aab; --line: #2e2a37;
  --accent: #a58bff; --accent-soft: #2c2350; --hot: #fb923c; --hot-soft: #3a2416; --ok: #4ade80; --ok-soft: #173322; --yt: #ff6b6b; color-scheme: dark }
body { background: var(--bg); color: var(--ink); font-family: var(--body); font-size: 15px; line-height: 1.45;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 0 56px; }
.wrap { max-width: 1060px; margin: 0 auto; display: grid; gap: 22px; }
header { padding-block: 28px 0; display: flex; flex-wrap: wrap; gap: 12px 24px; align-items: end; justify-content: space-between; }
h1 { font-family: var(--display); font-weight: 400; font-size: 2rem; margin: 0; line-height: 1.05; text-wrap: balance; }
.date { font-family: var(--mono); color: var(--muted); font-size: .85rem; margin-top: 6px; }
.tally { display: flex; flex-wrap: wrap; gap: 8px; }
.tally span { font-family: var(--mono); font-size: .8rem; padding: 6px 10px; border-radius: 6px; background: var(--panel); border: 1px solid var(--line); font-variant-numeric: tabular-nums; }
.tally b { font-weight: 500; }
.progress { height: 8px; border-radius: 99px; background: var(--line); overflow: hidden; }
.progress i { display: block; height: 100%; background: var(--accent); width: 0; transition: width .3s; }
h2 { font-size: .78rem; text-transform: uppercase; letter-spacing: .1em; color: var(--muted); margin: 0 0 10px; font-weight: 600; }
.lead { font-size: .88rem; color: var(--muted); margin: -4px 0 12px; max-width: 70ch; }
#today { display: grid; gap: 16px; }
.card { display: grid; grid-template-columns: minmax(0, 360px) minmax(0, 1fr); gap: 22px; background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 18px; }
.who { display: grid; gap: 10px; align-content: start; min-width: 0; }
.head { display: flex; gap: 12px; align-items: center; min-width: 0; }
.av { width: 64px; height: 64px; border-radius: 50%; flex: none; background: var(--accent-soft); overflow: hidden; display: grid; place-items: center; font-family: var(--display); color: var(--accent); font-size: 1.4rem; }
.av img { width: 100%; height: 100%; object-fit: cover; display: block; }
.cname { font-weight: 600; font-size: 1.12rem; color: var(--ink); text-decoration: none; overflow-wrap: anywhere; }
.cname:hover { color: var(--accent); text-decoration: underline; }
.handle { font-family: var(--mono); font-size: .78rem; color: var(--muted); }
.stats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 6px; }
.stats div { background: var(--bg); border-radius: 6px; padding: 6px 8px; display: grid; }
.stats b { font-family: var(--mono); font-weight: 500; font-size: .95rem; font-variant-numeric: tabular-nums; }
.stats span { font-size: .68rem; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }
.fit { font-family: var(--display); color: var(--hot); }
.played { font-size: .82rem; padding: 6px 9px; border-radius: 6px; background: var(--hot-soft); color: var(--hot); }
.why { font-size: .8rem; color: var(--muted); }
.desc { font-size: .8rem; color: var(--muted); font-style: italic; overflow-wrap: anywhere; }
.vids { display: grid; gap: 4px; margin: 0; padding: 0; list-style: none; }
.vids li { font-size: .82rem; display: flex; gap: 8px; min-width: 0; }
.vids a { color: var(--ink); text-decoration: none; flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.vids a:hover { color: var(--yt); text-decoration: underline; }
.vids small { font-family: var(--mono); color: var(--muted); font-size: .72rem; white-space: nowrap; font-variant-numeric: tabular-nums; }
.links { display: flex; flex-wrap: wrap; gap: 6px; }
.links a { font-size: .78rem; padding: 3px 8px; border-radius: 4px; border: 1px solid var(--line); color: var(--ink); text-decoration: none; }
.links a:hover { border-color: var(--accent); color: var(--accent); }
.links a.yt { border-color: var(--yt); color: var(--yt); }
.pitch { display: grid; gap: 12px; min-width: 0; align-content: start; }
.field { display: grid; gap: 4px; }
.field label, .lbl { font-size: .72rem; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); font-weight: 600; }
.hint { font-size: .78rem; color: var(--muted); }
.hint a { color: var(--accent); }
input[type=text], input[type=email], textarea, select { font: inherit; color: var(--ink); background: var(--bg); border: 1px solid var(--line); border-radius: 6px; padding: 7px 10px; width: 100%; box-sizing: border-box; }
textarea { min-height: 64px; resize: vertical; }
.preview { font-size: .86rem; padding: 10px 12px; border: 1px dashed var(--line); border-radius: 6px; background: var(--bg); white-space: pre-wrap; }
.preview b { color: var(--accent); }
button { font: inherit; font-size: .85rem; cursor: pointer; border-radius: 6px; padding: 7px 12px; border: 1px solid var(--line); background: var(--panel); color: var(--ink); white-space: nowrap; }
button:hover { border-color: var(--accent); }
button.primary { background: var(--accent); border-color: var(--accent); color: var(--panel); font-weight: 600; }
button.small { font-size: .75rem; padding: 4px 9px; }
button:disabled { opacity: .5; cursor: not-allowed; }
button:focus-visible, a:focus-visible, input:focus-visible, textarea:focus-visible, select:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.actions { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.done { text-align: center; padding: 36px 16px; background: var(--panel); border: 1px dashed var(--line); border-radius: 10px; display: grid; gap: 10px; justify-items: center; }
.done strong { font-family: var(--display); font-weight: 400; font-size: 1.3rem; }
details { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 14px 18px; }
summary { cursor: pointer; font-weight: 600; }
.log { width: 100%; border-collapse: collapse; font-size: .85rem; }
.log td, .log th { text-align: left; padding: 7px 8px; border-bottom: 1px solid var(--line); vertical-align: middle; }
.log th { font-size: .72rem; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); font-weight: 600; }
.log td.d { font-family: var(--mono); font-size: .78rem; color: var(--muted); white-space: nowrap; }
.log a { color: var(--ink); }
.tbl { overflow-x: auto; margin-top: 12px; }
.note { font-size: .8rem; color: var(--muted); }
.warn { font-size: .85rem; padding: 10px 12px; border-radius: 6px; background: var(--hot-soft); color: var(--hot); }
@media (max-width: 760px) { .card { grid-template-columns: 1fr; } h1 { font-size: 1.6rem; } .stats { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
</style>
<div class="wrap">
  <header>
    <div><h1>__TITLE__</h1><div class="date" id="date"></div></div>
    <div class="tally" id="tally"></div>
  </header>
  <div class="progress" aria-hidden="true"><i id="bar"></i></div>
  <div id="storeWarn" class="warn" hidden>Progress is only being saved in this browser right now, because the page couldn't reach its shared storage.</div>
  <section>
    <h2>Today's channels</h2>
    <p class="lead">Open the channel's About page, click View email address (YouTube asks you to sign in), paste it here and approve. Approved creators get the Steam key email from the daily send job. This page never sends anything and never holds keys.</p>
    <div id="today"></div>
  </section>
  <details id="qBox">
    <summary id="qTitle">Approved queue</summary>
    <p class="note">This is the send order for the daily job. Ask Claude to sync it, or copy it into queue.json in your private outreach repo yourself.</p>
    <div class="actions" style="margin-top:10px"><button id="copyQ">Copy queue.json</button><span class="note" id="qMsg"></span></div>
    <div class="tbl"><table class="log"><thead><tr><th>Creator</th><th>Email</th><th>Approved</th><th></th></tr></thead><tbody id="qRows"></tbody></table></div>
  </details>
  <details id="logBox">
    <summary id="logTitle">Replies</summary>
    <p class="note">Once the job has sent someone's email, mark how they answered here.</p>
    <div class="tbl"><table class="log"><thead><tr><th>Creator</th><th>Email</th><th>Status</th></tr></thead><tbody id="log"></tbody></table></div>
  </details>
  <details>
    <summary>Daily goal</summary>
    <div class="field" style="margin-top:12px;max-width:220px"><label for="perDay">Channels to review per day</label>
      <select id="perDay"><option>3</option><option>5</option><option>8</option><option>10</option><option>15</option></select></div>
  </details>
</div>
<script>
const QUEUE = __QUEUE__;
const CFG = __CONFIG__;
const $ = id => document.getElementById(id);
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const todayKey = () => { const d = new Date(); return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); };
const ago = d => d == null ? "?" : d === 0 ? "today" : d < 7 ? d + "d ago" : d < 60 ? Math.round(d / 7) + "w ago" : Math.round(d / 30) + "mo ago";
const num = n => n == null ? "?" : n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "K" : String(n);
const LINKS = { x: "X", bluesky: "Bluesky", discord: "Discord", twitch: "Twitch", tiktok: "TikTok", instagram: "Instagram", website: "Website" };

// status: { [channelId]: {status: approved|skipped|sent|replied|yes|no, date, email, line, creator} }
let status = {}, settings = { perDay: 5 };
const drafts = {};
let db = null, extra = 0;
function lsGet(k, d) { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch (e) { return d; } }
function lsSet(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
Object.assign(drafts, lsGet("cs-drafts", {}));

const draft = c => ({ email: (c.emails || "").split(" ")[0] || "", line: c.line, creator: c.creator, ...(drafts[c.id] || {}) });
const validEmail = e => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e || "");

function picks() {
  const today = todayKey();
  const doneToday = Object.values(status).filter(s => s.date === today).length;
  const pending = QUEUE.filter(c => !status[c.id]);
  const room = Math.max(0, settings.perDay - doneToday) + extra;
  return { doneToday, pending, list: pending.slice(0, room) };
}

function previewHtml(c) {
  const d = draft(c);
  return `Hey <b>${esc(d.creator || "there")}</b>,\n\nI came across your youtube channel, and thought i would reach out. I made a little painting game and thought it might be your kind of thing, so here's a free Steam key. No strings attached: play it if it looks fun, and no need to make a video if it's not for you.\n\n[banner, game blurb, links, Steam key, screenshots]`;
}

function cardHtml(c) {
  const d = draft(c);
  const links = `<a class="yt" href="${esc(c.url)}" target="_blank" rel="noopener">Channel</a><a class="yt" href="${esc(c.about)}" target="_blank" rel="noopener">About page${c.bizEmail ? " (has email)" : ""}</a>` +
    Object.entries(c.links).map(([k, u]) => `<a href="${esc(u)}" target="_blank" rel="noopener">${LINKS[k] || k}</a>`).join("");
  const vids = c.videos.map(v => `<li><a href="${v.id ? "https://www.youtube.com/watch?v=" + esc(v.id) : esc(c.url)}" target="_blank" rel="noopener" title="${esc(v.t)}">${esc(v.t)}</a><small>${num(v.views)} views · ${ago(v.age)}</small></li>`).join("");
  const emailHint = c.emails ? `Found in their channel description.` : c.bizEmail
    ? `Their email is behind YouTube's <a href="${esc(c.about)}" target="_blank" rel="noopener">View email address</a> button on the About page.`
    : `No email listed. Try their links, or skip.`;
  return `<article class="card" data-id="${esc(c.id)}">
    <div class="who">
      <div class="head"><div class="av"><img src="thumbs/${esc(c.id)}.jpg" alt="" loading="lazy" onerror="this.remove()"><span aria-hidden="true">${esc((c.name || "?").trim()[0] || "?")}</span></div>
        <div style="min-width:0"><a class="cname" href="${esc(c.url)}" target="_blank" rel="noopener">${esc(c.name)}</a><div class="handle">${esc(c.handle)}${c.country ? " · " + esc(c.country) : ""}</div></div></div>
      <div class="stats"><div><b>${num(c.subs)}</b><span>subs</span></div><div><b>${ago(c.last)}</b><span>last upload</span></div><div><b>${num(c.median)}</b><span>median views</span></div><div><b class="fit">${c.fit}</b><span>fit</span></div></div>
      ${c.played ? `<div class="played">Played games like yours: ${esc(c.played)}</div>` : ""}
      ${c.why ? `<div class="why">${esc(c.why)}</div>` : ""}
      <ul class="vids">${vids}</ul>
      ${c.desc ? `<div class="desc">${esc(c.desc)}${c.desc.length >= 260 ? "…" : ""}</div>` : ""}
      <div class="links">${links}</div>
    </div>
    <div class="pitch">
      <div class="field"><label for="em-${esc(c.id)}">Their email</label>
        <input type="email" id="em-${esc(c.id)}" data-f="email" value="${esc(d.email)}" placeholder="paste it from their About page">
        <span class="hint">${emailHint}</span></div>
      <div class="field"><label for="cr-${esc(c.id)}">Call them</label>
        <input type="text" id="cr-${esc(c.id)}" data-f="creator" value="${esc(d.creator)}"></div>
      <div class="field"><span class="lbl">Email opens with</span><div class="preview" data-prev>${previewHtml(c)}</div></div>
      <div class="actions">
        <span style="flex:1"></span>
        <button data-act="skipped">Skip</button>
        <button class="primary" data-act="approved" ${validEmail(d.email) ? "" : "disabled"}>Approve for sending</button>
      </div>
    </div></article>`;
}

function render() {
  const { doneToday, pending, list } = picks();
  const all = Object.values(status);
  const approved = all.filter(s => s.status === "approved").length;
  const sent = all.filter(s => ["sent", "replied", "yes", "no"].includes(s.status)).length;
  const yes = all.filter(s => s.status === "yes").length;
  $("date").textContent = new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });
  $("tally").innerHTML = `<span><b>${doneToday}</b> / ${settings.perDay} reviewed today</span><span><b>${approved}</b> approved, waiting</span><span><b>${sent}</b> sent</span><span><b>${yes}</b> said yes</span><span><b>${pending.length}</b> left to review</span>`;
  $("bar").style.width = Math.min(100, 100 * doneToday / settings.perDay) + "%";
  $("today").innerHTML = list.length ? list.map(cardHtml).join("") : (pending.length
    ? `<div class="done"><strong>Done for today</strong><span class="note">${doneToday} reviewed. Come back tomorrow for the next ${settings.perDay}.</span><button id="more">Show one more</button></div>`
    : `<div class="done"><strong>Nobody left to review</strong><span class="note">Every channel in the list has been handled. Ask Claude for a fresh search.</span></div>`);
  const more = $("more"); if (more) more.onclick = () => { extra++; render(); };

  const byId = id => QUEUE.find(q => q.id === id) || { name: id, url: "https://www.youtube.com/channel/" + id };
  const q = Object.entries(status).filter(([, s]) => s.status === "approved").sort((a, b) => (a[1].date || "").localeCompare(b[1].date || ""));
  $("qTitle").textContent = `Approved queue (${q.length})`;
  $("qRows").innerHTML = q.length ? q.map(([id, s]) => `<tr><td><a href="${esc(byId(id).url)}" target="_blank" rel="noopener">${esc(byId(id).name)}</a></td><td class="d">${esc(s.email)}</td><td class="d">${esc(s.date)}</td><td><button class="small" data-undo="${esc(id)}">Undo</button></td></tr>`).join("")
    : `<tr><td colspan="4" class="note">Nobody approved yet.</td></tr>`;
  const sentRows = Object.entries(status).filter(([, s]) => ["sent", "replied", "yes", "no"].includes(s.status));
  $("logTitle").textContent = `Replies (${sentRows.length})`;
  $("log").innerHTML = sentRows.length ? sentRows.map(([id, s]) => `<tr><td><a href="${esc(byId(id).url)}" target="_blank" rel="noopener">${esc(byId(id).name)}</a></td><td class="d">${esc(s.email)}</td>
    <td><select data-status="${esc(id)}" aria-label="Status for ${esc(byId(id).name)}">${["sent", "replied", "yes", "no"].map(v => `<option value="${v}" ${v === s.status ? "selected" : ""}>${{ sent: "Sent, waiting", replied: "Replied", yes: "Will cover it", no: "Not interested" }[v]}</option>`).join("")}</select></td></tr>`).join("")
    : `<tr><td colspan="3" class="note">Nothing sent yet. Sent emails show up here after Claude syncs the send log.</td></tr>`;
}

async function save(id, rec) {
  status = { ...status, [id]: rec };
  lsSet("cs-status", status); render();
  if (db) { try { rec === null ? await db.collection("creators").doc(id).delete() : await db.collection("creators").doc(id).set(rec); } catch (e) { $("storeWarn").hidden = false; } }
}

document.addEventListener("click", e => {
  const card = e.target.closest(".card");
  const act = e.target.closest("[data-act]");
  if (act && card && !act.disabled) {
    const c = QUEUE.find(q => q.id === card.dataset.id), d = draft(c);
    if (extra) extra--;
    save(c.id, act.dataset.act === "approved"
      ? { status: "approved", date: todayKey(), email: d.email.trim(), line: d.line.trim(), creator: d.creator.trim() }
      : { status: "skipped", date: todayKey() });
  }
  const undo = e.target.closest("[data-undo]");
  if (undo) { const id = undo.dataset.undo; const { [id]: _, ...rest } = status; status = rest; lsSet("cs-status", status); render(); if (db) db.collection("creators").doc(id).delete().catch(() => {}); }
  if (e.target.id === "copyQ") {
    const out = Object.entries(status).filter(([, s]) => s.status === "approved").sort((a, b) => (a[1].date || "").localeCompare(b[1].date || ""))
      .map(([id, s]) => ({ channel_id: id, creator: s.creator, email: s.email, personal_line: s.line, approved: true }));
    const text = JSON.stringify(out, null, 1);
    navigator.clipboard.writeText(text).then(() => $("qMsg").textContent = `Copied ${out.length} creators`, () => $("qMsg").textContent = "Copy was blocked here. Ask Claude to sync the queue instead.");
  }
});
document.addEventListener("input", e => {
  const f = e.target.dataset.f; if (!f) return;
  const card = e.target.closest(".card"), c = QUEUE.find(q => q.id === card.dataset.id);
  drafts[c.id] = { ...draft(c), [f]: e.target.value }; lsSet("cs-drafts", drafts);
  card.querySelector("[data-prev]").innerHTML = previewHtml(c);
  card.querySelector('[data-act="approved"]').disabled = !validEmail(draft(c).email);
});
document.addEventListener("change", e => {
  if (e.target.matches("[data-status]")) { const id = e.target.dataset.status; save(id, { ...status[id], status: e.target.value }); }
  if (e.target.id === "perDay") { settings = { ...settings, perDay: +e.target.value }; lsSet("cs-settings", settings); if (db) db.doc("settings/main").set(settings).catch(() => {}); render(); }
});

status = lsGet("cs-status", {});
settings = { ...settings, ...lsGet("cs-settings", {}) };
$("perDay").value = String(settings.perDay); render();

(async () => {
  db = window.claude ? await window.claude.use("db") : null;
  if (!db) { $("storeWarn").hidden = false; return; }
  db.collection("creators").onSnapshot(snap => {
    const next = {};
    snap.docs.forEach(d => { next[d.id] = d.data(); });
    for (const [id, rec] of Object.entries(status)) if (!next[id]) { next[id] = rec; db.collection("creators").doc(id).set(rec).catch(() => {}); }
    status = next; lsSet("cs-status", status); render();
  }, () => { $("storeWarn").hidden = false; });
  db.doc("settings/main").onSnapshot(d => { if (d.exists) { settings = { ...settings, ...d.data() }; $("perDay").value = String(settings.perDay); render(); } });
})();
setInterval(() => { if ($("date").textContent !== new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })) { extra = 0; render(); } }, 60000);
</script>
"""

page = (PAGE.replace("__TITLE__", _html.escape(json.loads(CFG)["title"]))
        .replace("__CONFIG__", CFG).replace("__QUEUE__", payload))
open(args.dst, "w", encoding="utf-8").write(page)
print(f"Wrote {args.dst} with {len(queue)} channels")
