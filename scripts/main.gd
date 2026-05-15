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

# §5.3 expanded grid. Buttons whose wallet count is 0 stay disabled; tapping
# a button picks up that Element for placement during Expand.
#
# ITCH.IO TRIM: this release ships only the four MVP-active Elements as a
# single column (Wood below Wind). To restore the full 3×4 grid for the next
# version, revert GRID_COLS to 4, restore the 12-Element layout below, and
# in scenes/main.tscn move RecycleButton back to offset_top=420 / offset_bottom=520:
#   Element.Type.EARTH, Element.Type.WOOD, Element.Type.WATER, Element.Type.SHADOW,
#   Element.Type.METAL, Element.Type.FIRE, Element.Type.POISON, Element.Type.DREAD,
#   Element.Type.WIND,  Element.Type.ICE,  Element.Type.LIGHTNING, Element.Type.ACID,
const GRID_ICON_SIZE := 100.0
const GRID_SPACING := 20.0
const GRID_COUNT_FONT_SIZE := 32
const GRID_COLS := 1
const ELEMENT_GRID_LAYOUT: Array[int] = [
	Element.Type.EARTH,
	Element.Type.METAL,
	Element.Type.WIND,
	Element.Type.WOOD,
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

# §4.4 Exterminate visuals. Selection outline lands above the role outline; the
# move / attack fills sit over the tile body but under the role outline so the
# tile's identity stays readable through the highlight.
const SELECTION_OUTLINE_COLOR := Color("#FFD400")
const SELECTION_OUTLINE_WIDTH := 8.0
const MOVE_HIGHLIGHT_FILL := Color(0.20, 0.80, 0.30, 0.40)
const ATTACK_HIGHLIGHT_FILL := Color(0.95, 0.20, 0.25, 0.40)

# §4.4 enemy half: short pause between actions so the player can follow the
# replay. Below ~0.3s feels jerky; above ~0.6s drags. Tune via playtesting.
const ENEMY_TURN_DELAY := 0.45

# HP indicator on damaged living tiles. Bottom-right of the icon area, distinct
# from the overflow "+M" badge at (0, 50). Uses Dread red — the palette's only
# "this means harm" hue.
const HP_FONT_SIZE := 28
const HP_BADGE_OFFSET := Vector2(45, 42)
const HP_BADGE_COLOR := Color("#FF0055")

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

# §4.4 Exterminate state. `units_acted` is Vector2i -> true for units that have
# spent their action this phase. `selected_unit_coord` is meaningful only when
# `has_unit_selected` is true — Vector2i has no null, so we gate with a flag.
# `valid_moves` / `valid_attacks` are coord-sets re-computed on each selection.
# `in_enemy_half` suppresses input + redirects the play button while the AI
# replays. `game_over` latches once any enemy lands on the Heart.
var units_acted: Dictionary = {}
var selected_unit_coord: Vector2i
var has_unit_selected: bool = false
var valid_moves: Dictionary = {}
var valid_attacks: Dictionary = {}
var in_enemy_half: bool = false
var game_over: bool = false

@onready var phase_label: Label = $UI/PhaseLabel
@onready var next_phase_button: Button = $UI/NextPhaseButton
@onready var multiplier_label: Label = $UI/MultiplierLabel
@onready var element_grid: Control = $UI/ElementGrid
@onready var recycle_button: Button = $UI/RecycleButton
@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var play_again_button: Button = $UI/GameOverPanel/PlayAgainButton
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_seed_starting_candidates()
	var heart := Sprite2D.new()
	heart.texture = load("res://assets/heart.png")
	heart.position = layout.hex_to_screen(Vector2i.ZERO)
	# heart.png is 204px; sized down to match the Element-icon footprint so it
	# stays inside its own tile (was spilling ~50px into each neighbor and
	# painting over neighbor HP badges + parts of neighbor icons). Matches the
	# §11 placeholder note: Heart art will sit "alongside the Element symbols."
	heart.scale = Vector2.ONE * (TILE_ICON_SIZE / float(heart.texture.get_width()))
	add_child(heart)
	_build_element_grid()
	Game.phase_changed.connect(_on_phase_changed)
	Game.wallet_changed.connect(_refresh_wallet_display)
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	recycle_button.pressed.connect(_on_recycle_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)
	_refresh_phase_ui()
	_refresh_wallet_display()
	_refresh_multiplier_label()


func _build_element_grid() -> void:
	for i in ELEMENT_GRID_LAYOUT.size():
		var elem: int = ELEMENT_GRID_LAYOUT[i]
		var row: int = i / GRID_COLS
		var col: int = i % GRID_COLS
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
# Subsumed-candidate biomes also become guaranteed resource nodes, drawn
# from the same 2 × multiplier budget after the chosen-biome node.
# Enemies stay at distance ≥ 2 from the Heart; the Heart tile itself never
# holds resources or enemies; tiles already occupied by an overlapping
# previously-revealed cluster keep their existing contents.
# Multi-Element tiles are intended (§4.1 talks of "total Elements," not
# "total tiles") — _stacked_tile_count keeps clusters from saturating at
# higher multipliers by piling Elements onto fewer rich tiles.
func _seed_contents(big_hex: BigHex, bonus_biomes: Array[int]) -> void:
	var mult := Game.difficulty_multiplier()
	var resource_elements: int = 2 * mult
	var enemy_elements: int = randi_range(0, 2 * mult)

	# §4.1 priority for guaranteed resource nodes: chosen biome first, then
	# subsumed-candidate biomes in original-offer order. Cap by budget —
	# overflow drops silently per the spec's tie-break rule.
	var guaranteed: Array[int] = [big_hex.biome]
	for b in bonus_biomes:
		if guaranteed.size() >= resource_elements:
			break
		guaranteed.append(b)

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
	# Reserve at least one resource tile per guaranteed biome so subsumed
	# bonuses don't silently drop while the cluster still has free tiles.
	var resource_tile_count: int = max(_stacked_tile_count(resource_elements), guaranteed.size())
	resource_tile_count = min(resource_tile_count, resource_eligible.size())
	var resource_coords: Array[Vector2i] = resource_eligible.slice(0, resource_tile_count)

	_seed_resources(resource_coords, resource_elements, guaranteed)
	_seed_enemies(enemy_coords, enemy_elements, big_hex.biome)


# Aim for ~2 Elements per occupied tile. Stacking is visible from cycle 1
# (multiplier 1: 2 Elements on 1 tile) and tile count grows slower than the
# Element budget so the cluster doesn't saturate at high multipliers.
static func _stacked_tile_count(elements: int) -> int:
	if elements <= 0:
		return 0
	return max(1, (elements + 1) / 2)


func _seed_resources(coords: Array[Vector2i], element_count: int, guaranteed: Array[int]) -> void:
	if coords.is_empty() or element_count == 0:
		return
	# §4.1: each resource tile holds a single Element type — its "predetermined
	# type." Guaranteed types fill the first len(guaranteed) tiles in priority
	# order (chosen biome, then subsumed-candidate biomes); remaining tiles
	# take a random MVP biome each. Random Element scatter then stacks each
	# tile's predetermined type, never mixing types on a single resource tile.
	var types: Array[int] = []
	for i in coords.size():
		if i < guaranteed.size():
			types.append(guaranteed[i])
		else:
			types.append(MVP_BIOMES.pick_random())
	var seeded_count: int = min(guaranteed.size(), coords.size())
	for i in seeded_count:
		var c: Vector2i = coords[i]
		var t := Tile.new(c, Tile.Kind.RESOURCE)
		t.add_element(types[i])
		tiles[c] = t
	# Random fill for the remaining budget. Each Element lands on a random
	# eligible tile and adopts that tile's predetermined type so resource
	# tiles stay single-typed.
	for _i in range(seeded_count, element_count):
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
	if has_unit_selected:
		_draw_selection_outline(selected_unit_coord)


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
		# §4.4 highlight fills sit between the tile body and the role outline
		# so the role color (and icons drawn after) stay legible through the
		# wash. Move and attack are mutually exclusive — a unit only ever has
		# the same tile in one of the two sets.
		if valid_moves.has(tile_coord):
			draw_colored_polygon(corners, MOVE_HIGHLIGHT_FILL)
		elif valid_attacks.has(tile_coord):
			draw_colored_polygon(corners, ATTACK_HIGHLIGHT_FILL)
		var tile: Tile = tiles.get(tile_coord)
		if tile != null and not tile.is_empty():
			_draw_role_outline(corners, tile.kind)
			_draw_element_icon(tile)
			if _is_living_tile(tile) and tile.current_hp < tile.max_hp:
				_draw_hp_badge(tile)
		else:
			_draw_tile_outline(corners)
	_draw_cluster_perimeter(big_hex)


func _draw_selection_outline(coord: Vector2i) -> void:
	var corners := layout.hex_corners(coord)
	var closed := PackedVector2Array(corners)
	closed.append(closed[0])
	draw_polyline(closed, SELECTION_OUTLINE_COLOR, SELECTION_OUTLINE_WIDTH, true)


func _draw_hp_badge(tile: Tile) -> void:
	var at := layout.hex_to_screen(tile.coord) + HP_BADGE_OFFSET
	var font: Font = ThemeDB.fallback_font
	var text := "%d/%d" % [tile.current_hp, tile.max_hp]
	var box_width: float = TILE_ICON_SIZE
	var pos := Vector2(at.x - box_width * 0.5, at.y + HP_FONT_SIZE * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_width, HP_FONT_SIZE, COUNT_OUTLINE_WIDTH, Color.WHITE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_width, HP_FONT_SIZE, HP_BADGE_COLOR)


static func _is_living_tile(tile: Tile) -> bool:
	return tile.kind == Tile.Kind.UNIT or tile.kind == Tile.Kind.ENEMY


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
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_width, font_size, COUNT_OUTLINE_WIDTH, FOG_FILL)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box_width, font_size, Color.WHITE)


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
	if game_over:
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
		Phase.Type.EXTERMINATE:
			if not in_enemy_half:
				_try_exterminate_at(world_pos)


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
	_refresh_multiplier_label()
	queue_redraw()


