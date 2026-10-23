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
| Wander | always | Pathfinds on foot to 1 to 3 random reachable spots and looks around at each. |
| Paint the canvas | at least one sticker owned, canvas reachable on foot | Pathfinds to the active studio canvas, places 12 to 30 random owned stickers with random rotation and size, then presses the red Detach button. Stops detaching after 3 per session so paintings don't pile up. Restores the player's sticker selection afterwards. |

## Adding a behavior

Add a `_can_<x>()` gate (check `ShopManager.is_purchased(...)`, `AutomationManager.is_assistant_active()`, etc.) and a `_<x>(token)` coroutine to `AutoplayBot.gd`, then pick it in `_run()`.

Ideas: transfer and convert the assistant's work once the assistant is hired, hang finished paintings in the gallery, play a record on the boombox, use the nail gun.
