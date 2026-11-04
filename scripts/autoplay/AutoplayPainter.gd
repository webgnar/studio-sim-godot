extends RefCounted
class_name AutoplayPainter

## How the idle autoplay bot composes a painting. This is the file to tune.
##
## When the bot steps up to a canvas it calls begin_painting(), which plans
## the whole painting up front as a list of strokes, then asks for them one at
## a time with next_stroke(). A stroke says which sticker to use, where it ends
## up (canvas UV), its rotation and size, and the path the sticker ghost takes
## across the canvas before it's placed. AutoplayBot drags the ghost along that
## path in view of the player and places it, exactly like a player would.
##
## v2 strategy: modelled on the paintings in the Hall of Fame (res://hall_of_fame).
## Those almost never leave bare canvas, build up in layers, repeat a few
## stickers instead of using many, and keep rotations aligned. So a painting is
## planned the same way, back to front:
##   1. Background: one fill sticker tiled big over the whole canvas.
##   2. Structure: a horizon, a split, stripes, a border, panels, or nothing.
##   3. Motif: one sticker repeated in a row, grid, ring, stack or mirrored pairs.
##   4. Focal: one big subject (sometimes a stacked "figure") on a strong spot.
##   5. Accents: a few lines and small shapes near the focal point.
## Each painting also gets a colour scheme (a key colour family that changes
## from painting to painting, plus a second and an accent colour), and stickers
## are picked by how well their own colours fit it, so the colour fields vary.
## About a third of paintings are "meticulous" instead: an even ground and then
## stickers set out in exact grids, rings or mirror symmetry, each one nudged
## into place before it goes down.
## Abstractions: often the focal point starts as a quick burst of stickers
## piled into a bunch. Later the bot comes back and draws a form out of that
## texture, using the thinnest line stickers as small pen marks chained along
## the form's edge, sometimes with light hatching outside it. The form is
## usually the silhouette of one of the painting's own stickers, traced from
## its transparency.
## No bare canvas: each painting either covers the canvas early (a solid
## ground, gaps patched) or skips the ground and fills only the spots still
## bare at the end, walking from spot to spot like a pen. A coverage grid built
## from every sticker's real shape finds the bare spots, and a last look at
## what actually went down touches up any slivers.
## Mistakes: now and then a stroke goes wrong (the hand slips, or the bot
## glances away and the ghost drifts) or an
## impulsive, unplanned sticker goes down. The bot notices, looks at it, and
## then deals with it like a person would: undoes it, paints over it, repeats
## it so it looks deliberate, or builds around it. Some get left alone.
## Plans are made in "viewer space" (x right, y down, 0..1 across the canvas as
## the player sees it, rotation 0 = upright) and converted to the canvas's own
## UV and rotation at the end, so they come out upright on any canvas.

## Stroke timing: tiles go down briskly, the bits you look at get mulled over.
const CONSIDER_POINTS_MIN := 1       ## "hmm, maybe here" stops before settling
const CONSIDER_POINTS_MAX := 3
const CONSIDER_SPREAD := 0.18        ## how far from the final spot those stops wander (viewer space)
const DRAG_SPEED := 0.45             ## canvas widths per second while moving the ghost
const DRAG_TIME_MIN := 0.25
const HOVER_MIN := 0.15              ## pause at each considering stop
const HOVER_MAX := 0.5
const SETTLE_MIN := 0.3              ## pause on the final spot before placing
const SETTLE_MAX := 0.8
const QUICK_SETTLE := 0.15           ## same, for background tiles
const PAUSE_AFTER_MIN := 0.3         ## step back and look after placing
const PAUSE_AFTER_MAX := 1.0
const QUICK_PAUSE_AFTER := 0.15
const NUDGES_MIN := 2                ## meticulous strokes: tiny corrections before placing
const NUDGES_MAX := 4
const NUDGE_SPREAD := 0.012          ## viewer space
const PRECISE_SETTLE_MIN := 0.6
const PRECISE_SETTLE_MAX := 1.2

## Where sticker centres may go, in viewer space. A little past the edges is
## fine (and needed to tile to the edge); the canvas's hitbox reaches further.
const BLEED := 0.08
## Tiles are spaced at this fraction of their size, so they overlap and leave no gaps.
## Sparser stickers get packed tighter: spacing = size x (TILE_OVERLAP_SPARSE..TILE_OVERLAP) by coverage.
const TILE_OVERLAP := 0.75
const TILE_OVERLAP_SPARSE := 0.45
## Stickers that cover at least this much of their image can tile into a colour
## field even when ROLES doesn't call them a fill.
const FILL_COVERAGE := 0.45
## Fills covering less than this get a second, offset pass of tiles to close the gaps.
const SECOND_PASS_BELOW := 0.7
## Meticulous grounds use fills, plus shapes at least this dense (so most colours have one).
const GROUND_COVERAGE := 0.55
## Smallest sticker a plan asks for (canvas widths). begin_painting() replaces
## it with what the canvas's minimum scale allows.
const DEFAULT_MIN_SIZE := 0.13

## No bare canvas: each painting either covers everything early (the ground,
## checked and patched with big shapes) or skips the ground and, at the end,
## fills only the bare spots with small marks walked from spot to spot like a
## pen line. Coverage is worked out from every planned sticker's shape on a grid.
const LATE_FILL_CHANCE := 0.35       ## skip the ground and fill the bare spots at the end
const CONTRAST_FILL_CHANCE := 0.4    ## a late fill uses a completely different colour scheme
const BASE_SOLIDITY := 0.6           ## early grounds are at least this solid (see _solidity)
const SOLID_INTERIOR := 0.78         ## late fill inks: solid shapes, so they close gaps instead of making lace
const LATE_STRUCTURES := {"horizon": 4, "split": 2, "stripes": 2, "panels": 2}   ## big shapes first when there's no ground
const COVER_MARGIN := 0.035          ## planned stickers count this much smaller (canvas widths), for the hand's wobble
const COVER_GRID := 48               ## coverage grid cells across the canvas
const MASK_RES := 32                 ## sticker shapes are sampled at this many pixels across
const PATCH_MAX := 60                ## most big patches an early cover gets
const FINAL_LOOKS := 3               ## times the bot steps back to check the finished painting
const FINAL_LOOK_MAX := 40           ## most touch-up marks per look
const FILL_MAX := 260                ## most marks a late fill lays
const CELL_SAMPLES: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0.02, 0.02), Vector2(0.98, 0.02), Vector2(0.02, 0.98), Vector2(0.98, 0.98)]   ## centre and corners, so neighbouring cells meet with no gap
const CELL_FULL := 31                ## all five sample bits set
const FILL_RETRIES := 3              ## goes back to a stubborn spot this many times before giving up
const FILL_TRIES := 12                ## placements a fill mark tries before going down
const FILL_OVERLAP_COST := 0.6       ## how much covering finished painting counts against a placement
const FILL_REACH := 2.0              ## a fill mark's size, as a multiple of the gap's half-width
const FILL_LARGEST := 0.6            ## biggest late fill mark (canvas widths)

## Mistakes, per stroke the bot is paying attention to (not background tiles).
## Meticulous paintings get fewer and fix them more carefully.
const MISTAKE_CHANCE := 0.08
const MISTAKE_CHANCE_METICULOUS := 0.04
const IMPULSE_CHANCE := 0.06         ## per considered stroke: slap down something unplanned
const IMPULSE_CHANCE_METICULOUS := 0.02
const MISTAKES := {"slip": 3, "distracted": 2}
## What to do about a mistake once it's noticed. undo and cover redo the
## intended stroke afterwards; echo and build_around keep the mistake and make
## it part of the painting.
const FIXES := {"undo": 2, "cover": 3, "echo": 2, "build_around": 2, "leave": 1}
const FIXES_METICULOUS := {"undo": 5, "cover": 2, "echo": 2, "build_around": 1}
const STARE_MIN := 0.6               ## seconds looking at a mistake before fixing it
const STARE_MAX := 1.8
const LOOK_AWAY_MIN := 1.0           ## a distraction: seconds looking off the canvas
const LOOK_AWAY_MAX := 2.5

## Abstractions: a burst of stickers carved into a form (layered paintings only).
const ABSTRACTION_CHANCE := 0.75     ## the focal point is an abstraction (zack likes the drawn-with-marks forms)
const SECOND_ABSTRACTION_CHANCE := 0.3   ## plus a smaller one balancing it
const BURST_MIN := 18
const BURST_MAX := 32
const LINE_OVERLAP := 0.8           ## line marks are spaced at this fraction of their length, so they join up
const HATCH_SPACING := 0.6           ## gap between hatching rows, as a fraction of a mark's length
const HATCH_MAX := 14                ## most hatching marks per form
const HATCH_CHANCE := 0.5            ## chance a drawn form also gets hatching outside its line
const REDRAW_CHANCE := 0.5           ## chance the hand goes back over part of the line
const PEN_COVERAGE := 0.13           ## line stickers thinner than this (share of their box filled) can draw
const CUTS_MIN := 6                  ## straight cuts a sticker silhouette is simplified to (fewer if it still looks like the sticker)
const CUTS_MAX := 10
## How often the carved form is a sticker's silhouette rather than a plain shape.
const SILHOUETTE_CHANCE := 0.8
const SILHOUETTE_RES := 96.0         ## pixels the silhouette is traced at
const SILHOUETTE_SIMPLIFY := 2.5     ## outline simplification, in those pixels
const SILHOUETTE_SOLIDITY := 0.5     ## outline area / convex hull area, at least
const SILHOUETTE_MAX_POINTS := 60
const SILHOUETTE_COMPACTNESS := 0.25  ## 4*pi*area/perimeter^2: 1 for a circle, low for thin or spiky shapes
const FORMS := {"circle": 3, "square": 2, "triangle": 2, "diamond": 2, "arch": 2}

## The bot's "brain": a mood that wanders stroke by stroke, so its hand and
## its decisions aren't mechanical. focus (0..1) steadies the hand, slows it
## down and makes mistakes rarer; energy (0..1) makes it quicker and more
## impulsive. Both drift a little every stroke and get pulled back toward
## this painting's own baseline, so one painting can be calm and the next
## restless, and the mood shifts within a painting too.
const MOOD_DRIFT := 0.08             ## how far focus and energy can move per stroke
const MOOD_PULL := 0.1               ## how strongly they return to the painting's baseline
const HAND_WOBBLE := 0.025           ## position error at zero focus (canvas widths, gaussian)
const HAND_WOBBLE_PRECISE := 0.35    ## meticulous strokes wobble this fraction as much
const ROT_WOBBLE := 6.0              ## degrees at zero focus
const SIZE_WOBBLE := 0.07            ## size error at zero focus (fraction)
## Nobody paints a row strictly left to right: runs of the same sticker are
## put down in a loosely shuffled order. Higher = more jumbled.
const ORDER_JUMBLE := 2.5
const ORDER_JUMBLE_METICULOUS := 0.8

## How often a painting is meticulous rather than layered.
const METICULOUS_CHANCE := 0.35
## "Studio" paintings follow how zack painted when we watched him (2026-10-25):
## big shapes first, buried by bands and veils, then a step back to find a
## form that came out of that by itself (never planned) and bring it out,
## a trial undone, a loose grid of window frames turning the collage into
## scenes, and a calm sky. (No pencil yet: only once the bot can use a
## bought pencil.)
const STUDIO_CHANCE := 0.4
const PALE_LIGHT := 0.7              ## average luminance for a "pale" veil sticker
const STUDIO_FIELDS := 110           ## most marks closing a studio painting's canvas under the rest
const STUDIO_TRIAL_CHANCE := 0.6     ## tries something big over the middle, looks, takes it back
const FORM_VALUES: Array[float] = [0.38, 0.6]   ## a squint sorts every spot into dark / middle / light at these luminances
const FORM_SQUINT := 2               ## passes of the squint (a majority blur of the value map)
const FORM_SMALLEST := 0.03          ## a found form covers at least this share of the canvas
const FORM_LARGEST := 0.2            ## and at most this
const FORM_SIZE := 0.08              ## the size it most likes to find
const FORM_BORDER := 0.25            ## most of a form's cells that may lie on the canvas edge
const FORM_COMPACT := Vector2(0.08, 0.7)   ## 4*pi*area/perimeter^2 range: not a sliver, not a plain blob
const FORM_RING := Vector2(2.0, 4.0) ## cells round a found form that later rounds leave alone
const FORM_STRIP := Vector2(0.13, 0.2)   ## length of the strips banding a found form
const FORM_LINE_TRIES := 4           ## a band mark that would cut into a form is nudged out this many times before leaving a gap
const FORM_SIDE := 3.0               ## cells along one side of a form's edge line that are made continuous
const FORM_SIDE_MARKS := 14          ## most marks doing that
const FORM_CONTRAST := 0.3           ## those marks differ from the form by at least this much lightness
const FORM_INTRUDE := 2              ## sample points a later shape may land inside the form
const FORM_SAFETY := 0.015           ## shapes count this much bigger when checked against the form, for the hand's wobble
const STUDIO_ANY_STICKER := 1.0      ## share of studio paintings where every pick is any sticker at all, ignoring role and colour
const FORM_ZOOM := 0.7               ## each round looks for forms this much smaller than the last
const FORM_TINIEST := 0.006          ## smallest form any round will take (share of the canvas)
const FORM_PASSES := 8               ## most squint-and-define rounds per painting
const FORM_REFINE := 30              ## most marks calming the specks around the forms per round
const FORM_REFINE_CHANCE := 0.0      ## a round also covers specks that clash with their mass (off: chops the masses up with this library)
const ACCENT_CHANCE := 0.8           ## share of found forms that get a personality
const ACCENTS := {"beads": 3, "crown": 2, "fringe": 3, "jewel": 2, "stitch": 2}   ## kinds of personality and how often each is picked
const ACCENT_MAX := 24               ## most accent marks per form
const ACCENT_SIZE := Vector2(1.3, 1.5)   ## accent sticker size, as a multiple of the smallest sticker size (louder when higher)
const STUDIO_VARIETY := 1.0          ## share of studio picks that ignore the learned colour scheme (still the right kind of sticker); 1 = always
const STUDIO_ROLE_FREE := 0.5        ## share of studio picks that ignore the kind of sticker the job asks for and draw from the whole library (still meeting the job's light/dark or shape test)
const STUDIO_FRESH := 0.25           ## how likely a studio pick takes a sticker used in the last STUDIO_FRESH_PAINTINGS paintings (1 = no preference, lower = fresher)
const STUDIO_FRESH_PAINTINGS := 3    ## how many past paintings count for STUDIO_FRESH
const STUDIO_VEIL_LIGHT := 0.55      ## studio veils and sky wisps: lightest sticker value allowed, any colour (lower = more stickers qualify, darker veils)
const STUDIO_UNDER_DARK := 0.65      ## studio dark under-fill: stickers darker than this qualify (higher = more stickers qualify, lighter masses)
const STUDIO_UNDER_SOLID := 0.7      ## studio dark under-fill: how solid a sticker must be (lower = more stickers qualify, lacier)
const STUDIO_REUSE := 0.5            ## how likely a studio pick reuses a sticker already in the painting (1 = no preference, below 1 = prefers new ones)
const FORM_LINE_CHANCE := 0.5        ## part of the form's edge is also drawn with pen marks
## The studio assistant (see "The studio assistant" below) paints studio
## paintings like these, all any-sticker, and never stops on its own.
const ASSISTANT_MIN_SIZE := DEFAULT_MIN_SIZE   ## smallest sticker on the assistant's canvas (canvas widths): lower = finer pen marks
const ASSISTANT_CORE_SPREAD := Vector2(0.3, 0.25)   ## later rounds: how far from the middle each new skeleton may land (across, down)
const ASSISTANT_KEEP_FORMS := 0.5     ## share of found forms the next round's new shapes leave alone (0 = everything can be buried, 1 = forms are kept for good)
const ASSISTANT_PLAN_LIMIT := 1500    ## stickers remembered for planning; past that, ones hidden under others are forgotten (the canvas keeps them)
## Aerial map (zack, 2026-11-03): a top-down game overworld, like the maps
## in his reference screenshots. Land laid as a patchwork of fields, lakes or
## sea and winding rivers cut through it, clumps of forest, towns of small
## stickers packed like buildings, and roads joining the towns. On the
## assistant's wall the map keeps growing round after round: new towns and
## roads, forests spreading, now and then a flood.
const MAP_CHANCE := 0.25             ## share of the bot's paintings that are aerial maps (0 = never)
const MAP_KINDS := {"inland": 3, "coast": 2, "island": 1}   ## what the water is and how often: inland lakes, a sea along one side, an island in the sea
const MAP_WATER := {"inland": 0.1, "coast": 0.3, "island": 0.42}   ## share of the canvas under lakes or sea, by kind (rivers come on top)
const MAP_NOISE := 2.5               ## lumps of land and water across the canvas (higher = more, smaller lakes and bays)
const MAP_RIVERS := Vector2i(1, 2)   ## rivers per map (least, most)
const MAP_RIVER_WIDTH := Vector2(0.035, 0.07)   ## river width at its source and at its mouth (canvas widths)
const MAP_RIVER_BEND := 0.35         ## how much rivers meander (0 = straight)
const MAP_DARK_WATER := 0.35         ## chance the water is dark (black/navy) rather than blue
const MAP_FIELDS := Vector2i(4, 8)   ## patches the land is split into
const MAP_LAND_INKS := Vector2i(2, 4)   ## different stickers the land patches use (each patch mixes two of them)
const MAP_PICK_SET := Vector2i(2, 3)   ## every map role (water, trees, roads, pavement, streets, copper) is a mix of this many stickers, never just one (zack 2026-11-04)
const MAP_GREEN_LAND := 0.7          ## chance the land prefers green stickers (else any colour, picked per map)
const MAP_FLAT := 0.08               ## land and water prefer flat-coloured stickers: busyness (spread of brightness) a sticker can have before it's picked much less (higher = busier land and water allowed)
const MAP_WATER_CONTRAST := 0.2      ## the water differs from the land by at least this much lightness
const MAP_MISTAKES := 0.3            ## mistakes and impulsive stickers on a map, as a share of the usual rate (0 = none)
const MAP_FIELD_SIZE := Vector2(0.08, 0.35)   ## smallest and biggest land tile (canvas widths)
const MAP_FORESTS := Vector2i(2, 5)  ## forest clumps per map
const MAP_FOREST_SIZE := Vector2(0.07, 0.16)   ## forest radius (canvas widths)
const MAP_TREE_SIZE := Vector2(0.04, 0.06)    ## one tree (canvas widths)
const MAP_FOREST_PACK := 0.7         ## tree spacing, as a fraction of a tree's size (lower = denser)
const MAP_TOWNS := Vector2i(3, 6)    ## towns per map
const MAP_TOWN_HOUSES := Vector2i(4, 10)   ## buildings per town
const MAP_HOUSE_SIZE := Vector2(0.06, 0.085)   ## one building (canvas widths)
const MAP_LANDMARK := 1.6            ## a town's first building is this much bigger (castle, church)
const MAP_TOWN_SPACING := 0.2        ## towns keep at least this far apart (canvas widths)
const MAP_TOWN_BY_WATER := 0.6       ## how strongly towns settle by the water (0 = anywhere on land)
const MAP_ROAD_LOOPS := 0.3          ## chance of each extra road beyond the ones that join every town
const MAP_ROAD_EXITS := Vector2i(1, 2)   ## roads leaving the map at its edges
const MAP_ROAD_WIGGLE := 0.12        ## how much roads wind, as a fraction of their length
const MAP_ROAD_MARK := 0.06          ## length of one road mark (canvas widths)
const MAP_ROAD_SPACING := 0.15       ## gap between road stamps, as a fraction of a stamp's size: low = stamped often while the hand moves slowly, so the road comes out as one continuous trail (zack, 2026-11-03)
const MAP_DIRT_ROADS := 0.5          ## chance a map's roads are dirt tracks (small solid stickers, lighter or darker than the land) rather than thin lines
const MAP_DIRT_SIZE := 0.045         ## one piece of dirt track (canvas widths)
const MAP_MIN_SIZE := 0.04           ## smallest sticker on the assistant's map (canvas widths); the bot uses its canvas's smallest
const MAP_GROW_TOWNS := Vector2i(1, 2)    ## assistant: new towns each later round
const MAP_GROW_HOUSES := Vector2i(1, 3)   ## assistant: buildings added to each old town each later round
const MAP_GROW_FORESTS := Vector2i(1, 2)  ## assistant: new forest clumps each later round
const MAP_FLOOD_CHANCE := 0.25       ## assistant: chance a later round floods part of the map with a new lake or river
const MAP_FLOOD_FOREST := 0.25       ## assistant: once forest covers this share of the land, the next round floods the thickest forest to keep it from overgrowing the map (1 = never)
const MAP_FLOOD_LAKES := 4           ## assistant: most lakes one forest flood makes, stopping once the forest is back under MAP_FLOOD_FOREST
const MAP_CITY_AFTER := 10           ## assistant: after this many rounds the oldest town starts growing into a city (0 = never)
const MAP_CITY_BLOCK := 0.13         ## one city block plus its street (canvas widths)
const MAP_CITY_HOUSES := 2           ## buildings along each side of a block (2 = four per block)
const MAP_CITY_STREET := 0.02        ## width of a city street (canvas widths)
const MAP_CITY_STREET_SPACING := 0.4   ## gap between street stamps, as a fraction of a stamp's length
const MAP_CITY_RINGS := 6            ## most rings of blocks the city grows to, one ring a round
const MAP_BOARD := true              ## assistant: once the city is fully grown, the map builds out into a circuit board, a little more each round (zack, 2026-11-04)
const MAP_BOARD_CHIPS := Vector2i(1, 2)    ## chips added each round
const MAP_CHIP_SIZE := Vector2(0.1, 0.2)   ## a chip's size (canvas widths)
const MAP_BOARD_PARTS := Vector2i(16, 36)  ## small components packed onto the board each round, in one patch
const MAP_PART_SIZE := 0.045         ## one small component (canvas widths; never under the smallest sticker)
const MAP_BOARD_TRACES := Vector2i(1, 1)   ## bundles of copper traces routed each round
const MAP_TRACE_LINES := Vector2i(3, 6)    ## traces side by side in a bundle
const MAP_TRACE_WIDTH := 0.012       ## one trace's width (canvas widths)
const MAP_TRACE_GAP := 0.03          ## distance between traces in a bundle, centre to centre
const MAP_FLOOD_TOWN_SAFE := 0.07     ## assistant: floods stay this far from a town's middle (canvas widths)
const MAP_FLOOD_SIZE := Vector2(0.06, 0.12)   ## assistant: radius of a flood lake (canvas widths)
const MAP_FLOOD_NEW_INK := 1.0       ## assistant: chance each flood switches to a different water sticker from the floods before it (zack, 2026-11-04)
const MAP_NEW_MAP_ROUNDS := 0        ## assistant: after this many rounds a whole new map is laid over the old one (0 = never: one map keeps growing forever, zack 2026-11-03)
const METICULOUS := {"catalog": 1, "checker": 2, "rings": 2, "mandala": 3, "gradient": 2}

