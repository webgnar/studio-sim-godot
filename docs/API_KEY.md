# Gallery server key

The game talks to the studio-sim-gallery server (Vercel) with a shared key sent
as the `X-API-Key` header. The server checks it against the `UPLOAD_API_KEY`
environment variable.

The key is **not** in git. It lives in `data/api_key.json` (gitignored):

```json
{"api_key": "the-key"}
```

Copy `data/api_key.example.json` to `data/api_key.json` and fill it in.
Every script reads it through `ApiKey.get_key()` (`scripts/ApiKey.gd`).

- **Exports:** every preset in `export_presets.cfg` lists `data/api_key.json`
  in its include filter, so builds made on a machine that has the file carry it.
  A build made without the file still runs, it just has no online features.
- **Missing file:** the game prints one warning and keeps running. Uploads,
  sticker market, voice, visitor chat, the assistant and the fortune teller get
  "unauthorized" from the server and fall back the way they do when offline.
- **It is still in every build.** Anyone who unpacks a released build can read
  the key. Keeping it out of git stops it being scraped from GitHub; the server's
  rate limit (`lib/guard.ts` in studio-sim-gallery) is what limits abuse.

## Rotating the key

1. Make a new key: `openssl rand -hex 24`
2. Put it in `data/api_key.json` here, and export the new builds (Steam depots,
   web) but don't publish them yet.
3. Vercel → studio-sim-gallery → Settings → Environment Variables:
   set `UPLOAD_API_KEY` to the new key (Production, and Preview if used).
   Optional: put the old key in `UPLOAD_API_KEY_PREVIOUS` for a few days so
   players on old builds keep working while the update rolls out; delete it
   afterwards to kill the old key.
4. Redeploy (Deployments → latest → Redeploy). Env changes only apply to new
   deployments.
5. Publish the new builds right away.
6. Other games that use the server (Underground LA's `data/talk_key.json`)
   need the new key too, or their own key in `UNDERGROUND_LA_API_KEY`.
