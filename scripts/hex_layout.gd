class_name HexLayout
extends RefCounted

# Pixel <-> hex coordinate conversion. Flat-top by default (SPEC §7).
# Ported from Master Dungeon's HexLayout (Swift/SpriteKit), in
# /Users/noahkastin/Documents/Programming/master-dungeon/Master-Dungeon-Xcode/Master Dungeon/HexGrid.swift
# Reference: https://www.redblobgames.com/grids/hexagons/

const SQRT_3 := 1.7320508075688772

var hex_size: float
var origin: Vector2
var flat_top: bool

# Forward (hex -> pixel) and backward (pixel -> hex) orientation matrices.
var f0: float
var f1: float
var f2: float
var f3: float
var b0: float
var b1: float
var b2: float
var b3: float
var start_angle_deg: float


func _init(size: float, layout_origin: Vector2 = Vector2.ZERO, is_flat_top: bool = true) -> void:
	hex_size = size
	origin = layout_origin
	flat_top = is_flat_top
	if flat_top:
		f0 = 1.5
		f1 = 0.0
		f2 = SQRT_3 / 2.0
		f3 = SQRT_3
		b0 = 2.0 / 3.0
		b1 = 0.0
		b2 = -1.0 / 3.0
		b3 = SQRT_3 / 3.0
		start_angle_deg = 0.0
	else:
		f0 = SQRT_3
		f1 = SQRT_3 / 2.0
		f2 = 0.0
		f3 = 1.5
		b0 = SQRT_3 / 3.0
		b1 = -1.0 / 3.0
		b2 = 0.0
		b3 = 2.0 / 3.0
		start_angle_deg = 30.0


func hex_to_screen(coord: Vector2i) -> Vector2:
	var x := (f0 * coord.x + f1 * coord.y) * hex_size
	var y := (f2 * coord.x + f3 * coord.y) * hex_size
	return Vector2(x, y) + origin


func screen_to_hex(point: Vector2) -> Vector2i:
	var local := (point - origin) / hex_size
	var q := b0 * local.x + b1 * local.y
	var r := b2 * local.x + b3 * local.y
	return _cube_round(q, r)


func hex_corners(coord: Vector2i) -> PackedVector2Array:
	var center := hex_to_screen(coord)
	var corners := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i + start_angle_deg)
		corners.append(center + hex_size * Vector2(cos(angle), sin(angle)))
	return corners


static func _cube_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var q_diff := absf(rq - q)
	var r_diff := absf(rr - r)
	var s_diff := absf(rs - s)
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
