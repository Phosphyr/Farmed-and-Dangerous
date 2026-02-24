extends Node2D

#prepping the plant scene for the battle. This will get unwieldy down the track and need a more elegan solution
@export var plant_scene: PackedScene = preload("res://test_plant.tscn") 

#setting nodes with easier to write names for use in code
@onready var hex_map: TileMapLayer = $TileMapLayer
@onready var units_root: Node2D = $units
@onready var art_rect: TextureRect = $UI/seedbox/HBoxContainer/VBoxContainer/art
@onready var amount_label: RichTextLabel = $UI/seedbox/HBoxContainer/VBoxContainer/amount

#setting colors for tile highlighting. Works via overlaying a color on the hex.
const VALID_HIGHLIGHT_COLOR := Color(0.25, 0.9, 0.35, 0.35)
const INVALID_HIGHLIGHT_COLOR := Color(0.733, 0.741, 0.161, 0.565)
const AREA_HIGHLIGHT_COLOR := Color(0.177, 0.526, 0.784, 0.35)
const ENEMY_AREA_HIGHLIGHT_COLOR := Color(0.95, 0.2, 0.2, 0.35)
#areas for initial placement of player pieces are 17-19x, 13-20y
const START_AREA_MIN_X := 17
const START_AREA_MAX_X := 19
const START_AREA_MIN_Y := 13
const START_AREA_MAX_Y := 20
#areas for initial placement of enemy pieces are 30-32x, 13-20y
const ENEMY_AREA_MIN_X := 30
const ENEMY_AREA_MAX_X := 32
const ENEMY_AREA_MIN_Y := 13
const ENEMY_AREA_MAX_Y := 20

var dragging_seed := false
var drag_preview: TextureRect
var placement_highlight: Polygon2D
var start_area_highlights: Node2D
var movement_highlights: Node2D
var occupied_cells := {} # Dictionary[Vector2i, Node2D]
var reachable_move_cells := {} # Dictionary[Vector2i, int]
var selected_unit: Node2D
var battle_started = false
var turn_counter = 1
var hex_polygon_cache: PackedVector2Array
func _ready() -> void:
	hex_polygon_cache = _build_hex_polygon()
	_setup_seedbox_entry()
	_setup_start_area_highlights()
	_setup_placement_highlight()
	_setup_movement_highlights()
	art_rect.gui_input.connect(_on_seed_art_gui_input)

#this function prepares the seedbox so the player can drag plants onto the battle scene. 
#once we set up a plant dictionary or something similar we will need to pull from that when populating.
func _setup_seedbox_entry() -> void:
	if plant_scene == null:
		return

	#loads in plant scenes for use in the battle. We'll need to look at making the plant scene as modular as possible for the various combinations of plants
	var plant_preview := plant_scene.instantiate()
	var plant_sprite := plant_preview.get_node_or_null("Sprite2D") as Sprite2D
	
	#not null is defensive coding so that a game doesn't just crash out if a sprite is missing, you'll see this a bit
	if plant_sprite != null:
		art_rect.texture = plant_sprite.texture
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	#cleans the preview after the texture is read so that we don't end up keeping a bunch of logic running for what is functionally just supposed to be an image
	plant_preview.queue_free()
	amount_label.text = "x" + str(gamestate.plantamount)

#this fires when the player clicks a seed. it tracks if the plant is dragged and then fires the seed drag func.
func _on_seed_art_gui_input(event: InputEvent) -> void:
	print("gui input triggered")
	if plant_scene == null or gamestate.plantamount <= 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_seed_drag()

func _input(event: InputEvent) -> void:
#splits inputs based on whether the battle has started or not. Probably a cleaner way to do this but fine for now.
	if battle_started == false:
		#returns function if a plant isn't in the players hand
		if not dragging_seed:
			return
		#
		if event is InputEventMouseMotion:
			_update_drag_preview()
			_update_placement_highlight()
		#this is the logic that tells the game where the player has dropped the hex, runs the function to check if the placement is valid and if true, places the plant
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var cell := _mouse_cell()
			if _can_place(cell):
				_place_plant(cell)
			_end_seed_drag()
		return

	#this is where the battle interaction logic will go
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_world := get_global_mouse_position()
		var clicked_cell := hex_map.local_to_map(hex_map.to_local(mouse_world))
		var clicked_unit: Node2D = occupied_cells.get(clicked_cell)

		if is_instance_valid(selected_unit) and reachable_move_cells.has(clicked_cell):
			move_unit(clicked_cell)
			return

		if is_instance_valid(clicked_unit):
			show_movement(clicked_unit)
		else:
			selected_unit = null
			_clear_movement_highlights()

