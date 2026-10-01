# Lou Gnar (arcade mini-game)

Port of the Lou Gnar web game (built with Excalibur.js) as a self-contained Godot scene.
Tap to ollie, tap again in the air for tricks, grind rails, stomp UFOs (restores all
jumps), grab flowers. Speed ramps up through 6 tiers as the score climbs.

## Try it in 2D
Open `LouGnarDemo.tscn` and press **F6**. Space / Enter / left click / gamepad A
is the only control.

## Put it on the arcade cabinet
`LouGnar.tscn` **is a `SubViewport`** (800x600). Same pattern as `CreditsTV`:

```gdscript
@onready var _game: LouGnarGame = $LouGnar   # instanced scene
func _ready() -> void:
    var mat: ShaderMaterial = preload("res://materials/tv.tres").duplicate()
    mat.set_shader_parameter("tv_tex", _game.get_texture())
    $Screen.material_override = mat
    _game.audio_enabled = false      # silent until someone is at the machine
    _game.input_enabled = false
```

| Property / method | Purpose |
|---|---|
| `input_enabled` | Ignore the `lou_gnar_jump` action unless someone is playing |
| `audio_enabled` | Mute music + sfx (resumes the right music when re-enabled) |
| `set_running(bool)` | Freeze simulation + rendering + audio when nobody is around |
| `press_jump()` | Feed a jump/confirm from your own interaction code |
| `return_to_title()` | Reset to the title card |
| `leaderboard` | Assign an `LouGnarLeaderboard` provider (see below) |
| signals | `game_started`, `score_changed(score)`, `game_over(final_score)`, `returned_to_title` |

Input polls the global `Input` singleton, so while `input_enabled` is true the game also
sees clicks/space meant for the first-person controller — lock the player controller while
someone is playing. The `lou_gnar_jump` action is registered at runtime if the project does not
define it; define it in Project Settings to rebind.

Audio plays non-positionally on the `SFX` / `Music` buses (falls back to `Master`).

## Placeholder cabinet
`LouGnarCabinet.tscn` is a primitive-built arcade machine (swap the meshes for a real
model any time) that already does the hookup above. Instance it anywhere; front faces local **+Z**.
- Look at it and press interact to play: player input is locked, the camera blends to
  `PlayCamera`, the game gets input + sound. Interact (E / gamepad X), Esc / B or start leaves.
- Idle, the screen shows the silent title card. Uses `tv.tres` for the CRT look.
- Relies on the project autoloads `CameraManager` and `InputDeviceManager`, and on
  `PlayerInteractionComponent` (it pauses that component while you play).

## Leaderboard / Steam
The player name is the Steam persona name (`SteamManager.persona_name` when Steam is
available, otherwise `PLAYER`), so there is no name entry. On game over the score is
auto-submitted and the top 10 shown.

`LouGnarLocalLeaderboard` (default) stores a top 10 in `user://lou_gnar_scores.json`.
For Steam, subclass `LouGnarLeaderboard`:

```gdscript
extends LouGnarLeaderboard
func request_entries() -> void:
    # Steam.downloadLeaderboardEntries(...) -> on callback:
    entries_loaded.emit([{"rank": 1, "name": "...", "score": 123, "is_player": false}])
func submit_score(_player_name: String, score: int) -> void:
    # Steam.uploadLeaderboardScore(score, true, [], handle) -> on callback:
    score_submitted.emit(true)
```
then `_game.leaderboard = MySteamLeaderboard.new()`.

## Layout
- `scripts/lou_gnar.gd` - game root (phases, wiring, public API)
- `scripts/lou_gnar_player.gd` - physics, state machine, tricks, animation
- `scripts/lou_gnar_terrain.gd` (+ platform/rail/coin/ufo) - endless level generation
- `scripts/lou_gnar_parallax.gd`, `lou_gnar_effects.gd`, `lou_gnar_camera_fx.gd`, `lou_gnar_hud.gd`, title/game-over screens
- `assets/` - sprites, sounds and font copied from the web game

All gameplay constants match `player.ts` / `terrain-manager.ts` in the original.