func _reveal(big_hex: BigHex) -> void:
	big_hex.revealed = true
	revealed_big_hexes.append(big_hex)
	for t in big_hex.tiles():
		revealed_tiles[t] = true
	# Erase the chosen big-hex before collecting subsumed biomes — its center
	# is now in revealed_tiles too, but it's the reveal source, not one of the
	# candidates about to be pruned by it.
	candidates.erase(big_hex)
	var subsumed_biomes := _collect_subsumed_biomes()
	_seed_contents(big_hex, subsumed_biomes)
	_prune_nested_candidates()
	_add_candidates_around(big_hex)
	queue_redraw()
	Game.advance_phase()


# §4.1: a candidate whose center now sits inside revealed territory is about
# to be pruned. Its biome becomes a guaranteed extra resource node in the
# chosen big-hex, in the order it was originally offered. The caller must
# erase the chosen big-hex from `candidates` first so it isn't picked up here.
func _collect_subsumed_biomes() -> Array[int]:
	var result: Array[int] = []
	for c in candidates:
		if revealed_tiles.has(c.center):
			result.append(c.biome)
	return result


func _on_next_phase_pressed() -> void:
	if game_over:
		return
	# §4.4: pressing play during Exterminate ends the player's unit half and
	# kicks off the enemy half; only at the end of that does the cycle tick
	# over to the next Explore.
	if Game.phase == Phase.Type.EXTERMINATE:
		if not in_enemy_half:
			_run_enemy_half()
		return
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
	if new_phase == Phase.Type.EXTERMINATE:
		units_acted.clear()
		in_enemy_half = false
	crafting_mode = false
	_clear_picked()
	_clear_unit_selection()
	_refresh_recycle_visual()
	_refresh_phase_ui()
	_refresh_wallet_display()
	_refresh_multiplier_label()