func _begin_seed_drag() -> void:
	dragging_seed = true
	drag_preview = TextureRect.new()
	drag_preview.texture = art_rect.texture
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.custom_minimum_size = Vector2(48, 48)
	drag_preview.size = Vector2(48, 48)
	$UI.add_child(drag_preview)
	_set_start_area_highlight_visible(true)
	_update_drag_preview()
	_update_placement_highlight()

#drags the preview of the plant along with the mouse.
func _update_drag_preview() -> void:
	var m := get_viewport().get_mouse_position()
	drag_preview.global_position = m - drag_preview.size * 0.5

func _end_seed_drag() -> void:
	dragging_seed = false
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null
	_set_start_area_highlight_visible(false)
	_clear_placement_highlight()

#checks if the cell is valid for placement, currently only checks if there is a terrain cell placed
func _can_place(cell: Vector2i) -> bool:
	if not _has_terrain(cell):
		return false
	if hex_map.get_cell_source_id(cell) == -1:
		return false
	return not occupied_cells.has(cell)

#checks if cell is within start area, hard coded up top in variables for now
func _is_in_start_area(cell: Vector2i) -> bool:
	return (
		cell.x >= START_AREA_MIN_X
		and cell.x <= START_AREA_MAX_X
		and cell.y >= START_AREA_MIN_Y
		and cell.y <= START_AREA_MAX_Y
	)

func _place_plant(cell: Vector2i) -> void:
	var plant := plant_scene.instantiate() as Node2D
	plant.global_position = hex_map.to_global(hex_map.map_to_local(cell))
	units_root.add_child(plant)

	if plant.has_method("initialize_for_battle"):
		plant.call("initialize_for_battle", cell)

	occupied_cells[cell] = plant
	gamestate.plantamount -= 1
	amount_label.text = "x" + str(gamestate.plantamount)

func _setup_placement_highlight() -> void:
	placement_highlight = Polygon2D.new()
	placement_highlight.polygon = hex_polygon_cache
	placement_highlight.visible = false
	placement_highlight.z_index = 100
	hex_map.add_child(placement_highlight)

