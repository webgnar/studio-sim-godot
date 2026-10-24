# Idle Autoplay

A screensaver-style bot that plays the studio for the player while they're away.

- **Turn it on:** Options > Game > "Idle Autoplay". The slider sets how long the player must be idle (30s to 10 min, default 2 min).
- **When it starts:** only in plain studio gameplay (no menus, missions, camera zones, skating or climbing), and never while the player is holding a painting or a tool.
- **When it stops:** any key, mouse button, mouse movement, touch, gamepad or Steam Input activity. Control returns on that frame and the bot's fade is cleared.

## Code

- `scripts/autoplay/AutoplayManager.gd` (autoload): settings, idle detection, start/stop, on-screen label. Listens on the root window's `window_input` signal so scene nodes that handle input can't hide it.
- `scripts/autoplay/AutoplayNavigation.gd`: bakes a navmesh of the whole level at runtime from its static collision, on a private navigation map (gallery visitors keep theirs). Baked once per scene, the first time the bot starts. The bot always walks; it never teleports. When it gets snagged it logs `AutoplayBot: snagged at ...` and re-plans.
- `scripts/autoplay/AutoplayBot.gd`: the behaviors. Each one is a coroutine that checks `still_running(token)` after every await, so a stop cancels it right away. The bot never fakes InputEvents; it calls game code directly.
- `PlayerController.gd`: `autoplay_move` replaces the move input while the bot is active, and `autoplay_look_at()` steers the view through the normal camera smoothing.

## Behaviors

| Behavior | Gate | What it does |
| --- | --- | --- |
| Clear the canvas | loose paintings within 3.5 m of the canvas | Before painting and after each detach, walks up to each loose painting (up to 3 per pass), picks it up, carries it to one dump corner of the studio and tosses it onto the pile. The corner is found once per scene on a 1 m grid (walls on two perpendicular sides, at least 5 m from the canvas and 3 m from doors), so it's the same corner every launch. If autoplay stops mid-carry, the painting is set down. A painting that slips out twice is left alone for the session. |
| Wander | always | Pathfinds on foot to 1 to 3 random reachable spots and looks around at each. |
| Paint the canvas | at least one sticker owned, canvas reachable on foot | Pathfinds to the active studio canvas and paints in plain view: the sticker ghost is dragged across the canvas through a few "considering" stops while it eases into its rotation and size, then placed with the same screen-centre click a player uses. Then presses the red Detach button. Stops detaching after 3 per session. Restores the player's sticker selection afterwards. |

## Tuning how it paints

`scripts/autoplay/AutoplayPainter.gd` decides what gets painted: which stickers, where they end up, rotation, size, the path the ghost takes on the way there, and the timing (drag speed, hover, settle). `AutoplayBot` only performs what the painter plans, so composition work goes in the painter without touching movement code.

The current strategy is modelled on the Hall of Fame paintings (`res://hall_of_fame/`). Those cover the whole canvas, build up in layers, repeat a few stickers instead of using many, and keep rotations aligned. So `begin_painting()` plans the whole painting up front, back to front:

1. **Background:** one dense sticker tiled big and overlapping over the whole canvas, sometimes with a sparse texture on top.
2. **Structure:** a horizon (a second fill over the bottom, often with a row of bands on the line), a split, stripes, a border, 2x2 panels, or nothing.
3. **Motif:** one sticker repeated in a row, grid, ring, stack, mirrored pairs or a scatter.
4. **Focal:** one big subject on the centre or a thirds line, sitting on the horizon when there is one. Sometimes a few subjects stacked into a figure.
5. **Accents:** a few small lines and arcs near the focal point.

**Colour:** each painting gets a scheme: a key colour family (yellow, orange, red, pink, purple, blue, teal, green or black/white/grey), skipping the last three used so consecutive paintings change colour, plus a second and an accent colour (same family, neighbours, the complement, or greys). Every sticker's colour is measured once from its pixels (main hue, how colourful, how dense), custom stickers included, and picks are weighted by how well a sticker fits the slot it's filling. The background takes the key colour, so the overall colour field changes from painting to painting.

**Meticulous paintings:** `METICULOUS_CHANCE` (about a third) of paintings are planned in exact order instead of in layers: a calm square-laid ground, then a colour-sorted specimen chart, a checkerboard of two stickers, concentric rings, four-fold mirror symmetry, or rows growing steadily in size. Each of those stickers is nudged into place with a few tiny corrections and a longer settle before it goes down.

