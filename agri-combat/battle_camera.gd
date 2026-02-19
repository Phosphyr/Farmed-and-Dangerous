extends Camera2D

@export var zoom_step := 0.1
@export var min_zoom := 1
@export var max_zoom :=  4
@export var zoom_lerp := 12.0
@export_range(0.0, 1.0, 0.01) var high_zoom_drag_damping := 0.55

var dragging := false
var target_zoom := Vector2.ONE

func _ready() -> void:
	target_zoom = zoom

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			return

		if event.pressed and (
			event.button_index == MOUSE_BUTTON_WHEEL_UP
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			# Wheel up zooms in (smaller zoom), wheel down zooms out (larger zoom).
			var dir := -1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 1
			var desired = clamp(target_zoom.x + (zoom_step * dir), min_zoom, max_zoom)
			target_zoom = Vector2(desired, desired)
			return

	if dragging and event is InputEventMouseMotion:
		# Move opposite the pointer so the world follows the cursor while dragging.
		var drag_scale := zoom.x
		if drag_scale > 1.0:
			# Reduce drag growth at higher zoom levels (1.0 keeps old behavior).
			drag_scale = 1.0 + ((drag_scale - 1.0) * high_zoom_drag_damping)
		global_position -= event.relative * drag_scale * 0.3

func _process(delta: float) -> void:
	var t = clamp(zoom_lerp * delta, 0.0, 1.0)
	zoom = zoom.lerp(target_zoom, t)
