extends Node2D

# Scene root: hex draw, tap input, Explore-phase candidates, and tile contents.

const HEX_SIZE := 80.0
const ICON_TARGET_SIZE := 120.0
const TILE_ICON_SIZE := 100.0
const COUNT_FONT_SIZE := 56
const COUNT_OUTLINE_WIDTH := 4
const TILE_OUTLINE_COLOR := Color("#000000")
const TILE_OUTLINE_WIDTH := 2.0
const ROLE_OUTLINE_WIDTH := 4.0
const PERIMETER_WIDTH := 6.0
const FOG_FILL := Color("#BFBFBF")
const REVEALED_FILL := Color("#FFFFFF")

# §4.1: of an enemy's biome ≈ "highly likely but not guaranteed." Per-enemy
# probability of getting the biome's Element vs a uniform MVP draw.
const ENEMY_BIOME_BIAS := 0.7

# §10: MVP slice biomes. Subsequent-round candidates draw uniformly from these.
const MVP_BIOMES: Array[int] = [
	Element.Type.EARTH,
	Element.Type.METAL,
	Element.Type.WIND,
	Element.Type.WOOD,
]

# §4.1: at game start, three candidates with biomes drawn from {Earth, Metal, Wind}.
const STARTING_BIOMES: Array[int] = [
	Element.Type.EARTH,
	Element.Type.METAL,
	Element.Type.WIND,
]

# Big-hex centers for the three game-start candidates. Each center is a small-hex
# adjacent to the Heart at (0, 0), so the Heart sits on each cluster's boundary.
# TODO §4.1: map slots to "bottom / top-right / top-left" rigorously.
const STARTING_CENTERS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(-1, 1),
]

# For a flat-top hex with start_angle=0, the i-th edge (between corners i and
# i+1) faces the neighbor in the axial direction at index i below. Used to
# detect which edges of a cluster's tiles lie on the cluster's outer perimeter.
const PERIMETER_EDGE_NEIGHBOR: Array[Vector2i] = [
	Vector2i(1, 0),    # edge 0→1
	Vector2i(0, 1),    # edge 1→2
	Vector2i(-1, 1),   # edge 2→3
	Vector2i(-1, 0),   # edge 3→4
	Vector2i(0, -1),   # edge 4→5
	Vector2i(1, -1),   # edge 5→0
]

# §5.2: role-tag tile outlines. Empty revealed tiles use the standard black
# outline; only occupied tiles get a role color.
const ROLE_OUTLINE_COLOR := {
	Tile.Kind.RESOURCE: Color("#3498DB"),
	Tile.Kind.ENEMY: Color("#E63946"),
	Tile.Kind.UNIT: Color("#2ECC71"),
}

var layout := HexLayout.new(HEX_SIZE)
var candidates: Array[BigHex] = []
var revealed_big_hexes: Array[BigHex] = []
var revealed_tiles: Dictionary = {} # Vector2i -> true
var tiles: Dictionary = {}          # Vector2i -> Tile (occupied tiles only)
var harvested_this_phase: int = 0

@onready var phase_label: Label = $UI/PhaseLabel
@onready var next_phase_button: Button = $UI/NextPhaseButton
@onready var wallet_label: Label = $UI/WalletLabel
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_seed_starting_candidates()
	var heart := Sprite2D.new()
	heart.texture = load("res://assets/heart.png")
	heart.position = layout.hex_to_screen(Vector2i.ZERO)
	add_child(heart)
	Game.phase_changed.connect(_on_phase_changed)
	Game.wallet_changed.connect(_refresh_wallet_label)
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	_refresh_phase_ui()
	_refresh_wallet_label()


func _seed_starting_candidates() -> void:
	var biomes := STARTING_BIOMES.duplicate()
	biomes.shuffle()
	for i in STARTING_CENTERS.size():
		candidates.append(BigHex.new(STARTING_CENTERS[i], biomes[i]))


# §4.1: each reveal adds the just-revealed cluster's six lattice-neighbor
# centers as candidates, skipping any already-pending or whose center sits
# inside revealed territory (would produce a cluster nested inside another).
# Unrevealed candidates persist across rounds so the player can come back
# later to options they passed over.
func _add_candidates_around(big_hex: BigHex) -> void:
	var existing: Dictionary = {}
	for c in candidates:
		existing[c.center] = true
	for neighbor_center in HexGrid.big_hex_neighbors(big_hex.center):
		if existing.has(neighbor_center):
			continue
		if revealed_tiles.has(neighbor_center):
			continue
		var biome: int = MVP_BIOMES.pick_random()
		candidates.append(BigHex.new(neighbor_center, biome))


