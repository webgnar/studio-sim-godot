#!/usr/bin/env python3
"""Build the daily outreach page from the JSON that find_games.py wrote.

    python3 make_outreach.py results.json outreach.html            # top 250 games that have an email
    python3 make_outreach.py results.json outreach.html queue.txt  # or your own order of appids

The page shows a few games to email each day (best fit first), with the
Steam header image (thumbs/<appid>.jpg, published next to the page), contact
links and the bundle pitch filled in. The pitch comes from the "outreach"
part of the profile. Sent/skipped status lives in the artifact's database,
so nothing here sends email.
"""
import argparse
import json

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("queue", nargs="?", help="file of appids in the order to email them")
ap.add_argument("--top", type=int, default=250, help="without a queue file: how many games to queue")
ap.add_argument("--write-queue", help="also save the chosen order here (feed it to fetch_thumbs.py)")
args = ap.parse_args()

data = json.load(open(args.src, encoding="utf-8"))
rows = {r["appid"]: r for r in data["rows"]}
if args.queue:
    order = [int(a) for a in open(args.queue).read().split() if a.isdigit()]
else:
    ranked = sorted(data["rows"], key=lambda r: (r.get("fit_score") or 0, r.get("followers") or 0), reverse=True)
    order = [r["appid"] for r in ranked if r.get("support_email") or r.get("website_emails")][:args.top]
if args.write_queue:
    open(args.write_queue, "w").write("\n".join(map(str, order)) + "\n")
keep = ["appid", "name", "release", "released", "developer", "publisher", "fit_score", "fit_tags", "followers",
        "has_demo", "support_email", "website_emails", "discord", "x", "bluesky", "itch", "website", "store_url",
        "short_description"]
queue = [{k: rows[a].get(k, "") for k in keep} for a in order if a in rows]
payload = json.dumps(queue).replace("</", "<\\/")

prof = data.get("profile") or {}
o = prof.get("outreach") or {}
game = o.get("game") or prof.get("name") or "my game"
store = f"https://store.steampowered.com/app/{prof['our_appid']}/" if prof.get("our_appid") else ""
intro = o.get("intro") or f"I'm the dev of {game}, coming to Steam soon:"
contact = o.get("contact") or "just reply"
signature = o.get("signature") or game
body = o.get("body") or f"""Hey {{dev}},

{intro} {store}

I came across {{game}} and {{liked}}. I think our audience could overlap, so I wanted to ask if you'd be down to Steam bundle together.

How it works on Steam: I create the bundle in Steamworks, you add your game's package to it, I lock the bundle, you approve it, and I hit publish. Steam splits the revenue automatically by each game's price, so no money changes hands between us. Players who own one game get a "complete the set" discount on the other, and both store pages show the bundle.

I'm happy to do the setup. If you're interested, {contact} and we can sort out the discount together. If now isn't a good time, no worries at all.

{{signoff}}

{signature}"""
CONFIG = json.dumps({
    "title": o.get("title") or f"{game} Outreach",
    "game": game,
    "subject": o.get("subject") or "Steam bundle with {game}?",
    "body": body,
    "liked_example": o.get("liked_example") or "e.g. love the art style in the trailer",
}).replace("</", "<\\/")

