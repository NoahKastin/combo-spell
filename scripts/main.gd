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

# §5.3 expanded grid: 3 rows × 4 columns with this exact ordering. Buttons
# whose wallet count is 0 stay disabled; tapping a button picks up that
# Element for placement during Expand.
const GRID_ICON_SIZE := 100.0
const GRID_SPACING := 20.0
const GRID_COUNT_FONT_SIZE := 32
const ELEMENT_GRID_LAYOUT: Array[int] = [
	Element.Type.EARTH, Element.Type.WOOD, Element.Type.WATER, Element.Type.SHADOW,
	Element.Type.METAL, Element.Type.FIRE, Element.Type.POISON, Element.Type.DREAD,
	Element.Type.WIND, Element.Type.ICE, Element.Type.LIGHTNING, Element.Type.ACID,
]
const PICKED_TINT := Color(1.4, 1.4, 0.7)
const CRAFTING_TINT := Color(1.0, 0.8, 1.4)

# §4.2: crafting trades 2 of the dragged Element for 1 of the dropped Element.
const CRAFT_COST := 2
const CRAFT_YIELD := 1

# §5.2 mid-zoom: primary symbol at center, up to N=2 smaller satellites
# adjacent. Hex-corner positions at 240° (upper-left) and 300° (upper-right),
# at radius 50 from the tile center; each satellite icon is half the primary
# size. Beyond N+1 distinct types, an "+M" badge nudges the player to zoom in.
const MAX_VISIBLE_SECONDARIES := 2
const SATELLITE_ICON_SIZE := 50.0
const SATELLITE_OFFSETS: Array[Vector2] = [
	Vector2(25, -43),    # ring 1, 300° (upper-right)
	Vector2(-25, -43),   # ring 1, 240° (upper-left)
]
const SATELLITE_COUNT_FONT_SIZE := 28
const OVERFLOW_FONT_SIZE := 32
const OVERFLOW_BADGE_OFFSET := Vector2(0, 50)

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
var picked_element: int = -1        # -1 = nothing picked up; otherwise Element.Type
var crafting_mode: bool = false
var element_buttons: Dictionary = {}      # Element.Type -> TextureButton
var element_count_labels: Dictionary = {} # Element.Type -> Label

@onready var phase_label: Label = $UI/PhaseLabel
@onready var next_phase_button: Button = $UI/NextPhaseButton
@onready var element_grid: Control = $UI/ElementGrid
@onready var recycle_button: Button = $UI/RecycleButton
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_seed_starting_candidates()
	var heart := Sprite2D.new()
	heart.texture = load("res://assets/heart.png")
	heart.position = layout.hex_to_screen(Vector2i.ZERO)
	add_child(heart)
	_build_element_grid()
	Game.phase_changed.connect(_on_phase_changed)
	Game.wallet_changed.connect(_refresh_wallet_display)
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	recycle_button.pressed.connect(_on_recycle_pressed)
	_refresh_phase_ui()
	_refresh_wallet_display()