## Colour families a painting's key colour is drawn from (hue 0..1, -1 = black/white/grey).
## The last few used are skipped, so consecutive paintings change colour.
const FAMILIES := {
	"yellow": 0.13, "orange": 0.07, "red": 0.99, "pink": 0.93, "purple": 0.75,
	"blue": 0.62, "teal": 0.5, "green": 0.3, "neutral": -1.0,
}
const RECENT_FAMILIES := 3
const SCHEMES := {"mono": 2, "analogous": 3, "complement": 3, "neutral_accent": 2}
const HUE_TOLERANCE := 0.06          ## how far a sticker's hue can stray from the target and still fit

## What each built-in sticker is good for, by its id (its file name in
## res://sprites/painting layers/). A sticker can have several roles.
##   fill:    dense, roughly rectangular; tiles into a solid background
##   texture: sparse pattern; laid over a fill as a second layer
##   band:    long and thin; horizons, stripes, borders, rows
##   line:    thin line or arc; accents
##   frame:   outline; panels and borders
##   motif:   compact shape that reads well repeated
##   subject: interesting enough to be the focal point
## Stickers missing here (custom and bought ones) are guessed from their shape.
const ROLES := {
	"1": ["band"], "2": ["texture", "band"], "3": ["line"], "4": ["band"],
	"5": ["motif", "subject"], "6": ["subject"], "7": ["subject"], "8": ["band", "subject"],
	"9": ["subject"], "10": ["line"], "11": ["fill"], "12": ["texture"],
	"13": ["subject"], "14": ["fill"], "15": ["band", "motif"], "18": ["subject"],
	"19": ["texture"], "20": ["fill"], "21": ["subject"], "22": ["subject"],
	"23": ["subject"], "24": ["fill", "band"], "25": ["fill"], "26": ["subject"],
	"27": ["motif", "subject"], "28": ["subject"], "29": ["subject"], "31": ["band", "fill"],
	"32": ["motif", "subject"], "33": ["subject"], "34": ["frame"], "36": ["subject"],
	"37": ["motif", "subject"], "38": ["motif"], "39": ["subject"], "40": ["motif"],
	"41": ["subject"], "42": ["frame"], "43": ["motif", "subject"], "44": ["subject"],
	"45": ["subject"], "47": ["subject"], "48": ["subject"], "50": ["texture", "band"],
	"51": ["subject"], "52": ["band", "subject"], "54": ["fill", "band"], "55": ["band", "line"],
	"56": ["frame"], "57": ["subject", "fill"], "58": ["subject"], "61": ["band"],
	"63": ["line"], "64": ["band", "subject"], "65": ["motif", "subject"], "66": ["subject"],
	"67": ["line"], "68": ["subject"], "69": ["subject"], "70": ["line"],
	"71": ["line"], "72": ["line"],
}

## How often each structure is picked (relative weights).
const STRUCTURES := {"horizon": 4, "split": 1, "stripes": 2, "border": 2, "panels": 1, "none": 2}
## How often each motif arrangement is picked.
const ARRANGEMENTS := {"row": 3, "grid": 2, "ring": 2, "stack": 1, "mirror": 2, "scatter": 1, "none": 1}

var _plan: Array[Dictionary] = []
var _frame: Dictionary = {}
var _aspect := 1.0   ## canvas height / width, as the viewer sees it
var _min_size := DEFAULT_MIN_SIZE
## Hues for this painting: {key, second, accent} (-1 = neutral), and how
## welcome black/white/grey stickers are.
var _scheme: Dictionary = {}
var _recent_families: Array[String] = []
var last_style := ""   ## what the last plan was, for logs and previews
var _meticulous_style := false
var focus := 0.6
var energy := 0.5
var _focus_base := 0.6
var _energy_base := 0.5
var _ground := -1          ## the background sticker, for painting over mistakes
var _ground_rot := 0.0
var _masks := {}           ## sticker index -> alpha mask (MASK_RES square), for coverage
var late_fill := false     ## this painting fills its bare spots at the end, for previews
var _fill_inks: Array[int] = []   ## what the late fill used, for touching up
var _looks := 0            ## final looks taken at the finished painting
var _add_on := false
var _cover_margin := COVER_MARGIN   ## 0 when looking at what actually went down
var _forms: Array[PackedVector2Array] = []   ## studio forms, canvas-width units
var _keep_out := PackedByteArray()  ## coverage grid with only the forms bare: nothing goes there
var _found: Array[Dictionary] = []  ## the forms found this painting (see _find_form), for accents
var _any_sticker := false          ## every pick is any sticker at all (studio paintings)
var _recent_stickers: Array = []   ## stickers picked in each of the last few paintings (STUDIO_FRESH)
var _variety := false              ## studio painting: picks loosen the colour scheme (STUDIO_VARIETY, STUDIO_REUSE)
var _zoom := 1.0                    ## how close the current squint-and-define round looks (1 = first round)
var _form_ink := -1               ## what the forms are filled with, for touching them up
var last_carve_source := ""   ## id of the sticker whose silhouette was last carved, for previews
var _guard := false               ## new shapes skip anything that would cut into the kept forms (assistant rounds)
var _cycle := 0                   ## assistant: rounds of making shapes and defining forms so far
var _next := 0                    ## assistant: next stroke to hand out
var _assistant_style := "studio"  ## assistant: "studio", "hall_of_fame" or "aerial_map" (see begin_assistant)
var _map_water := PackedByteArray()   ## aerial map: 1 = lake, sea or river, per coverage cell
var _map_towns: Array[Vector2] = []   ## aerial map: town centres (canvas-width units)
var _map_land: Array[int] = []        ## aerial map: the land stickers
var _map_seas: Array[int] = []        ## aerial map: the water stickers
var _map_trees: Array[int] = []       ## aerial map: the tree stickers
var _map_pens: Array[int] = []        ## aerial map: the road stickers
var _map_dirt := false                ## aerial map: roads are dirt tracks (MAP_DIRT_ROADS)
var _map_woods := PackedByteArray()   ## aerial map: 1 = forest, per coverage cell (see MAP_FLOOD_FOREST)
var _map_flood_inks: Array[int] = []  ## assistant: water stickers used so far, so each flood takes a new one
var _map_city := Vector2(-1, -1)      ## assistant: the city's middle (canvas-width units), once a town becomes one
var _map_city_rings := 0             ## assistant: rings of blocks the city has
var _map_city_angle := 0.0
var _map_city_grounds: Array[int] = []   ## assistant: the city's pavement stickers
var _map_city_pens: Array[int] = []  ## assistant: the city's street stickers
var _map_streets := {}               ## assistant: city streets already laid
var _map_coppers: Array[int] = []     ## assistant: the circuit board's trace stickers
var _map_chips: Array[Vector2] = []   ## assistant: chip centres on the board (canvas-width units)
var _map_style := false               ## this painting is an aerial map (see MAP_MISTAKES)
var _map_rounds := 0                  ## assistant: rounds painted on the current map (0 = no map yet)
static var _colors: Dictionary = {}
static var _silhouettes: Dictionary = {}   ## sticker id -> traced outline, see _silhouette()   ## sticker id -> colour summary, see _color()


# --- Interface used by AutoplayBot ---

## Plan a painting for `system`, the canvas the bot is standing in front of.
func begin_painting(system: PaintingSystem2D) -> void:
	_frame = _canvas_frame(system)
	_aspect = _frame.height / _frame.width
	_min_size = system.min_scale * system.sticker_scale * system.plane_width / _frame.width
	# Don't bury a painting someone else started: just add to it
	plan_painting(_aspect, not system.placed_layers.is_empty())


func stroke_count() -> int:
	return _plan.size()


## The i-th planned stroke, converted to the canvas's UV and rotation.
## Returns {sticker_index, waypoints: Array[Vector2] (UV), rotation_deg, scale,
## settle, pause_after}.
func next_stroke(system: PaintingSystem2D, i: int) -> Dictionary:
	var s := issue(i)
	if s.has("action"):
		return {"undo": true, "stare_uv": _to_uv(s.stare_pos), "stare": s.stare, "pause_after": randf_range(PAUSE_AFTER_MIN, PAUSE_AFTER_MAX)}
	var waypoints: Array[Vector2] = []
	var look_away_at := -1
	var stops := randi_range(CONSIDER_POINTS_MIN, CONSIDER_POINTS_MAX) if s.ponder else 0
	for k in stops:
		var spread := CONSIDER_SPREAD * float(stops - k) / float(stops)
		var p: Vector2 = s.pos + Vector2(randf_range(-spread, spread), randf_range(-spread, spread) / _aspect)
		waypoints.append(_to_uv(p.clamp(Vector2.ZERO, Vector2.ONE)))
	if s.precise:
		# Line it up: tiny corrections, each smaller than the last
		var nudges := randi_range(NUDGES_MIN, NUDGES_MAX)
		for k in nudges:
			var spread := NUDGE_SPREAD * float(nudges - k) / float(nudges)
			waypoints.append(_to_uv(s.pos + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))))
	if s.has("look_away"):
		# Got it lined up, glanced away, and it drifted
		waypoints.append(_to_uv(s.intended_pos))
		look_away_at = waypoints.size() - 1
	waypoints.append(_to_uv(s.pos))
	var settle := QUICK_SETTLE
	if s.precise:
		settle = randf_range(PRECISE_SETTLE_MIN, PRECISE_SETTLE_MAX)
	elif s.ponder:
		settle = randf_range(SETTLE_MIN, SETTLE_MAX)
	var stroke := {
		"sticker_index": s.sticker,
		"waypoints": waypoints,
		"rotation_deg": _frame.rotation_offset + _frame.rotation_sign * s.rot,
		"scale": clampf(s.size * _frame.width / (system.sticker_scale * system.plane_width), system.min_scale, system.max_scale),
		"settle": settle * (0.6 + focus * 0.8) * (1.3 - energy * 0.6),
		"pause_after": (randf_range(PAUSE_AFTER_MIN, PAUSE_AFTER_MAX) if s.ponder or s.precise else QUICK_PAUSE_AFTER) * (1.3 - energy * 0.6),
	}
	if look_away_at >= 0:
		stroke.look_away = s.look_away
		stroke.look_away_at = look_away_at
	if s.has("stare"):
		stroke.stare = s.stare
		stroke.stare_uv = _to_uv(s.stare_pos)
	return stroke


## Seconds to drag the ghost between two canvas points.
func drag_time(from_uv: Vector2, to_uv: Vector2) -> float:
	return maxf(from_uv.distance_to(to_uv) / DRAG_SPEED, DRAG_TIME_MIN)


func hover_time() -> float:
	return randf_range(HOVER_MIN, HOVER_MAX)


# --- The studio assistant ---
# The assistant (StickerWallManager) paints like the bot's studio paintings,
# every pick any sticker, but it never calls a painting done: when a round of
# making shapes and defining the forms that come out of them is finished, it
# steps back and starts another round over the top, somewhere else on the
# canvas, and keeps going until the player transfers the work. Some of the
# forms it found (ASSISTANT_KEEP_FORMS) are left alone by the next round's
# shapes; the rest can be buried, so only fragments of them survive. It
# places stickers directly, without a ghost, so strokes are just stamps in
# viewer space.

## Start (or pick up) the assistant's painting. `aspect` is canvas height /
## width; `placed` is what's already on its canvas, as viewer-space stamps.
## `style` "studio" paints the studio rounds above; "hall_of_fame" paints the
## way the bot did before the studio style (layered, meticulous and drawn
## abstractions, saved on branch autoplay-painter-v1), then keeps adding
## motifs and focal points over it. "aerial_map" lays a map and then keeps
## growing it (see "Aerial map").
func begin_assistant(aspect: float, placed: Array[Dictionary] = [], style: String = "studio") -> void:
	_assistant_style = style
	_aspect = aspect
	_min_size = MAP_MIN_SIZE if style == "aerial_map" else ASSISTANT_MIN_SIZE
	_map_rounds = 0
	_fresh_painting(false)
	_plan = placed.duplicate()
	for st in _plan:
		st.issued = true
	_next = _plan.size()
	# A canvas picked up from a save starts its next round off centre
	_cycle = 0 if placed.is_empty() else 1


## Whether the current round is used up and the next one needs planning.
## Planning a round takes about a second, so the assistant runs plan_round()
## on a worker thread (warm_up() every sticker on the main thread first, so
## the thread never reads a texture).
func needs_round() -> bool:
	return _next >= _plan.size()


func plan_round() -> void:
	_assistant_round()


## Work out everything the painter reads from a sticker's pixels (shape,
## colour, silhouette), so planning never has to touch its texture.
func warm_up(sticker: int) -> void:
	_mask(sticker)
	_color(sticker)
	_silhouette(sticker)


## The assistant's next stroke: a stamp {sticker, pos, rot, size} in viewer
## space, or {action: "undo"} to take the last sticker back off. Plans the
## next round right here if it hasn't been, so it never ends.
func assistant_stroke() -> Dictionary:
	if needs_round():
		_assistant_round()
	var i := _next
	_next += 1
	var s := issue(i)
	after_stroke(i)
	return s


func _assistant_round() -> void:
	"""Step back from what's on the canvas and paint another round over it:
	shapes first, then squint, define what came out, accent it."""
	_plan = _on_canvas()
	_forget_hidden()
	_next = _plan.size()
	if _assistant_style == "aerial_map":
		_map_round()
		return
	if _assistant_style == "hall_of_fame":
		# A whole painting on a bare canvas, then add-ons over it
		var placed := _plan
		var more := plan_painting(_aspect, not placed.is_empty(), false)
		placed.append_array(more)
		_plan = placed
		return
	var kept: Array[PackedVector2Array] = []
	for f in _forms:
		if randf() < ASSISTANT_KEEP_FORMS:
			kept.append(f)
	var plan := _plan
	_fresh_painting(_cycle > 0)
	_plan = plan
	_cycle += 1
	_forms = kept
	_keep_out = _form_grid() if not kept.is_empty() else PackedByteArray()
	late_fill = true
	_variety = true
	_any_sticker = true
	last_style = "assistant round %d" % _cycle
	_studio(_plan)
	if _cycle == 1:
		_finish_cover(_plan)


func _on_canvas() -> Array[Dictionary]:
	"""The stamps actually on the canvas: every undo takes the one before it back off."""
	var placed: Array[Dictionary] = []
	for s in _plan.slice(0, _next):
		if s.has("action"):
			if not placed.is_empty():
				placed.pop_back()
		else:
			placed.append(s)
	return placed


func _forget_hidden() -> void:
	"""Planning looks through every stamp, so a long-running canvas would get
	slower and slower. Past ASSISTANT_PLAN_LIMIT, forget the stamps that
	aren't on top anywhere (they're under the rest; the canvas keeps them)."""
	if _plan.size() <= ASSISTANT_PLAN_LIMIT:
		return
	var showing := {}
	for k in _top_stamps(_plan):
		showing[k] = true
	var kept: Array[Dictionary] = []
	for k in _plan.size():
		if showing.has(k) or k >= _plan.size() - ASSISTANT_PLAN_LIMIT / 4:
			kept.append(_plan[k])
	_plan = kept


# --- Planning (viewer space) ---

## The whole painting as a list of stamps, back to front. Each stamp is
## {sticker, pos: Vector2 (0..1 across and down), rot (degrees clockwise,
## 0 = upright), size (longest side, as a fraction of canvas width), ponder,
## precise}.
## `add_on` skips the background and structure, for canvases that already
## have something on them. `allow_studio` false never picks the studio style.
## Doesn't touch the scene, so tools can call it directly to preview plans.
func plan_painting(aspect: float, add_on: bool = false, allow_studio: bool = true) -> Array[Dictionary]:
	_aspect = aspect
	_cycle = 0
	_fresh_painting(add_on)
	var plan: Array[Dictionary] = []
	_plan = plan
	var family: String = _recent_families[-1]
	_meticulous_style = false
	if allow_studio and not add_on and randf() < MAP_CHANCE:
		_aerial_map(plan)
		return plan
	_meticulous_style = not add_on and randf() < METICULOUS_CHANCE
	if _meticulous_style:
		last_style = "meticulous " + _weighted(METICULOUS)
		_meticulous(plan, last_style.get_slice(" ", 1))
		last_style += ", " + family
		_jumble_order(plan, ORDER_JUMBLE_METICULOUS)
		if last_style.begins_with("meticulous catalog"):
			# A catalog is a stage, never the final statement: build over it
			last_style += ", built over"
			_build_over(plan)
		_finish_cover(plan)
		return plan
	if allow_studio and not add_on and randf() < STUDIO_CHANCE:
		last_style = "studio, " + family
		late_fill = true
		_variety = true
		_any_sticker = randf() < STUDIO_ANY_STICKER
		if _any_sticker:
			last_style += ", any sticker"
		_studio(plan)
		_finish_cover(plan)
		return plan
	last_style = "layered, " + family
	var horizon := -1.0
	if late_fill:
		# No ground: build straight onto the bare canvas, fill what's left at the end
		last_style += ", fills late"
		horizon = _structure(plan, _weighted(LATE_STRUCTURES), -1)
	elif not add_on:
		var fill := _pick("fill_base", [], "key")
		var fill_rot := _layer_rotation(false)
		_tile(plan, fill, Rect2(0, 0, 1, 1), randf_range(0.7, 1.1), fill_rot)
		_patch_bare(plan, fill, fill_rot)
		_ground = fill
		_ground_rot = fill_rot
		if randf() < 0.3:
			_tile(plan, _pick("texture", [], "second"), Rect2(0, 0, 1, 1), randf_range(0.6, 1.0), _layer_rotation())
		horizon = _structure(plan, _weighted(STRUCTURES), fill)
	if add_on or randf() >= ABSTRACTION_CHANCE:
		_motif(plan, _weighted(ARRANGEMENTS), horizon)
		_accents(plan, _focal(plan, horizon))
		_jumble_order(plan, ORDER_JUMBLE)
		if not add_on:
			_finish_cover(plan)
		return plan
	# Abstraction as the focal point: burst now, do other things, come back and carve
	last_style += ", abstraction"
	var spot := _focal_spot(horizon, 0.2)
	var bursts: Array[Dictionary] = [_burst(plan, spot, randf_range(0.24, 0.32))]
	if randf() < SECOND_ABSTRACTION_CHANCE:
		var balance := Vector2(1.0 - spot.x, clampf(1.0 - spot.y + randf_range(-0.1, 0.1), 0.2, 0.8))
		bursts.append(_burst(plan, balance, randf_range(0.14, 0.18)))
	_motif(plan, _weighted(ARRANGEMENTS), horizon)
	for b in bursts:
		_carve(plan, b)
	_accents(plan, spot)
	_jumble_order(plan, ORDER_JUMBLE)
	_finish_cover(plan)
	return plan


func _fresh_painting(add_on: bool) -> void:
	"""Forget the last painting and get ready for a new one: colours, mood,
	forms and fills."""
	if not _palette.is_empty():
		_recent_stickers.append(_palette.duplicate())
		if _recent_stickers.size() > STUDIO_FRESH_PAINTINGS:
			_recent_stickers.pop_front()
	_palette.clear()
	_choose_scheme()
	_ground = -1
	last_carve_source = ""
	late_fill = not add_on and randf() < LATE_FILL_CHANCE
	_add_on = add_on
	_looks = 0
	_fill_inks.clear()
	_forms.clear()
	_keep_out = PackedByteArray()
	_form_ink = -1
	_zoom = 1.0
	_any_sticker = false
	_variety = false
	_map_style = false
	_found.clear()
	_focus_base = randf_range(0.35, 0.85)
	_energy_base = randf_range(0.25, 0.8)
	focus = _focus_base
	energy = _energy_base


func _build_over(plan: Array[Dictionary]) -> void:
	"""Take a finished meticulous layer somewhere: a burst drawn into a form
	with marks, or a big subject, over the top of it, plus accents."""
	var spot := _focal_spot(-1.0, 0.2)
	if randf() < 0.7:
		var b := _burst(plan, spot, randf_range(0.24, 0.32))
		_carve(plan, b)
	else:
		spot = _focal(plan, -1.0)
	_accents(plan, spot)


