extends Node2D

@export var plant_scene: PackedScene = preload("res://test_plant.tscn")
@onready var hex_map: TileMapLayer = $TileMapLayer
@onready var art_rect: TextureRect = $UI/seedbox/HBoxContainer/VBoxContainer/art
@onready var amount_label: RichTextLabel = $UI/seedbox/HBoxContainer/VBoxContainer/amount

const VALID_HIGHLIGHT_COLOR := Color(0.25, 0.9, 0.35, 0.35)
const INVALID_HIGHLIGHT_COLOR := Color(0.95, 0.2, 0.2, 0.35)

var dragging_seed := false
var drag_preview: TextureRect
var placement_highlight: Polygon2D
var occupied_cells := {} # Dictionary[Vector2i, bool]

func _ready() -> void:
	_setup_seedbox_entry()
	_setup_placement_highlight()
	art_rect.gui_input.connect(_on_seed_art_gui_input)

func _setup_seedbox_entry() -> void:
	if plant_scene == null:
		return

	var plant_preview := plant_scene.instantiate()
	var plant_sprite := plant_preview.get_node_or_null("Sprite2D") as Sprite2D
	if plant_sprite != null:
		art_rect.texture = plant_sprite.texture
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	plant_preview.queue_free()
	amount_label.text = "x" + str(gamestate.plantamount)

func _on_seed_art_gui_input(event: InputEvent) -> void:
	print("gui input triggered")
	if plant_scene == null or gamestate.plantamount <= 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_seed_drag()

func _input(event: InputEvent) -> void:
	if not dragging_seed:
		return

	if event is InputEventMouseMotion:
		_update_drag_preview()
		_update_placement_highlight()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var mouse_world := get_global_mouse_position()
		var cell := hex_map.local_to_map(hex_map.to_local(mouse_world))
		if _can_place(cell):
			_place_plant(cell)
		_end_seed_drag()

func _begin_seed_drag() -> void:
	dragging_seed = true
	drag_preview = TextureRect.new()
	drag_preview.texture = art_rect.texture
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.custom_minimum_size = Vector2(48, 48)
	drag_preview.size = Vector2(48, 48)
	$UI.add_child(drag_preview)
	_update_drag_preview()
	_update_placement_highlight()

func _update_drag_preview() -> void:
	var m := get_viewport().get_mouse_position()
	drag_preview.global_position = m - drag_preview.size * 0.5

func _end_seed_drag() -> void:
	dragging_seed = false
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null
	_clear_placement_highlight()

func _can_place(cell: Vector2i) -> bool:
	if hex_map.get_cell_source_id(cell) == -1:
		return false
	return not occupied_cells.has(cell)

func _place_plant(cell: Vector2i) -> void:
	var plant := plant_scene.instantiate() as Node2D
	plant.global_position = hex_map.to_global(hex_map.map_to_local(cell))
	add_child(plant)
	occupied_cells[cell] = true
	gamestate.plantamount -= 1
	amount_label.text = "x" + str(gamestate.plantamount)

func _setup_placement_highlight() -> void:
	placement_highlight = Polygon2D.new()
	placement_highlight.polygon = _build_hex_polygon()
	placement_highlight.visible = false
	placement_highlight.z_index = 100
	hex_map.add_child(placement_highlight)

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

	var mouse_world := get_global_mouse_position()
	var cell := hex_map.local_to_map(hex_map.to_local(mouse_world))
	var can_place := _can_place(cell)

	placement_highlight.visible = true
	placement_highlight.position = hex_map.map_to_local(cell)
	placement_highlight.color = VALID_HIGHLIGHT_COLOR if can_place else INVALID_HIGHLIGHT_COLOR

func _clear_placement_highlight() -> void:
	if is_instance_valid(placement_highlight):
		placement_highlight.visible = false
