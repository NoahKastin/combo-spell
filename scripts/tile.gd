class_name Tile
extends RefCounted

# A small-hex tile's occupant state. Resources, enemies, and units all share
# the Element-bag model (SPEC §1, §3) — the Kind enum just distinguishes
# whose side they're on and how the rest of the game treats them.

enum Kind { EMPTY, RESOURCE, ENEMY, UNIT }

var coord: Vector2i
var kind: int
var composition: Dictionary  # Element.Type -> int


func _init(c: Vector2i, k: int = Kind.EMPTY) -> void:
	coord = c
	kind = k
	composition = {}


func add_element(t: int, count: int = 1) -> void:
	composition[t] = composition.get(t, 0) + count


func is_empty() -> bool:
	return kind == Kind.EMPTY


func element_count() -> int:
	var total := 0
	for k in composition:
		total += composition[k]
	return total


# The "primary" Element drives the tile's mid-zoom symbol (SPEC §5.2):
# most-used, ties broken by earliest player addition. For a single-Element
# tile this just returns the only key.
func primary_element() -> int:
	var best_kind := -1
	var best_count := -1
	for k in composition:
		if composition[k] > best_count:
			best_count = composition[k]
			best_kind = k
	return best_kind
