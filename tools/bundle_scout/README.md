# Bundle Scout

Finds upcoming and recently released Steam games that are like yours, ranks
them by how well they fit, and collects every public way to reach the
developer (Steamworks support email, website emails, Discord, X, Bluesky,
itch.io, press kit). Then it builds two pages:

- **report.html**: every game found, filterable, with a fit score.
- **outreach.html**: a daily "email a few devs" page with your bundle pitch
  filled in per game. Sent/replied status is saved when it is published as a
  Claude artifact with the `db` capability (otherwise only in that browser).

It only reads Steam's public store pages. It never contacts anyone.
Python 3.8+, standard library only (`fetch_thumbs.py` needs Pillow).

## Use it in another repo

Copy this whole `tools/bundle_scout/` folder, plus
`.github/workflows/bundle-scout.yml` if you want to run it on GitHub Actions.
Nothing in it depends on the rest of the repo.

## 1. Make a profile

A profile is a small JSON file in `profiles/`. Start from
`profiles/studio_sim_example.json` (or `profiles/qfs.json`, the one used for
Quest For Stoken) and change:

| Field | What it does |
|---|---|
| `name` | Your game's name. |
| `our_appid` | Your Steam appid (left out of results, used for the store link in the pitch). `null` if you don't have one yet. |
| `search_tags` | Steam tags every searched game must have. Searched three ways: most-wishlisted upcoming, soonest upcoming, and recent releases. |
| `extra_searches` | More tag combos to search (upcoming + recent), e.g. `{"tags": ["Tycoon"], "label": "tycoon"}`. |
| `similar_games` | Appids of existing games like yours. Their store tags are learned into the fit score automatically (top tags count most; generic ones like Indie are capped at 1). |
| `fit_weights` | Hand-set points per Steam tag. These win over learned ones. |
| `exclude_appids` | Games to always leave out. |
| `report_title`, `report_blurb` | Text at the top of report.html. |
| `outreach` | The pitch: `title`, `game`, `intro` (one sentence, your store link is added after it), `contact`, `signature`, `liked_example`. Or give a full `body` and `subject` yourself. |

Tag names must match Steam exactly (see store.steampowered.com/tag/browse);
unknown ones are reported and skipped.

## 2. Run it

```sh
cd tools/bundle_scout
python3 find_games.py --profile profiles/my_game.json              # writes results.csv + results.json
python3 make_report.py results.json report.html
python3 make_outreach.py results.json outreach.html --write-queue queue.txt
python3 fetch_thumbs.py queue.txt thumbs                           # header images for the outreach page
```

No profile? Quick version straight from the command line:

```sh
python3 find_games.py --name "My Game" --tags "Management" --similar 239820,362620
```

Useful options: `--max-upcoming 50 --max-soon 30 --max-recent 50` for a quick
scan, `--no-website` to skip dev websites, `--min-fit 5` to drop weak fits,
`--seen seen.txt` to flag games that are new since the last run.
`python3 find_games.py --help` lists them all.

A full scan of ~650 games takes 2 to 3 hours, mostly because Steam
rate-limits follower counts. Partial results are saved every 25 games.

## On GitHub Actions

Steam's store is blocked from some networks (including Claude's cloud
machines), so the workflow runs the scan on GitHub instead: Actions tab →
**Bundle Scout** → Run workflow, then pick the profile. It only runs when
you start it. Results are attached to the run as the `bundle-scout`
artifact and the CSV is also printed in the log between
`=====CSV-BEGIN=====` and `=====CSV-END=====`.

## Publishing the outreach page

Publish `outreach.html` as a Claude artifact with the `db` capability, and
publish each `thumbs/<appid>.jpg` next to it as `thumbs/<appid>.jpg`. Status
is stored in the `outreach` collection (one doc per appid) and the template
in `settings/main`, so it stays in sync across devices.
