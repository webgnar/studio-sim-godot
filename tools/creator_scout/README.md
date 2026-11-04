# Creator Scout

Finds small YouTube channels (default 20 to 500 subscribers) that would fit
your game, the same way Bundle Scout finds games to bundle with. It searches
for recent videos of games like yours, topic searches and channel searches,
then opens every channel it finds: About page (subscribers, description,
links, country, whether an email is listed) and its latest uploads. Channels
that posted recently are scored by how well their videos match your game.

It only reads public YouTube pages through YouTube's own web API (no API key,
no sign-in). Nothing here contacts anyone except `send_daily.py`, and that only
with `--send` and only for creators you approved.

## Run a search

```sh
cd tools/creator_scout
python3 find_creators.py --profile profiles/studio_sim.json --out results   # results.csv + results.json, 1-2 hours
python3 make_outreach.py results.json outreach.html --write-queue queue.txt
python3 fetch_avatars.py results.json queue.txt thumbs                      # pip install pillow
```

`--max-searches 5 --max-channels 40 --pages 1` makes a quick test run.
`cache.json` keeps every channel already opened, so a rerun is fast.

## Profile

| Field | What it does |
|---|---|
| `min_subs`, `max_subs` | Subscriber range to keep. |
| `active_days` | Drop channels with no upload in this many days. |
| `similar_games` | Well-known games like yours. Searched for videos from this year; a channel that played one scores `played_similar_points` each. |
| `small_similar_games` | Small, recent games like yours (e.g. from Bundle Scout). Searched with no date filter. |
| `topic_queries` | Video searches, uploads from this month. |
| `channel_queries` | Channel searches. |
| `keyword_weights` / `penalty_keywords` | Points for words in their video titles and channel description. |
| `english_only`, `min_english` | Rough language filter on titles. |
| `min_fit` | Drop weaker fits. |
| `outreach` | Page title, email subject, example opening line. |

## Review page

`outreach.html` shows a few channels a day. You check each one, paste the
email from its About page (YouTube hides most small channels' emails behind a
sign-in), keep the opening line true, and approve. Publish it as a Claude
artifact with the `db` capability so approvals are saved (collection
`creators`). The page never holds Steam keys.

## Daily send job

`send_daily.py` + `send-daily.workflow.yml` + `email_template.html` belong in a
**private** repo, because the queue and log hold creators' email addresses.
Secrets: `GMAIL_ADDRESS`, `GMAIL_APP_PASSWORD`, `STEAM_KEYS` (one per line),
optional `BCC`. Each run sends one approved creator the key email, gives them
the next unused key, and commits `sent_log.json` (key number only, never the
key). Without `--send` it is a dry run. The schedule in the workflow ships
commented out.