func _structure(plan: Array[Dictionary], kind: String, base_fill: int) -> float:
	"""Lays down the painting's big shapes. Returns the horizon height
	(0..1 down) when there is one, so later layers can sit on it, else -1."""
	# With no ground under them, the big shapes have to be solid or the
	# canvas shows through their lace
	var big := "fill_base" if late_fill else "fill"
	match kind:
		"horizon":
			var h := randf_range(0.55, 0.72)
			var ground := _pick(big, [base_fill], "second")
			var ground_rot := _layer_rotation(false)
			_tile(plan, ground, Rect2(0, h, 1, 1.0 - h), randf_range(0.5, 0.8), ground_rot)
			if randf() < 0.6:
				_row(plan, _pick("band", [], "accent"), h, randf_range(0.3, 0.5), 0.0)
			return h
		"split":
			var x := randf_range(0.4, 0.6)
			var side := _pick(big, [base_fill], "second")
			var side_rot := _layer_rotation(false)
			_tile(plan, side, Rect2(x, 0, 1.0 - x, 1), randf_range(0.5, 0.8), side_rot)
		"stripes":
			var band := _pick("band", [], "second")
			var angle: float = [0.0, 90.0, randf_range(25.0, 60.0) * (1 if randf() < 0.5 else -1)].pick_random()
			var count := randi_range(4, 7)
			var dir := Vector2.from_angle(deg_to_rad(angle + 90.0))
			for i in count:
				var offset := (float(i) + 0.5) / count - 0.5
				var c := Vector2(0.5, 0.5) + dir * offset * 1.1
				_stamp(plan, band, Vector2(c.x, c.y), angle, randf_range(1.3, 1.6), false)
		"border":
			var band := _pick("band", [], "accent")
			var size := randf_range(0.35, 0.55)
			var inset := 0.05
			_row(plan, band, inset, size, 0.0)
			_row(plan, band, 1.0 - inset, size, 180.0)
			_column(plan, band, inset, size, -90.0)
			_column(plan, band, 1.0 - inset, size, 90.0)
		"panels":
			var a := _pick(big, [base_fill], "key")
			var b := _pick(big, [base_fill, a], "second")
			for q in 4:
				var cell := Rect2((q % 2) * 0.5 + 0.03, (q / 2) * 0.5 + 0.03, 0.44, 0.44)
				_tile(plan, a if (q == 0 or q == 3) else b, cell, 0.35, 0.0, 0.02)
	return -1.0


func _motif(plan: Array[Dictionary], kind: String, horizon: float) -> void:
	"""One sticker repeated: the rhythm in most Hall of Fame paintings."""
	if kind == "none":
		return
	var sticker := _pick("motif", [], ["second", "accent"].pick_random())
	var size := randf_range(0.14, 0.26)
	var rot := _upright_rotation()
	match kind:
		"row":
			var y := horizon - size * 0.4 if horizon > 0 else randf_range(0.2, 0.8)
			var n := randi_range(3, 6)
			for i in n:
				_stamp(plan, sticker, Vector2((i + 0.5) / n, y), rot, size, i == 0)
		"grid":
			var n := randi_range(2, 3)
			var m := 0.22
			for gy in n:
				for gx in n:
					var p := Vector2(m + (1.0 - 2 * m) * gx / (n - 1), m + (1.0 - 2 * m) * gy / (n - 1))
					_stamp(plan, sticker, p, rot, size, gx + gy == 0)
		"ring":
			var n := randi_range(5, 8)
			var radius := randf_range(0.28, 0.36)
			var spin := randf() < 0.5   # turn each one to follow the ring
			for i in n:
				var a := TAU * i / n - PI / 2
				var p := Vector2(0.5, 0.5) + Vector2(cos(a), sin(a) * _aspect_fix()) * radius
				_stamp(plan, sticker, p, rad_to_deg(a) + 90.0 if spin else rot, size, i == 0)
		"stack":
			var n := 3
			for i in n:
				_stamp(plan, sticker, Vector2(0.5, (i + 0.5) / n), rot, randf_range(0.4, 0.6), i == 0)
		"mirror":
			var pairs := randi_range(1, 3)
			for i in pairs:
				var p := Vector2(randf_range(0.12, 0.35), randf_range(0.15, 0.85))
				var r := randf_range(-30.0, 30.0)
				_stamp(plan, sticker, p, r, size, true)
				_stamp(plan, sticker, Vector2(1.0 - p.x, p.y), -r, size, false)
		"scatter":
			for i in randi_range(4, 7):
				_stamp(plan, sticker, Vector2(randf_range(0.1, 0.9), randf_range(0.1, 0.9)), randf_range(0.0, 360.0), size * randf_range(0.7, 1.2), i == 0)


func _focal_spot(horizon: float, half_height: float) -> Vector2:
	"""A strong spot for the focal point: the centre or a thirds line,
	sitting on the horizon when there is one."""
	var x: float = [1.0 / 3.0, 0.5, 0.5, 2.0 / 3.0].pick_random()
	var y := horizon - half_height if horizon > 0 else randf_range(0.4, 0.6)
	return Vector2(x, y)


func _focal(plan: Array[Dictionary], horizon: float) -> Vector2:
	"""One big subject on a strong spot. Returns where it went."""
	var size := randf_range(0.45, 0.7)
	var p := _focal_spot(horizon, size * 0.35)
	var x := p.x
	var y := p.y
	if randf() < 0.3:
		# A "figure": a few subjects stacked into one shape
		var parts := randi_range(2, 3)
		var part_size := size * 0.6
		for i in parts:
			var py := y + (i - (parts - 1) / 2.0) * part_size * 0.6
			_stamp(plan, _pick("subject", [], "accent"), Vector2(x + randf_range(-0.03, 0.03), py), randf_range(-12.0, 12.0), part_size, true)
	else:
		_stamp(plan, _pick("subject", [], "accent"), p, randf_range(-10.0, 10.0), size, true)
	return p


func _accents(plan: Array[Dictionary], focus: Vector2) -> void:
	var line := _pick("line", [], "accent")
	for i in randi_range(1, 4):
		var p := focus + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		_stamp(plan, line, p.clamp(Vector2(0.08, 0.08), Vector2(0.92, 0.92)), randf_range(0.0, 360.0), randf_range(0.15, 0.3), i == 0)


func _meticulous(plan: Array[Dictionary], kind: String) -> void:
	"""An even ground, then stickers set out in exact order: same sizes,
	square rotations, equal spacing, placed one by one in reading order."""
	# A calm ground: only the stickers made to be fills, laid square
	_ground = _pick("ground_base", [], "key")
	_ground_rot = [0.0, 90.0].pick_random()
	_tile(plan, _ground, Rect2(0, 0, 1, 1), randf_range(0.8, 1.1), _ground_rot, 0.0, 0.0)
	_patch_bare(plan, _ground, _ground_rot)
	match kind:
		"catalog":
			# A specimen chart: a different sticker in every cell, sorted by colour
			var n := randi_range(4, 6)
			var cell := 0.84 / n
			var chosen: Array[int] = []
			for i in n * n:
				chosen.append(_pick(["motif", "subject"].pick_random(), chosen, ["key", "second", "accent"].pick_random()))
			chosen.sort_custom(func(a, b): return _color(a).hue < _color(b).hue)
			for i in chosen.size():
				var p := Vector2(0.08 + cell * (i % n + 0.5), 0.08 + cell * (i / n + 0.5))
				_stamp(plan, chosen[i], p, 0.0, cell * 0.8, false, true)
		"checker":
			# Two stickers alternating on an exact grid
			var a := _pick("motif", [], "second")
			var b := _pick("motif", [a], "accent")
			var n := randi_range(4, 7)
			var cell := 0.9 / n
			for gy in n:
				for gx in n:
					var p := Vector2(0.05 + cell * (gx + 0.5), 0.05 + cell * (gy + 0.5))
					_stamp(plan, a if (gx + gy) % 2 == 0 else b, p, 0.0, cell * 0.85, false, true)
		"rings":
			# Concentric rings, one sticker per ring, each turned to follow it
			var rings := randi_range(2, 3)
			_stamp(plan, _pick("subject", [], "accent"), Vector2(0.5, 0.5), 0.0, 0.2, false, true)
			for r in rings:
				var radius := 0.15 * (r + 1)
				var sticker := _pick("motif", [], ["second", "accent"][r % 2])
				var count := 6 * (r + 1)
				var size := clampf(TAU * radius / count * 1.1, _min_size, 0.2)
				for i in count:
					var a := TAU * i / count - PI / 2
					_stamp(plan, sticker, Vector2(0.5, 0.5) + Vector2(cos(a), sin(a) * _aspect_fix()) * radius, rad_to_deg(a) + 90.0, size, false, true)
		"mandala":
			# Four-fold symmetry: every piece goes down four times, a quarter turn apart
			for e in randi_range(3, 5):
				var sticker := _pick(["motif", "subject", "line"].pick_random(), [], ["second", "accent"].pick_random())
				var offset := Vector2(randf_range(0.06, 0.34), randf_range(0.06, 0.34))
				var rot: float = [0.0, 45.0, 90.0].pick_random()
				var size := randf_range(0.12, 0.22)
				for k in 4:
					var o := offset.rotated(PI / 2 * k)
					_stamp(plan, sticker, Vector2(0.5 + o.x, 0.5 + o.y * _aspect_fix()), rot + 90.0 * k, size, false, true)
			_stamp(plan, _pick("subject", [], "accent"), Vector2(0.5, 0.5), 0.0, randf_range(0.18, 0.28), false, true)
		"gradient":
			# Rows of one sticker growing steadily in size from left to right
			var rows := randi_range(3, 5)
			for r in rows:
				var sticker := _pick("motif", [], ["second", "accent"][r % 2])
				var y := (r + 0.5) / rows
				var count := randi_range(5, 8)
				for i in count:
					var t := float(i) / (count - 1)
					_stamp(plan, sticker, Vector2(0.08 + 0.84 * t, y), 0.0, lerpf(_min_size, 0.9 / rows, t), false, true)


# --- The brain: mood, hand and order ---

func _drift_mood() -> void:
	focus = clampf(focus + randf_range(-MOOD_DRIFT, MOOD_DRIFT) + (_focus_base - focus) * MOOD_PULL, 0.0, 1.0)
	energy = clampf(energy + randf_range(-MOOD_DRIFT, MOOD_DRIFT) + (_energy_base - energy) * MOOD_PULL, 0.0, 1.0)


func _wobble(s: Dictionary) -> void:
	"""An imperfect hand: every placement lands a little off what was meant,
	more so when focus is low. Careful strokes wobble less, never zero."""
	var unsteady := (1.15 - focus) * (HAND_WOBBLE_PRECISE if s.get("precise", false) else 1.0)
	s.pos += Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0) * _aspect_fix()) * HAND_WOBBLE * unsteady
	s.rot += randfn(0.0, 1.0) * ROT_WOBBLE * unsteady
	s.size = maxf(s.size * (1.0 + randfn(0.0, 1.0) * SIZE_WOBBLE * unsteady), _min_size)


func _jumble_order(plan: Array[Dictionary], amount: float, from: int = 0) -> void:
	"""Loosely shuffle runs of the same sticker (a row, a grid, a tiled
	layer, a burst) so they go down roughly, not strictly, in order.
	Strokes before `from` are already down and stay put."""
	var start := from
	while start < plan.size():
		var end := start + 1
		while end < plan.size() and plan[end].sticker == plan[start].sticker:
			end += 1
		if end - start >= 3:
			var run := plan.slice(start, end)
			var keyed := []
			for k in run.size():
				keyed.append([k + randfn(0.0, amount), run[k]])
			keyed.sort_custom(func(a, b): return a[0] < b[0])
			for k in keyed.size():
				plan[start + k] = keyed[k][1]
		start = end


# --- Studio (learned from watching zack paint) ---

func _studio(plan: Array[Dictionary]) -> void:
	"""Paint the way zack did, without a goal: big and few first, bury it,
	then step back and see whether a form came out of it by itself, and only
	then bring that form out. Then rhyme, frame into scenes and calm the rest
	around it. The bot never decides what the form will be (see _find_form).
	`from` is where this painting starts in `plan` (the assistant paints
	round after round into one plan)."""
	var from := plan.size()
	_guard = not _keep_out.is_empty()
	var left := randf() < 0.5   # which side the edge strip goes
	var side := 1.0 if left else -1.0
	var edge_x := 0.1 if left else 0.9
	# 1. Skeleton: an edge strip, a big subject, a bar across it
	var strip := _pick("band", [], "second")
	_stamp(plan, strip, Vector2(edge_x, 0.5), 90.0 + randf_range(-3.0, 3.0), randf_range(1.1, 1.3), true)
	var core := Vector2(randf_range(0.42, 0.58), randf_range(0.4, 0.5))
	if _cycle > 1:
		# The assistant's later rounds start somewhere else on the canvas
		core += Vector2(randf_range(-1.0, 1.0) * ASSISTANT_CORE_SPREAD.x, randf_range(-1.0, 1.0) * ASSISTANT_CORE_SPREAD.y)
	var subject := _pick("subject", [], "key")
	_stamp(plan, subject, core, _upright_rotation(), randf_range(0.5, 0.65), true)
	_stamp(plan, _pick("band", [strip], "accent"), core + Vector2(randf_range(-0.05, 0.1), randf_range(0.1, 0.16)), randf_range(-6.0, 6.0), randf_range(0.5, 0.7), true)
	# 2. Big line stickers as structure, crossing the zones
	for k in randi_range(1, 3):
		var line := _pick("line", [], ["accent", "second"].pick_random())
		_stamp(plan, line, core + Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.15)), randf_range(0.0, 360.0), randf_range(0.45, 0.8), true)
	# 3. Bury it: a big striped/textured panel over one side of the subject,
	# then big pale veils, so the first layer survives only as fragments
	var panel := _pick(["texture", "band"].pick_random(), [strip], "second")
	_stamp(plan, panel, Vector2(core.x + side * 0.2, core.y - 0.05), randf_range(-15.0, 15.0) + (90.0 if randf() < 0.5 else 0.0), randf_range(0.65, 0.85), true)
	var veil := _pick_by("veil", func(i): return _solidity(i) >= 0.6, [], "any")
	var veils: Array[Vector2] = [core + Vector2(randf_range(-0.05, 0.05), randf_range(0.05, 0.15)), Vector2(1.0 - edge_x, randf_range(0.3, 0.7)), Vector2(randf_range(0.3, 0.7), randf_range(0.8, 0.95))]
	for v in veils.slice(0, randi_range(1, 2)):
		_stamp(plan, veil, v, randf_range(0.0, 360.0), randf_range(0.6, 0.85), true)
	# Close the canvas now, under everything that comes next, in a dark or
	# middle value, so the painting has real masses of light and dark for
	# forms to come out of (not one pale wash)
	var under: Array[int] = [_pick_by("dense", func(i): var t := _texture_size(i); return _color(i).light < STUDIO_UNDER_DARK and maxf(t.x, t.y) / minf(t.x, t.y) < 3.0, [], "second")]
	var guard := _guard
	_guard = false   # the fill checks the forms itself
	_fill_spots(plan, _coverage(plan), under, 0.2, 0.9, STUDIO_FIELDS, NAN, "under", true)
	_guard = guard
	# Pieces of the first layer come back through the veil
	_stamp(plan, strip, Vector2(edge_x, randf_range(0.2, 0.8)), 90.0 + randf_range(-3.0, 3.0), randf_range(0.5, 0.7), true)
	_stamp(plan, panel, Vector2(core.x + side * 0.25, core.y - 0.25), randf_range(-15.0, 15.0), randf_range(0.4, 0.55), true)
	var trial_at := plan.size()
	# 4. Rhymes: the panel again, smaller, in the opposite corner, and a
	# texture balancing it
	var opposite := Vector2(clampf(1.0 - core.x + side * 0.15, 0.1, 0.9), randf_range(0.75, 0.85))
	_stamp(plan, panel, opposite, randf_range(0.0, 360.0), randf_range(0.25, 0.35), true)
	_stamp(plan, _pick("texture", [panel], "accent"), Vector2(1.0 - opposite.x, randf_range(0.15, 0.25)), randf_range(0.0, 360.0), randf_range(0.25, 0.35), true)
	# 5. Windows: a loose grid of frames over the lower part, each holding
	# one contrasting piece
	var frame := _pick_frame()
	var top := randf_range(0.35, 0.5)
	var x0 := randf_range(0.04, 0.4)
	var x1 := minf(x0 + randf_range(0.4, 0.6), 0.96)
	var cols := clampi(int((x1 - x0) / 0.18), 2, 3)
	var rows := randi_range(2, 3)
	var cell := Vector2((x1 - x0) / cols, (1.0 - top) / rows)
	var tex := _texture_size(frame)
	var used: Array = [frame]
	for r in rows:
		for c in cols:
			var w := Vector2(x0 + (c + 0.5) * cell.x, top + (r + 0.5) * cell.y) + Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0)) * 0.006
			var size := maxf(cell.x, cell.y * _aspect)
			var rot := 90.0 if (tex.y > tex.x) != (cell.y * _aspect > cell.x) else 0.0
			_stamp(plan, frame, w, rot + randf_range(-2.0, 2.0), size * randf_range(0.97, 1.03), false, true)
			var piece := _pick(["subject", "motif", "texture"].pick_random(), used.slice(maxi(0, used.size() - 2)), ["key", "second", "accent"].pick_random())
			used.append(piece)
			_stamp(plan, piece, w, _upright_rotation(), minf(cell.x, cell.y * _aspect) * randf_range(0.55, 0.75), true)
	# 6. Calm sky: pale wisps across the top
	var wisp := _pick_by("veil", func(i): return _solidity(i) >= 0.7, [veil], "any")
	var n := randi_range(2, 3)
	for k in n:
		_stamp(plan, wisp if k % 2 == 0 else veil, Vector2((k + 0.5) / n + randf_range(-0.04, 0.04), randf_range(0.06, 0.12)), randf_range(-20.0, 20.0) + (180.0 if k % 2 else 0.0), randf_range(0.3, 0.45), false)
	_stamp(plan, _pick("veil", [veil, wisp], "any"), Vector2(edge_x, randf_range(0.75, 0.88)), randf_range(0.0, 360.0), randf_range(0.3, 0.4), true)
	_jumble_order(plan, ORDER_JUMBLE, from)
	_guard = false
	# 7. Squint and refine, over and over: step back, find a form that came
	# out by itself, define it, calm what's around it, then look again and
	# tend to another part of the picture. Each round looks closer than the
	# last (smaller forms, finer squint), working into what's left between
	# the forms already defined
	var center := core
	for pass_i in FORM_PASSES:
		_zoom = pow(FORM_ZOOM, pass_i)
		var found := _find_form(plan)
		if found.is_empty():
			continue
		_forms.append(found.outline)
		_found.append(found)
		_keep_out = _form_grid()
		if _form_ink < 0:
			_form_ink = found.ink
			var box := _bounds(found.outline)
			center = Vector2(box.get_center().x, box.get_center().y * _aspect_fix())
		_bring_out(plan, found)
		if randf() < FORM_REFINE_CHANCE:
			_refine(plan)
	_zoom = 1.0
	# 8. Personalities: each defined form gets a few subtle decorative
	# accents of its own
	_accent_forms(plan)
	if not _forms.is_empty():
		last_style += ", found %d form%s" % [_forms.size(), "" if _forms.size() == 1 else "s"]
	# A trial: something big goes over the middle of it all, gets a long
	# look, and comes back off (it would have killed the painting)
	if randf() < STUDIO_TRIAL_CHANCE:
		var trial := _pick("texture", [], "any")
		var at := center + Vector2(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04))
		plan.insert(trial_at, {"sticker": trial, "pos": at, "rot": randf_range(0.0, 360.0), "size": randf_range(0.6, 0.8), "ponder": true, "precise": false, "phase": "trial", "fix": true})
		plan.insert(trial_at + 1, {"action": "undo", "fix": true, "stare": randf_range(STARE_MIN, STARE_MAX) * 1.5, "stare_pos": at})


