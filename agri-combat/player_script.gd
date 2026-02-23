extends CharacterBody2D

var character_speed := 120.0
var character_direction : Vector2

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:

	character_direction.x = Input.get_axis("left", "right")
	character_direction.y = Input.get_axis("up", "down")
	character_direction = character_direction.normalized()

	if character_direction != Vector2.ZERO:

		if abs(character_direction.y) > abs(character_direction.x):
			if character_direction.y < 0:
				animated_sprite_2d.animation = "walk_up"
			else:
				animated_sprite_2d.animation = "walk_down"
		else:
			if character_direction.x < 0:
				animated_sprite_2d.animation = "walk_left"
			else:
				animated_sprite_2d.animation = "walk_right"

		velocity = character_direction * character_speed

	else:
		velocity = Vector2.ZERO
		
		if animated_sprite_2d.animation == "walk_left":
			animated_sprite_2d.animation = "idle_left"
		elif animated_sprite_2d.animation == "walk_right":
			animated_sprite_2d.animation = "idle_right"
		elif animated_sprite_2d.animation == "walk_up":
			animated_sprite_2d.animation = "idle_up"
		elif animated_sprite_2d.animation == "walk_down":
			animated_sprite_2d.animation = "idle_down"

	move_and_slide()