**Abstractions:** in about half the layered paintings (`ABSTRACTION_CHANCE`) the focal point starts as a quick burst of 18 to 32 stickers piled into a bunch from two or three stickers, sometimes with a smaller one balancing it across the canvas. After the motif goes down, the bot comes back and carves a form out of each burst. The form is usually (`SILHOUETTE_CHANCE`) the silhouette of a sticker already in the painting: each sticker's outline is traced once from its transparency (`BitMap.opaque_to_polygons`). Stickers that aren't one solid, fairly compact shape (mazes, scattered pieces, lines, long strips, thin leggy shapes) are skipped, which leaves 17 of the 62 built-ins. The outline is simplified to 6 to 10 straight cuts like a paper cut-out, as long as it still looks like the sticker. Otherwise the form is a plain circle, square, triangle, diamond or arch. The bot then draws the form with the existing stickers used as simple marks, like a pen line. Only the thinnest line stickers can be pens (`PEN_COVERAGE`: 3, 63, 70, 71 and 72 among the built-ins). Each goes down at the smallest size the canvas allows, laid along the edge and chained end to end (`LINE_OVERLAP`), with curved marks all bowing the same way so they join into one line. Half the time (`REDRAW_CHANCE`) the hand goes back over part of the line in a looser second pass. Half the time (`HATCH_CHANCE`) a few rows of the same marks at one angle hatch the burst just outside the line (`HATCH_SPACING`, `HATCH_MAX`), kept light so they don't bury it.

The smallest a sticker can go on the studio canvas is about 13% of its width (`min_scale` times `sticker_scale`), so pen marks are dashes rather than fine lines and only fairly big forms read clearly.

**The brain:** to keep placement from feeling mechanical, the painter has a mood: `focus` and `energy` (0..1) start at a random baseline for each painting and drift a little every stroke. Low focus means a shakier hand (every placement lands a little off in position, rotation and size, with meticulous strokes still wobbling slightly) and more mistakes; high energy means quicker strokes, shorter pauses and more impulses. Runs of the same sticker (rows, grids, tiles, bursts) also go down in a loosely shuffled order instead of strictly one after another.

**Mistakes and fixes:** to feel human, some strokes go wrong. On strokes the bot is paying attention to (not background tiles), `MISTAKE_CHANCE` of them (half that when meticulous) become a mistake when issued: a slip (off target, turned or resized) or a distraction (the bot glances off the canvas for a second or two and the ghost has drifted when it looks back). `IMPULSE_CHANCE` also slaps down an unplanned sticker of any colour now and then. After a mistake the bot stares at it for a moment, then picks a fix from `FIXES`: **undo** (right-click, exactly like a player) and redo it properly, **cover** it with the background sticker and redo it, **echo** it (mirror or repeat it so it reads as deliberate), **build around** it (frame it with a few small pieces), or **leave** it. Players can only undo the last sticker, so fixes happen right after the mistake. `issue()` and `after_stroke()` are the hooks: the plan grows as fixes are queued, so the bot's loop re-reads `stroke_count()`.

What each sticker is good for (fill, texture, band, line, frame, motif, subject) is the `ROLES` table at the top of the painter, keyed by sticker id. Custom and bought stickers aren't in the table, so they're guessed from their shape. `STRUCTURES` and `ARRANGEMENTS` weight how often each layout is picked. If the canvas already has stickers on it (someone else's painting), the background and structure are skipped so their work isn't buried.

Plans are made in viewer space (x right, y down, 0..1, rotation 0 = upright as the player sees it), and the painter converts them with the canvas's transform, so they come out upright on any canvas.

**Previewing plans without the game:** `plan_painting(aspect)` doesn't touch the scene, so a headless script can fill `StickerLibrary.sticker_library` from the PNGs in `res://sprites/painting layers/`, call it, dump the stamps to JSON, and render them with PIL (scale the longest side to `size` x canvas width, rotate by `-rot` in PIL, centre at `pos`). That's how the sample paintings for tuning were made.

## Adding a behavior

Add a `_can_<x>()` gate (check `ShopManager.is_purchased(...)`, `AutomationManager.is_assistant_active()`, etc.) and a `_<x>(token)` coroutine to `AutoplayBot.gd`, then pick it in `_run()`.

Ideas: transfer and convert the assistant's work once the assistant is hired, hang finished paintings in the gallery, play a record on the boombox, use the nail gun.
