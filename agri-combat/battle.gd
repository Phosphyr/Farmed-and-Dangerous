extends Node2D

@export var plant_scene: PackedScene = preload("res://test_plant.tscn")
@onready var hex_map: TileMapLayer = $TileMapLayer
@onready var art_rect: TextureRect = $UI/seedbox/HBoxContainer/VBoxContainer/art
@onready var amount_label: RichTextLabel = $UI/seedbox/HBoxContainer/VBoxContainer/amount

var dragging_seed := false
var drag_preview: TextureRect
var occupied_cells := {} # Dictionary[Vector2i, bool]

func _ready() -> void:
	_setup_seedbox_entry()
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

func _update_drag_preview() -> void:
	var m := get_viewport().get_mouse_position()
	drag_preview.global_position = m - drag_preview.size * 0.5

func _end_seed_drag() -> void:
	dragging_seed = false
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null

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
