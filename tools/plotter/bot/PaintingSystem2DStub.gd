class_name PaintingSystem2D
extends Node

## Stand-in so AutoplayPainter compiles in a bare project. Only the fields
## the painter reads; tools never call begin_painting()/next_stroke().

var painting_plane: Node3D
var placed_layers: Array = []
var min_scale := 0.1
var max_scale := 10.0
var sticker_scale := 1.0
var plane_width := 1.0
var plane_height := 1.0
