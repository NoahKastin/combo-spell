extends Node2D

# Scene root: hex draw, tap input, and Explore-phase candidate logic.

const HEX_SIZE := 80.0
const ICON_TARGET_SIZE := 120.0
const TILE_OUTLINE_COLOR := Color("#000000")
const TILE_OUTLINE_WIDTH := 2.0
const PERIMETER_WIDTH := 6.0
const FOG_FILL := Color("#BFBFBF")
const REVEALED_FILL := Color("#FFFFFF")

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

var layout := HexLayout.new(HEX_SIZE)
var candidates: Array[BigHex] = []
var revealed_big_hexes: Array[BigHex] = []
var revealed_tiles: Dictionary = {} # Vector2i -> true

@onready var phase_label: Label = $UI/PhaseLabel
@onready var next_phase_button: Button = $UI/NextPhaseButton
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_seed_explore_candidates()
	var heart := Sprite2D.new()
	heart.texture = load("res://assets/heart.png")
	heart.position = layout.hex_to_screen(Vector2i.ZERO)
	add_child(heart)
	Game.phase_changed.connect(_on_phase_changed)
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	_refresh_phase_ui()


func _seed_explore_candidates() -> void:
	candidates.clear()
	if revealed_big_hexes.is_empty():
		_seed_starting_candidates()
	else:
		_seed_subsequent_candidates()
	queue_redraw()


func _seed_starting_candidates() -> void:
	var biomes := STARTING_BIOMES.duplicate()
	biomes.shuffle()
	for i in STARTING_CENTERS.size():
		candidates.append(BigHex.new(STARTING_CENTERS[i], biomes[i]))


# §4.1: subsequent rounds offer 6 candidates at the big-hex-lattice neighbors
# of the most-recently-revealed cluster. Already-revealed centers drop out.
func _seed_subsequent_candidates() -> void:
	var anchor := revealed_big_hexes[-1].center
	var revealed_centers: Dictionary = {}
	for b in revealed_big_hexes:
		revealed_centers[b.center] = true
	for neighbor_center in HexGrid.big_hex_neighbors(anchor):
		if revealed_centers.has(neighbor_center):
			continue
		var biome: int = MVP_BIOMES.pick_random()
		candidates.append(BigHex.new(neighbor_center, biome))


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
	for tile in big_hex.tiles():
		var corners := layout.hex_corners(tile)
		draw_colored_polygon(corners, REVEALED_FILL)
		_draw_tile_outline(corners)
	_draw_cluster_perimeter(big_hex)


func _draw_tile_outline(corners: PackedVector2Array) -> void:
	var closed := PackedVector2Array(corners)
	closed.append(closed[0])
	draw_polyline(closed, TILE_OUTLINE_COLOR, TILE_OUTLINE_WIDTH, true)


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
	if Game.phase != Phase.Type.EXPLORE:
		return
	var world_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_pos = get_global_mouse_position()
	elif event is InputEventScreenTouch and event.pressed:
		world_pos = get_canvas_transform().affine_inverse() * event.position
	else:
		return
	_try_reveal_at(world_pos)


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


func _reveal(big_hex: BigHex) -> void:
	big_hex.revealed = true
	revealed_big_hexes.append(big_hex)
	for t in big_hex.tiles():
		revealed_tiles[t] = true
	candidates.clear()
	queue_redraw()
	Game.advance_phase()


func _on_next_phase_pressed() -> void:
	Game.advance_phase()


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == Phase.Type.EXPLORE:
		_seed_explore_candidates()
	_refresh_phase_ui()


func _refresh_phase_ui() -> void:
	var p := Game.phase
	phase_label.text = Phase.NAME[p]
	phase_label.modulate = Phase.COLOR[p]
	# Force a deliberate candidate pick during Explore. The button stays
	# enabled in other phases as a phase-skip helper.
	next_phase_button.disabled = (p == Phase.Type.EXPLORE) and not candidates.is_empty()