PAGE = r"""<title>__TITLE__</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bungee&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: today's picks as large cards (image left, pitch right), then the template and the sent log */
:root {
  --bg: #eef0f2; --panel: #ffffff; --ink: #16191e; --muted: #5d6570; --line: #d7dbe0;
  --accent: #1f4fe0; --accent-soft: #e3eafd; --hot: #c2410c; --hot-soft: #fdeadf; --ok: #15803d; --ok-soft: #dcf3e3;
  --display: "Bungee", "Arial Black", Impact, sans-serif;
  --body: "IBM Plex Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Menlo, Consolas, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #121418; --panel: #1b1e24; --ink: #e8eaee; --muted: #9aa2ad; --line: #2c3139;
  --accent: #7d9bff; --accent-soft: #23305a; --hot: #fb923c; --hot-soft: #3a2416; --ok: #4ade80; --ok-soft: #173322; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #121418; --panel: #1b1e24; --ink: #e8eaee; --muted: #9aa2ad; --line: #2c3139;
  --accent: #7d9bff; --accent-soft: #23305a; --hot: #fb923c; --hot-soft: #3a2416; --ok: #4ade80; --ok-soft: #173322; color-scheme: dark }
body { background: var(--bg); color: var(--ink); font-family: var(--body); font-size: 15px; line-height: 1.45;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 0 56px; }
.wrap { max-width: 1040px; margin: 0 auto; display: grid; gap: 22px; }
header { padding-block: 28px 0; display: flex; flex-wrap: wrap; gap: 12px 24px; align-items: end; justify-content: space-between; }
h1 { font-family: var(--display); font-weight: 400; font-size: 2rem; margin: 0; line-height: 1.05; }
.date { font-family: var(--mono); color: var(--muted); font-size: .85rem; margin-top: 6px; }
.tally { display: flex; flex-wrap: wrap; gap: 8px; }
.tally span { font-family: var(--mono); font-size: .8rem; padding: 6px 10px; border-radius: 6px; background: var(--panel); border: 1px solid var(--line); font-variant-numeric: tabular-nums; }
.tally b { font-weight: 500; }
.progress { height: 8px; border-radius: 99px; background: var(--line); overflow: hidden; }
.progress i { display: block; height: 100%; background: var(--accent); width: 0; transition: width .3s; }
h2 { font-size: .78rem; text-transform: uppercase; letter-spacing: .1em; color: var(--muted); margin: 0 0 10px; font-weight: 600; }
#today { display: grid; gap: 16px; }
.card { display: grid; grid-template-columns: minmax(0, 320px) minmax(0, 1fr); gap: 20px; background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 18px; }
.shot { display: grid; gap: 10px; align-content: start; min-width: 0; }
.shot a.img { display: block; aspect-ratio: 460 / 215; max-width: 100%; border-radius: 6px; overflow: hidden; background: var(--accent-soft); }
.shot img { width: 100%; height: 100%; object-fit: cover; display: block; }
.shot .ph { width: 100%; height: 100%; display: grid; place-items: center; font-family: var(--display); color: var(--accent); padding: 12px; text-align: center; }
.gname { font-weight: 600; font-size: 1.15rem; color: var(--ink); text-decoration: none; }
.gname:hover { color: var(--accent); text-decoration: underline; }
.facts { font-family: var(--mono); font-size: .76rem; color: var(--muted); display: grid; gap: 2px; }
.facts b { color: var(--ink); font-weight: 500; }
.fit { display: inline-block; font-family: var(--display); color: var(--hot); font-size: 1rem; }
.why { font-size: .8rem; color: var(--muted); }
.links { display: flex; flex-wrap: wrap; gap: 6px; }
.links a { font-size: .78rem; padding: 3px 8px; border-radius: 4px; border: 1px solid var(--line); color: var(--ink); text-decoration: none; }
.links a:hover { border-color: var(--accent); color: var(--accent); }
.pitch { display: grid; gap: 10px; min-width: 0; }
.field { display: grid; gap: 4px; }
.field label, .lbl { font-size: .72rem; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); font-weight: 600; }
.line { display: flex; gap: 8px; align-items: center; min-width: 0; }
.line .val { flex: 1; min-width: 0; font-family: var(--mono); font-size: .85rem; padding: 7px 10px; border: 1px solid var(--line); border-radius: 6px; background: var(--bg); overflow-wrap: anywhere; user-select: all; }
input[type=text], textarea, select { font: inherit; color: var(--ink); background: var(--bg); border: 1px solid var(--line); border-radius: 6px; padding: 7px 10px; width: 100%; box-sizing: border-box; }
.liked { background: var(--hot-soft); border-color: var(--hot); }
.body { white-space: pre-wrap; font-size: .88rem; padding: 10px 12px; border: 1px solid var(--line); border-radius: 6px; background: var(--bg); max-height: 260px; overflow: auto; }
.body mark { background: var(--hot-soft); color: var(--hot); padding: 0 2px; border-radius: 2px; }
button { font: inherit; font-size: .85rem; cursor: pointer; border-radius: 6px; padding: 7px 12px; border: 1px solid var(--line); background: var(--panel); color: var(--ink); white-space: nowrap; }
button:hover { border-color: var(--accent); }
button.primary { background: var(--accent); border-color: var(--accent); color: var(--panel); font-weight: 600; }
button.small { font-size: .75rem; padding: 4px 9px; }
button:focus-visible, a:focus-visible, input:focus-visible, textarea:focus-visible, select:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.actions { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.actions .mail { font-size: .8rem; color: var(--accent); }
.done { text-align: center; padding: 36px 16px; background: var(--panel); border: 1px dashed var(--line); border-radius: 10px; display: grid; gap: 10px; justify-items: center; }
.done strong { font-family: var(--display); font-weight: 400; font-size: 1.3rem; }
details { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 14px 18px; }
summary { cursor: pointer; font-weight: 600; }
.tpl { display: grid; gap: 10px; margin-top: 12px; }
.tpl textarea { min-height: 300px; font-family: var(--mono); font-size: .82rem; line-height: 1.5; }
.hint { font-size: .8rem; color: var(--muted); }
.hint code { font-family: var(--mono); background: var(--bg); padding: 1px 4px; border-radius: 3px; }
.log { width: 100%; border-collapse: collapse; font-size: .85rem; }
.log td, .log th { text-align: left; padding: 7px 8px; border-bottom: 1px solid var(--line); vertical-align: middle; }
.log th { font-size: .72rem; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); font-weight: 600; }
.log td.d { font-family: var(--mono); font-size: .78rem; color: var(--muted); white-space: nowrap; }
.log a { color: var(--ink); }
.tbl { overflow-x: auto; margin-top: 12px; }
.st { font-family: var(--mono); font-size: .72rem; padding: 2px 7px; border-radius: 4px; background: var(--accent-soft); color: var(--accent); }
.st.yes { background: var(--ok-soft); color: var(--ok); } .st.no, .st.skipped { background: var(--bg); color: var(--muted); } .st.replied { background: var(--hot-soft); color: var(--hot); }
.note { font-size: .8rem; color: var(--muted); }
.warn { font-size: .85rem; padding: 10px 12px; border-radius: 6px; background: var(--hot-soft); color: var(--hot); }
@media (max-width: 720px) { .card { grid-template-columns: 1fr; } h1 { font-size: 1.6rem; } }
</style>
<div class="wrap">
  <header>
    <div><h1>__TITLE__</h1><div class="date" id="date"></div></div>
    <div class="tally" id="tally"></div>
  </header>
  <div class="progress" aria-hidden="true"><i id="bar"></i></div>
  <div id="storeWarn" class="warn" hidden>Progress is only being saved in this browser right now, because the page couldn't reach its shared storage.</div>
  <section>
    <h2>Today's emails</h2>
    <div id="today"></div>
  </section>
  <details id="tplBox">
    <summary>Email template and daily goal</summary>
    <div class="tpl">
      <div class="field"><label for="perDay">Emails per day</label>
        <select id="perDay"><option>3</option><option>5</option><option>8</option><option>10</option></select></div>
      <div class="field"><label for="tplSubject">Subject</label><input type="text" id="tplSubject"></div>
      <div class="field"><label for="tplBody">Body</label><textarea id="tplBody"></textarea></div>
      <p class="hint">Placeholders: <code>{game}</code> their game, <code>{dev}</code> developer name, <code>{liked}</code> the line you type on each card, <code>{release}</code> their release date, <code>{timing}</code> "once both games are out" or, for games already released, "once __GAME__ launches", <code>{signoff}</code> "Thanks, and good luck with the launch!" for upcoming games, plain "Thanks!" for released ones.</p>
      <div class="actions"><button class="primary" id="saveTpl">Save template</button><button id="resetTpl">Reset to default</button><span class="note" id="tplMsg"></span></div>
    </div>
  </details>
  <details id="logBox">
    <summary id="logTitle">Sent log</summary>
    <p class="note">Update a row when someone answers, so you know who to follow up with. Follow up once if there's no reply after about a week.</p>
    <div class="tbl"><table class="log"><thead><tr><th>Game</th><th>Email</th><th>Sent</th><th>Status</th></tr></thead><tbody id="log"></tbody></table></div>
  </details>
</div>
<script>
const QUEUE = __QUEUE__;
const CFG = __CONFIG__;
const DEFAULT_SUBJECT = CFG.subject;
const DEFAULT_BODY = CFG.body;

const $ = id => document.getElementById(id);
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const todayKey = () => { const d = new Date(); return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); };
const emailOf = g => g.support_email || (g.website_emails || "").split(" ")[0] || "";
const firstDev = g => (g.developer || "there").split(",")[0].trim();

// status: { [appid]: {status, date} }  settings: {perDay, subject, body}
let status = {}, settings = { perDay: 5, subject: DEFAULT_SUBJECT, body: DEFAULT_BODY };
const liked = {};   // per-card "what you liked" lines, kept in this browser
let db = null, extra = 0;

function lsGet(k, d) { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch (e) { return d; } }
function lsSet(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
Object.assign(liked, lsGet("so-liked", {}));

function fill(tpl, g) {
  const like = (liked[g.appid] || "").trim();
  const out = g.released !== "no";
  return tpl.replaceAll("{timing}", out ? "once " + CFG.game + " launches" : "once both games are out")
            .replaceAll("{signoff}", out ? "Thanks!" : "Thanks, and good luck with the launch!")
            .replaceAll("{game}", g.name).replaceAll("{dev}", firstDev(g)).replaceAll("{release}", g.release || "")
            .replaceAll("{liked}", like || "[WHAT YOU LIKED]");
}
function bodyHtml(g) {
  return esc(fill(settings.body, g)).replace("[WHAT YOU LIKED]", "<mark>[type what you liked above]</mark>");
}

function picks() {
  const today = todayKey();
  const sentToday = Object.values(status).filter(s => s.status !== "skipped" && s.date === today).length;
  const pending = QUEUE.filter(g => !status[g.appid]);
  const room = Math.max(0, settings.perDay - sentToday) + extra;
  return { sentToday, pending, list: pending.slice(0, room) };
}

function render() {
  const { sentToday, pending, list } = picks();
  const all = Object.values(status);
  const sent = all.filter(s => s.status !== "skipped").length;
  const yes = all.filter(s => s.status === "yes").length, replied = all.filter(s => s.status === "replied" || s.status === "yes" || s.status === "no").length;
  $("date").textContent = new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });
  $("tally").innerHTML = `<span><b>${sentToday}</b> / ${settings.perDay} sent today</span><span><b>${sent}</b> sent total</span><span><b>${replied}</b> replied</span><span><b>${yes}</b> said yes</span><span><b>${pending.length}</b> left in queue</span>`;
  $("bar").style.width = Math.min(100, 100 * sentToday / settings.perDay) + "%";

  $("today").innerHTML = list.length ? list.map(g => {
    const email = emailOf(g);
    const links = [["store_url", "Steam page"], ["discord", "Discord"], ["x", "X"], ["bluesky", "Bluesky"], ["itch", "itch.io"], ["website", "Website"]]
      .filter(([k]) => g[k]).map(([k, l]) => `<a href="${esc(g[k])}" target="_blank" rel="noopener">${l}</a>`).join("");
    return `<article class="card" data-id="${g.appid}">
      <div class="shot">
        <a class="img" href="${esc(g.store_url)}" target="_blank" rel="noopener"><img src="thumbs/${g.appid}.jpg" alt="${esc(g.name)}" loading="lazy" onerror="this.outerHTML='<div class=ph>'+this.alt.replace(/</g,'&lt;')+'</div>'"></a>
        <a class="gname" href="${esc(g.store_url)}" target="_blank" rel="noopener">${esc(g.name)}</a>
        <div class="facts"><span>by <b>${esc(g.developer || "?")}</b></span><span>${esc(g.release || "TBA")} · ${g.released === "no" ? "upcoming" : "released"}${g.has_demo === "yes" ? " · has demo" : ""}</span><span><b>${(g.followers ?? "?").toLocaleString()}</b> followers · fit <span class="fit">${g.fit_score}</span></span></div>
        ${g.fit_tags ? `<div class="why">${esc(g.fit_tags)}</div>` : ""}
        ${g.short_description ? `<div class="why">${esc(g.short_description)}</div>` : ""}
        <div class="links">${links}</div>
      </div>
      <div class="pitch">
        <div class="field"><span class="lbl">To</span><div class="line"><span class="val">${esc(email)}</span><button class="small" data-copy="to">Copy</button></div></div>
        <div class="field"><span class="lbl">Subject</span><div class="line"><span class="val" data-subj>${esc(fill(settings.subject, g))}</span><button class="small" data-copy="subject">Copy</button></div></div>
        <div class="field"><label for="like-${g.appid}">One thing you liked about their game</label>
          <input type="text" class="liked" id="like-${g.appid}" data-like placeholder="${esc(CFG.liked_example)}" value="${esc(liked[g.appid] || "")}"></div>
        <div class="field"><span class="lbl">Email</span><div class="body" data-body>${bodyHtml(g)}</div></div>
        <div class="actions">
          <button data-copy="body">Copy email</button>
          <a class="mail" data-mail href="#" target="_blank" rel="noopener">Open in mail app</a>
          <span style="flex:1"></span>
          <button data-act="skipped">Skip</button>
          <button class="primary" data-act="sent">Mark sent</button>
        </div>
      </div></article>`;
  }).join("") : (pending.length
      ? `<div class="done"><strong>Done for today</strong><span class="note">${sentToday} sent. Come back tomorrow for the next ${settings.perDay}.</span><button id="more">Show one more</button></div>`
      : `<div class="done"><strong>Queue empty</strong><span class="note">Every game in the list has been handled. Ask Claude for a fresh scan.</span></div>`);
  document.querySelectorAll(".card").forEach(updateMail);
  const more = $("more"); if (more) more.onclick = () => { extra++; render(); };

  const logRows = Object.entries(status).filter(([, s]) => s.status !== "skipped")
    .sort((a, b) => (b[1].date || "").localeCompare(a[1].date || ""));
  $("logTitle").textContent = `Sent log (${logRows.length})`;
  $("log").innerHTML = logRows.length ? logRows.map(([id, s]) => {
    const g = QUEUE.find(q => String(q.appid) === id) || { name: id, store_url: "https://store.steampowered.com/app/" + id + "/" };
    return `<tr><td><a href="${esc(g.store_url)}" target="_blank" rel="noopener">${esc(g.name)}</a></td><td class="d">${esc(emailOf(g))}</td><td class="d">${esc(s.date)}</td>
      <td><select data-status="${id}" aria-label="Status for ${esc(g.name)}">${["sent", "replied", "yes", "no"].map(v => `<option value="${v}" ${v === s.status ? "selected" : ""}>${{sent: "Sent, waiting", replied: "Replied", yes: "Said yes", no: "Said no"}[v]}</option>`).join("")}</select></td></tr>`;
  }).join("") : `<tr><td colspan="4" class="note">Nothing sent yet. Mark an email as sent and it shows up here.</td></tr>`;
}

function gameFor(card) { return QUEUE.find(g => String(g.appid) === card.dataset.id); }
function updateMail(card) {
  const g = gameFor(card);
  card.querySelector("[data-mail]").href = "mailto:" + encodeURIComponent(emailOf(g)) + "?subject=" + encodeURIComponent(fill(settings.subject, g)) + "&body=" + encodeURIComponent(fill(settings.body, g));
}

async function setStatus(id, value) {
  const rec = { status: value, date: (status[id] && status[id].date) || todayKey() };
  status = { ...status, [id]: rec };
  lsSet("so-status", status);
  render();
  if (db) { try { await db.collection("outreach").doc(String(id)).set(rec); } catch (e) { $("storeWarn").hidden = false; } }
}
async function saveSettings() {
  lsSet("so-settings", settings);
  if (db) { try { await db.doc("settings/main").set(settings); } catch (e) { $("storeWarn").hidden = false; } }
}

document.addEventListener("click", e => {
  const card = e.target.closest(".card");
  const copy = e.target.closest("[data-copy]");
  if (copy && card) {
    const g = gameFor(card);
    const text = { to: emailOf(g), subject: fill(settings.subject, g), body: fill(settings.body, g) }[copy.dataset.copy];
    if (copy.dataset.copy === "body" && !(liked[g.appid] || "").trim()) { card.querySelector("[data-like]").focus(); }
    navigator.clipboard.writeText(text).then(() => { const t = copy.textContent; copy.textContent = "Copied"; setTimeout(() => copy.textContent = t, 1400); },
      () => { const el = copy.dataset.copy === "body" ? card.querySelector("[data-body]") : copy.previousElementSibling;
              const r = document.createRange(); r.selectNodeContents(el); const s = getSelection(); s.removeAllRanges(); s.addRange(r); });
  }
  const act = e.target.closest("[data-act]");
  if (act && card) { if (extra && act.dataset.act === "sent") extra--; setStatus(card.dataset.id, act.dataset.act); }
});
document.addEventListener("input", e => {
  if (e.target.matches("[data-like]")) {
    const card = e.target.closest(".card"), g = gameFor(card);
    liked[g.appid] = e.target.value; lsSet("so-liked", liked);
    card.querySelector("[data-body]").innerHTML = bodyHtml(g); updateMail(card);
  }
});
document.addEventListener("change", e => {
  if (e.target.matches("[data-status]")) setStatus(e.target.dataset.status, e.target.value);
  if (e.target.id === "perDay") { settings = { ...settings, perDay: +e.target.value }; saveSettings(); render(); }
});

function loadTplForm() { $("perDay").value = String(settings.perDay); $("tplSubject").value = settings.subject; $("tplBody").value = settings.body; }
$("saveTpl").onclick = () => { settings = { ...settings, subject: $("tplSubject").value, body: $("tplBody").value }; saveSettings(); render(); $("tplMsg").textContent = "Saved"; };
$("resetTpl").onclick = () => { $("tplSubject").value = DEFAULT_SUBJECT; $("tplBody").value = DEFAULT_BODY; $("tplMsg").textContent = "Default restored. Save to keep it."; };

// Start from this browser's copy, then switch to shared storage when it answers.
status = lsGet("so-status", {});
settings = { ...settings, ...lsGet("so-settings", {}) };
loadTplForm(); render();

(async () => {
  db = window.claude ? await window.claude.use("db") : null;
  if (!db) { $("storeWarn").hidden = false; return; }
  db.collection("outreach").onSnapshot(snap => {
    const next = {};
    snap.docs.forEach(d => { next[d.id] = d.data(); });
    // first sync: push anything recorded only in this browser
    for (const [id, rec] of Object.entries(status)) if (!next[id]) { next[id] = rec; db.collection("outreach").doc(id).set(rec).catch(() => {}); }
    status = next; lsSet("so-status", status); render();
  }, () => { $("storeWarn").hidden = false; });
  db.doc("settings/main").onSnapshot(d => {
    if (d.exists) { settings = { ...settings, ...d.data() }; lsSet("so-settings", settings); loadTplForm(); render(); }
  });
})();
setInterval(() => { if ($("date").textContent !== new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })) { extra = 0; render(); } }, 60000);
</script>
"""

import html as _html
page = (PAGE.replace("__TITLE__", _html.escape(json.loads(CONFIG)["title"])).replace("__GAME__", _html.escape(game))
        .replace("__CONFIG__", CONFIG).replace("__QUEUE__", payload))
open(args.dst, "w", encoding="utf-8").write(page)
print(f"Wrote {args.dst} with {len(queue)} games")
