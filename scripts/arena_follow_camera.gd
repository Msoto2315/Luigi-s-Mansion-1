extends Camera3D
class_name ArenaFollowCamera

@export var target_path: NodePath = ^".."
@export var focus_path: NodePath
@export var fixed_yaw_degrees := 0.0
@export var distance := 720.0
@export var height := 225.0
@export var screen_side_offset := 0.0
@export_range(0.5, 20.0, 0.1) var follow_smoothing := 2.35
@export_range(0.5, 20.0, 0.1) var look_smoothing := 2.8
@export_range(0.0, 1.0, 0.01) var focus_weight := 0.35
@export_range(0.5, 20.0, 0.1) var focus_smoothing := 1.45
@export var look_height := 80.0
@export var dead_zone_radius := 95.0
@export var mouse_sensitivity := 0.12
@export var pitch_degrees := 11.0
@export var min_pitch_degrees := -4.0
@export var max_pitch_degrees := 28.0
@export var capture_mouse_on_click := true

var _look_at_position := Vector3.ZERO
var _framing_center := Vector3.ZERO
var _focus_position := Vector3.ZERO
var _target_anchor := Vector3.ZERO
var _yaw_degrees := 0.0
var _pitch_degrees := 0.0
var _initialized := false


func _ready() -> void:
	top_level = true
	current = true
	_yaw_degrees = fixed_yaw_degrees
	_pitch_degrees = pitch_degrees


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if capture_mouse_on_click and event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw_degrees -= event.relative.x * mouse_sensitivity
		_pitch_degrees = clamp(
			_pitch_degrees - event.relative.y * mouse_sensitivity,
			min_pitch_degrees,
			max_pitch_degrees
		)


func _process(delta: float) -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target == null:
		return

	var target_position := target.global_position
	if not _initialized:
		_target_anchor = target_position
	else:
		var anchor_delta := target_position - _target_anchor
		anchor_delta.y = 0.0
		if anchor_delta.length() > dead_zone_radius:
			_target_anchor += anchor_delta.normalized() * (anchor_delta.length() - dead_zone_radius)

	var desired_focus := _get_focus_position(target_position)
	var focus_t := 1.0 - exp(-focus_smoothing * delta)
	if not _initialized:
		_focus_position = desired_focus
	else:
		_focus_position = _focus_position.lerp(desired_focus, focus_t)

	var desired_center := _target_anchor.lerp(_focus_position, focus_weight)
	if not _initialized:
		_framing_center = desired_center
		_look_at_position = desired_center + Vector3.UP * look_height
		_initialized = true
	else:
		_framing_center = _framing_center.lerp(desired_center, focus_t)

	var camera_backward := _fixed_camera_backward()
	var camera_right := camera_backward.cross(Vector3.UP).normalized()
	var desired_height := height + sin(deg_to_rad(_pitch_degrees)) * distance
	var desired_distance := cos(deg_to_rad(_pitch_degrees)) * distance
	var desired_position := _framing_center + camera_backward * desired_distance + camera_right * screen_side_offset + Vector3.UP * desired_height
	var follow_t := 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(desired_position, follow_t)

	var desired_look := _framing_center + Vector3.UP * look_height
	var look_t := 1.0 - exp(-look_smoothing * delta)
	_look_at_position = _look_at_position.lerp(desired_look, look_t)
	look_at(_look_at_position, Vector3.UP)


func _fixed_camera_backward() -> Vector3:
	var yaw := deg_to_rad(_yaw_degrees)
	return Vector3(sin(yaw), 0.0, cos(yaw)).normalized()


func _get_focus_position(fallback: Vector3) -> Vector3:
	var focus := get_node_or_null(focus_path) as Node3D
	if focus != null:
		return focus.global_position

	var nearest_pillar := _find_nearest_destructible_pillar(fallback)
	if nearest_pillar != null:
		return nearest_pillar.global_position

	return fallback


func _find_nearest_destructible_pillar(from_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF

	for node in get_tree().get_nodes_in_group("DestructiblePillar"):
		var pillar := node as Node3D
		if pillar == null or not pillar.is_inside_tree():
			continue

		var distance := from_position.distance_squared_to(pillar.global_position)
		if distance < nearest_distance:
			nearest = pillar
			nearest_distance = distance

	return nearest