func _find_form(plan: Array[Dictionary]) -> Dictionary:
	"""Step back and squint. Every spot of the canvas is reduced to the value
	(light, middle, dark) of whatever sticker ended up on top there, and the
	bot looks for a patch of one value that the shapes around it happened to
	cut into a shape of its own: not too big or too small, mostly inside the
	picture, and made from several overlapping pieces (one sticker sitting
	there whole isn't a discovery, it's just the sticker). It doesn't know or
	care what the shape looks like. Returns {outline (canvas-width units),
	ink (the sticker most of it is), light}, or {} if nothing came out."""
	var rows := _cover_rows()
	var look := _squint(plan)
	var top: PackedInt32Array = look.top
	var value: PackedInt32Array = look.value
	# Parts already defined (and the ring around them) are done: look elsewhere
	var near := _near_forms()
	if not near.is_empty():
		for i in value.size():
			if near[i] <= maxf((FORM_RING.y + 1.0) * _zoom, 1.5):
				value[i] = -1
	var seen := PackedByteArray()
	seen.resize(top.size())
	var best := {}
	var best_score := -INF
	for start in top.size():
		if seen[start] or value[start] < 0:
			continue
		# Flood out the patch of this value
		var cells: Array[int] = [start]
		seen[start] = 1
		var k := 0
		var edges := 0
		var border := 0
		while k < cells.size():
			var i: int = cells[k]
			k += 1
			var c := i % COVER_GRID
			var r := i / COVER_GRID
			if c == 0 or r == 0 or c == COVER_GRID - 1 or r == rows - 1:
				border += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: int = c + d.x
				var nr: int = r + d.y
				if nc < 0 or nr < 0 or nc >= COVER_GRID or nr >= rows:
					edges += 1
					continue
				var j := nr * COVER_GRID + nc
				if value[j] != value[start]:
					edges += 1
				elif not seen[j]:
					seen[j] = 1
					cells.append(j)
		var share := float(cells.size()) / top.size()
		if share < maxf(FORM_SMALLEST * _zoom, FORM_TINIEST) or share > FORM_LARGEST * _zoom or float(border) / cells.size() > FORM_BORDER:
			continue
		var compact := 4.0 * PI * cells.size() / float(edges * edges)
		if compact < FORM_COMPACT.x or compact > FORM_COMPACT.y:
			continue
		var stamps := {}
		var inks := {}
		for i in cells:
			stamps[top[i]] = true
			inks[plan[top[i]].sticker] = inks.get(plan[top[i]].sticker, 0) + 1
		if stamps.size() < 2:
			continue
		# Mid-sized, with a few stray ideas: no preference for any kind of shape
		var score := -absf(log(share / (FORM_SIZE * _zoom))) + randf() * 0.6
		if not near.is_empty():
			# The further from what's already been worked on, the better
			var far := 0.0
			for i in cells:
				far += near[i]
			score += minf(far / cells.size() / COVER_GRID, 0.3) * 2.0
		if score > best_score:
			var ink: int = inks.keys()[0]
			for s in inks:
				if inks[s] > inks[ink]:
					ink = s
			best_score = score
			best = {"cells": cells, "ink": ink, "light": _color(ink).light}
	if best.is_empty():
		return {}
	# Trace its outline, softened a little, the way it reads from a step back
	var img := Image.create(COVER_GRID, rows, false, Image.FORMAT_LA8)
	for i in best.cells:
		img.set_pixel(i % COVER_GRID, i / COVER_GRID, Color(1, 1, 1, 1))
	img.resize(COVER_GRID * 4, rows * 4, Image.INTERPOLATE_BILINEAR)
	var bits := BitMap.new()
	bits.create_from_image_alpha(img, 0.5)
	var outline := PackedVector2Array()
	var area := 0.0
	for poly in bits.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), 1.5):
		if absf(_signed_area(poly)) > area:
			area = absf(_signed_area(poly))
			outline = poly
	if outline.size() < 3:
		return {}
	var scale := Vector2(1.0 / (COVER_GRID * 4), _aspect / (rows * 4))
	for p in outline.size():
		outline[p] *= scale
	best.outline = outline
	return best


func _squint(plan: Array[Dictionary]) -> Dictionary:
	"""What the painting looks like from a step back: for each coverage cell,
	the stamp on top (top), its value 0 dark / 1 middle / 2 light (raw), and
	that value after squinting, where each spot takes the value most of its
	neighbourhood has (value). -1 is bare canvas."""
	var rows := _cover_rows()
	var top := _top_stamps(plan)
	var value := PackedInt32Array()
	value.resize(top.size())
	for i in top.size():
		if top[i] < 0:
			value[i] = -1
		else:
			var light: float = _color(plan[top[i]].sticker).light
			value[i] = 0 if light < FORM_VALUES[0] else (1 if light < FORM_VALUES[1] else 2)
	var raw := value.duplicate()
	# Squint: each spot takes the value most of its neighbourhood has, so
	# specks and ragged edges melt into masses
	for pass_i in maxi(1, roundi(FORM_SQUINT * _zoom + 0.4)):
		var blurred := value.duplicate()
		for i in value.size():
			var c := i % COVER_GRID
			var r := i / COVER_GRID
			var votes := [0, 0, 0]
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					var nc := c + dc
					var nr := r + dr
					if nc >= 0 and nr >= 0 and nc < COVER_GRID and nr < rows and value[nr * COVER_GRID + nc] >= 0:
						votes[value[nr * COVER_GRID + nc]] += 1
			var most := votes.find(votes.max())
			if votes[most] >= 5:
				blurred[i] = most
		value = blurred
	return {"top": top, "raw": raw, "value": value}


func _near_forms() -> PackedFloat32Array:
	"""How far each coverage cell is from the found forms, in cells (0 inside
	one). Empty if nothing has been found yet."""
	if _keep_out.is_empty():
		return PackedFloat32Array()
	var inside := PackedByteArray()
	inside.resize(_keep_out.size())
	for i in inside.size():
		inside[i] = CELL_FULL if _keep_out[i] != CELL_FULL else 0
	return _clearance(inside)


func _refine(plan: Array[Dictionary]) -> void:
	"""Calm what's around the forms: wherever a speck's value disagrees with
	the mass it sits in (what the squint melted away), cover it with that
	mass's own sticker, so the busy bits settle into the larger shapes.
	Never touches a form."""
	var look := _squint(plan)
	var near := _near_forms()
	var top: PackedInt32Array = look.top
	var raw: PackedInt32Array = look.raw
	var value: PackedInt32Array = look.value
	for v in 3:
		# The mass's ink: the sticker most often on top where this value is
		var counts := {}
		var turns := {}
		var grid := PackedByteArray()
		grid.resize(top.size())
		var specks := 0
		for i in top.size():
			if value[i] == v and raw[i] == v:
				var s: int = plan[top[i]].sticker
				counts[s] = counts.get(s, 0) + 1
				turns[s] = plan[top[i]].rot
			var speck := value[i] == v and raw[i] != v and (near.is_empty() or near[i] > FORM_RING.y + 1.0)
			grid[i] = 0 if speck else CELL_FULL
			if speck:
				specks += 1
		if specks == 0 or counts.is_empty():
			continue
		# The calmest sticker that's a real part of the mass
		var total := 0
		for s in counts:
			total += counts[s]
		var ink: int = counts.keys()[0]
		for s in counts:
			if counts[s] >= total * 0.15 and (counts[ink] < total * 0.15 or _color(s).busy < _color(ink).busy):
				ink = s
		# Fewer, bigger pieces turned the way the mass already runs, so they
		# join it instead of chopping it up
		_fill_spots(plan, grid, [ink], 0.2, 0.5, FORM_REFINE / 3, turns[ink], "refine", true, 1)


func _top_stamps(plan: Array[Dictionary]) -> PackedInt32Array:
	"""For each coverage cell, the index of the planned stamp on top at its
	centre (-1 for bare canvas)."""
	var rows := _cover_rows()
	var top := PackedInt32Array()
	top.resize(COVER_GRID * rows)
	top.fill(-1)
	var cell_w := 1.0 / COVER_GRID
	var cell_h := _aspect / rows
	for k in plan.size():
		var s: Dictionary = plan[k]
		if s.has("action"):
			continue
		var tex := _texture_size(s.sticker)
		var texel: float = s.size / maxf(tex.x, tex.y)
		var center := Vector2(s.pos.x, s.pos.y * _aspect)
		var reach: float = s.size * 0.71
		var mask := _mask(s.sticker)
		var turn := -deg_to_rad(s.rot)
		for r in range(maxi(0, floori((center.y - reach) / cell_h)), mini(rows, ceili((center.y + reach) / cell_h))):
			for c in range(maxi(0, floori((center.x - reach) / cell_w)), mini(COVER_GRID, ceili((center.x + reach) / cell_w))):
				var local := (Vector2((c + 0.5) * cell_w, (r + 0.5) * cell_h) - center).rotated(turn) / texel / tex + Vector2(0.5, 0.5)
				if local.x < 0.0 or local.y < 0.0 or local.x >= 1.0 or local.y >= 1.0:
					continue
				if mask[int(local.y * MASK_RES) * MASK_RES + int(local.x * MASK_RES)] == 1:
					top[r * COVER_GRID + c] = k
	return top


func _bring_out(plan: Array[Dictionary], found: Dictionary) -> void:
	"""Make a found form read: contrasting marks worked into a ring just
	outside it, right up to its edge and never over it, so it separates from
	what it grew out of; then sometimes part of its edge drawn with pen marks."""
	var light: float = found.light
	var differs := func(i): return absf(_color(i).light - light) >= FORM_CONTRAST
	var strips := func(i): var t := _texture_size(i); return differs.call(i) and maxf(t.x, t.y) / minf(t.x, t.y) >= 1.8
	var inks: Array[int] = []
	for k in randi_range(1, 2):
		var ink := _pick_by("solid", strips, inks + [found.ink], ["second", "accent"][k - 1])
		if differs.call(ink) and not ink in inks:
			inks.append(ink)
	if inks.is_empty():
		var ink := _pick_by("solid", differs, [found.ink], "any")
		if not differs.call(ink):
			return
		inks.append(ink)
	# The ring: strips laid end to end along the edge, just outside it and
	# turned with it, so they read as one band of contrast round the form
	# rather than a scatter of marks
	var size := maxf(randf_range(FORM_STRIP.x, FORM_STRIP.y) * sqrt(_zoom), _min_size)
	var tex := _texture_size(inks[0])
	var thick := size * minf(tex.x, tex.y) / maxf(tex.x, tex.y)
	var shapes := Geometry2D.offset_polygon(found.outline, thick * 0.6, Geometry2D.JOIN_ROUND)
	if shapes.is_empty():
		return
	# Before the line goes down, look along one side of it (inside the form
	# or just outside the line) and make that side continuous
	_continue_side(plan, found, thick * COVER_GRID)
	var points := _resample(shapes[0], size * LINE_OVERLAP)
	var n := points.size()
	for k in n:
		var p := points[k]
		if p.y < -0.02 or p.y > _aspect + 0.02:
			continue
		var tangent := (points[(k + 1) % n] - points[(k - 1 + n) % n]).normalized()
		var outward := tangent.orthogonal()
		if Geometry2D.is_point_in_polygon(p + outward * thick, found.outline):
			outward = -outward
		var sticker: int = inks[0] if inks.size() == 1 or randf() < 0.75 else inks[1]
		var rot := rad_to_deg(tangent.angle()) + _long_axis_spin(inks[0]) + randfn(0.0, 5.0)
		# Keep the line unbroken: where a mark would cut into a form, nudge
		# it outward and shorten it a little rather than leave a gap
		for t in FORM_LINE_TRIES:
			var q := p + outward * thick * 0.4 * t
			var mark := {"sticker": sticker, "pos": Vector2(q.x, q.y * _aspect_fix()), "rot": rot, "size": size * pow(0.9, t)}
			if not _intrudes(mark, 1):
				_stamp(plan, sticker, mark.pos, rot, mark.size, false, true)
				plan[-1].phase = "carve"
				break
	if randf() < FORM_LINE_CHANCE:
		_draw_edge(plan, _pick("pen", [], "any"), found.outline, randf_range(0.35, 0.8))


func _accent_forms(plan: Array[Dictionary]) -> void:
	"""Give the found forms personalities: each one (ACCENT_CHANCE) picks a
	kind of accent and a small sticker of its own and gets a few subtle
	marks of it, so no two forms are decorated alike.
	beads: a short run of small pieces just inside part of the edge.
	crown: a few pieces along its top edge, standing outward.
	fringe: short pen marks across a stretch of the edge, like hair or tassels.
	jewel: one small contrasting piece somewhere inside, off centre.
	stitch: pen dashes crossing the edge at even steps."""
	var keep := _keep_out
	_keep_out = PackedByteArray()   # accents belong to the forms
	var used: Array = []
	for found in _found:
		if randf() >= ACCENT_CHANCE:
			continue
		var outline: PackedVector2Array = found.outline
		var light: float = found.light
		var kind := _weighted(ACCENTS)
		var size := _min_size * randf_range(ACCENT_SIZE.x, ACCENT_SIZE.y)
		var pen := ["fringe", "stitch"].has(kind)
		var ink := _pick("pen", used, "accent") if pen else _pick_by("motif", func(i): return absf(_color(i).light - light) >= FORM_CONTRAST, used, "accent")
		used.append(ink)
		var count := randi_range(maxi(2, ACCENT_MAX / 3), ACCENT_MAX)
		var points := _resample(outline, size * (0.9 if kind == "beads" else 1.3))
		var n := points.size()
		if n < 3:
			continue
		count = mini(count, n / (2 if kind == "stitch" else 1))   # never round the edge twice
		var start := randi() % n
		if kind == "crown":
			for k in n:
				if points[k].y < points[start].y:
					start = k
			start = (start - count / 2 + n) % n
		var inward := func(k: int) -> Vector2:
			var t := (points[(k + 1) % n] - points[(k - 1 + n) % n]).normalized()
			var o := t.orthogonal()
			return o if Geometry2D.is_point_in_polygon(points[k] + o * 0.01, outline) else -o
		match kind:
			"jewel":
				var box := _bounds(outline)
				for t in 30:
					var q := box.position + box.size * Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8))
					if Geometry2D.is_point_in_polygon(q, outline) and q.distance_to(box.get_center()) > box.size.length() * 0.08:
						_stamp(plan, ink, Vector2(q.x, q.y * _aspect_fix()), _upright_rotation(), size, false, true)
						plan[-1].phase = "accent"
						break
			_:
				for c in count:
					var k := (start + c * (2 if kind == "stitch" else 1)) % n
					var dir: Vector2 = inward.call(k)
					var q: Vector2 = points[k]
					var rot := rad_to_deg(dir.angle())
					match kind:
						"beads":
							q += dir * size * 0.6
							rot = _upright_rotation()
						"crown":
							q -= dir * size * 0.4
							rot = rad_to_deg((-dir).angle()) + _long_axis_spin(ink)
						"fringe", "stitch":
							rot = rad_to_deg(dir.angle()) + _long_axis_spin(ink)
							if kind == "fringe":
								q -= dir * size * 0.35
					if q.y < 0.0 or q.y > _aspect:
						continue
					_stamp(plan, ink, Vector2(q.x, q.y * _aspect_fix()), rot + randfn(0.0, 6.0), size, false, true)
					plan[-1].phase = "accent"
	_keep_out = keep


func _continue_side(plan: Array[Dictionary], found: Dictionary, band: float) -> void:
	"""Look at one side of a form's edge line, inside the form or just
	outside the line, and make it as continuous as possible: along that side,
	spots whose value breaks from the side's own value are covered with the
	side's main sticker, turned the way it already runs, so the line ends up
	bordering one unbroken field instead of a broken one."""
	var look := _squint(plan)
	var top: PackedInt32Array = look.top
	var raw: PackedInt32Array = look.raw
	var form := PackedByteArray()
	form.resize(top.size())
	for i in found.cells:
		form[i] = CELL_FULL
	var outside := PackedByteArray()
	outside.resize(top.size())
	for i in top.size():
		outside[i] = 0 if form[i] else CELL_FULL
	var to_form := _clearance(form)        # distance out from the form
	var to_edge := _clearance(outside)     # distance in from its edge
	var interior := randf() < 0.5
	var side: Array[int] = []
	for i in top.size():
		if top[i] < 0:
			continue
		if interior and form[i] and to_edge[i] <= maxf(FORM_SIDE * _zoom, 1.5):
			side.append(i)
		elif not interior and not form[i] and to_form[i] > band + 0.5 and to_form[i] <= band + 0.5 + maxf(FORM_SIDE * _zoom, 1.5) and (_keep_out.is_empty() or _keep_out[i] == CELL_FULL):
			side.append(i)
	if side.is_empty():
		return
	# The side's own value, and the sticker that carries it most
	var votes := [0, 0, 0]
	for i in side:
		votes[raw[i]] += 1
	var v: int = votes.find(votes.max())
	var counts := {}
	var turns := {}
	var sizes := {}
	for i in side:
		if raw[i] == v:
			var st: int = plan[top[i]].sticker
			counts[st] = counts.get(st, 0) + 1
			turns[st] = plan[top[i]].rot
			sizes[st] = sizes.get(st, 0.0) + plan[top[i]].size
	var ink: int = counts.keys()[0]
	for st in counts:
		if counts[st] > counts[ink]:
			ink = st
	var grid := PackedByteArray()
	grid.resize(top.size())
	grid.fill(CELL_FULL)
	var breaks := 0
	for i in side:
		if raw[i] != v:
			grid[i] = 0
			breaks += 1
	if breaks == 0:
		return
	# Inside the form the keep-out doesn't apply: this is the form itself
	var keep := _keep_out
	if interior:
		_keep_out = PackedByteArray()
	# Pieces the size that sticker already is there: small ones would chop
	# the side into a mosaic, the opposite of continuous
	var usual: float = sizes[ink] / counts[ink]
	_fill_spots(plan, grid, [ink], maxf(usual * 0.7, _min_size), maxf(usual, _min_size), FORM_SIDE_MARKS, turns[ink], "continue", true)
	_keep_out = keep


func _bounds(poly: PackedVector2Array) -> Rect2:
	"""Bounding box of an outline, in canvas-width units."""
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	return box


func _form_grid(grow: float = 0.0) -> PackedByteArray:
	"""A coverage grid with every sample point outside the forms (grown by
	`grow` canvas widths) already covered, so only the forms are bare."""
	var shapes: Array[PackedVector2Array] = []
	for f in _forms:
		shapes.append_array(Geometry2D.offset_polygon(f, grow, Geometry2D.JOIN_ROUND) if grow > 0.0 else [f])
	var grid := PackedByteArray()
	grid.resize(COVER_GRID * _cover_rows())
	var rows := _cover_rows()
	var cell_w := 1.0 / COVER_GRID
	var cell_h := _aspect / rows
	for r in rows:
		for c in COVER_GRID:
			var bits := CELL_FULL
			for k in CELL_SAMPLES.size():
				var q := Vector2((c + CELL_SAMPLES[k].x) * cell_w, (r + CELL_SAMPLES[k].y) * cell_h)
				for poly in shapes:
					if Geometry2D.is_point_in_polygon(q, poly):
						bits &= ~(1 << k)
						break
			grid[r * COVER_GRID + c] = bits
	return grid


func _intrudes(s: Dictionary, allowed: int = FORM_INTRUDE) -> bool:
	"""Whether a stamp would land inside the form. Counted a little bigger
	than it is, for the hand's wobble."""
	if _keep_out.is_empty():
		return false
	var margin := _cover_margin
	_cover_margin = -FORM_SAFETY
	var inside := _cover(_keep_out, s, false).x
	_cover_margin = margin
	return inside > allowed


func _draw_edge(plan: Array[Dictionary], pen: int, form: PackedVector2Array, share: float) -> void:
	"""Small pen marks chained along part of the form's edge, sitting just
	outside it, so the edge is drawn as well as carved."""
	var size := _min_size * randf_range(1.0, 1.15)
	var outline: PackedVector2Array = Geometry2D.offset_polygon(form, size * 0.18, Geometry2D.JOIN_ROUND)[0]
	var points := _resample(outline, size * LINE_OVERLAP)
	var n := points.size()
	var start := randi() % n
	var flip := 180.0 if randf() < 0.5 else 0.0
	for step in int(n * share):
		var k := (start + step) % n
		var tangent := (points[(k + 1) % n] - points[(k - 1 + n) % n]).normalized()
		var p := points[k] + Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0)) * size * 0.03
		if p.y < 0.0 or p.y > _aspect:
			continue
		_stamp(plan, pen, Vector2(p.x, p.y * _aspect_fix()), rad_to_deg(tangent.angle()) + _long_axis_spin(pen) + flip + randfn(0.0, 4.0), size, false, true)
		plan[-1].phase = "carve"


func _any(pick: int) -> int:
	"""In an any-sticker painting (STUDIO_ANY_STICKER) a pick ignores what
	it asked for (role, colour, shape): any sticker from the whole library
	goes in its place, for a much wider range of colour and tone."""
	if not _any_sticker:
		return pick
	return randi() % maxi(StickerLibrary.sticker_library.size(), 1)


func _pick_frame() -> int:
	"""An outline sticker for window frames: the square ones, not brackets."""
	var library := StickerLibrary.sticker_library
	var squares: Array[int] = []
	for i in library.size():
		if _has_role(i, "frame") and _color(i).coverage < 0.4:
			var t := _texture_size(i)
			if maxf(t.x, t.y) / minf(t.x, t.y) < 2.2:
				squares.append(i)
	if squares.is_empty():
		return _pick("frame", [], "any")
	var pick: int = squares.pick_random()
	if not pick in _palette:
		_palette.append(pick)
	return _any(pick)


func _pick_by(role: String, test: Callable, avoid: Array = [], slot: String = "any") -> int:
	"""Like _pick, but only stickers passing `test` (falls back to any of the role)."""
	var library := StickerLibrary.sticker_library
	var candidates: Array[int] = []
	var any_role := _variety and randf() < STUDIO_ROLE_FREE
	for i in library.size():
		if not i in avoid and ((any_role and _taste_role(role)) or _has_role(i, role)) and test.call(i):
			candidates.append(i)
	if candidates.is_empty():
		return _pick(role, avoid, slot)
	var free := _variety and randf() < STUDIO_VARIETY
	var weights: Array[float] = []
	var total := 0.0
	for i in candidates:
		var w := _pick_weight(i, slot, free)
		weights.append(w)
		total += w
	var r := randf() * total
	var pick := candidates[-1]
	for k in candidates.size():
		r -= weights[k]
		if r <= 0.0:
			pick = candidates[k]
			break
	if not pick in _palette:
		_palette.append(pick)
	return _any(pick)


# --- Aerial map ---
# A top-down game overworld (MAP_*): the land first, as a patchwork of
# fields, then the water over it (lakes or sea, and rivers winding through),
# clumps of forest, the roads joining the towns, and the towns themselves,
# small stickers packed like buildings. Map geometry is worked out in
# canvas-width units (x 0..1, y 0.._aspect) on the coverage grid, then
# stamped in viewer space.

