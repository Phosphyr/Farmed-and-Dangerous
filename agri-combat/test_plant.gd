extends Node2D

@export var unit_name: String = "Test Plant"
@export var health: int = 20
@export var movement: int = 4
@export var range: int = 1
@export var damage: int = 5
@export var team: StringName = &"player"

var grid_cell: Vector2i = Vector2i.ZERO
var moves_left: int = 0

func initialize_for_battle(start_cell: Vector2i, battle_team: StringName = &"player") -> void:
	grid_cell = start_cell
	team = battle_team
	moves_left = movement

func begin_turn() -> void:
	moves_left = movement
