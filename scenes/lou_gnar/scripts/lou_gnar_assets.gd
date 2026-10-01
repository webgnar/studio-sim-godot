class_name LouGnarAssets
extends RefCounted
## Central preloads for the LouGnar arcade game (mirrors resources.ts).

const BASE := "res://scenes/lou_gnar/assets/"

const FONT: FontFile = preload("res://scenes/lou_gnar/assets/fonts/studio-sim.ttf")

# Player sprite sheets: horizontal strips of 66x75 frames.
const PLAYER_FRAME_SIZE := Vector2(66, 75)
const SHEET_IDLE: Texture2D = preload("res://scenes/lou_gnar/assets/player/idle.png")
const SHEET_PUSH: Texture2D = preload("res://scenes/lou_gnar/assets/player/push.png")
const SHEET_OLLIE: Texture2D = preload("res://scenes/lou_gnar/assets/player/ollie.png")
const SHEET_IMPACT: Texture2D = preload("res://scenes/lou_gnar/assets/player/impact.png")
const SHEET_KICKFLIP: Texture2D = preload("res://scenes/lou_gnar/assets/player/kickflip.png")
const SHEET_HEELFLIP: Texture2D = preload("res://scenes/lou_gnar/assets/player/heelflip.png")
const SHEET_SHUV1: Texture2D = preload("res://scenes/lou_gnar/assets/player/shuv1.png")
const SHEET_SHUV2: Texture2D = preload("res://scenes/lou_gnar/assets/player/shuv2.png")
const SHEET_GRIND1: Texture2D = preload("res://scenes/lou_gnar/assets/player/grind1.png")
const SHEET_GRIND2: Texture2D = preload("res://scenes/lou_gnar/assets/player/grind2.png")
const SHEET_FREEFALL: Texture2D = preload("res://scenes/lou_gnar/assets/player/freefall.png")

# World
const SHEET_UFO: Texture2D = preload("res://scenes/lou_gnar/assets/world/ufo.png") # 9 x 58x39
const SHEET_COIN: Texture2D = preload("res://scenes/lou_gnar/assets/world/coinDark-Sheet.png") # 6 x 30x31
const BUILDING_TILES: Array[Texture2D] = [
	preload("res://scenes/lou_gnar/assets/world/tile1.jpeg"),
	preload("res://scenes/lou_gnar/assets/world/tile2.jpeg"),
	preload("res://scenes/lou_gnar/assets/world/tile3.jpeg"),
	preload("res://scenes/lou_gnar/assets/world/tile4.jpeg"),
	preload("res://scenes/lou_gnar/assets/world/tile5.jpeg"),
	preload("res://scenes/lou_gnar/assets/world/tile6.jpeg"),
]
# Note: the original game deliberately swaps the cap files (capLeft uses railCapR.png).
const RAIL_CAP_LEFT: Texture2D = preload("res://scenes/lou_gnar/assets/world/railCapR.png")
const RAIL_TILE: Texture2D = preload("res://scenes/lou_gnar/assets/world/railTile.png")
const RAIL_CAP_RIGHT: Texture2D = preload("res://scenes/lou_gnar/assets/world/railcapL.png")

# Effects
const SPARKS: Array[Texture2D] = [
	preload("res://scenes/lou_gnar/assets/effects/spark1.png"),
	preload("res://scenes/lou_gnar/assets/effects/spark2.png"),
	preload("res://scenes/lou_gnar/assets/effects/spark3.png"),
]
const STAR: Texture2D = preload("res://scenes/lou_gnar/assets/effects/star.png")
const GREEN_SMASH: Texture2D = preload("res://scenes/lou_gnar/assets/effects/green_smash.png")
const DUST_PUFF: Texture2D = preload("res://scenes/lou_gnar/assets/effects/dust_puff.png")

# Backgrounds (all 800px wide)
const BG_SKY: Texture2D = preload("res://scenes/lou_gnar/assets/backgrounds/sky.png")
const BG_FAR_MOUNTAINS: Texture2D = preload("res://scenes/lou_gnar/assets/backgrounds/mountains.png")
const BG_MID_HILLS: Texture2D = preload("res://scenes/lou_gnar/assets/backgrounds/mountain-mid.png")
const BG_NEAR_TREES: Texture2D = preload("res://scenes/lou_gnar/assets/backgrounds/background-near.png")
const BG_FOREGROUND: Texture2D = preload("res://scenes/lou_gnar/assets/backgrounds/foreground.png")

const TITLE_IMAGE: Texture2D = preload("res://scenes/lou_gnar/assets/ui/title.png")

# Audio
const MUSIC_TITLE: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/music_title.ogg")
const MUSIC_GAMEPLAY: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/music_gameplay.ogg")
const SFX_OLLIE: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/ollie.ogg")
const SFX_TRICK: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/trick.ogg")
const SFX_IMPACT: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/impact.ogg")
const SFX_GRIND: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/grind.ogg")
const SFX_DIE: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/game_over.ogg")
const SFX_COIN: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/coin.ogg")
const SFX_UFO_EXPLODE: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/ufo_explode.ogg")
const SFX_GAME_START: AudioStream = preload("res://scenes/lou_gnar/assets/sounds/game_start.ogg")