func _build_element_grid() -> void:
	for i in ELEMENT_GRID_LAYOUT.size():
		var elem: int = ELEMENT_GRID_LAYOUT[i]
		var row: int = i / 4
		var col: int = i % 4
		var slot_pos := Vector2(col * (GRID_ICON_SIZE + GRID_SPACING), row * (GRID_ICON_SIZE + GRID_SPACING))
		var btn := TextureButton.new()
		# ignore_texture_size and stretch_mode go before texture_normal —
		# otherwise the button auto-sizes to the (large) PNG before we can
		# tell it not to.
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_normal = Element.ICON[elem]
		btn.position = slot_pos
		btn.custom_minimum_size = Vector2(GRID_ICON_SIZE, GRID_ICON_SIZE)
		btn.size = Vector2(GRID_ICON_SIZE, GRID_ICON_SIZE)
		btn.pivot_offset = Vector2(GRID_ICON_SIZE, GRID_ICON_SIZE) * 0.5
		btn.pressed.connect(_on_element_picked.bind(elem))
		element_grid.add_child(btn)
		element_buttons[elem] = btn

		var lbl := Label.new()
		lbl.text = "0"
		lbl.add_theme_font_size_override("font_size", GRID_COUNT_FONT_SIZE)
		lbl.add_theme_color_override("font_outline_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.size = Vector2(GRID_ICON_SIZE, GRID_COUNT_FONT_SIZE + 8)
		lbl.position = Vector2(0, GRID_ICON_SIZE - GRID_COUNT_FONT_SIZE - 6)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl)
		element_count_labels[elem] = lbl


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
	var sorted := _sorted_composition(tile)
	if sorted.is_empty():
		return
	var tile_center := layout.hex_to_screen(tile.coord)

	var primary: int = sorted[0]
	_draw_icon_at(Element.ICON[primary], tile_center, TILE_ICON_SIZE)
	var primary_count: int = tile.composition[primary]
	if primary_count > 1:
		_draw_count_at(tile_center, str(primary_count), COUNT_FONT_SIZE)

	var visible_secondaries: int = min(MAX_VISIBLE_SECONDARIES, sorted.size() - 1)
	for i in visible_secondaries:
		var elem: int = sorted[1 + i]
		var sat_pos: Vector2 = tile_center + SATELLITE_OFFSETS[i]
		_draw_icon_at(Element.ICON[elem], sat_pos, SATELLITE_ICON_SIZE)
		var sat_count: int = tile.composition[elem]
		if sat_count > 1:
			_draw_count_at(sat_pos, str(sat_count), SATELLITE_COUNT_FONT_SIZE)

	var hidden: int = sorted.size() - 1 - visible_secondaries
	if hidden > 0:
		_draw_count_at(tile_center + OVERFLOW_BADGE_OFFSET, "+" + str(hidden), OVERFLOW_FONT_SIZE)


# Composition keys sorted by count (descending). MVP has no insertion-order
# tracking yet, so ties resolve by Dictionary iteration order (which is
# insertion order in GDScript) — matches the §5.2 "earliest player addition"
# tiebreaker for tiles built up by augment actions.
func _sorted_composition(tile: Tile) -> Array[int]:
	var keys := tile.composition.keys()
	keys.sort_custom(func(a, b): return tile.composition[a] > tile.composition[b])
	var result: Array[int] = []
	for k in keys:
		result.append(k)
	return result


func _draw_icon_at(icon: Texture2D, center: Vector2, sz: float) -> void:
	var box := Vector2.ONE * sz
	draw_texture_rect(icon, Rect2(center - box * 0.5, box), false)


