# Hall of Fame assets

This folder is populated from the `studio-sim-gallery` website repo, not authored here.

From that repo's root:

```bash
R2_PUBLIC_URL=https://your-r2-public-url node scripts/download-hall-of-fame.mjs
```

Then copy the `hall-of-fame/` folder it produces on top of this one (`res://hall_of_fame/`)
and reopen/focus the Godot editor so the `.glb` files import. Re-run the sync anytime to pick
up newly-hearted paintings — it skips files it already has and only rewrites `manifest.json`.

Expected contents per flagged painting:

- `<slug>.glb`
- `<slug>.png`
- `<slug>_recording.json` — the sticker recording, only for paintings uploaded by game builds that send one
- `manifest.json` — array of `{ id, title, artistName, artistStatement, createdAt, glb, png, recording }`

`scripts/hall_of_fame_gallery.gd` (attached to `hall of fame/HallOfFameGallery` in
`scenes/world.tscn`) reads `manifest.json` at `_ready()` and spawns each painting — no runtime
network calls, everything here is a build-time snapshot.

## Hall of fame commissions

`MissionManager` also turns every square painting here into a commission. Five of them go at the
end of the Commissions list: ones the player has completed stay there for good, and the other
slots get random hall of fame paintings, picked again every time the game starts
(`HALL_OF_FAME_SLOTS`). Wide paintings stay on the wall only. A painting with a `recording` gets
Watch Replay. Hall of fame commissions don't count toward the "complete every commission"
achievement. Unflag a painting on the website and re-sync to take it out of the next build.
