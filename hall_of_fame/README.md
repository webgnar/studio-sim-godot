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
- `manifest.json` — array of `{ id, title, artistName, artistStatement, createdAt, glb, png }`

`scripts/hall_of_fame_gallery.gd` (attached to `hall of fame/HallOfFameGallery` in
`scenes/world.tscn`) reads `manifest.json` at `_ready()` and spawns each painting — no runtime
network calls, everything here is a build-time snapshot.