func _aerial_map(plan: Array[Dictionary]) -> void:
	var kind := _weighted(MAP_KINDS)
	last_style = "aerial map, " + kind
	late_fill = false
	_map_style = true
	_map_rounds = 1
	_map_towns.clear()
	_map_city = Vector2(-1, -1)
	_map_city_rings = 0
	_map_streets.clear()
	_map_coppers.clear()
	_map_city_grounds.clear()
	_map_city_pens.clear()
	_map_chips.clear()
	_map_choose_inks()
	_map_flood_inks = _map_seas.duplicate()
	_map_water = _map_terrain(kind)
	_map_woods = PackedByteArray()
	_map_woods.resize(_map_water.size())
	for k in randi_range(MAP_RIVERS.x, MAP_RIVERS.y):
		_map_river(_map_water)
	_map_fields(plan)
	_map_lay_water(plan, _map_water)
	for k in randi_range(MAP_FORESTS.x, MAP_FORESTS.y):
		_map_forest(plan)
	var towns := _map_place_towns(randi_range(MAP_TOWNS.x, MAP_TOWNS.y))
	_map_roads(plan, towns, randi_range(MAP_ROAD_EXITS.x, MAP_ROAD_EXITS.y))
	for t in towns:
		_map_town(plan, t, randi_range(MAP_TOWN_HOUSES.x, MAP_TOWN_HOUSES.y), true)
	_map_towns.append_array(towns)
	_fill_inks = _map_land.duplicate()
	_map_touch_up(plan, _coverage(plan), FILL_MAX)


func _map_touch_up(plan: Array[Dictionary], grid: PackedByteArray, limit: int) -> void:
	"""Slivers of canvas left showing get the land's colour on land and the
	water's in the water."""
	for wet in [0, 1]:
		var part := grid.duplicate()
		for i in part.size():
			if _map_water[i] != wet:
				part[i] = CELL_FULL
		if not _bare_cells(part).is_empty():
			var inks: Array[int] = _map_land
			if wet == 1:
				inks = _map_seas
			_fill_spots(plan, part, inks, _min_size, FILL_LARGEST, limit)


func _map_round() -> void:
	"""The assistant's next round on its map: the first round (and every
	MAP_NEW_MAP_ROUNDS, if set) lays a whole new map, the rest make it grow."""
	var plan := _plan
	if _map_rounds == 0 or (MAP_NEW_MAP_ROUNDS > 0 and _map_rounds >= MAP_NEW_MAP_ROUNDS):
		_fresh_painting(false)
		_plan = plan
		_aerial_map(plan)
		return
	_map_rounds += 1
	last_style = "aerial map, round %d" % _map_rounds
	var overgrown := _map_forest_share() >= MAP_FLOOD_FOREST
	if overgrown:
		# The forest has taken over: flood the thickest of it (a new water
		# sticker), lake after lake until it's back under control, and no
		# new forest this round
		_map_new_flood_ink()
		var lakes := 0
		while lakes < MAP_FLOOD_LAKES and _map_forest_share() >= MAP_FLOOD_FOREST:
			_map_flood(plan, true)
			lakes += 1
		last_style += ", flood over the forest (%d lake%s)" % [lakes, "" if lakes == 1 else "s"]
	elif randf() < MAP_FLOOD_CHANCE:
		_map_new_flood_ink()
		_map_flood(plan, false)
		last_style += ", flood"
	for k in (0 if overgrown else randi_range(MAP_GROW_FORESTS.x, MAP_GROW_FORESTS.y)):
		_map_forest(plan)
	var towns := _map_place_towns(randi_range(MAP_GROW_TOWNS.x, MAP_GROW_TOWNS.y))
	_map_roads(plan, towns, 0)
	if MAP_CITY_AFTER > 0 and _map_rounds > MAP_CITY_AFTER and _map_city_rings < MAP_CITY_RINGS and not _map_towns.is_empty():
		_map_grow_city(plan)
		last_style += ", city ring %d" % _map_city_rings
	elif MAP_BOARD and _map_city_rings >= MAP_CITY_RINGS:
		_map_grow_board(plan)
		last_style += ", circuit board"
	for t in _map_towns:
		if _map_city.x >= 0.0 and t == _map_towns[0]:
			continue   # that one's the city now
		_map_town(plan, t, randi_range(MAP_GROW_HOUSES.x, MAP_GROW_HOUSES.y), false)
	for t in towns:
		_map_town(plan, t, randi_range(MAP_TOWN_HOUSES.x, MAP_TOWN_HOUSES.y), true)
	_map_towns.append_array(towns)


func _map_flood(plan: Array[Dictionary], overgrown: bool) -> void:
	"""A new lake or river floods part of the map, roads and all. When the
	forest has overgrown the map it's a lake over the thickest of it."""
	var flood := PackedByteArray()
	flood.resize(_map_water.size())
	if overgrown:
		_map_lake(flood, _map_thickest_forest())
	elif randf() < 0.5:
		_map_river(flood)
	else:
		_map_lake(flood, Vector2(randf_range(0.15, 0.85) * COVER_GRID, randf_range(0.15, 0.85) * _cover_rows()))
	for t in _map_towns:
		_map_clear_around(flood, t, MAP_FLOOD_TOWN_SAFE)
	if _map_city.x >= 0.0:
		_map_clear_around(flood, _map_city, _map_city_reach())
	var grid := PackedByteArray()
	grid.resize(flood.size())
	for i in flood.size():
		grid[i] = 0 if flood[i] == 1 and _map_water[i] == 0 else CELL_FULL
		_map_water[i] |= flood[i]
		if flood[i] == 1:
			_map_woods[i] = 0
	_fill_spots(plan, grid, _map_seas, _min_size, 0.3, FILL_MAX, NAN, "map water", true)


func _map_new_flood_ink() -> void:
	"""Each flood switches to a new mix of water stickers the floods before
	it haven't used (MAP_FLOOD_NEW_INK); once they've run out, any but the
	last mix."""
	if randf() >= MAP_FLOOD_NEW_INK:
		return
	var land_light := _map_light(_map_land)
	var test := func(i): return _solidity(i) >= BASE_SOLIDITY and absf(_color(i).light - land_light) >= MAP_WATER_CONTRAST
	var inks := _map_pick_set(test, func(i): return _map_flat(i), _map_land + _map_flood_inks)
	if inks.size() < MAP_PICK_SET.x:
		_map_flood_inks = _map_seas.duplicate()
		inks = _map_pick_set(test, func(i): return _map_flat(i), _map_land + _map_flood_inks)
	if inks.size() >= MAP_PICK_SET.x:
		_map_seas = inks
		_map_flood_inks.append_array(inks)


func _map_forest_share() -> float:
	"""Share of the dry land under forest."""
	var land := 0
	var woods := 0
	for i in _map_water.size():
		if _map_water[i] == 0:
			land += 1
			woods += _map_woods[i]
	return float(woods) / maxf(land, 1.0)


func _map_thickest_forest() -> Vector2:
	"""The cell (column, row) with the most dry forest around it that a
	flood can reach (not a town)."""
	var rows := _cover_rows()
	var safe := PackedByteArray()
	safe.resize(_map_water.size())
	for t in _map_towns:
		_map_mark(safe, Vector2(t.x * COVER_GRID, t.y * _aspect_fix() * rows), MAP_FLOOD_TOWN_SAFE * COVER_GRID)
	if _map_city.x >= 0.0:
		_map_mark(safe, Vector2(_map_city.x * COVER_GRID, _map_city.y * _aspect_fix() * rows), _map_city_reach() * COVER_GRID)
	var reach := int(MAP_FLOOD_SIZE.y * COVER_GRID * 0.6)
	var best := Vector2(COVER_GRID / 2, rows / 2)
	var most := -1
	for r in range(0, rows, 2):
		for c in range(0, COVER_GRID, 2):
			var n := 0
			for y in range(maxi(0, r - reach), mini(rows, r + reach + 1)):
				for x in range(maxi(0, c - reach), mini(COVER_GRID, c + reach + 1)):
					var i := y * COVER_GRID + x
					n += _map_woods[i] * (1 - _map_water[i]) * (1 - safe[i])
			if n > most:
				most = n
				best = Vector2(c + 0.5, r + 0.5)
	return best


func _map_choose_inks() -> void:
	"""The map's stickers: solid ones for the land (green when MAP_GREEN_LAND
	says so) and a solid one for the water that stands apart from the land,
	compact ones for trees, a thin line for roads."""
	var library := StickerLibrary.sticker_library
	var land_hue: float = 0.3 if randf() < MAP_GREEN_LAND else FAMILIES.values().pick_random()
	_map_land.clear()
	for k in randi_range(MAP_LAND_INKS.x, MAP_LAND_INKS.y):
		var pick := _map_pick(func(i): return _has_role(i, "ground") and _solidity(i) >= BASE_SOLIDITY,
			func(i): return _map_hue_weight(i, land_hue) * _map_flat(i), _map_land)
		if pick >= 0:
			_map_land.append(pick)
	if _map_land.is_empty():
		_map_land.append(_pick("solid", [], "any"))
	if _map_land.size() < 2:
		_map_land.append(_pick("solid", _map_land, "any"))
	var land_light := _map_light(_map_land)
	var dark := randf() < MAP_DARK_WATER
	_map_seas = _map_pick_set(func(i): return _solidity(i) >= BASE_SOLIDITY and absf(_color(i).light - land_light) >= MAP_WATER_CONTRAST,
		func(i): return ((0.05 + pow(1.0 - _color(i).light, 3.0) * 3.0) if dark else _map_hue_weight(i, 0.6)) * _map_flat(i), _map_land, "solid")
	_map_trees = _map_pick_set(func(i): var t := _texture_size(i); return not ("line" in _roles(library[i]) or "frame" in _roles(library[i])) and maxf(t.x, t.y) / minf(t.x, t.y) < 1.8 and _color(i).coverage >= 0.3,
		func(i): return _map_hue_weight(i, 0.3) + (1.0 if i in _map_land else 0.0), _map_seas, "motif")
	_map_dirt = randf() < MAP_DIRT_ROADS
	_map_pens.clear()
	if _map_dirt:
		_map_pens = _map_pick_set(func(i): return _solidity(i) >= BASE_SOLIDITY and absf(_color(i).light - land_light) >= MAP_WATER_CONTRAST,
			func(i): return _map_flat(i), _map_land + _map_seas)
	if _map_pens.size() < MAP_PICK_SET.x:
		_map_dirt = false
		_map_pens = _map_pick_set(func(i): return _has_role(i, "pen"), func(i): return 1.0, [], "pen")


func _map_pick_set(test: Callable, weight: Callable, avoid: Array, fallback := "") -> Array[int]:
	"""MAP_PICK_SET different stickers for one role, drawn like _map_pick
	without repeats, so the role is always a mix and never one sticker.
	Short of passing ones, it tops up from `fallback` role picks (if given)."""
	var picks: Array[int] = []
	for k in randi_range(MAP_PICK_SET.x, MAP_PICK_SET.y):
		var pick := _map_pick(test, weight, avoid + picks)
		if pick < 0:
			break
		picks.append(pick)
	var tries := 0
	while fallback != "" and picks.size() < MAP_PICK_SET.x and tries < 20:
		var pick := _pick(fallback, avoid + picks, "any")
		if not pick in picks:
			picks.append(pick)
		tries += 1
	return picks


func _map_light(inks: Array[int]) -> float:
	"""The stickers' average lightness."""
	var light := 0.0
	for i in inks:
		light += _color(i).light / maxf(inks.size(), 1.0)
	return light


func _map_pick(test: Callable, weight: Callable, avoid: Array) -> int:
	"""A sticker passing `test`, weighted by `weight`, not one of `avoid`
	(-1 if none passes)."""
	var total := 0.0
	var candidates: Array[int] = []
	var weights: Array[float] = []
	for i in StickerLibrary.sticker_library.size():
		if i in avoid or not test.call(i):
			continue
		var w: float = weight.call(i)
		candidates.append(i)
		weights.append(w)
		total += w
	if candidates.is_empty():
		return -1
	var r := randf() * total
	for k in candidates.size():
		r -= weights[k]
		if r <= 0.0:
			return candidates[k]
	return candidates[-1]


func _map_flat(sticker: int) -> float:
	"""1 for a flat-coloured sticker, falling away for busy ones (MAP_FLAT)."""
	return 0.03 + exp(-pow(_color(sticker).busy / MAP_FLAT, 2.0))


func _map_hue_weight(sticker: int, hue: float) -> float:
	"""How well a sticker's colour fits `hue` (-1: grey, black or white)."""
	var c := _color(sticker)
	if hue < 0.0:
		return 1.0 if c.hue < 0.0 or c.colorful < 0.25 else 0.1
	if c.hue < 0.0:
		return 0.05
	var d := absf(wrapf(c.hue - hue, -0.5, 0.5))
	return 0.05 + exp(-pow(d / 0.1, 2.0)) * 3.0 * c.colorful


func _map_terrain(kind: String) -> PackedByteArray:
	"""Where the lakes or sea are: rolling noise, tipped toward one side for
	a coast or toward the edges for an island, cut at the height that puts
	MAP_WATER of the canvas under water."""
	var rows := _cover_rows()
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	noise.frequency = MAP_NOISE / COVER_GRID
	var sea := Vector2.from_angle(randi_range(0, 3) * PI / 2.0 + randf_range(-0.4, 0.4))
	var heights := PackedFloat32Array()
	heights.resize(COVER_GRID * rows)
	for r in rows:
		for c in COVER_GRID:
			var q := (_cell_center(Vector2(c, r)) - Vector2(0.5, 0.5)) * 2.0   # -1..1 across and down
			var h := noise.get_noise_2d(c, r)
			match kind:
				"coast":
					h -= 0.6 * q.dot(sea)
				"island":
					h -= 0.7 * q.length_squared()
			heights[r * COVER_GRID + c] = h
	var sorted := heights.duplicate()
	sorted.sort()
	var level := sorted[clampi(int(MAP_WATER[kind] * sorted.size()), 0, sorted.size() - 1)]
	var water := PackedByteArray()
	water.resize(heights.size())
	for i in heights.size():
		water[i] = 1 if heights[i] < level else 0
	return water


func _map_river(water: PackedByteArray) -> void:
	"""A river from one edge of the canvas across to another (or into a lake
	or the sea), meandering, widening as it goes."""
	var rows := _cover_rows()
	var size := Vector2(COVER_GRID, rows)
	var side := randi() % 4
	var along := randf_range(0.15, 0.85)
	var edges: Array[Vector2] = [Vector2(along, 0.0), Vector2(1.0, along), Vector2(along, 1.0), Vector2(0.0, along)]
	var p: Vector2 = edges[side] * size
	var target: Vector2 = edges[(side + [1, 2, 2, 3].pick_random()) % 4] * size
	target = Vector2(randf_range(0.1, 0.9), randf_range(0.1, 0.9)) * size if target.distance_to(p) < size.x * 0.4 else target
	var before := water.duplicate()
	var heading := (target - p).angle()
	var bend := 0.0
	var reach := p.distance_to(target)
	var cells_wide := Vector2(MAP_RIVER_WIDTH.x, MAP_RIVER_WIDTH.y) * COVER_GRID
	for step in int(reach * 4.0):
		bend = bend * 0.92 + randfn(0.0, MAP_RIVER_BEND)
		heading = lerp_angle(heading, (target - p).angle(), 0.06) + bend * 0.12
		p += Vector2.from_angle(heading) * 0.5
		if p.x < -2.0 or p.y < -2.0 or p.x > size.x + 2.0 or p.y > size.y + 2.0:
			return
		var width := lerpf(cells_wide.x, cells_wide.y, clampf(step * 0.5 / reach, 0.0, 1.0))
		_map_mark(water, p, width * 0.5)
		var cell := p.floor()
		if step > 12 and _in_grid(cell) and before[_cell_index(cell)] == 1:
			return   # ran into a lake or the sea


func _map_lake(water: PackedByteArray, center: Vector2) -> void:
	"""A lumpy lake around `center` (a cell: column, row), for floods."""
	var radius := randf_range(MAP_FLOOD_SIZE.x, MAP_FLOOD_SIZE.y) * COVER_GRID
	var phase := randf() * TAU
	for k in 24:
		var a := TAU * k / 24.0
		var r := radius * (0.6 + 0.4 * sin(a * 3.0 + phase))
		_map_mark(water, center + Vector2.from_angle(a) * r * randf(), radius * 0.45)


func _map_mark(water: PackedByteArray, p: Vector2, radius: float) -> void:
	"""Mark the cells within `radius` cells of `p` as water."""
	var r := maxf(radius, 0.6)
	for y in range(floori(p.y - r), ceili(p.y + r) + 1):
		for x in range(floori(p.x - r), ceili(p.x + r) + 1):
			var cell := Vector2(x, y)
			if _in_grid(cell) and (cell + Vector2(0.5, 0.5)).distance_to(p) <= r:
				water[_cell_index(cell)] = 1


func _map_clear_around(water: PackedByteArray, center: Vector2, radius: float) -> void:
	"""Keep a town out of a flood."""
	for i in water.size():
		var cell := Vector2(i % COVER_GRID, i / COVER_GRID)
		if _map_point(cell).distance_to(center) < radius:
			water[i] = 0


func _map_point(cell: Vector2) -> Vector2:
	"""A coverage cell's centre in canvas-width units."""
	var v := _cell_center(cell)
	return Vector2(v.x, v.y * _aspect)


func _map_view(p: Vector2) -> Vector2:
	"""Canvas-width units to viewer space."""
	return Vector2(p.x, p.y * _aspect_fix())


func _map_is_water(p: Vector2) -> bool:
	var cell := Vector2(floorf(p.x * COVER_GRID), floorf(p.y * _aspect_fix() * _cover_rows()))
	return _in_grid(cell) and _map_water[_cell_index(cell)] == 1


func _map_fields(plan: Array[Dictionary]) -> void:
	"""The land: patches around a few scattered centres (their borders
	roughened with noise), each tiled with one of the land stickers, every
	tile in a patch turned the same way like a ploughed field."""
	var rows := _cover_rows()
	var seeds: Array[Vector2] = []
	var inks: Array = []
	for k in randi_range(MAP_FIELDS.x, MAP_FIELDS.y):
		seeds.append(Vector2(randf(), randf() * _aspect))
		var main: int = _map_land[k % _map_land.size()] if k < _map_land.size() else _map_land.pick_random()
		var mix: Array[int] = [main]
		var others := _map_land.filter(func(i): return i != main)
		if not others.is_empty():
			mix.append(others.pick_random())
		inks.append(mix)
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 3.0 / COVER_GRID
	var owner := PackedInt32Array()
	owner.resize(COVER_GRID * rows)
	for i in owner.size():
		var cell := Vector2(i % COVER_GRID, i / COVER_GRID)
		var p := _map_point(cell) + Vector2(noise.get_noise_2d(cell.x, cell.y), noise.get_noise_2d(cell.x + 97.0, cell.y)) * 0.12
		var best := INF
		for k in seeds.size():
			var d := p.distance_squared_to(seeds[k])
			if d < best:
				best = d
				owner[i] = k
	for k in seeds.size():
		var grid := PackedByteArray()
		grid.resize(owner.size())
		var any := false
		for i in owner.size():
			var mine := owner[i] == k and _map_water[i] == 0
			grid[i] = 0 if mine else CELL_FULL
			any = any or mine
		if any:
			_fill_spots(plan, grid, inks[k], maxf(MAP_FIELD_SIZE.x, _min_size), MAP_FIELD_SIZE.y, FILL_MAX, _layer_rotation(false), "map land", true)


func _map_lay_water(plan: Array[Dictionary], water: PackedByteArray) -> void:
	"""The lakes, sea and rivers, over the land: big pieces in open water,
	small ones along the rivers, turned along the way the pen goes."""
	var grid := PackedByteArray()
	grid.resize(water.size())
	for i in water.size():
		grid[i] = 0 if water[i] == 1 else CELL_FULL
	_fill_spots(plan, grid, _map_seas, _min_size, 0.3, FILL_MAX * 4, NAN, "map water", true)


func _map_forest(plan: Array[Dictionary]) -> void:
	"""A clump of trees: two or more tree stickers mixed, packed close, inside a lumpy
	outline, on dry land away from the towns."""
	var center := Vector2(-1, -1)
	for t in 30:
		var p := Vector2(randf_range(0.05, 0.95), randf_range(0.05, 0.95) * _aspect)
		if _map_is_water(p) or _map_in_city(p) or _map_towns.any(func(town): return town.distance_to(p) < MAP_TOWN_SPACING * 0.5):
			continue
		center = p
		break
	if center.x < 0.0:
		return
	var size := maxf(randf_range(MAP_TREE_SIZE.x, MAP_TREE_SIZE.y), _min_size)
	var step := size * MAP_FOREST_PACK
	var radius := randf_range(MAP_FOREST_SIZE.x, MAP_FOREST_SIZE.y)
	var phase := Vector2(randf() * TAU, randf() * TAU)
	var spots: Array[Vector2] = []
	var row := 0
	var y := -radius
	while y <= radius:
		var x := -radius + (step * 0.5 if row % 2 == 1 else 0.0)
		while x <= radius:
			var q := center + Vector2(x, y) + Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0)) * step * 0.15
			var a := (q - center).angle()
			var edge := radius * (1.0 + 0.25 * sin(a * 3.0 + phase.x) + 0.12 * sin(a * 5.0 + phase.y))
			if q.distance_to(center) <= edge and not _map_is_water(q) and not _map_in_city(q) and q.x > -0.02 and q.x < 1.02 and q.y > -0.02 and q.y < _aspect + 0.02:
				spots.append(q)
			x += step
		y += step * 0.87
		row += 1
	spots.shuffle()
	for q in spots:
		_stamp(plan, _map_trees.pick_random(), _map_view(q), randf_range(-12.0, 12.0), size * randf_range(0.85, 1.15), false)
		plan[-1].phase = "map forest"
		_map_mark(_map_woods, Vector2(q.x * COVER_GRID, q.y * _aspect_fix() * _cover_rows()), size * COVER_GRID * 0.5)


