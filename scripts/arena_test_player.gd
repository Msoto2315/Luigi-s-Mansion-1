extends CharacterBody3D
class_name ArenaTestPlayer

@export var move_speed := 520.0
@export var acceleration := 10.0
@export var arena_height := 655.0
@export var camera_path: NodePath = ^"ArenaCamera"
@export var face_movement := true


func _ready() -> void:
	add_to_group("Player")
	add_to_group("Browser")


func _physics_process(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0

	input_vector = input_vector.limit_length(1.0)

	var move_direction := _camera_relative_direction(input_vector)
	var target_velocity := move_direction * move_speed
	var velocity_t := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, target_velocity.x, velocity_t)
	velocity.z = lerpf(velocity.z, target_velocity.z, velocity_t)
	velocity.y = 0.0

	move_and_slide()
	global_position.y = arena_height

	if face_movement and move_direction.length_squared() > 0.001:
		look_at(global_position + move_direction, Vector3.UP)


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector == Vector2.ZERO:
		return Vector3.ZERO

	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	var camera := get_node_or_null(camera_path) as Camera3D
	if camera != null:
		forward = -camera.global_basis.z
		right = camera.global_basis.x

	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	return (right * input_vector.x + forward * -input_vector.y).normalized()
