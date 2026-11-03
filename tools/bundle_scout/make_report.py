#!/usr/bin/env python3
"""Turn the JSON from find_games.py into a filterable HTML page.

    python3 make_report.py results.json report.html
"""
import json
import sys

import html as _html

src = sys.argv[1] if len(sys.argv) > 1 else "results.json"
dst = sys.argv[2] if len(sys.argv) > 2 else "report.html"
data = json.load(open(src, encoding="utf-8"))
prof = data.get("profile") or {}
weights = data.get("weights") or {}
TITLE = _html.escape(prof.get("report_title") or "Bundle Scout")
BLURB = _html.escape(prof.get("report_blurb") or
                     f"Upcoming and recent Steam games ranked by how well they fit {prof.get('name', 'our game')}, "
                     "with every public way to reach the developer.")
top = sorted(weights.items(), key=lambda kv: -kv[1])[:6]
FOOT = (f"Fit score adds up Steam tags that match {prof.get('name', 'our game')} ("
        + ", ".join(f"{t} {w}" for t, w in top) + "...). Followers are the game's Steam community hub members, "
        "a rough wishlist proxy. Emails come from the developer's Steam support info or their website.")
HIGH = [t for t, w in weights.items() if w >= 4]
payload = json.dumps(data).replace("</", "<\\/")