func _refresh_phase_ui() -> void:
	var p := Game.phase
	phase_label.text = Phase.NAME[p]
	phase_label.modulate = Phase.COLOR[p]
	# Force a deliberate candidate pick during Explore. The button stays
	# enabled in other phases as a phase-skip helper. During Exterminate it
	# also disables while the enemy half is replaying so the player can't
	# double-trigger advancement mid-replay.
	if game_over:
		next_phase_button.disabled = true
	elif p == Phase.Type.EXPLORE and not candidates.is_empty():
		next_phase_button.disabled = true
	elif p == Phase.Type.EXTERMINATE and in_enemy_half:
		next_phase_button.disabled = true
	else:
		next_phase_button.disabled = false
	# §5.3: the crafting (recycle) button only appears during Expand. The full
	# Element grid is hidden during Exterminate so the player focuses on action
	# resolution rather than loadout tweaks.
	recycle_button.visible = p == Phase.Type.EXPAND
	element_grid.visible = p != Phase.Type.EXTERMINATE


# §5.3: the right-notch multiplier slot doubles as the Exploit harvest-budget
# counter. Outside Exploit it shows the bare difficulty multiplier; during
# Exploit it shows `remaining/multiplier`, decrementing on each harvest.
func _refresh_multiplier_label() -> void:
	var mult := Game.difficulty_multiplier()
	if Game.phase == Phase.Type.EXPLOIT:
		var remaining: int = mult - harvested_this_phase
		multiplier_label.text = "%d/%d" % [remaining, mult]
	else:
		multiplier_label.text = str(mult)


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