# Drop candidates whose center now sits inside revealed territory. A fresh
# reveal can engulf a previously-added candidate's center; if so, revealing
# that candidate would draw a big-hex nested inside an already-explored
# cluster, which is never useful.
func _prune_nested_candidates() -> void:
	var keep: Array[BigHex] = []
	for c in candidates:
		if not revealed_tiles.has(c.center):
			keep.append(c)
	candidates = keep


# §4.1: at reveal, seed the cluster with resource Elements (= 2 × multiplier,
# biome guaranteed once) and up to that many enemy Elements (biome biased).
# Enemies stay at distance ≥ 2 from the Heart; the Heart tile itself never
# holds resources or enemies; tiles already occupied by an overlapping
# previously-revealed cluster keep their existing contents.
# Multi-Element tiles are intended (§4.1 talks of "total Elements," not
# "total tiles") — _stacked_tile_count keeps clusters from saturating at
# higher multipliers by piling Elements onto fewer rich tiles.
func _seed_contents(big_hex: BigHex) -> void:
	var mult := Game.difficulty_multiplier()
	var resource_elements: int = 2 * mult
	var enemy_elements: int = randi_range(0, 2 * mult)

	var available: Array[Vector2i] = []
	for t in big_hex.tiles():
		if t == Vector2i.ZERO:
			continue
		if tiles.has(t):
			continue
		available.append(t)
	available.shuffle()

	var enemy_eligible: Array[Vector2i] = []
	for t in available:
		if HexGrid.distance(t, Vector2i.ZERO) >= 2:
			enemy_eligible.append(t)

	var enemy_tile_count: int = min(_stacked_tile_count(enemy_elements), enemy_eligible.size())
	var enemy_coords: Array[Vector2i] = enemy_eligible.slice(0, enemy_tile_count)

	var enemy_set: Dictionary = {}
	for c in enemy_coords:
		enemy_set[c] = true
	var resource_eligible: Array[Vector2i] = []
	for t in available:
		if not enemy_set.has(t):
			resource_eligible.append(t)
	var resource_tile_count: int = min(_stacked_tile_count(resource_elements), resource_eligible.size())
	var resource_coords: Array[Vector2i] = resource_eligible.slice(0, resource_tile_count)

	_seed_resources(resource_coords, resource_elements, big_hex.biome)
	_seed_enemies(enemy_coords, enemy_elements, big_hex.biome)


# Aim for ~2 Elements per occupied tile. Stacking is visible from cycle 1
# (multiplier 1: 2 Elements on 1 tile) and tile count grows slower than the
# Element budget so the cluster doesn't saturate at high multipliers.
static func _stacked_tile_count(elements: int) -> int:
	if elements <= 0:
		return 0
	return max(1, (elements + 1) / 2)


func _seed_resources(coords: Array[Vector2i], element_count: int, biome: int) -> void:
	if coords.is_empty() or element_count == 0:
		return
	# §4.1: each resource tile holds a single Element type. Tile coords[0]
	# carries the biome (guaranteed); other tiles each get a random MVP type.
	# Element scatter then stacks each tile's predetermined type, never
	# mixing types on a single resource tile.
	var types: Array[int] = [biome]
	for _i in range(1, coords.size()):
		types.append(MVP_BIOMES.pick_random())
	tiles[coords[0]] = Tile.new(coords[0], Tile.Kind.RESOURCE)
	tiles[coords[0]].add_element(biome)
	for _i in range(1, element_count):
		var idx: int = randi() % coords.size()
		var c: Vector2i = coords[idx]
		var t: Tile = tiles.get(c)
		if t == null:
			t = Tile.new(c, Tile.Kind.RESOURCE)
			tiles[c] = t
		t.add_element(types[idx])


