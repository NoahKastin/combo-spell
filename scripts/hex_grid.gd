class_name HexGrid
extends RefCounted

# Hex coordinate math for Combo Spell. Flat-top orientation.
# Ported from Master Dungeon's HexGrid.swift (Swift/SpriteKit).
# Storage convention: Vector2i(q, r); third cube coord s = -q - r is derived.
# Reference: https://www.redblobgames.com/grids/hexagons/
#
# TODO: port HexPathfinder (A*) when enemy movement is implemented.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),    # E
	Vector2i(1, -1),   # NE
	Vector2i(0, -1),   # NW
	Vector2i(-1, 0),   # W
	Vector2i(-1, 1),   # SW
	Vector2i(0, 1),    # SE
]

# Offsets from one big-hex center to each adjacent big-hex center, in axial (q, r).
# Big-hex centers form their own hex lattice rotated relative to the small hexes.
const BIG_HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(3, -1),
	Vector2i(2, -3),
	Vector2i(-1, -2),
	Vector2i(-3, 1),
	Vector2i(-2, 3),
	Vector2i(1, 2),
]

static func neighbor(coord: Vector2i, direction: int) -> Vector2i:
	return coord + DIRECTIONS[direction % 6]

static func neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRECTIONS:
		result.append(coord + d)
	return result

# Hex distance using cube coordinates.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -dq - dr
	return (abs(dq) + abs(dr) + abs(ds)) / 2

# All hexes within `radius` of `center`, inclusive.
static func hexes_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dq in range(-radius, radius + 1):
		var lower: int = max(-radius, -dq - radius)
		var upper: int = min(radius, -dq + radius)
		for dr in range(lower, upper + 1):
			result.append(Vector2i(center.x + dq, center.y + dr))
	return result

# The 7 small hexes that make up a big-hex centered on `center`:
# the center itself plus its 6 immediate neighbors.
static func big_hex_tiles(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [center]
	for d in DIRECTIONS:
		result.append(center + d)
	return result

# The 6 big-hex centers adjacent to a big-hex centered on `center`.
static func big_hex_neighbors(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in BIG_HEX_DIRECTIONS:
		result.append(center + d)
	return result