func _map_place_towns(count: int) -> Array[Vector2]:
	"""Spots for new towns: on land, apart from each other and the towns
	already there, drawn to the water (MAP_TOWN_BY_WATER)."""
	var grid := PackedByteArray()
	grid.resize(_map_water.size())
	for i in _map_water.size():
		grid[i] = CELL_FULL if _map_water[i] == 1 else 0
	var to_water := _clearance(grid)
	var towns: Array[Vector2] = []
	for n in count:
		var best := Vector2(-1, -1)
		var best_score := -INF
		for t in 60:
			var p := Vector2(randf_range(0.08, 0.92), randf_range(0.1, 0.9) * _aspect)
			if _map_is_water(p):
				continue
			var near := INF
			for other in _map_towns + towns:
				near = minf(near, other.distance_to(p))
			if near < MAP_TOWN_SPACING:
				continue
			var cell := Vector2(floorf(p.x * COVER_GRID), floorf(p.y * _aspect_fix() * _cover_rows()))
			var d := to_water[_cell_index(cell)] if _in_grid(cell) else 99.0
			var score := randf() - MAP_TOWN_BY_WATER * absf(d - 2.5) * 0.3
			if score > best_score:
				best_score = score
				best = p
		if best.x >= 0.0:
			towns.append(best)
	return towns


func _map_town(plan: Array[Dictionary], center: Vector2, houses: int, new_town: bool) -> void:
	"""Buildings: varied small stickers set out on the town's own little
	grid, spiralling out from its middle onto dry land, all turned the same
	way. A new town starts with a bigger landmark."""
	var library := StickerLibrary.sticker_library
	var angle := 0.0 if randf() < 0.6 else randf_range(-30.0, 30.0)
	var size := maxf(randf_range(MAP_HOUSE_SIZE.x, MAP_HOUSE_SIZE.y), _min_size)
	var spacing := size * 1.1
	var spots: Array[Vector2] = []
	for j in range(-4, 5):
		for i in range(-4, 5):
			spots.append(Vector2(i, j) + Vector2(randfn(0.0, 0.25), randfn(0.0, 0.25)))
	spots.sort_custom(func(a, b): return a.length() < b.length())
	var taken := 0
	for s in spots:
		if taken >= houses:
			break
		var q := center + (s * spacing).rotated(deg_to_rad(angle))
		if _map_is_water(q) or q.x < 0.0 or q.x > 1.0 or q.y < 0.0 or q.y > _aspect:
			continue
		if not new_town and taken == 0 and s.length() < 1.5:
			continue   # an old town grows at its edges
		var landmark := new_town and taken == 0
		var house := _map_pick(func(i): var t := _texture_size(i); return not ("line" in _roles(library[i]) or "frame" in _roles(library[i])) and maxf(t.x, t.y) / minf(t.x, t.y) < 2.2 and not i in _map_land and not i in _map_seas,
			func(i): return 1.0, [])
		_stamp(plan, house, _map_view(q), angle + randf_range(-3.0, 3.0), size * (MAP_LANDMARK if landmark else randf_range(0.85, 1.1)), landmark, true)
		plan[-1].phase = "map town"
		taken += 1


func _map_grow_city(plan: Array[Dictionary]) -> void:
	"""The oldest town grows into a city, one ring of blocks a round: each
	block paved, ringed by streets, and packed with buildings in a grid.
	The city takes its ground back from floods and forest."""
	var library := StickerLibrary.sticker_library
	if _map_city.x < 0.0:
		_map_city = _map_towns[0]
		_map_city_angle = 0.0 if randf() < 0.7 else randf_range(-20.0, 20.0)
		# Pavement: a dense, squarish, flat sticker; streets: a solid one that
		# stands out from it, worn into a band like a dirt track
		_map_city_grounds = _map_pick_set(func(i): var t := _texture_size(i); return _color(i).coverage >= 0.45 and maxf(t.x, t.y) / minf(t.x, t.y) < 1.6 and not i in _map_land,
			func(i): return _map_flat(i) * pow(_color(i).coverage, 2.0) * pow(_color(i).light, 3.0), _map_seas, "solid")
		var paved := _map_light(_map_city_grounds)
		_map_city_pens = _map_pick_set(func(i): return _solidity(i) >= BASE_SOLIDITY and absf(_color(i).light - paved) >= 0.3,
			func(i): return _map_flat(i) * absf(_color(i).light - paved), _map_city_grounds, "solid")
	var k := _map_city_rings
	_map_city_rings += 1
	var pitch := MAP_CITY_BLOCK
	var turn := deg_to_rad(_map_city_angle)
	var blocks: Array[Vector2] = []
	for j in range(-k, k + 1):
		for i in range(-k, k + 1):
			if maxi(absi(i), absi(j)) != k:
				continue
			var c := _map_city + (Vector2(i, j) * pitch).rotated(turn)
			if c.x > -pitch * 0.4 and c.x < 1.0 + pitch * 0.4 and c.y > -pitch * 0.4 and c.y < _aspect + pitch * 0.4:
				blocks.append(c)
	blocks.shuffle()
	for c in blocks:
		# Pave it: the city takes its ground back from the water and the trees
		var ground: int = _map_city_grounds.pick_random()
		var tex := _texture_size(ground)
		var pave := minf(pitch * 1.05 * maxf(tex.x, tex.y) / minf(tex.x, tex.y), pitch * 2.0)
		_stamp(plan, ground, _map_view(c), _map_city_angle + randf_range(-2.0, 2.0), pave, false)
		plan[-1].phase = "map city"
		for i in _map_water.size():
			if _map_point(Vector2(i % COVER_GRID, i / COVER_GRID)).distance_to(c) < pitch * 0.55:
				_map_water[i] = 0
				_map_woods[i] = 0
	for c in blocks:
		# Streets round the block
		var h := pitch * 0.5
		var corners: Array[Vector2] = []
		for v in [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]:
			corners.append(c + v.rotated(turn))
		for e in 4:
			# Neighbouring blocks share a street: lay it once
			var key := [corners[e].snapped(Vector2(0.001, 0.001)), corners[(e + 1) % 4].snapped(Vector2(0.001, 0.001))]
			key.sort()
			if _map_streets.has(str(key)):
				continue
			_map_streets[str(key)] = true
			_map_street(plan, corners[e], corners[(e + 1) % 4], _map_city_pens)
	for c in blocks:
		# Buildings, set out on the block's own grid
		var n := MAP_CITY_HOUSES
		var cell := pitch * 0.72 / n
		for b in n * n:
			var off := (Vector2(b % n, b / n) - Vector2(n - 1, n - 1) * 0.5) * cell
			var house := _map_pick(func(i): var t := _texture_size(i); return not ("line" in _roles(library[i]) or "frame" in _roles(library[i])) and maxf(t.x, t.y) / minf(t.x, t.y) < 2.2 and not i in _map_city_grounds,
				func(i): return 1.0, [])
			_stamp(plan, house, _map_view(c + off.rotated(turn)), _map_city_angle + randf_range(-2.0, 2.0), maxf(cell * randf_range(0.85, 1.0), _min_size), false, true)
			plan[-1].phase = "map city"


func _map_street(plan: Array[Dictionary], a: Vector2, b: Vector2, inks: Array[int], width: float = MAP_CITY_STREET, phase: String = "map city") -> void:
	"""A straight band from `a` to `b` (a city street, a circuit trace): the
	stickers, mixed stamp by stamp, laid lengthwise along it and stamped
	close together so it reads as one band `width` wide."""
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var along := 0.0
	while true:
		var ink: int = inks.pick_random()
		var tex := _texture_size(ink)
		var size := maxf(width * maxf(tex.x, tex.y) / minf(tex.x, tex.y), _min_size)   # its short side is the band's width
		_stamp(plan, ink, _map_view(a + dir * minf(along, length)), rad_to_deg((b - a).angle()) + _long_axis_spin(ink) + randfn(0.0, 2.0), size, false)
		plan[-1].phase = phase
		if along >= length:
			break
		along += size * MAP_CITY_STREET_SPACING


func _map_grow_board(plan: Array[Dictionary]) -> void:
	"""After the city, the map turns into a circuit board, a little more each
	round: a patch of small components packed in rows, a chip or two (a
	square body with a smaller die on it), and bundles of copper traces
	routed square to the board with 45 degree corners, chip to chip or off
	the edge."""
	var library := StickerLibrary.sticker_library
	if _map_coppers.is_empty():
		# Copper: long, thin, solid stickers (thin enough that a trace
		# stays narrow at the smallest sticker size), as copper-brown as there are
		_map_coppers = _map_pick_set(func(i): var t := _texture_size(i); return _solidity(i) >= 0.5 and maxf(t.x, t.y) / minf(t.x, t.y) >= 2.0,
			func(i): var t := _texture_size(i); return pow(_map_hue_weight(i, 0.06), 2.0) * pow(minf(maxf(t.x, t.y) / minf(t.x, t.y), 6.0), 3.0), [], "band")
	var squarish := func(i): var t := _texture_size(i); return not ("line" in _roles(library[i]) or "frame" in _roles(library[i])) and maxf(t.x, t.y) / minf(t.x, t.y) < 1.5 and _color(i).coverage >= 0.4
	# Components: a patch of small parts in tight rows, a few kinds of part
	var kinds: Array[int] = []
	for k in randi_range(2, 4):
		kinds.append(_map_pick(squarish, func(i): return 1.0, kinds))
	kinds = kinds.filter(func(i): return i >= 0)
	var part := maxf(MAP_PART_SIZE, _min_size)
	var count := randi_range(MAP_BOARD_PARTS.x, MAP_BOARD_PARTS.y)
	var cols := maxi(2, int(sqrt(count * 1.5)))
	var corner := Vector2(randf_range(0.0, 1.0 - part * cols), randf_range(0.0, maxf(_aspect - part * count / cols, 0.0)))
	for k in count:
		var q := corner + Vector2(k % cols + 0.5, k / cols + 0.5) * part * 1.05 + Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0)) * part * 0.04
		_stamp(plan, kinds.pick_random() if not kinds.is_empty() else 0, _map_view(q), [0.0, 90.0, 180.0, 270.0].pick_random(), part * randf_range(0.8, 1.0), false, true)
		plan[-1].phase = "map board"
	# Chips
	var new_chips: Array[Vector2] = []
	for k in randi_range(MAP_BOARD_CHIPS.x, MAP_BOARD_CHIPS.y):
		var size := randf_range(MAP_CHIP_SIZE.x, MAP_CHIP_SIZE.y)
		var c := Vector2(randf_range(size * 0.6, 1.0 - size * 0.6), randf_range(size * 0.6, _aspect - size * 0.6))
		var body := _map_pick(squarish, func(i): return _map_hue_weight(i, 0.3) * _map_flat(i) + 0.05, _map_coppers)
		var die := _map_pick(squarish, func(i): return _map_flat(i), _map_coppers + [body])
		if body < 0:
			continue
		_stamp(plan, body, _map_view(c), 0.0 if randf() < 0.5 else 90.0, size, true, true)
		plan[-1].phase = "map board"
		if die >= 0:
			_stamp(plan, die, _map_view(c), 0.0, maxf(size * 0.45, _min_size), false, true)
			plan[-1].phase = "map board"
		new_chips.append(c)
	_map_chips.append_array(new_chips)
	# Traces
	for k in randi_range(MAP_BOARD_TRACES.x, MAP_BOARD_TRACES.y):
		var a: Vector2 = _map_chips.pick_random() if not _map_chips.is_empty() and randf() < 0.7 else _map_edge_point()
		var b: Vector2 = _map_chips.pick_random() if _map_chips.size() > 1 and randf() < 0.5 else _map_edge_point()
		if a.distance_to(b) < 0.15:
			b = _map_edge_point()
		var path := _map_trace_path(a, b)
		var lines := randi_range(MAP_TRACE_LINES.x, MAP_TRACE_LINES.y)
		for l in lines:
			var shifted := _map_offset_path(path, (l - (lines - 1) * 0.5) * MAP_TRACE_GAP)
			for e in shifted.size() - 1:
				_map_street(plan, shifted[e], shifted[e + 1], _map_coppers, MAP_TRACE_WIDTH, "map board")


func _map_edge_point() -> Vector2:
	"""A point just off one edge of the canvas."""
	match randi() % 4:
		0: return Vector2(randf_range(0.1, 0.9), -0.03)
		1: return Vector2(randf_range(0.1, 0.9), _aspect + 0.03)
		2: return Vector2(-0.03, randf_range(0.1, 0.9) * _aspect)
	return Vector2(1.03, randf_range(0.1, 0.9) * _aspect)


func _map_trace_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	"""A circuit trace from `a` to `b`: legs square to the board, alternating
	across and down with a jog or two, every corner cut at 45 degrees."""
	var corners := PackedVector2Array([a])
	var p := a
	var across := randf() < 0.5
	var legs := randi_range(2, 4)
	for leg in legs:
		var last := leg == legs - 1
		var q := p
		if across:
			q.x = b.x if last or leg == legs - 2 else lerpf(p.x, b.x, randf_range(0.3, 0.8))
		else:
			q.y = b.y if last or leg == legs - 2 else lerpf(p.y, b.y, randf_range(0.3, 0.8))
		if q.distance_to(p) > 0.001:
			corners.append(q)
		p = q
		across = not across
	if p.distance_to(b) > 0.001:
		corners.append(b)
	# Cut each corner at 45 degrees
	var path := PackedVector2Array([corners[0]])
	for k in range(1, corners.size() - 1):
		var into := corners[k] - corners[k - 1]
		var out := corners[k + 1] - corners[k]
		var cut := minf(minf(into.length(), out.length()) * 0.4, 0.06)
		path.append(corners[k] - into.normalized() * cut)
		path.append(corners[k] + out.normalized() * cut)
	path.append(corners[-1])
	return path


func _map_offset_path(path: PackedVector2Array, by: float) -> PackedVector2Array:
	"""`path` moved sideways by `by`, corners mitred, so bundled traces stay
	parallel round the bends."""
	if absf(by) < 0.0001:
		return path
	var out := PackedVector2Array()
	for k in path.size():
		var n_in := (path[k] - path[maxi(k - 1, 0)]).orthogonal().normalized() if k > 0 else Vector2.ZERO
		var n_out := (path[mini(k + 1, path.size() - 1)] - path[k]).orthogonal().normalized() if k < path.size() - 1 else Vector2.ZERO
		var n := (n_in + n_out).normalized() if n_in != Vector2.ZERO and n_out != Vector2.ZERO else n_in + n_out
		var miter := maxf(n.dot(n_out if n_out != Vector2.ZERO else n_in), 0.5)
		out.append(path[k] + n * by / miter)
	return out


func _map_city_reach() -> float:
	"""How far the city reaches from its middle (canvas widths)."""
	return (_map_city_rings + 0.5) * MAP_CITY_BLOCK * 1.42


func _map_in_city(p: Vector2) -> bool:
	if _map_city.x < 0.0:
		return false
	var q := (p - _map_city).rotated(-deg_to_rad(_map_city_angle)) / MAP_CITY_BLOCK
	return maxf(absf(q.x), absf(q.y)) < _map_city_rings - 0.5


func _map_roads(plan: Array[Dictionary], towns: Array[Vector2], exits: int) -> void:
	"""Roads: every new town joined to the nearest town already linked (the
	towns already on the map count as linked), sometimes an extra loop, and
	a few roads running off the edge of the map."""
	var linked: Array[Vector2] = _map_towns.duplicate()
	var waiting := towns.duplicate()
	if linked.is_empty() and not waiting.is_empty():
		linked.append(waiting.pop_front())
	while not waiting.is_empty():
		var best := [INF, 0, Vector2.ZERO]
		for k in waiting.size():
			for l in linked:
				var d: float = waiting[k].distance_to(l)
				if d < best[0]:
					best = [d, k, l]
		var town: Vector2 = waiting.pop_at(best[1])
		_map_road(plan, best[2], town)
		if randf() < MAP_ROAD_LOOPS and linked.size() > 1:
			var others := linked.filter(func(l): return l != best[2])
			others.sort_custom(func(a, b): return a.distance_to(town) < b.distance_to(town))
			_map_road(plan, others[0], town)
		linked.append(town)
	for k in exits:
		if linked.is_empty():
			break
		var from: Vector2 = linked.pick_random()
		var ends: Array[Vector2] = [Vector2(from.x, -0.02), Vector2(from.x, _aspect + 0.02), Vector2(-0.02, from.y), Vector2(1.02, from.y)]
		ends.sort_custom(func(a, b): return a.distance_to(from) < b.distance_to(from))
		var to: Vector2 = ends[randi() % 2]
		# Slant it a little rather than heading straight for the edge
		to += Vector2(randf_range(-0.15, 0.15), 0.0) if absf(to.y - from.y) > absf(to.x - from.x) else Vector2(0.0, randf_range(-0.15, 0.15))
		_map_road(plan, from, to)


func _map_road(plan: Array[Dictionary], a: Vector2, b: Vector2) -> void:
	"""One road from `a` to `b`, winding (MAP_ROAD_WIGGLE), drawn with short
	marks of the road sticker chained end to end."""
	var path := PackedVector2Array([a, b])
	var wiggle := a.distance_to(b) * MAP_ROAD_WIGGLE
	for level in 3:
		var finer := PackedVector2Array()
		for k in path.size() - 1:
			var mid := (path[k] + path[k + 1]) * 0.5
			var normal := (path[k + 1] - path[k]).orthogonal().normalized()
			finer.append(path[k])
			finer.append(mid + normal * randfn(0.0, wiggle))
		finer.append(path[-1])
		path = finer
		wiggle *= 0.5
	var size := maxf(MAP_DIRT_SIZE if _map_dirt else MAP_ROAD_MARK, _min_size)
	var spacing := size * MAP_ROAD_SPACING
	var walked := 0.0
	var next := size * 0.6   # start a little out of the town
	var total := 0.0
	for k in path.size() - 1:
		total += path[k].distance_to(path[k + 1])
	for k in path.size() - 1:
		var seg := path[k].distance_to(path[k + 1])
		while next <= walked + seg and next <= total - size * 0.6:
			var p := path[k].lerp(path[k + 1], (next - walked) / maxf(seg, 0.0001))
			var tangent := path[k + 1] - path[k]
			var pen: int = _map_pens.pick_random()
			var turn := rad_to_deg(tangent.angle()) + _long_axis_spin(pen) + randfn(0.0, 4.0)
			if _map_dirt:
				turn = randf() * 360.0   # a track is worn, not drawn
			_stamp(plan, pen, _map_view(p), turn, size * (randf_range(0.85, 1.15) if _map_dirt else 1.0), false)
			plan[-1].phase = "map road"
			next += spacing
		walked += seg


# --- Abstractions ---

func _burst(plan: Array[Dictionary], center: Vector2, radius: float) -> Dictionary:
	"""Pile a bunch of stickers into a rough patch, fast and loose, from two
	or three stickers that suit the scheme. Returns what _carve() needs."""
	var stickers: Array[int] = []
	for k in randi_range(2, 3):
		stickers.append(_pick(["texture", "motif", "subject", "line"].pick_random(), stickers, ["second", "accent", "key"][k]))
	var largest := 0.0
	# Enough stickers to pack the patch, whatever its size
	var count := int(randi_range(BURST_MIN, BURST_MAX) * clampf(radius / 0.2, 0.7, 1.6))
	for k in count:
		# Small pieces, so the patch is a texture rather than a few big shapes
		var size := randf_range(_min_size, maxf(_min_size, radius * 0.6))
		largest = maxf(largest, size)
		var offset := Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		_stamp(plan, stickers.pick_random(), center + Vector2(offset.x, offset.y * _aspect_fix()), randf_range(0.0, 360.0), size, false)
		plan[-1].phase = "burst"
	return {"center": center, "radius": radius, "reach": radius + largest * 0.5}