func _seed_enemies(coords: Array[Vector2i], element_count: int, biome: int) -> void:
	if coords.is_empty() or element_count == 0:
		return
	# Each enemy tile gets at least one Element, with biome bias on its first.
	for c in coords:
		var t := Tile.new(c, Tile.Kind.ENEMY)
		var first_elem: int = biome if randf() < ENEMY_BIOME_BIAS else MVP_BIOMES.pick_random()
		t.add_element(first_elem)
		tiles[c] = t
	# Remaining Elements scatter across enemies (uniform from MVP set).
	for i in range(coords.size(), element_count):
		var c: Vector2i = coords.pick_random()
		var t: Tile = tiles[c]
		t.add_element(MVP_BIOMES.pick_random())


func _draw() -> void:
	_draw_fog_layer()
	for big_hex in revealed_big_hexes:
		_draw_revealed_big_hex(big_hex)
	for big_hex in candidates:
		_draw_biome_marker(big_hex)


func _draw_fog_layer() -> void:
	for tile in _visible_hexes():
		if revealed_tiles.has(tile):
			continue
		var corners := layout.hex_corners(tile)
		draw_colored_polygon(corners, FOG_FILL)
		_draw_tile_outline(corners)


func _draw_revealed_big_hex(big_hex: BigHex) -> void:
	for tile_coord in big_hex.tiles():
		var corners := layout.hex_corners(tile_coord)
		draw_colored_polygon(corners, REVEALED_FILL)
		var tile: Tile = tiles.get(tile_coord)
		if tile != null and not tile.is_empty():
			_draw_role_outline(corners, tile.kind)
			_draw_element_icon(tile)
		else:
			_draw_tile_outline(corners)
	_draw_cluster_perimeter(big_hex)


func _draw_tile_outline(corners: PackedVector2Array) -> void:
	var closed := PackedVector2Array(corners)
	closed.append(closed[0])
	draw_polyline(closed, TILE_OUTLINE_COLOR, TILE_OUTLINE_WIDTH, true)


func _draw_role_outline(corners: PackedVector2Array, kind: int) -> void:
	var color: Color = ROLE_OUTLINE_COLOR[kind]
	var closed := PackedVector2Array(corners)
	closed.append(closed[0])
	draw_polyline(closed, color, ROLE_OUTLINE_WIDTH, true)


func _draw_cluster_perimeter(big_hex: BigHex) -> void:
	var color: Color = Element.COLOR[big_hex.biome]
	var members: Dictionary = {}
	for t in big_hex.tiles():
		members[t] = true
	for tile in big_hex.tiles():
		var corners := layout.hex_corners(tile)
		for edge in 6:
			var neighbor: Vector2i = tile + PERIMETER_EDGE_NEIGHBOR[edge]
			if members.has(neighbor):
				continue
			draw_line(corners[edge], corners[(edge + 1) % 6], color, PERIMETER_WIDTH, true)


func _draw_biome_marker(big_hex: BigHex) -> void:
	var icon: Texture2D = Element.ICON[big_hex.biome]
	var size := Vector2.ONE * ICON_TARGET_SIZE
	var pos := layout.hex_to_screen(big_hex.center) - size * 0.5
	draw_texture_rect(icon, Rect2(pos, size), false)


func _draw_element_icon(tile: Tile) -> void:
	var primary := tile.primary_element()
	if primary < 0:
		return
	var icon: Texture2D = Element.ICON[primary]
	var size := Vector2.ONE * TILE_ICON_SIZE
	var tile_center := layout.hex_to_screen(tile.coord)
	draw_texture_rect(icon, Rect2(tile_center - size * 0.5, size), false)
	var count: int = tile.composition[primary]
	if count > 1:
		_draw_tile_count(tile_center, count)