func _draw_count_at(at: Vector2, text: String, font_size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var box_width: float = TILE_ICON_SIZE * 1.5
	var pos := Vector2(at.x - box_width * 0.5, at.y + font_size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_width, font_size, COUNT_OUTLINE_WIDTH, Color.WHITE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_width, font_size, Color.BLACK)


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
		Phase.Type.EXPAND:
			# §4.2: while crafting mode is on, the only valid drop targets
			# are other grid Elements. Tile drops are gated off so the
			# player can't accidentally place a unit mid-craft.
			if not crafting_mode:
				_try_place_or_augment_at(world_pos)
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


# §4.2: Expand places a unit (drop on empty revealed tile) or augments an
# existing unit (drop on a Kind.UNIT tile) by spending 1 of the picked
# Element from the wallet. Heart, fog, resource, and enemy tiles refuse
# the drop. The drag-and-drop equivalent (§5.1) is "tap to pick up, tap a
# tile to drop" — pickup happens via the ElementGrid buttons.
func _try_place_or_augment_at(world_pos: Vector2) -> void:
	if picked_element < 0:
		return
	if Game.wallet.get(picked_element, 0) <= 0:
		_clear_picked()
		return
	var hex := layout.screen_to_hex(world_pos)
	if hex == Vector2i.ZERO:
		return
	if not revealed_tiles.has(hex):
		return
	var existing: Tile = tiles.get(hex)
	if existing == null:
		var unit := Tile.new(hex, Tile.Kind.UNIT)
		unit.add_element(picked_element)
		tiles[hex] = unit
	elif existing.kind == Tile.Kind.UNIT:
		existing.add_element(picked_element)
	else:
		# Resource or enemy — placement refused.
		return
	Game.add_to_wallet(picked_element, -1)
	queue_redraw()
	if Game.wallet.get(picked_element, 0) <= 0:
		_clear_picked()


func _on_element_picked(elem: int) -> void:
	if Game.phase != Phase.Type.EXPAND:
		return
	if picked_element == elem:
		_clear_picked()
		return
	if crafting_mode and picked_element >= 0:
		# Source already in hand: drop onto a different grid Element.
		_try_craft(picked_element, elem)
		return
	var min_required: int = CRAFT_COST if crafting_mode else 1
	if Game.wallet.get(elem, 0) < min_required:
		return
	picked_element = elem
	_refresh_picked_visual()
	_refresh_wallet_display()


# §4.2: crafting spends 2 of `source` and yields 1 of `target`. Wallet must
# already hold the cost; pickup gating in _on_element_picked enforces this,
# but we re-check here in case the source count changed between pickup and
# drop (e.g., a future action consumes Elements without clearing the pick).
func _try_craft(source: int, target: int) -> void:
	if Game.wallet.get(source, 0) < CRAFT_COST:
		_clear_picked()
		return
	Game.add_to_wallet(source, -CRAFT_COST)
	Game.add_to_wallet(target, CRAFT_YIELD)
	_clear_picked()


func _clear_picked() -> void:
	picked_element = -1
	_refresh_picked_visual()
	_refresh_wallet_display()


func _refresh_picked_visual() -> void:
	for elem in element_buttons:
		var btn: TextureButton = element_buttons[elem]
		btn.modulate = PICKED_TINT if elem == picked_element else Color.WHITE


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


func _on_recycle_pressed() -> void:
	if Game.phase != Phase.Type.EXPAND:
		return
	crafting_mode = not crafting_mode
	_clear_picked()
	_refresh_recycle_visual()
	_refresh_wallet_display()


func _refresh_recycle_visual() -> void:
	recycle_button.modulate = CRAFTING_TINT if crafting_mode else Color.WHITE


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == Phase.Type.EXPLOIT:
		harvested_this_phase = 0
	crafting_mode = false
	_clear_picked()
	_refresh_recycle_visual()
	_refresh_phase_ui()
	_refresh_wallet_display()


func _refresh_phase_ui() -> void:
	var p := Game.phase
	phase_label.text = Phase.NAME[p]
	phase_label.modulate = Phase.COLOR[p]
	# Force a deliberate candidate pick during Explore. The button stays
	# enabled in other phases as a phase-skip helper.
	next_phase_button.disabled = (p == Phase.Type.EXPLORE) and not candidates.is_empty()
	# §5.3: the crafting (recycle) button only appears during Expand.
	recycle_button.visible = p == Phase.Type.EXPAND


# Updates each grid slot's count label and disables buttons whose Element
# isn't pickable right now. Outside Expand: nothing is pickable. In Expand
# without crafting: need wallet ≥ 1 to pick up a placement. In Expand with
# crafting: pre-pickup needs wallet ≥ 2 (only valid sources are pickable);
# post-pickup all 12 buttons stay live so any can be a drop target or the
# source itself can be re-tapped to cancel.
func _refresh_wallet_display() -> void:
	var pickable_phase: bool = Game.phase == Phase.Type.EXPAND
	var has_pickup: bool = picked_element >= 0
	var min_required: int = CRAFT_COST if crafting_mode else 1
	for elem in element_buttons:
		var n: int = Game.wallet.get(elem, 0)
		var lbl: Label = element_count_labels[elem]
		lbl.text = str(n)
		var btn: TextureButton = element_buttons[elem]
		var enabled: bool = pickable_phase and (has_pickup or n >= min_required)
		btn.disabled = not enabled
