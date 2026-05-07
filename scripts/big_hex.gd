class_name BigHex
extends RefCounted

# A 7-tile big-hex cluster (SPEC §7): 1 center + 6 neighbors. Acts as both an
# Explore candidate (pre-reveal) and a permanent revealed cluster (post-reveal).

var center: Vector2i
var biome: int  # Element.Type
var revealed: bool


func _init(c: Vector2i, b: int) -> void:
	center = c
	biome = b
	revealed = false


func tiles() -> Array[Vector2i]:
	return HexGrid.big_hex_tiles(center)