func _draw_tile_count(at: Vector2, count: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var text := str(count)
	var box_width := TILE_ICON_SIZE * 1.5
	# draw_string anchors at the baseline; nudge down so the glyph sits near
	# the tile's vertical center.
	var pos := Vector2(at.x - box_width * 0.5, at.y + COUNT_FONT_SIZE * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_width, COUNT_FONT_SIZE, COUNT_OUTLINE_WIDTH, Color.WHITE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_width, COUNT_FONT_SIZE, Color.BLACK)


# All hex coords whose centers fall within the viewport, padded by 1 to cover
# tiles that straddle the edge.
func _visible_hexes() -> Array[Vector2i]:
	var view_size := get_viewport_rect().size
	var cam_pos := camera.position
	var screen_corners: Array[Vector2] = [
		cam_pos + Vector2(-view_size.x * 0.5, -view_size.y * 0.5),
		cam_pos + Vector2(view_size.x * 0.5, -view_size.y * 0.5),
		cam_pos + Vector2(-view_size.x * 0.5, view_size.y * 0.5),
		cam_pos + Vector2(view_size.x * 0.5, view_size.y * 0.5),
	]
	var first := layout.screen_to_hex(screen_corners[0])
	var min_q: int = first.x
	var max_q: int = first.x
	var min_r: int = first.y
	var max_r: int = first.y
	for i in range(1, screen_corners.size()):
		var h := layout.screen_to_hex(screen_corners[i])
		min_q = min(min_q, h.x)
		max_q = max(max_q, h.x)
		min_r = min(min_r, h.y)
		max_r = max(max_r, h.y)
	var result: Array[Vector2i] = []
	for q in range(min_q - 1, max_q + 2):
		for r in range(min_r - 1, max_r + 2):
			result.append(Vector2i(q, r))
	return result


func _unhandled_input(event: InputEvent) -> void:
	var world_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_pos = get_global_mouse_position()
	elif event is InputEventScreenTouch and event.pressed:
		world_pos = get_canvas_transform().affine_inverse() * event.position
	else:
		return
	match Game.phase:
		Phase.Type.EXPLORE:
			_try_reveal_at(world_pos)
		Phase.Type.EXPLOIT:
			_try_harvest_at(world_pos)


func _try_reveal_at(world_pos: Vector2) -> void:
	var hex := layout.screen_to_hex(world_pos)
	# A tap on a candidate's center (where the biome marker sits) takes
	# priority — disambiguates clusters whose outer tiles overlap, e.g., the
	# Heart at game-start sits in all three candidate clusters.
	for big_hex in candidates:
		if hex == big_hex.center:
			_reveal(big_hex)
			return
	var matches: Array[BigHex] = []
	for big_hex in candidates:
		if hex in big_hex.tiles():
			matches.append(big_hex)
	if matches.size() == 1:
		_reveal(matches[0])
	# Else (0 or >1 matches): no-op. Player taps closer to a marker for a
	# clean pick.


# §4.3: Exploit harvests Elements from resource tiles. Tap a resource → 1
# of its primary Element moves into Game.wallet, capped at `multiplier` per
# phase. Tap-and-hold and AI macros are MVP TODOs.
func _try_harvest_at(world_pos: Vector2) -> void:
	if harvested_this_phase >= Game.difficulty_multiplier():
		return
	var hex := layout.screen_to_hex(world_pos)
	var tile: Tile = tiles.get(hex)
	if tile == null or tile.kind != Tile.Kind.RESOURCE:
		return
	_harvest_one(tile)


func _harvest_one(tile: Tile) -> void:
	var primary := tile.primary_element()
	if primary < 0:
		return
	tile.composition[primary] -= 1
	if tile.composition[primary] <= 0:
		tile.composition.erase(primary)
	if tile.composition.is_empty():
		tiles.erase(tile.coord)
	harvested_this_phase += 1
	Game.add_to_wallet(primary, 1)
	queue_redraw()


func _reveal(big_hex: BigHex) -> void:
	big_hex.revealed = true
	revealed_big_hexes.append(big_hex)
	for t in big_hex.tiles():
		revealed_tiles[t] = true
	_seed_contents(big_hex)
	candidates.erase(big_hex)
	_prune_nested_candidates()
	_add_candidates_around(big_hex)
	queue_redraw()
	Game.advance_phase()


func _on_next_phase_pressed() -> void:
	Game.advance_phase()


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == Phase.Type.EXPLOIT:
		harvested_this_phase = 0
	_refresh_phase_ui()


func _refresh_phase_ui() -> void:
	var p := Game.phase
	phase_label.text = Phase.NAME[p]
	phase_label.modulate = Phase.COLOR[p]
	# Force a deliberate candidate pick during Explore. The button stays
	# enabled in other phases as a phase-skip helper.
	next_phase_button.disabled = (p == Phase.Type.EXPLORE) and not candidates.is_empty()


func _refresh_wallet_label() -> void:
	var lines: Array[String] = []
	for kind in MVP_BIOMES:
		var n: int = Game.wallet.get(kind, 0)
		var line: String = "%s: %d" % [Element.NAME[kind], n]
		lines.append(line)
	wallet_label.text = "\n".join(lines)
