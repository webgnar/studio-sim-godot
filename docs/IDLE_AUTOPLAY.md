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

What each sticker is good for (fill, texture, band, line, frame, motif, subject) is the `ROLES` table at the top of the painter, keyed by sticker id. Custom and bought stickers aren't in the table, so they're guessed from their shape. `STRUCTURES` and `ARRANGEMENTS` weight how often each layout is picked. If the canvas already has stickers on it (someone else's painting), the background and structure are skipped so their work isn't buried.

Plans are made in viewer space (x right, y down, 0..1, rotation 0 = upright as the player sees it), and the painter converts them with the canvas's transform, so they come out upright on any canvas.

**Previewing plans without the game:** `plan_painting(aspect)` doesn't touch the scene, so a headless script can fill `StickerLibrary.sticker_library` from the PNGs in `res://sprites/painting layers/`, call it, dump the stamps to JSON, and render them with PIL (scale the longest side to `size` x canvas width, rotate by `-rot` in PIL, centre at `pos`). That's how the sample paintings for tuning were made.

## Adding a behavior

Add a `_can_<x>()` gate (check `ShopManager.is_purchased(...)`, `AutomationManager.is_assistant_active()`, etc.) and a `_<x>(token)` coroutine to `AutoplayBot.gd`, then pick it in `_run()`.

Ideas: transfer and convert the assistant's work once the assistant is hired, hang finished paintings in the gallery, play a record on the boombox, use the nail gun.