# ============================================================================
# §4.4 Exterminate — unit half
# ============================================================================

# Tap dispatch during the unit half. With nothing selected: tapping an un-acted
# friendly unit selects it. With a unit selected: tapping the same unit
# deselects, tapping a highlighted move/attack tile resolves that action,
# tapping a different un-acted unit switches selection, and an irrelevant tap
# is a no-op (selection sticks so the player doesn't fight a fat-finger tap).
func _try_exterminate_at(world_pos: Vector2) -> void:
	var hex := layout.screen_to_hex(world_pos)
	if has_unit_selected:
		if hex == selected_unit_coord:
			_clear_unit_selection()
			return
		if valid_moves.has(hex):
			_move_selected_to(hex)
			return
		if valid_attacks.has(hex):
			_attack_with_selected(hex)
			return
	var tile: Tile = tiles.get(hex)
	if tile != null and tile.kind == Tile.Kind.UNIT and not units_acted.has(hex):
		_select_unit(hex)


func _select_unit(coord: Vector2i) -> void:
	selected_unit_coord = coord
	has_unit_selected = true
	var tile: Tile = tiles[coord]
	valid_moves = _compute_valid_moves(tile)
	valid_attacks = _compute_valid_attacks(tile)
	queue_redraw()


func _clear_unit_selection() -> void:
	if not has_unit_selected:
		return
	has_unit_selected = false
	valid_moves = {}
	valid_attacks = {}
	queue_redraw()


# BFS from the unit's tile through unit-passable tiles, up to Wood steps. The
# start tile is excluded from the result; only destinations the unit can land
# on are included.
func _compute_valid_moves(unit: Tile) -> Dictionary:
	var wood: int = unit.composition.get(Element.Type.WOOD, 0)
	if wood <= 0:
		return {}
	var result: Dictionary = {}
	var distances: Dictionary = {unit.coord: 0}
	var frontier: Array[Vector2i] = [unit.coord]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var d: int = distances[current]
		if d >= wood:
			continue
		for neighbor in HexGrid.neighbors(current):
			if distances.has(neighbor):
				continue
			if not _unit_can_pass(neighbor):
				continue
			distances[neighbor] = d + 1
			result[neighbor] = true
			frontier.append(neighbor)
	return result


# Player units skip the Heart and any occupied tile (resource, enemy, other
# unit). Fog-covered tiles are off-limits — Explore confines play to revealed
# territory (§4.1).
func _unit_can_pass(coord: Vector2i) -> bool:
	if not revealed_tiles.has(coord):
		return false
	if coord == Vector2i.ZERO:
		return false
	return not tiles.has(coord)


# §3.1 Metal: intentional attack needs Wind ≥ 1; range is Wind hex distance.
# MVP has no line-of-sight check — Wind is pure distance.
func _compute_valid_attacks(unit: Tile) -> Dictionary:
	var metal: int = unit.composition.get(Element.Type.METAL, 0)
	var wind: int = unit.composition.get(Element.Type.WIND, 0)
	if metal <= 0 or wind <= 0:
		return {}
	var result: Dictionary = {}
	for coord in tiles:
		var tile: Tile = tiles[coord]
		if tile.kind != Tile.Kind.ENEMY:
			continue
		if HexGrid.distance(unit.coord, coord) > wind:
			continue
		result[coord] = true
	return result


