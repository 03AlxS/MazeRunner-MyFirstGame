extends CharacterBody2D

var speed = 200

func _physics_process(delta) -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	look_at(get_global_mouse_position())
