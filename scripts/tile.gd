class_name Tile
extends RefCounted

# A small-hex tile's occupant state. Resources, enemies, and units all share
# the Element-bag model (SPEC §1, §3) — the Kind enum just distinguishes
# whose side they're on and how the rest of the game treats them.

enum Kind { EMPTY, RESOURCE, ENEMY, UNIT }

# §3.1 Earth: living tiles (units and enemies) have a base max HP of 1, plus
# 1 per Earth in their composition. Resources and empty tiles don't track HP.
const BASE_LIVING_HP := 1

var coord: Vector2i
var kind: int
var composition: Dictionary  # Element.Type -> int
var max_hp: int
var current_hp: int


func _init(c: Vector2i, k: int = Kind.EMPTY) -> void:
	coord = c
	kind = k
	composition = {}
	if _is_living(k):
		max_hp = BASE_LIVING_HP
		current_hp = BASE_LIVING_HP
	else:
		max_hp = 0
		current_hp = 0


# §3.1 / §4.2: each Earth bumps max HP by 1 and "fills only the new HP point"
# (current HP rises by 1 too, but previously-lost HP isn't restored). Applies
# uniformly to placement-time and augment-time additions, and to enemy seeding.
func add_element(t: int, count: int = 1) -> void:
	composition[t] = composition.get(t, 0) + count
	if t == Element.Type.EARTH and _is_living(kind):
		max_hp += count
		current_hp += count


# Subtracts from current HP. The caller (Exterminate combat resolver) is
# responsible for removing tiles whose current_hp drops to 0 or below — Tile
# just tracks state.
func take_damage(amount: int) -> void:
	current_hp -= amount


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


static func _is_living(k: int) -> bool:
	return k == Kind.UNIT or k == Kind.ENEMY