PAGE = r"""<title>__TITLE__</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bungee&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: one column of game rows under a sticky filter bar, fit score on the left edge of each row */
:root {
  --bg: #eef0f2; --panel: #ffffff; --ink: #16191e; --muted: #5d6570; --line: #d7dbe0;
  --accent: #1f4fe0; --accent-soft: #e3eafd; --hot: #c2410c; --hot-soft: #fdeadf; --ok: #15803d;
  --display: "Bungee", "Arial Black", Impact, sans-serif;
  --body: "IBM Plex Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Menlo, Consolas, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #121418; --panel: #1b1e24; --ink: #e8eaee; --muted: #9aa2ad; --line: #2c3139;
  --accent: #7d9bff; --accent-soft: #23305a; --hot: #fb923c; --hot-soft: #3a2416; --ok: #4ade80; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #121418; --panel: #1b1e24; --ink: #e8eaee; --muted: #9aa2ad; --line: #2c3139;
  --accent: #7d9bff; --accent-soft: #23305a; --hot: #fb923c; --hot-soft: #3a2416; --ok: #4ade80; color-scheme: dark }
body { background: var(--bg); color: var(--ink); font-family: var(--body); font-size: 15px; line-height: 1.45;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 0 48px; }
body::before { content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--bg); }
.wrap { max-width: 980px; margin: 0 auto; }
header { padding-block: 28px 12px; display: grid; gap: 6px; }
h1 { font-family: var(--display); font-weight: 400; font-size: 2rem; margin: 0; letter-spacing: .01em; text-wrap: balance; }
.sub { color: var(--muted); max-width: 65ch; margin: 0; }
.stats { display: flex; flex-wrap: wrap; gap: 6px 18px; font-family: var(--mono); font-size: .8rem; color: var(--muted); margin-top: 4px; }
.stats b { color: var(--ink); font-weight: 500; }
.bar { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--bg); padding-block: 10px; border-bottom: 1px solid var(--line);
  display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.bar input[type=search] { flex: 1 1 220px; min-width: 0; font: inherit; padding: 8px 10px; border: 1px solid var(--line); border-radius: 6px; background: var(--panel); color: var(--ink); }
.chipbtn { font: inherit; font-size: .82rem; padding: 6px 10px; border-radius: 999px; border: 1px solid var(--line); background: var(--panel); color: var(--ink); cursor: pointer; }
.chipbtn[aria-pressed=true] { background: var(--accent); border-color: var(--accent); color: var(--panel); }
.bar select { font: inherit; font-size: .82rem; padding: 6px 8px; border-radius: 6px; border: 1px solid var(--line); background: var(--panel); color: var(--ink); }
.chipbtn:focus-visible, .bar select:focus-visible, .bar input:focus-visible, a:focus-visible, .copy:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
#list { display: grid; gap: 10px; margin-top: 14px; }
.row { display: grid; grid-template-columns: 56px 1fr; gap: 14px; background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 14px; }
.fit { font-family: var(--display); font-size: 1.5rem; line-height: 1; text-align: center; padding-top: 4px; }
.fit small { display: block; font-family: var(--mono); font-size: .62rem; color: var(--muted); letter-spacing: .08em; margin-top: 4px; }
.fit.high { color: var(--hot); }
.main { min-width: 0; display: grid; gap: 6px; }
.title { display: flex; flex-wrap: wrap; gap: 6px 10px; align-items: baseline; }
.title a { font-weight: 600; font-size: 1.05rem; color: var(--ink); text-decoration: none; }
.title a:hover { color: var(--accent); text-decoration: underline; }
.pill { font-family: var(--mono); font-size: .7rem; padding: 2px 7px; border-radius: 4px; background: var(--accent-soft); color: var(--accent); white-space: nowrap; }
.pill.demo { background: var(--hot-soft); color: var(--hot); }
.pill.new { background: var(--ok); color: var(--panel); }
.meta { font-family: var(--mono); font-size: .78rem; color: var(--muted); display: flex; flex-wrap: wrap; gap: 4px 14px; font-variant-numeric: tabular-nums; }
.meta b { color: var(--ink); font-weight: 500; }
.desc { color: var(--muted); font-size: .88rem; max-width: 70ch; }
.contacts { display: flex; flex-wrap: wrap; gap: 6px; }
.contacts a, .email { font-size: .8rem; padding: 3px 8px; border-radius: 4px; border: 1px solid var(--line); color: var(--ink); text-decoration: none; display: inline-flex; gap: 6px; align-items: center; }
.contacts a:hover { border-color: var(--accent); color: var(--accent); }
.contacts a.discord { border-color: var(--accent); }
.email { font-family: var(--mono); user-select: all; max-width: 100%; overflow-wrap: anywhere; }
.copy { font: inherit; font-size: .7rem; border: 0; background: none; color: var(--accent); cursor: pointer; padding: 0; }
.none { font-size: .8rem; color: var(--hot); }
.tags { font-size: .75rem; color: var(--muted); }
.tags .hit { color: var(--ink); font-weight: 500; }
.empty { color: var(--muted); padding: 40px 0; text-align: center; }
footer { color: var(--muted); font-size: .8rem; margin-top: 24px; max-width: 70ch; }
@media (max-width: 480px) { .row { grid-template-columns: 1fr; gap: 8px; } .fit { text-align: left; display: flex; gap: 8px; align-items: baseline; } .fit small { margin: 0; } h1 { font-size: 1.6rem; } }
</style>
<div class="wrap">
  <header>
    <h1>__TITLE__</h1>
    <p class="sub">__BLURB__</p>
    <div class="stats" id="stats"></div>
  </header>
  <div class="bar">
    <input type="search" id="q" placeholder="Search name, dev, tag" aria-label="Search">
    <button class="chipbtn" id="f-upcoming" aria-pressed="false">Upcoming only</button>
    <button class="chipbtn" id="f-demo" aria-pressed="false">Has demo</button>
    <button class="chipbtn" id="f-indie" aria-pressed="true">Self-published</button>
    <button class="chipbtn" id="f-contact" aria-pressed="false">Has contact</button>
    <select id="sort" aria-label="Sort by">
      <option value="fit">Sort: best fit</option>
      <option value="followers">Sort: most followers</option>
      <option value="date">Sort: release date</option>
    </select>
  </div>
  <div id="list"></div>
  <footer id="foot"></footer>
</div>
<script>
const DATA = __DATA__;
const rows = DATA.rows;
const $ = id => document.getElementById(id);
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const LINKS = [["discord","Discord"],["x","X"],["bluesky","Bluesky"],["itch","itch.io"],["youtube","YouTube"],["tiktok","TikTok"],["instagram","Instagram"],["presskit","Press kit"],["website","Website"],["support_url","Support page"]];
const HIGH = __HIGH__;
function emails(r) { return [...new Set([r.support_email, ...(r.website_emails || "").split(" ")].filter(Boolean))]; }
function hasContact(r) { return emails(r).length || LINKS.some(([k]) => r[k] && k !== "website" && k !== "support_url"); }
function dateVal(r) { const t = Date.parse(r.release); return isNaN(t) ? Infinity : t; }
const state = { q: "", upcoming: false, demo: false, indie: true, contact: false, sort: "fit" };
try { Object.assign(state, JSON.parse(localStorage.getItem("bundle-scout") || "{}")); } catch (e) {}
function save() { try { localStorage.setItem("bundle-scout", JSON.stringify(state)); } catch (e) {} }
function render() {
  const q = state.q.toLowerCase();
  let list = rows.filter(r =>
    (!q || [r.name, r.developer, r.publisher, r.tags].join(" ").toLowerCase().includes(q)) &&
    (!state.upcoming || r.released === "no") && (!state.demo || r.has_demo === "yes") &&
    (!state.indie || r.self_published === "yes") && (!state.contact || hasContact(r)));
  const by = { fit: (a, b) => b.fit_score - a.fit_score || (b.followers || 0) - (a.followers || 0),
               followers: (a, b) => (b.followers || 0) - (a.followers || 0),
               date: (a, b) => dateVal(a) - dateVal(b) };
  list.sort(by[state.sort]);
  $("list").innerHTML = list.length ? list.map(r => {
    const em = emails(r);
    const links = LINKS.filter(([k]) => r[k]).map(([k, label]) => `<a class="${k}" href="${esc(r[k])}" target="_blank" rel="noopener">${label}</a>`).join("");
    const mails = em.map(e => `<span class="email">${esc(e)} <button class="copy" data-copy="${esc(e)}">copy</button></span>`).join("");
    const tags = (r.tags || "").split(", ").filter(Boolean).map(t => HIGH.includes(t) ? `<span class="hit">${esc(t)}</span>` : esc(t)).join(", ");
    return `<article class="row">
      <div class="fit ${r.fit_score >= 20 ? "high" : ""}">${r.fit_score}<small>FIT</small></div>
      <div class="main">
        <div class="title"><a href="${esc(r.store_url)}" target="_blank" rel="noopener">${esc(r.name)}</a>
          ${r.new ? '<span class="pill new">NEW</span>' : ""}
          ${r.has_demo === "yes" ? '<span class="pill demo">demo</span>' : ""}
          <span class="pill">${r.released === "no" ? "upcoming" : "released"}</span></div>
        <div class="meta"><span>${esc(r.release || "TBA")}</span><span><b>${(r.followers ?? "?").toLocaleString()}</b> followers</span>
          ${r.wishlist_rank ? `<span>wishlist rank <b>#${r.wishlist_rank}</b></span>` : ""}
          ${r.reviews !== "" && r.reviews != null ? `<span><b>${r.reviews}</b> reviews</span>` : ""}
          <span>by <b>${esc(r.developer || "?")}</b>${r.publisher && r.publisher !== r.developer ? ` · pub ${esc(r.publisher)}` : ""}</span></div>
        ${r.short_description ? `<div class="desc">${esc(r.short_description)}</div>` : ""}
        <div class="contacts">${mails}${links}${!em.length && !links ? '<span class="none">No public contact found</span>' : ""}</div>
        ${tags ? `<div class="tags">${tags}</div>` : ""}
      </div></article>`;
  }).join("") : '<p class="empty">No games match these filters. Try turning one off.</p>';
  const withContact = rows.filter(hasContact).length;
  $("stats").innerHTML = `<span><b>${rows.length}</b> games scanned</span><span><b>${list.length}</b> shown</span>
    <span><b>${rows.filter(r => r.has_demo === "yes").length}</b> with a demo</span>
    <span><b>${withContact}</b> with a direct contact</span><span>updated <b>${esc(DATA.generated)}</b></span>`;
}
for (const k of ["upcoming", "demo", "indie", "contact"]) {
  const b = $("f-" + k); b.setAttribute("aria-pressed", state[k]);
  b.onclick = () => { state[k] = !state[k]; b.setAttribute("aria-pressed", state[k]); save(); render(); };
}
$("q").value = state.q; $("q").oninput = e => { state.q = e.target.value; save(); render(); };
$("sort").value = state.sort; $("sort").onchange = e => { state.sort = e.target.value; save(); render(); };
$("list").addEventListener("click", e => {
  const b = e.target.closest(".copy"); if (!b) return;
  navigator.clipboard.writeText(b.dataset.copy).then(() => { b.textContent = "copied"; }, () => {
    const r = document.createRange(); r.selectNodeContents(b.parentNode); const s = getSelection(); s.removeAllRanges(); s.addRange(r); });
});
$("foot").textContent = __FOOT__;
render();
</script>
"""

page = (PAGE.replace("__TITLE__", TITLE).replace("__BLURB__", BLURB).replace("__HIGH__", json.dumps(HIGH))
        .replace("__FOOT__", json.dumps(FOOT).replace("</", "<\\/")).replace("__DATA__", payload))
open(dst, "w", encoding="utf-8").write(page)
print(f"Wrote {dst}")