func _move_selected_to(dest: Vector2i) -> void:
	var unit: Tile = tiles[selected_unit_coord]
	tiles.erase(selected_unit_coord)
	unit.coord = dest
	tiles[dest] = unit
	units_acted[dest] = true
	_clear_unit_selection()


func _attack_with_selected(target_coord: Vector2i) -> void:
	var unit: Tile = tiles[selected_unit_coord]
	var damage: int = unit.composition.get(Element.Type.METAL, 0)
	var attacker_coord: Vector2i = selected_unit_coord
	_apply_attack_damage(target_coord, damage, attacker_coord)
	# Counter may have killed the attacker; only mark acted if still alive
	# (a tile entry for a dead unit would never be read, but stale state is
	# stale state).
	if tiles.has(attacker_coord):
		units_acted[attacker_coord] = true
	_clear_unit_selection()


# §3.1 Metal: an intentional attack also triggers the defender's counter if it
# survives with Metal ≥ 1 and the attacker sits within (defender Wind + 1) hex
# distance — so a 0-Wind defender still swings back at an adjacent attacker.
# Per §3 "passive triggers fire automatically as part of whatever active action
# causes them," the counter doesn't cost the defender's own Exterminate action.
# Counters don't chain — they're scoped to intentional attacks only, so a
# counter never triggers a counter-counter.
func _apply_attack_damage(target_coord: Vector2i, amount: int, attacker_coord: Vector2i) -> void:
	_apply_damage(target_coord, amount)
	var defender: Tile = tiles.get(target_coord)
	if defender == null:
		return
	var defender_metal: int = defender.composition.get(Element.Type.METAL, 0)
	if defender_metal <= 0:
		return
	if not tiles.has(attacker_coord):
		return
	var counter_range: int = defender.composition.get(Element.Type.WIND, 0) + 1
	if HexGrid.distance(target_coord, attacker_coord) > counter_range:
		return
	_apply_damage(attacker_coord, defender_metal)


# §1: defeated enemies refund their full Element composition to the player.
# Player units don't — losing them is a real cost.
func _apply_damage(target_coord: Vector2i, amount: int) -> void:
	var target: Tile = tiles.get(target_coord)
	if target == null:
		return
	target.take_damage(amount)
	if target.current_hp > 0:
		return
	if target.kind == Tile.Kind.ENEMY:
		for elem in target.composition:
			Game.add_to_wallet(elem, target.composition[elem])
	tiles.erase(target_coord)


# ============================================================================
# §4.4 Exterminate — enemy half
# ============================================================================

# Replay loop. Each enemy decides and animates its action in turn, with a
# short pause between so the player can read what happened. If any enemy lands
# on the Heart, latch game_over and stop. Otherwise advance to next Explore.
func _run_enemy_half() -> void:
	in_enemy_half = true
	_refresh_phase_ui()
	var enemy_coords := _enemy_action_order()
	for start_coord in enemy_coords:
		if game_over:
			break
		# Guard against an enemy already gone (no current passive can chain-kill
		# during the enemy half — cheap to keep the loop honest anyway).
		var enemy: Tile = tiles.get(start_coord)
		if enemy == null or enemy.kind != Tile.Kind.ENEMY:
			continue
		await _run_enemy(start_coord)
	in_enemy_half = false
	if game_over:
		_show_game_over()
	else:
		Game.advance_phase()


# Deterministic action order: ascending q, then ascending r. Keeps the replay
# reproducible given identical board state.
func _enemy_action_order() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for coord in tiles:
		if tiles[coord].kind == Tile.Kind.ENEMY:
			coords.append(coord)
	coords.sort_custom(func(a, b):
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y)
	return coords


