class_name Polargraph
extends RefCounted

## Kinematics of a hanging two-cord plotter (polargraph).
##
## Two motors sit on a horizontal beam above the canvas, each winding a cord.
## The gondola hangs where the two cords meet, so its position is set by the
## two cord lengths L1 (left motor) and L2 (right motor).
##
## Everything is in canvas millimetres: origin at the canvas's top-left corner,
## +x to the right, +y DOWN the canvas. The motors are therefore at negative y.
##
## Pure math, no nodes: the same class drives the simulator and, later, the
## G-code exporter for the real machine.

## Distance between the two motor (cord exit) points, mm. ~8 ft.
var motor_spacing: float = 2440.0
## How far the motors sit above the canvas's top edge, mm.
var motor_offset: float = 450.0
## Canvas width × height, mm. 6 × 4 ft landscape.
var canvas_size: Vector2 = Vector2(1830.0, 1220.0)

## Cords closer together than this (degrees, measured at the gondola) give poor
## sideways resolution and stability: the bottom of a tall machine.
var min_cord_angle: float = 20.0
## Cords wider apart than this are nearly horizontal: huge tension, sagging,
## poor vertical resolution. The top of a wide machine.
var max_cord_angle: float = 160.0

## Drive: motor full steps per rev, microstepping, and cord paid out per rev.
## Default is a 20-tooth GT2 pulley (20 × 2 mm = 40 mm per rev).
## For a 25 mm spool use set_spool_diameter(25.0) (≈78.5 mm per rev).
var steps_per_rev: int = 200
var microsteps: int = 16
var mm_per_rev: float = 40.0


func _init(p_motor_spacing: float = 2440.0, p_motor_offset: float = 450.0, p_canvas_size: Vector2 = Vector2(1830.0, 1220.0)) -> void:
	motor_spacing = p_motor_spacing
	motor_offset = p_motor_offset
	canvas_size = p_canvas_size


# --- Geometry ---------------------------------------------------------------

## Left motor point, canvas mm. The beam is centred over the canvas.
func left_motor() -> Vector2:
	return Vector2((canvas_size.x - motor_spacing) * 0.5, -motor_offset)


## Right motor point, canvas mm.
func right_motor() -> Vector2:
	return Vector2((canvas_size.x + motor_spacing) * 0.5, -motor_offset)


func canvas_rect() -> Rect2:
	return Rect2(Vector2.ZERO, canvas_size)


# --- Kinematics -------------------------------------------------------------

## Inverse kinematics: gondola position (canvas mm) -> cord lengths (L1, L2) in mm.
func xy_to_lengths(p: Vector2) -> Vector2:
	return Vector2(p.distance_to(left_motor()), p.distance_to(right_motor()))


## Forward kinematics: cord lengths (L1, L2) -> gondola position, canvas mm.
## The gondola hangs below the beam, so of the two circle intersections the
## lower one is returned. Returns Vector2(NAN, NAN) if the cords can't meet
## (L1 + L2 shorter than the motor spacing, or one cord too long for the other).
func lengths_to_xy(l1: float, l2: float) -> Vector2:
	var d := motor_spacing
	if l1 < 0.0 or l2 < 0.0 or l1 + l2 < d or absf(l1 - l2) > d:
		return Vector2(NAN, NAN)
	# a: distance along the beam from the left motor to the foot of the gondola
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var m1 := left_motor()
	return Vector2(m1.x + a, m1.y + h)


## Angle between the two cords at the gondola, degrees (0..180).
func cord_angle(p: Vector2) -> float:
	var to_left := left_motor() - p
	var to_right := right_motor() - p
	if to_left.length_squared() < 1e-9 or to_right.length_squared() < 1e-9:
		return 0.0
	return rad_to_deg(absf(to_left.angle_to(to_right)))


## Quality of a point, 0..1. 1 where the cords meet at 90° (best balance of
## sideways and vertical resolution), falling linearly to 0 at min_cord_angle
## and max_cord_angle, and 0 beyond them. Points at or above the beam are 0.
func quality(p: Vector2) -> float:
	if p.y <= -motor_offset:
		return 0.0
	var angle := cord_angle(p)
	if angle <= min_cord_angle or angle >= max_cord_angle:
		return 0.0
	if angle <= 90.0:
		return (angle - min_cord_angle) / (90.0 - min_cord_angle)
	return (max_cord_angle - angle) / (max_cord_angle - 90.0)


## True when a point's cord angle is inside the usable band.
func is_usable(p: Vector2) -> bool:
	return quality(p) > 0.0


## Quality sampled on a grid over the canvas, for shading the usable region.
## Returns a row-major PackedFloat32Array of cols × rows samples taken at cell
## centres; cols/rows are returned alongside.
func quality_grid(cell_mm: float) -> Dictionary:
	var cols := maxi(1, ceili(canvas_size.x / cell_mm))
	var rows := maxi(1, ceili(canvas_size.y / cell_mm))
	var values := PackedFloat32Array()
	values.resize(cols * rows)
	for r in rows:
		for c in cols:
			values[r * cols + c] = quality(Vector2((c + 0.5) * cell_mm, (r + 0.5) * cell_mm))
	return {"cols": cols, "rows": rows, "cell_mm": cell_mm, "values": values}


# --- Drive ------------------------------------------------------------------

func set_spool_diameter(diameter_mm: float) -> void:
	mm_per_rev = PI * diameter_mm


func set_gt2_pulley(teeth: int) -> void:
	mm_per_rev = teeth * 2.0


## Microsteps per millimetre of cord.
func steps_per_mm() -> float:
	return steps_per_rev * microsteps / mm_per_rev


## Cord lengths -> motor positions in microsteps (rounded).
func lengths_to_steps(lengths: Vector2) -> Vector2i:
	var k := steps_per_mm()
	return Vector2i(roundi(lengths.x * k), roundi(lengths.y * k))


func steps_to_lengths(steps: Vector2i) -> Vector2:
	var k := steps_per_mm()
	return Vector2(steps.x / k, steps.y / k)