func show_movement(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return

	selected_unit = unit
	_clear_movement_highlights()

	var start_cell: Vector2i = unit.grid_cell
	var movement_points = max(int(unit.moves_left), 0)
	if movement_points <= 0:
		return

	var visited_distance := {start_cell: 0} # Dictionary[Vector2i, int]
	var frontier: Array[Vector2i] = [start_cell]

	while not frontier.is_empty():
		var current_cell = frontier.pop_front()
		var current_distance: int = visited_distance[current_cell]
		if current_distance >= movement_points:
			continue

		for neighbor in _get_neighbor_cells(current_cell):
			if visited_distance.has(neighbor):
				continue
			if not _can_move_through_cell(neighbor, start_cell):
				continue

			visited_distance[neighbor] = current_distance + 1
			frontier.append(neighbor)

	var hex_polygon := hex_polygon_cache
	for cell in visited_distance.keys():
		if cell == start_cell:
			continue

		reachable_move_cells[cell] = visited_distance[cell]
		var move_highlight := Polygon2D.new()
		move_highlight.polygon = hex_polygon
		move_highlight.position = hex_map.map_to_local(cell)
		move_highlight.color = AREA_HIGHLIGHT_COLOR
		movement_highlights.add_child(move_highlight)

func move_unit(cell: Vector2i) -> void:
	if not is_instance_valid(selected_unit):
		return
	if not reachable_move_cells.has(cell):
		return

	var move_cost: int = int(reachable_move_cells[cell])
	if move_cost <= 0:
		return
	if move_cost > int(selected_unit.moves_left):
		return

	var from_cell: Vector2i = selected_unit.grid_cell
	occupied_cells.erase(from_cell)
	occupied_cells[cell] = selected_unit

	selected_unit.grid_cell = cell
	selected_unit.global_position = hex_map.to_global(hex_map.map_to_local(cell))
	selected_unit.moves_left = max(int(selected_unit.moves_left) - move_cost, 0)

	if int(selected_unit.moves_left) > 0:
		show_movement(selected_unit)
	else:
		_clear_movement_highlights()

func _setup_movement_highlights() -> void:
	movement_highlights = Node2D.new()
	movement_highlights.z_index = 80
	hex_map.add_child(movement_highlights)

func _clear_movement_highlights() -> void:
	reachable_move_cells.clear()
	if not is_instance_valid(movement_highlights):
		return

	for child in movement_highlights.get_children():
		child.queue_free()

func _get_neighbor_cells(cell: Vector2i) -> Array[Vector2i]:
	return hex_map.get_surrounding_cells(cell)

func _can_move_through_cell(cell: Vector2i, start_cell: Vector2i) -> bool:
	if not _has_terrain(cell):
		return false
	if cell != start_cell and occupied_cells.has(cell):
		return false
	return true

func _mouse_cell() -> Vector2i:
	var mouse_world := get_global_mouse_position()
	return hex_map.local_to_map(hex_map.to_local(mouse_world))

func _add_rect_area_highlights(parent: Node, min_x:int, max_x:int, min_y:int, max_y:int, color: Color) -> void:
	var hex_polygon := _build_hex_polygon() # or cached (see next section)
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var cell := Vector2i(x, y)
			if hex_map.get_cell_source_id(cell) == -1:
				continue
			var p := Polygon2D.new()
			p.polygon = hex_polygon
			p.position = hex_map.map_to_local(cell)
			p.color = color
			parent.add_child(p)
func _setup_start_area_highlights() -> void:
	start_area_highlights = Node2D.new()
	start_area_highlights.visible = false
	start_area_highlights.z_index = 90
	hex_map.add_child(start_area_highlights)

	_add_rect_area_highlights(start_area_highlights, START_AREA_MIN_X, START_AREA_MAX_X, START_AREA_MIN_Y, START_AREA_MAX_Y, AREA_HIGHLIGHT_COLOR)
	_add_rect_area_highlights(start_area_highlights, ENEMY_AREA_MIN_X, ENEMY_AREA_MAX_X, ENEMY_AREA_MIN_Y, ENEMY_AREA_MAX_Y, ENEMY_AREA_HIGHLIGHT_COLOR)

func _set_start_area_highlight_visible(is_visible: bool) -> void:
	if is_instance_valid(start_area_highlights):
		start_area_highlights.visible = is_visible

func _build_hex_polygon() -> PackedVector2Array:
	var tile_size := Vector2(hex_map.tile_set.tile_size)
	var half_w := tile_size.x * 0.5
	var half_h := tile_size.y * 0.5

	if hex_map.tile_set.tile_offset_axis == TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
		return PackedVector2Array([
			Vector2(0, -half_h),
			Vector2(half_w * 0.5, -half_h * 0.5),
			Vector2(half_w * 0.5, half_h * 0.5),
			Vector2(0, half_h),
			Vector2(-half_w * 0.5, half_h * 0.5),
			Vector2(-half_w * 0.5, -half_h * 0.5),
		])

	return PackedVector2Array([
		Vector2(-half_w, 0),
		Vector2(-half_w * 0.5, -half_h),
		Vector2(half_w * 0.5, -half_h),
		Vector2(half_w, 0),
		Vector2(half_w * 0.5, half_h),
		Vector2(-half_w * 0.5, half_h),
	])

func _update_placement_highlight() -> void:
	if not is_instance_valid(placement_highlight):
		return

	var cell := _mouse_cell()
	var can_place := _can_place(cell)

	placement_highlight.visible = true
	placement_highlight.position = hex_map.map_to_local(cell)
	placement_highlight.color = VALID_HIGHLIGHT_COLOR if can_place else INVALID_HIGHLIGHT_COLOR

func _clear_placement_highlight() -> void:
	if is_instance_valid(placement_highlight):
		placement_highlight.visible = false


func _on_start_pressed() -> void:
	$UI/turn_counter/startbutton.visible = false
	$UI/turn_counter/turncounter.visible = true
	$UI/seedbox.visible = false
	$UI/end_turn.visible = true
	battle_started = true
	$UI/turn_counter/turncounter.text = "Turn " + str(turn_counter)


func _on_endturn_button_pressed() -> void:
	selected_unit = null
	_clear_movement_highlights()

	for unit in units_root.get_children():
		if unit.has_method("begin_turn"):
			unit.call("begin_turn")
	turn_counter += 1
	$UI/turn_counter/turncounter.text = "Turn " + str(turn_counter)
func _has_terrain(cell: Vector2i) -> bool:
	return hex_map.get_cell_source_id(cell) != -1