# §4.4 enemy decision (MVP): attack if Metal ≥ 1, Wind ≥ 1, and a unit is in
# range; otherwise move toward the Heart up to Wood steps. No compound
# move-then-attack — single action per turn matches the player rule.
func _run_enemy(coord: Vector2i) -> void:
	var enemy: Tile = tiles[coord]
	var metal: int = enemy.composition.get(Element.Type.METAL, 0)
	var wind: int = enemy.composition.get(Element.Type.WIND, 0)
	if metal > 0 and wind > 0:
		var target := _find_enemy_attack_target(coord, wind)
		if target != Vector2i.MAX:
			await _animate_enemy_attack(coord, target, metal)
			return
	var wood: int = enemy.composition.get(Element.Type.WOOD, 0)
	if wood <= 0:
		return
	var dest := _find_enemy_destination(coord, wood)
	if dest == coord:
		return
	await _animate_enemy_move(coord, dest)


# Closest unit within Wind range; ties → lowest current HP, then lexicographic
# (q, r) for determinism. Vector2i.MAX means "no unit in range."
func _find_enemy_attack_target(attacker: Vector2i, wind: int) -> Vector2i:
	var best := Vector2i.MAX
	var best_dist: int = wind + 1
	var best_hp: int = 1 << 30
	for coord in tiles:
		var tile: Tile = tiles[coord]
		if tile.kind != Tile.Kind.UNIT:
			continue
		var d: int = HexGrid.distance(attacker, coord)
		if d > wind:
			continue
		var hp: int = tile.current_hp
		var better: bool = false
		if d < best_dist:
			better = true
		elif d == best_dist and hp < best_hp:
			better = true
		elif d == best_dist and hp == best_hp:
			if coord.x < best.x or (coord.x == best.x and coord.y < best.y):
				better = true
		if better:
			best = coord
			best_dist = d
			best_hp = hp
	return best


# BFS up to Wood steps through enemy-passable tiles, then pick the reachable
# tile that minimizes cube-distance to the Heart. Ties prefer the largest step
# count (most progress made), then lexicographic (q, r) for determinism. The
# Heart at (0, 0) is treated as passable — that's how enemies "touch" it (§1).
func _find_enemy_destination(start: Vector2i, wood: int) -> Vector2i:
	var distances: Dictionary = {start: 0}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var d: int = distances[current]
		if d >= wood:
			continue
		for neighbor in HexGrid.neighbors(current):
			if distances.has(neighbor):
				continue
			if not _enemy_can_pass(neighbor):
				continue
			distances[neighbor] = d + 1
			frontier.append(neighbor)
	var best: Vector2i = start
	var best_to_heart: int = HexGrid.distance(start, Vector2i.ZERO)
	var best_steps: int = 0
	for coord in distances:
		if coord == start:
			continue
		var to_heart: int = HexGrid.distance(coord, Vector2i.ZERO)
		var steps: int = distances[coord]
		var better: bool = false
		if to_heart < best_to_heart:
			better = true
		elif to_heart == best_to_heart and steps > best_steps:
			better = true
		elif to_heart == best_to_heart and steps == best_steps:
			if coord.x < best.x or (coord.x == best.x and coord.y < best.y):
				better = true
		if better:
			best = coord
			best_to_heart = to_heart
			best_steps = steps
	return best


# §4.4: enemies skip resource tiles, units, and other enemies. The Heart is
# the only "occupied-ish" tile they enter — landing on it triggers the loss
# condition (§1). Fog tiles stay off-limits since enemy seeding is contained
# to revealed clusters.
func _enemy_can_pass(coord: Vector2i) -> bool:
	if not revealed_tiles.has(coord):
		return false
	if coord == Vector2i.ZERO:
		return true
	return not tiles.has(coord)


func _animate_enemy_move(start: Vector2i, dest: Vector2i) -> void:
	var enemy: Tile = tiles[start]
	tiles.erase(start)
	enemy.coord = dest
	tiles[dest] = enemy
	if dest == Vector2i.ZERO:
		game_over = true
	queue_redraw()
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout


func _animate_enemy_attack(attacker: Vector2i, target: Vector2i, damage: int) -> void:
	_apply_attack_damage(target, damage, attacker)
	queue_redraw()
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout


func _show_game_over() -> void:
	game_over_panel.visible = true
	_refresh_phase_ui()


# Restart from the game-over panel. Resets the autoload first so the freshly
# reloaded scene's `_ready` re-seeds candidates and re-creates the Heart sprite
# from a clean wallet/phase/cycle baseline.
func _on_play_again_pressed() -> void:
	Game.reset_for_new_game()
	get_tree().reload_current_scene()