func _carve(plan: Array[Dictionary], burst: Dictionary) -> void:
	"""Come back to a burst and draw a form out of it. The existing stickers
	are used as simple marks, as small as they go: thin line stickers
	chained end to end trace the form's edge like a pen line, then hatching
	(sometimes) shades the burst just outside the
	line, pushing it back so the form inside reads. The form is usually the
	silhouette of a sticker already in the painting, so the drawn shapes echo
	the stickers themselves."""
	var center: Vector2 = burst.center
	var r: float = burst.radius * randf_range(0.9, 1.05)
	var outline := PackedVector2Array()
	var source := _carve_source() if randf() < SILHOUETTE_CHANCE else -1
	if source >= 0:
		var rot := deg_to_rad(randf_range(-20.0, 20.0)) if randf() < 0.5 else 0.0
		for pt in _facets(_silhouette(source), randi_range(CUTS_MIN, CUTS_MAX)):
			outline.append(pt.rotated(rot) * r)
		if last_carve_source == "":
			last_carve_source = StickerLibrary.sticker_library[source].id
	else:
		outline = _form_outline(_weighted(FORMS), r)
	var pen := _pick("pen", [], ["accent", "second"].pick_random())
	var mark_size := _min_size * randf_range(1.0, 1.15)
	var pen_spin := _long_axis_spin(pen)
	# The line goes round once, then sometimes a second, looser pass over
	# part of it, the way a hand goes back over a drawn edge.
	var passes := 2 if randf() < REDRAW_CHANCE else 1
	for pass_i in passes:
		var points := _resample(outline, mark_size * LINE_OVERLAP)
		var n := points.size()
		var start := randi() % n
		var count := n if pass_i == 0 else int(n * randf_range(0.3, 0.6))
		var drift := mark_size * (0.04 if pass_i == 0 else 0.12)
		# Curved marks all bow the same way so they chain into one line
		var flip := 180.0 if randf() < 0.5 else 0.0
		for step in count:
			var k := (start + step) % n
			var p: Vector2 = points[k] + Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0)) * drift
			var tangent := (points[(k + 1) % n] - points[(k - 1 + n) % n]).normalized()
			_stamp(plan, pen, center + Vector2(p.x, p.y * _aspect_fix()), rad_to_deg(tangent.angle()) + pen_spin + flip + randfn(0.0, 4.0), mark_size, false, true)
			plan[-1].phase = "carve"
	if randf() >= HATCH_CHANCE:
		return
	# Light hatching just outside the line: a few rows of the same small
	# marks at one angle, enough to push the burst back without burying it.
	var hatch := pen if randf() < 0.6 else _pick("pen", [pen], ["key", "second"].pick_random())
	var angle := randf_range(20.0, 70.0) * (1 if randf() < 0.5 else -1)
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var across := dir.orthogonal()
	var band := clampf(burst.reach - r, mark_size * 0.6, mark_size * 1.5)
	var outer := r + band
	var marks: Array[Vector2] = []
	var gap := mark_size * HATCH_SPACING
	var rows := ceili(outer * 2.0 / gap)
	for i in rows:
		for j in ceili(outer * 2.0 / mark_size):
			var q := across * (-outer + (i + 0.5) * gap) + dir * (-outer + (j + 0.5) * mark_size)
			q += Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0)) * mark_size * 0.08
			if q.length() > outer or Geometry2D.is_point_in_polygon(q, outline):
				continue
			if _distance_to_outline(q, outline) > band:
				continue
			marks.append(q)
	marks.shuffle()
	for q in marks.slice(0, HATCH_MAX):
		_stamp(plan, hatch, center + Vector2(q.x, q.y * _aspect_fix()), angle + _long_axis_spin(hatch) + randf_range(-4.0, 4.0), mark_size, false, false)
		plan[-1].phase = "carve"


func _long_axis_spin(sticker: int) -> float:
	"""Extra rotation that lays a sticker's long side along rotation 0."""
	var tex := _texture_size(sticker)
	return 90.0 if tex.y > tex.x else 0.0


func _distance_to_outline(q: Vector2, outline: PackedVector2Array) -> float:
	var best := INF
	for k in outline.size():
		var closest := Geometry2D.get_closest_point_to_segment(q, outline[k], outline[(k + 1) % outline.size()])
		best = minf(best, q.distance_to(closest))
	return best


func _resample(outline: PackedVector2Array, spacing: float) -> PackedVector2Array:
	"""Evenly spaced points around a closed outline."""
	var perimeter := 0.0
	for k in outline.size():
		perimeter += outline[k].distance_to(outline[(k + 1) % outline.size()])
	var count := maxi(3, ceili(perimeter / maxf(spacing, 0.001)))
	var step := perimeter / count
	var out := PackedVector2Array()
	var k := 0
	var walked := 0.0      # distance along the outline at the start of edge k
	for j in count:
		var target := j * step
		while k < outline.size() - 1 and walked + outline[k].distance_to(outline[k + 1]) < target:
			walked += outline[k].distance_to(outline[k + 1])
			k += 1
		var a := outline[k]
		var b := outline[(k + 1) % outline.size()]
		var len := a.distance_to(b)
		out.append(a.lerp(b, clampf((target - walked) / len, 0.0, 1.0)) if len > 0.0 else a)
	return out


func _facets(outline: PackedVector2Array, cuts: int) -> PackedVector2Array:
	"""Simplify an outline to about `cuts` straight edges, keeping its
	character: the points that stray furthest from a simpler outline stay."""
	if outline.size() <= cuts:
		return outline
	var area := _signed_area(outline)
	var eps := 0.02
	var best := outline
	while eps < 1.0:
		var simple := _simplify_closed(outline, eps)
		# Too simple stops looking like the sticker (or folds over itself)
		if simple.size() < 3 or _signed_area(simple) < area * 0.6 or Geometry2D.triangulate_polygon(simple).is_empty():
			break
		best = simple
		if simple.size() <= cuts:
			break
		eps *= 1.3
	return best


func _simplify_closed(outline: PackedVector2Array, eps: float) -> PackedVector2Array:
	# Split at the two points furthest apart and simplify each half
	var far := 0
	for k in outline.size():
		if outline[k].distance_squared_to(outline[0]) > outline[far].distance_squared_to(outline[0]):
			far = k
	var first := outline.slice(0, far + 1)
	var second := outline.slice(far)
	second.append(outline[0])
	var a := _simplify(first, eps)
	var b := _simplify(second, eps)
	a.resize(a.size() - 1)
	b.resize(b.size() - 1)
	a.append_array(b)
	return a


func _simplify(line: PackedVector2Array, eps: float) -> PackedVector2Array:
	"""Ramer-Douglas-Peucker on an open polyline."""
	if line.size() < 3:
		return line
	var worst := 0
	var worst_d := 0.0
	for k in range(1, line.size() - 1):
		var d := absf((line[-1] - line[0]).normalized().cross(line[k] - line[0])) if line[-1] != line[0] else line[k].distance_to(line[0])
		if d > worst_d:
			worst_d = d
			worst = k
	if worst_d <= eps:
		return PackedVector2Array([line[0], line[-1]])
	var left := _simplify(line.slice(0, worst + 1), eps)
	var right := _simplify(line.slice(worst), eps)
	left.resize(left.size() - 1)
	left.append_array(right)
	return left


func _carve_source() -> int:
	"""A sticker whose silhouette makes a good form to carve: one already used
	in this painting if possible, a solid single shape, not a line or frame."""
	var candidates: Array[int] = []
	for i in _palette:
		if not _silhouette(i).is_empty():
			candidates.append(i)
	if candidates.is_empty():
		for i in StickerLibrary.sticker_library.size():
			if _has_role(i, "subject") and not _silhouette(i).is_empty():
				candidates.append(i)
	return candidates.pick_random() if not candidates.is_empty() else -1


func _silhouette(sticker: int) -> PackedVector2Array:
	"""A sticker's outline traced from its transparency, centred, scaled so its
	longest side spans -1..1, clockwise on screen. Empty when the sticker
	isn't one solid shape (scattered pieces, thin lines, outlines), since those
	don't make a readable form. Traced once per sticker."""
	var library := StickerLibrary.sticker_library
	if sticker < 0 or sticker >= library.size() or not library[sticker].texture:
		return PackedVector2Array()
	var id := library[sticker].id
	if _silhouettes.has(id):
		return _silhouettes[id]
	var result := PackedVector2Array()
	var roles := _roles(library[sticker])
	var img := library[sticker].texture.get_image()
	if img and not ("line" in roles or "frame" in roles):
		if img.is_compressed():
			img.decompress()
		var scale := SILHOUETTE_RES / float(maxi(img.get_width(), img.get_height()))
		img.resize(maxi(1, int(img.get_width() * scale)), maxi(1, int(img.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
		var bits := BitMap.new()
		bits.create_from_image_alpha(img, 0.5)
		var polygons := bits.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), SILHOUETTE_SIMPLIFY)
		var best := PackedVector2Array()
		var best_area := 0.0
		var total_area := 0.0
		for poly in polygons:
			var area := absf(_signed_area(poly))
			total_area += area
			if area > best_area:
				best_area = area
				best = poly
		# One dominant piece that fills a fair part of its box
		if best.size() >= 6 and best_area >= total_area * 0.6:
			var box := Rect2(best[0], Vector2.ZERO)
			for pt in best:
				box = box.expand(pt)
			# Mazes and tangles don't read as a form: skip outlines that are mostly
			# notches (area well short of their convex hull) or very busy
			var hull_area := absf(_signed_area(Geometry2D.convex_hull(best)))
			var long_side := maxf(box.size.x, box.size.y)
			var short_side := maxf(minf(box.size.x, box.size.y), 1.0)
			if best_area >= box.get_area() * 0.3 and best_area >= hull_area * SILHOUETTE_SOLIDITY and best.size() <= SILHOUETTE_MAX_POINTS and long_side / short_side <= 2.2:
				var half := maxf(box.size.x, box.size.y) / 2.0
				for pt in best:
					result.append((pt - box.get_center()) / half)
				if _signed_area(result) < 0.0:
					result.reverse()
				# Thin, leggy shapes get buried by carving from both sides
				var perimeter := 0.0
				for k in result.size():
					perimeter += result[k].distance_to(result[(k + 1) % result.size()])
				if 4.0 * PI * absf(_signed_area(result)) / (perimeter * perimeter) < SILHOUETTE_COMPACTNESS:
					result = PackedVector2Array()
	_silhouettes[id] = result
	return result


func _signed_area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


func _form_outline(form: String, r: float) -> PackedVector2Array:
	"""A form's outline around (0, 0), clockwise on screen (y down)."""
	var pts := PackedVector2Array()
	match form:
		"circle":
			for k in 16:
				pts.append(Vector2.from_angle(TAU * k / 16) * r)
		"square":
			pts = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
		"triangle":
			pts = PackedVector2Array([Vector2(0, -r * 1.1), Vector2(r, r * 0.8), Vector2(-r, r * 0.8)])
		"diamond":
			pts = PackedVector2Array([Vector2(0, -r * 1.2), Vector2(r * 0.8, 0), Vector2(0, r * 1.2), Vector2(-r * 0.8, 0)])
		"arch":
			for k in 9:
				pts.append(Vector2.from_angle(PI + PI * k / 8) * r)
			pts.append(Vector2(r, r))
			pts.append(Vector2(-r, r))
	return pts


func issue(i: int) -> Dictionary:
	var s: Dictionary = _plan[i]
	if s.has("action") or s.has("issued"):
		return s
	s.issued = true
	_drift_mood()
	_wobble(s)
	var chance := MISTAKE_CHANCE_METICULOUS if _meticulous_style else MISTAKE_CHANCE
	chance *= (1.6 - focus) * (MAP_MISTAKES if _map_style else 1.0)
	if not (s.ponder or s.precise) or s.get("fix", false) or s.has("mistake") or randf() >= chance:
		return s
	var intended := s.duplicate()
	intended.erase("issued")
	var kind := _weighted(MISTAKES)
	s.mistake = kind
	s.intended = intended
	match kind:
		"slip":
			s.pos += Vector2.from_angle(randf() * TAU) * randf_range(0.05, 0.12)
			if randf() < 0.6:
				s.rot += randf_range(12.0, 40.0) * (1 if randf() < 0.5 else -1)
			if randf() < 0.4:
				s.size *= [0.65, 1.5].pick_random()
		"distracted":
			s.intended_pos = s.pos
			s.pos += Vector2.from_angle(randf() * TAU) * randf_range(0.08, 0.2)
			s.look_away = randf_range(LOOK_AWAY_MIN, LOOK_AWAY_MAX)
	s.pos = s.pos.clamp(Vector2(-BLEED, -BLEED), Vector2(1.0 + BLEED, 1.0 + BLEED))
	return s


## Call after the i-th stroke is done. Reacts to a mistake by queueing its fix
## right after it, and now and then queues an impulsive sticker.
func after_stroke(i: int) -> void:
	var s: Dictionary = _plan[i]
	if s.has("mistake"):
		_plan_fix(i, s)
	if i == _plan.size() - 1:
		_final_look()
		return
	elif (s.get("ponder", false) or s.get("precise", false)) and not s.get("fix", false):
		if randf() < (IMPULSE_CHANCE_METICULOUS if _meticulous_style else IMPULSE_CHANCE) * (0.4 + energy * 1.6) * (MAP_MISTAKES if _map_style else 1.0):
			var impulse := _impulse()
			_plan.insert(i + 1, impulse)


func _impulse() -> Dictionary:
	"""Something unplanned, slapped down without much thought: any sticker,
	any colour, a bold size."""
	var library_size := StickerLibrary.sticker_library.size()
	var stamp := {
		"sticker": randi() % maxi(library_size, 1),
		"pos": Vector2(randf_range(0.1, 0.9), randf_range(0.1, 0.9)),
		"rot": randf_range(0.0, 360.0),
		"size": maxf(randf_range(0.2, 0.5), _min_size),
		"ponder": false, "precise": false, "issued": true,
		"mistake": "impulse",
	}
	if _map_style:
		stamp.size = maxf(randf_range(MAP_HOUSE_SIZE.x, MAP_HOUSE_SIZE.y) * 1.5, _min_size)   # a stray building, not a slab across the map
	for t in 8:
		if not _intrudes(stamp):
			break
		stamp.pos = Vector2(randf_range(0.1, 0.9), randf_range(0.1, 0.9))
	return stamp


func _plan_fix(i: int, s: Dictionary) -> void:
	var fix := _weighted(FIXES_METICULOUS if _meticulous_style else FIXES)
	if _intrudes(s):
		fix = "undo"   # it cut into the form: always taken back
	s.fix_kind = fix
	var steps: Array[Dictionary] = []
	match fix:
		"undo":
			steps.append({"action": "undo", "fix": true})
		"cover":
			# Paint over it with the background, sized to hide it
			if _ground >= 0:
				var cover_extent := _extent(_ground, 1.0, _ground_rot)
				var size := clampf(s.size * 1.3 / minf(cover_extent.x, cover_extent.y), s.size, 1.2)
				_stamp(steps, _ground, s.pos, _ground_rot + randf_range(-3.0, 3.0), size, false)
			else:
				steps.append({"action": "undo", "fix": true})
		"echo":
			# Do it again, on purpose, so it reads as a decision
			var copies := randi_range(1, 3)
			if randf() < 0.5 or copies == 1:
				_stamp(steps, s.sticker, Vector2(1.0 - s.pos.x, s.pos.y), -s.rot, s.size, true)
			var step := Vector2.from_angle(randf() * TAU) * maxf(s.size * 0.9, 0.12)
			for k in copies - 1:
				_stamp(steps, s.sticker, s.pos + step * (k + 1), s.rot, s.size, k == 0)
		"build_around":
			# Make it the centre of something: frame it with a few small pieces
			var accent := _pick(["line", "motif", "motif"].pick_random(), [], "accent")
			var n := randi_range(2, 4)
			var radius := maxf(s.size * 0.6, 0.1)
			var start := randf() * TAU
			for k in n:
				var a := start + TAU * k / n
				_stamp(steps, accent, s.pos + Vector2(cos(a), sin(a) * _aspect_fix()) * radius, rad_to_deg(a) + 90.0, maxf(s.size * 0.6, 0.15), k == 0)
	# undo and cover put the intended stroke back where it belonged
	if fix in ["undo", "cover"] and s.has("intended"):
		var redo: Dictionary = s.intended.duplicate()
		redo.erase("look_away")
		redo.erase("intended_pos")
		steps.append(redo)
	steps = steps.filter(func(st): return st.has("action") or not _intrudes(st))
	for step in steps:
		step.fix = true
		step.issued = true
	if not steps.is_empty():
		# Notice it first: look at the mistake for a moment
		steps[0].stare = randf_range(STARE_MIN, STARE_MAX)
		steps[0].stare_pos = s.pos
	for k in steps.size():
		_plan.insert(i + 1 + k, steps[k])


# --- No bare canvas ---

func _patch_bare(plan: Array[Dictionary], sticker: int, rot: float) -> void:
	"""Early cover: after the ground goes down, look for any canvas still
	showing between tiles and close it with big copies of the same sticker."""
	# A ground with holes can't close its own holes: patch with a solid one
	var ink := sticker if _solidity(sticker) >= SOLID_INTERIOR else _pick("solid", [], "key")
	_fill_spots(plan, _coverage(plan), [ink], 0.25, 0.8, PATCH_MAX, rot, "patch", true)


func _finish_cover(plan: Array[Dictionary]) -> void:
	"""Late fill: step back, find the canvas still bare, and fill only those
	spots, walking from each spot to the nearest one still bare like a pen
	line. The ink is from the painting's own colours or, now and then, a
	completely different scheme. Paintings that covered early usually find
	little or nothing to do here; it's the safety net either way."""
	var grid := _coverage(plan)
	if _bare_cells(grid).is_empty():
		return
	var slot := "key" if randf() < 0.5 else "second"
	if late_fill and randf() < CONTRAST_FILL_CHANCE:
		var key: float = _scheme.key
		_scheme.contrast = fposmod((key if key >= 0.0 else randf()) + randf_range(0.35, 0.65), 1.0)
		slot = "contrast"
	var inks: Array[int] = [_pick("solid", [], slot)]
	if randf() < 0.4:
		inks.append(_pick("solid", inks, slot))
	_fill_inks = inks
	_fill_spots(plan, grid, inks, _min_size, FILL_LARGEST, FILL_MAX)


func _final_look() -> void:
	"""The plan's done, so step back and look at what actually went down: the
	hand never lands exactly where it meant to, and mistakes got moved or
	undone, so slivers of canvas can show that the plan didn't expect. Touch
	those up the same way, and look again (a few times at most)."""
	if _add_on or _looks >= FINAL_LOOKS:
		return
	_looks += 1
	var placed: Array[Dictionary] = []
	for s in _plan:
		if s.has("action"):
			if not placed.is_empty():
				placed.pop_back()
		else:
			placed.append(s)
	_cover_margin = 0.0
	var grid := _coverage(placed)
	if _form_ink >= 0:
		# Canvas showing inside a form gets the form's own colour
		var inside := grid.duplicate()
		for i in inside.size():
			inside[i] |= _keep_out[i]
		_fill_spots(_plan, inside, [_form_ink], _min_size, 0.2, FINAL_LOOK_MAX, NAN, "fill", false, 1 << 20)
		grid = _coverage(placed)
		for i in grid.size():
			grid[i] |= CELL_FULL ^ _keep_out[i]
	if _map_style and _map_water.size() == grid.size():
		_map_touch_up(_plan, grid, FINAL_LOOK_MAX)
	elif not _bare_cells(grid).is_empty():
		if _fill_inks.is_empty():
			_fill_inks = [_pick("solid", [], "key")]
		_fill_spots(_plan, grid, _fill_inks, _min_size, FILL_LARGEST, FINAL_LOOK_MAX, NAN, "fill", false, FORM_INTRUDE * 3)
	_cover_margin = COVER_MARGIN


func _fill_spots(plan: Array[Dictionary], grid: PackedByteArray, inks: Array[int], smallest: float, largest: float, limit: int, rot: float = NAN, phase: String = "fill", biggest_first: bool = false, intrude: int = FORM_INTRUDE) -> void:
	"""Cover the bare cells in `grid`. The pen goes to the nearest bare spot,
	slides deeper into that gap, and puts down a mark sized to the gap, so
	marks sit in the bare canvas and cover as little of the painting around
	it as they can. Big gaps get big marks, slivers get the smallest.
	`rot` NAN turns each mark along the pen's path. `biggest_first` goes to
	the biggest gap instead of the nearest (patching a ground). Marks never
	land inside a studio form (more than `intrude` sample points)."""
	var pen := Vector2(randf(), randf())
	var tried := {}
	var room := _clearance(grid)
	var cell_w := 1.0 / COVER_GRID
	for k in limit:
		var target := Vector2(-1, -1)
		var best := INF
		if k % 4 == 0:
			room = _clearance(grid)
		for c in _bare_cells(grid):
			if tried.get(c, 0) >= FILL_RETRIES:
				continue
			var d := -room[_cell_index(c)] if biggest_first else _cell_center(c).distance_squared_to(pen)
			if d < best:
				best = d
				target = c
		if target.x < 0.0:
			return
		tried[target] = tried.get(target, 0) + 1
		# Slide into the middle of the gap, but not far from where the pen is
		var spot := target
		for step in 8:
			var next := spot
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
				var n: Vector2 = spot + d
				if _in_grid(n) and room[_cell_index(n)] > room[_cell_index(next)]:
					next = n
			if next == spot:
				break
			spot = next
		var size := clampf(room[_cell_index(spot)] * cell_w * FILL_REACH, smallest, largest)
		var p := _cell_center(spot)
		var ink: int = inks.pick_random() if inks.size() > 2 else inks[0] if inks.size() == 1 or randf() < 0.7 else inks[1]
		var heading := rad_to_deg((p - pen).angle()) if p.distance_to(pen) > 0.001 else randf() * 360.0
		# Try the mark a few ways (nudged, turned, a touch bigger or smaller)
		# and keep the one that fills the most bare canvas for the least
		# painting it covers up
		var best_stamp := {}
		var best_score := 0.0
		for t in FILL_TRIES:
			var turn := rot + randf_range(-6.0, 6.0) if not is_nan(rot) else heading + _long_axis_spin(ink) + randfn(0.0, 25.0)
			# Half the tries are sized to the gap, half anywhere from smallest to
			# largest: over lacy layers (bare canvas showing through holes) a
			# bigger mark that covers some painting is the better choice
			var tsize := size * randf_range(0.85, 1.25) if t % 2 == 0 else exp(randf_range(log(smallest), log(largest)))
			var cand := {"sticker": ink, "pos": p + Vector2(randfn(0.0, 1.0), randfn(0.0, 1.0)) * tsize * 0.15, "rot": turn, "size": maxf(tsize, _min_size)}
			var counts := _cover(grid, cand, false)
			var score := counts.x - FILL_OVERLAP_COST * counts.y
			if counts.x > 0 and (best_stamp.is_empty() or score > best_score) and not _intrudes(cand, intrude):
				best_stamp = cand
				best_score = score
		if best_stamp.is_empty():
			continue
		# Careful near a form's edge
		_stamp(plan, ink, best_stamp.pos, best_stamp.rot, best_stamp.size, false, not _keep_out.is_empty() and _intrudes(best_stamp, 0))
		plan[-1].phase = phase
		_cover(grid, plan[-1])
		pen = p


func _clearance(grid: PackedByteArray) -> PackedFloat32Array:
	"""For every cell, how far (in cells) it is to the nearest covered cell.
	Off the canvas counts as bare, so gaps at the edge aren't cramped."""
	var rows := _cover_rows()
	var room := PackedFloat32Array()
	room.resize(grid.size())
	for i in grid.size():
		room[i] = 0.0 if grid[i] == CELL_FULL else 1e6
	# Two-pass chamfer distance
	for r in rows:
		for c in COVER_GRID:
			var i := r * COVER_GRID + c
			if c > 0: room[i] = minf(room[i], room[i - 1] + 1.0)
			if r > 0:
				room[i] = minf(room[i], room[i - COVER_GRID] + 1.0)
				if c > 0: room[i] = minf(room[i], room[i - COVER_GRID - 1] + 1.414)
				if c < COVER_GRID - 1: room[i] = minf(room[i], room[i - COVER_GRID + 1] + 1.414)
	for r in range(rows - 1, -1, -1):
		for c in range(COVER_GRID - 1, -1, -1):
			var i := r * COVER_GRID + c
			if c < COVER_GRID - 1: room[i] = minf(room[i], room[i + 1] + 1.0)
			if r < rows - 1:
				room[i] = minf(room[i], room[i + COVER_GRID] + 1.0)
				if c < COVER_GRID - 1: room[i] = minf(room[i], room[i + COVER_GRID + 1] + 1.414)
				if c > 0: room[i] = minf(room[i], room[i + COVER_GRID - 1] + 1.414)
	for i in room.size():
		room[i] = minf(room[i], float(COVER_GRID))   # nothing covered at all
	return room


func _in_grid(cell: Vector2) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COVER_GRID and cell.y < _cover_rows()


func _cell_index(cell: Vector2) -> int:
	return int(cell.y) * COVER_GRID + int(cell.x)


func _cover_rows() -> int:
	return maxi(1, roundi(COVER_GRID * _aspect))


func _cell_center(cell: Vector2) -> Vector2:
	"""Viewer-space centre of a coverage cell (column, row)."""
	return Vector2((cell.x + 0.5) / COVER_GRID, (cell.y + 0.5) / _cover_rows())


func _coverage(plan: Array[Dictionary]) -> PackedByteArray:
	"""Which grid cells of the canvas the plan covers. Each cell keeps one bit
	per sample point (CELL_SAMPLES), and only counts as covered once every
	point is, so thin slivers of canvas between stickers aren't missed."""
	var grid := PackedByteArray()
	grid.resize(COVER_GRID * _cover_rows())
	for s in plan:
		if not s.has("action"):
			_cover(grid, s)
	return grid


func _bare_cells(grid: PackedByteArray) -> Array[Vector2]:
	var cells: Array[Vector2] = []
	for i in grid.size():
		if grid[i] != CELL_FULL:
			cells.append(Vector2(i % COVER_GRID, i / COVER_GRID))
	return cells


func _cover(grid: PackedByteArray, s: Dictionary, apply: bool = true) -> Vector2i:
	"""Mark the cells a stamp's opaque pixels land on. Returns how many bare
	sample points it covers and how many already-covered ones it lands on;
	with `apply` false it only counts, to try a placement out."""
	var gained := 0
	var overlapped := 0
	var rows := _cover_rows()
	var cell_w := 1.0 / COVER_GRID
	var cell_h := _aspect / rows
	var tex := _texture_size(s.sticker)
	# While planning, count each sticker a little smaller than it is, since
	# the hand will land it a little off: the plan then overlaps enough
	var shown: float = maxf(s.size - _cover_margin, s.size * 0.75)
	var texel: float = shown / maxf(tex.x, tex.y)   # canvas widths per texture pixel
	var center := Vector2(s.pos.x, s.pos.y * _aspect)
	var reach: float = s.size * 0.71
	var mask := _mask(s.sticker)
	var turn := -deg_to_rad(s.rot)
	for r in range(maxi(0, floori((center.y - reach) / cell_h)), mini(rows, ceili((center.y + reach) / cell_h))):
		for c in range(maxi(0, floori((center.x - reach) / cell_w)), mini(COVER_GRID, ceili((center.x + reach) / cell_w))):
			var i := r * COVER_GRID + c
			if apply and grid[i] == CELL_FULL:
				continue
			for k in CELL_SAMPLES.size():
				var local := (Vector2((c + CELL_SAMPLES[k].x) * cell_w, (r + CELL_SAMPLES[k].y) * cell_h) - center).rotated(turn) / texel / tex + Vector2(0.5, 0.5)
				if local.x < 0.0 or local.y < 0.0 or local.x >= 1.0 or local.y >= 1.0:
					continue
				if mask[int(local.y * MASK_RES) * MASK_RES + int(local.x * MASK_RES)] == 1:
					if grid[i] & (1 << k) == 0:
						gained += 1
						if apply:
							grid[i] |= 1 << k
					else:
						overlapped += 1
	return Vector2i(gained, overlapped)


func _solidity(sticker: int) -> float:
	"""Share of a sticker's opaque pixels that are inside its shape rather
	than on an edge: high for solid blobs, low for lace, lines and specks."""
	var mask := _mask(sticker)
	var opaque := 0
	var inside := 0
	for y in MASK_RES:
		for x in MASK_RES:
			if mask[y * MASK_RES + x] == 0:
				continue
			opaque += 1
			if x > 0 and y > 0 and x < MASK_RES - 1 and y < MASK_RES - 1 \
					and mask[y * MASK_RES + x - 1] == 1 and mask[y * MASK_RES + x + 1] == 1 \
					and mask[(y - 1) * MASK_RES + x] == 1 and mask[(y + 1) * MASK_RES + x] == 1:
				inside += 1
	return float(inside) / maxf(opaque, 1.0)


func _mask(sticker: int) -> PackedByteArray:
	if _masks.has(sticker):
		return _masks[sticker]
	var mask := PackedByteArray()
	mask.resize(MASK_RES * MASK_RES)
	var library := StickerLibrary.sticker_library
	var img: Image = library[sticker].texture.get_image() if sticker >= 0 and sticker < library.size() and library[sticker].texture else null
	if img:
		if img.is_compressed():
			img.decompress()
		img.resize(MASK_RES, MASK_RES, Image.INTERPOLATE_BILINEAR)
		for y in MASK_RES:
			for x in MASK_RES:
				mask[y * MASK_RES + x] = 1 if img.get_pixel(x, y).a >= 0.5 else 0
	else:
		mask.fill(1)
	_masks[sticker] = mask
	return mask


# --- Layout helpers ---

func _tile(plan: Array[Dictionary], sticker: int, area: Rect2, size: float, rot: float, jitter: float = 0.04, rot_jitter: float = 3.0) -> void:
	"""Cover `area` with overlapping copies of one sticker, brick-style."""
	var extent := _extent(sticker, size, rot)
	var overlap := lerpf(TILE_OVERLAP_SPARSE, TILE_OVERLAP, clampf(_color(sticker).coverage / 0.85, 0.0, 1.0))
	var step := Vector2(extent.x * overlap, extent.y * overlap / _aspect)
	var cols := maxi(1, ceili(area.size.x / step.x))
	var rows := maxi(1, ceili(area.size.y / step.y))
	var used := Vector2(cols * step.x, rows * step.y)
	var origin := area.position + (area.size - used) / 2.0 + step / 2.0
	for r in rows:
		var shift := step.x * 0.5 if r % 2 == 1 and cols > 1 else 0.0
		for c in cols + (1 if shift > 0.0 else 0):
			var p := origin + Vector2(c * step.x - shift, r * step.y)
			p += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
			_stamp(plan, sticker, p, rot + randf_range(-rot_jitter, rot_jitter), size, false)
	# Gappy shapes leave holes between tiles: fill them with a second pass
	# offset by half a tile, turned a half turn so it doesn't just repeat
	if _color(sticker).coverage < SECOND_PASS_BELOW:
		for r in rows:
			for c in cols:
				var p := origin + Vector2((c + 0.5) * step.x, (r + 0.5) * step.y)
				p += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
				_stamp(plan, sticker, p, rot + 180.0 + randf_range(-rot_jitter, rot_jitter), size, false)


func _row(plan: Array[Dictionary], sticker: int, y: float, size: float, rot: float) -> void:
	var extent := _extent(sticker, size, rot)
	var n := maxi(2, ceili(1.0 / (extent.x * 0.85)))
	for i in n:
		_stamp(plan, sticker, Vector2((i + 0.5) / n, y), rot, size, false)


func _column(plan: Array[Dictionary], sticker: int, x: float, size: float, rot: float) -> void:
	var extent := _extent(sticker, size, rot)
	var n := maxi(2, ceili(_aspect / (extent.y * 0.85)))
	for i in n:
		_stamp(plan, sticker, Vector2(x, (i + 0.5) / n), rot, size, false)


func _stamp(plan: Array[Dictionary], sticker: int, pos: Vector2, rot: float, size: float, ponder: bool, precise: bool = false) -> void:
	var s := {
		"sticker": sticker,
		"pos": pos.clamp(Vector2(-BLEED, -BLEED), Vector2(1.0 + BLEED, 1.0 + BLEED)),
		"rot": rot,
		"size": maxf(size, _min_size),
		"ponder": ponder,
		"precise": precise,
	}
	if _guard and _intrudes(s):
		return
	plan.append(s)


func _extent(sticker: int, size: float, rot: float) -> Vector2:
	"""Width and height a sticker covers at `size` (canvas widths), after a
	right-angle-ish rotation."""
	var tex := _texture_size(sticker)
	var e := tex / maxf(tex.x, tex.y) * size
	return Vector2(e.y, e.x) if absf(fposmod(rot, 180.0) - 90.0) < 45.0 else e


func _aspect_fix() -> float:
	return 1.0 / _aspect


func _layer_rotation(allow_diagonal: bool = true) -> float:
	"""One rotation for a whole layer: mostly square to the canvas. Fills stay
	square, since tilted tiles leave gaps at the edges."""
	if allow_diagonal and randf() < 0.15:
		return randf_range(-45.0, 45.0)
	return [0.0, 90.0, 180.0, 270.0].pick_random()


func _upright_rotation() -> float:
	return 0.0 if randf() < 0.7 else randf_range(-20.0, 20.0)


# --- Sticker picking ---

## Stickers are weighted by how well their colours fit the painting's scheme
## (`slot` is "key", "second", "accent" or "any"). Stickers already used in this
## painting get a boost, so it keeps to a small set like the Hall of Fame ones do.
var _palette: Array[int] = []

func _pick(role: String, avoid: Array = [], slot: String = "any") -> int:
	var library := StickerLibrary.sticker_library
	var candidates: Array[int] = []
	var any_role := _variety and randf() < STUDIO_ROLE_FREE
	for i in library.size():
		if not i in avoid and ((any_role and _taste_role(role)) or _has_role(i, role)):
			candidates.append(i)
	if candidates.is_empty():
		for i in library.size():
			if not i in avoid:
				candidates.append(i)
	if candidates.is_empty():
		return 0
	var free := _variety and randf() < STUDIO_VARIETY
	var weights: Array[float] = []
	var total := 0.0
	for i in candidates:
		var w := _pick_weight(i, slot, free)
		weights.append(w)
		total += w
	var r := randf() * total
	var pick := candidates[-1]
	for k in candidates.size():
		r -= weights[k]
		if r <= 0.0:
			pick = candidates[k]
			break
	if not pick in _palette:
		_palette.append(pick)
	return _any(pick)


func _taste_role(role: String) -> bool:
	"""A kind picked by hand in ROLES (band, subject, line, texture, motif,
	frame...), as opposed to one worked out from what the sticker can
	physically do (pale, solid, pen, ground, fill, *_base). STUDIO_ROLE_FREE
	only loosens the hand-picked kinds, so a veil still veils and a fill still
	covers."""
	return not (role in ["pale", "veil", "solid", "dense", "pen", "ground", "fill"] or role.ends_with("_base"))


func _has_role(sticker: int, role: String) -> bool:
	var roles := _roles(StickerLibrary.sticker_library[sticker])
	if role in roles:
		return true
	if role.ends_with("_base"):
		# A ground that covers: no lace, which would leave canvas showing everywhere
		return _has_role(sticker, role.trim_suffix("_base")) and _solidity(sticker) >= BASE_SOLIDITY
	if role == "pale":
		# Light, fairly dense stickers that veil what's under them
		return not ("line" in roles or "frame" in roles) and _color(sticker).light >= PALE_LIGHT and _color(sticker).coverage >= 0.35 and _color(sticker).colorful < 0.35
	if role == "veil":
		# Studio veils: pale-ish and dense enough to veil, any colour (STUDIO_VEIL_LIGHT)
		return not ("line" in roles or "frame" in roles) and _color(sticker).light >= STUDIO_VEIL_LIGHT and _color(sticker).coverage >= 0.35
	if role == "solid":
		return _solidity(sticker) >= SOLID_INTERIOR
	if role == "dense":
		return _solidity(sticker) >= STUDIO_UNDER_SOLID
	if role == "pen":
		return "line" in roles and _color(sticker).coverage < PEN_COVERAGE
	if role == "ground":
		return "fill" in roles or (not ("line" in roles or "frame" in roles) and _color(sticker).coverage >= GROUND_COVERAGE)
	# Any dense enough shape can tile into a colour field
	return role == "fill" and not ("line" in roles or "frame" in roles) and _color(sticker).coverage >= FILL_COVERAGE


func _roles(definition: PaintingLayerDefinition) -> Array:
	if ROLES.has(definition.id):
		return ROLES[definition.id]
	# Custom stickers: guess from shape
	var size := definition.texture.get_size() if definition.texture else Vector2.ONE
	var ratio := maxf(size.x, size.y) / maxf(minf(size.x, size.y), 1.0)
	return ["band", "line"] if ratio >= 2.5 else ["subject", "motif"]


func _texture_size(sticker: int) -> Vector2:
	var library := StickerLibrary.sticker_library
	if sticker < 0 or sticker >= library.size() or not library[sticker].texture:
		return Vector2.ONE
	return library[sticker].texture.get_size()


# --- Colour ---

func _choose_scheme() -> void:
	"""Pick this painting's colours: a key family not used in the last few
	paintings, and a second and accent colour that go with it."""
	var families: Array = FAMILIES.keys().filter(func(f): return not f in _recent_families)
	var family: String = families.pick_random()
	_recent_families.append(family)
	if _recent_families.size() > RECENT_FAMILIES:
		_recent_families.pop_front()
	var key: float = FAMILIES[family]
	var any_hue: float = FAMILIES.values().filter(func(h): return h >= 0.0).pick_random()
	if key < 0.0:
		_scheme = {"key": -1.0, "second": -1.0, "accent": any_hue, "neutral": 1.0}
		return
	var side := 1.0 if randf() < 0.5 else -1.0
	match _weighted(SCHEMES):
		"mono":
			_scheme = {"key": key, "second": key, "accent": key, "neutral": 0.15}
		"analogous":
			_scheme = {"key": key, "second": fposmod(key + 0.08 * side, 1.0), "accent": fposmod(key - 0.08 * side, 1.0), "neutral": 0.15}
		"complement":
			_scheme = {"key": key, "second": -1.0, "accent": fposmod(key + 0.5, 1.0), "neutral": 0.6}
		_:
			_scheme = {"key": key, "second": -1.0, "accent": key, "neutral": 0.8}


func _pick_weight(sticker: int, slot: String, free: bool) -> float:
	"""How likely a candidate is picked: the colour scheme's weight, doubled
	for stickers already in the painting. In a studio painting a free pick
	(STUDIO_VARIETY) drops the scheme and every sticker counts alike, and
	stickers already used count STUDIO_REUSE instead of double, and ones
	from the last few paintings STUDIO_FRESH, so the paintings draw on
	much more of the library."""
	if not _variety:
		return _color_weight(sticker, slot) * (2.0 if sticker in _palette else 1.0)
	var w := (1.0 if free else _color_weight(sticker, slot)) * (STUDIO_REUSE if sticker in _palette else 1.0)
	for past in _recent_stickers:
		if sticker in past:
			return w * STUDIO_FRESH
	return w


func _color_weight(sticker: int, slot: String) -> float:
	if slot == "any" or not _scheme.has(slot):
		return 1.0
	var c := _color(sticker)
	var target: float = _scheme[slot]
	if c.hue < 0.0 or c.colorful < 0.25:
		return 1.0 if target < 0.0 else _scheme.neutral
	if target < 0.0:
		return 0.1
	var d := absf(wrapf(c.hue - target, -0.5, 0.5))
	return 0.02 + exp(-pow(d / HUE_TOLERANCE, 2.0)) * 3.0 * c.colorful


func _color(sticker: int) -> Dictionary:
	"""A sticker's colour summary, worked out once from its pixels:
	{hue (0..1, or -1 if it has no clear colour), colorful (share of
	saturated pixels), light (average luminance), coverage (share of the image
	that isn't transparent), busy (spread of brightness: high for stripes and
	patterns, low for flat colour)}. Works for custom and bought stickers too."""
	var library := StickerLibrary.sticker_library
	if sticker < 0 or sticker >= library.size() or not library[sticker].texture:
		return {"hue": -1.0, "colorful": 0.0, "light": 0.5, "coverage": 0.5, "busy": 0.2}
	var id := library[sticker].id
	if _colors.has(id):
		return _colors[id]
	var img := library[sticker].texture.get_image()
	var summary := {"hue": -1.0, "colorful": 0.0, "light": 0.5, "coverage": 0.5, "busy": 0.2}
	if img:
		if img.is_compressed():
			img.decompress()
		img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
		var solid := 0
		var saturated := 0
		var light := 0.0
		var light_sq := 0.0
		var hue_vec := Vector2.ZERO
		for y in 64:
			for x in 64:
				var px := img.get_pixel(x, y)
				if px.a < 0.5:
					continue
				solid += 1
				light += px.get_luminance()
				light_sq += px.get_luminance() * px.get_luminance()
				if px.s > 0.3 and px.v > 0.25:
					saturated += 1
					hue_vec += Vector2.from_angle(px.h * TAU)
		if solid > 0:
			summary.coverage = solid / 4096.0
			summary.light = light / solid
			summary.busy = sqrt(maxf(light_sq / solid - summary.light * summary.light, 0.0))
			summary.colorful = float(saturated) / solid
			if saturated > 0 and hue_vec.length() / saturated > 0.3:
				summary.hue = fposmod(hue_vec.angle() / TAU, 1.0)
	_colors[id] = summary
	return summary


func _weighted(weights: Dictionary) -> String:
	var total := 0.0
	for w in weights.values():
		total += w
	var r := randf() * total
	for key in weights:
		r -= weights[key]
		if r <= 0.0:
			return key
	return weights.keys()[0]


# --- Canvas geometry ---

func _canvas_frame(system: PaintingSystem2D) -> Dictionary:
	"""How the canvas's UV and sticker rotation line up with what the player
	sees: which way is right and down on the canvas, its size as seen, and the
	rotation that makes a sticker upright. Canvases are mounted at all sorts
	of angles, so this works from the plane's transform and the camera."""
	var plane := system.painting_plane
	var basis := plane.global_basis.orthonormalized()
	var ax := basis.x   # canvas u
	var az := basis.z   # canvas v
	var normal := basis.y
	var up := Vector3.UP
	if absf(up.dot(normal)) > 0.9:
		up = -basis.z   # canvas lying flat: treat its far edge as "up"
	up = (up - normal * up.dot(normal)).normalized()
	var cam := plane.get_viewport().get_camera_3d()
	var side := 1.0
	if cam and (cam.global_position - plane.global_position).dot(normal) < 0.0:
		side = -1.0
	var right := (-normal * side).cross(up)
	var down := -up
	var r := Vector2(right.dot(ax), right.dot(az))
	var d := Vector2(down.dot(ax), down.dot(az))
	var sizes := Vector2(system.plane_width, system.plane_height)
	return {
		"right": r,  # viewer right, in canvas (u, v) axes
		"down": d,
		"width": absf(r.x) * sizes.x + absf(r.y) * sizes.y,
		"height": absf(d.x) * sizes.x + absf(d.y) * sizes.y,
		"rotation_offset": rad_to_deg(atan2(-d.x, d.y)),
		"rotation_sign": 1.0 if r.x * d.y - r.y * d.x > 0.0 else -1.0,
		"sizes": sizes,
	}


func _to_uv(p: Vector2) -> Vector2:
	"""Viewer space (0..1 across, 0..1 down) to canvas UV."""
	var offset: Vector2 = _frame.right * (p.x - 0.5) * _frame.width + _frame.down * (p.y - 0.5) * _frame.height
	return Vector2(0.5, 0.5) + offset / _frame.sizes
