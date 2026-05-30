@tool
extends Node3D
class_name FracturedPillar

@export var source_model: PackedScene
@export_range(0.01, 100.0, 0.01) var fragment_mass := 0.35
@export_range(0.0, 20.0, 0.1) var fragment_linear_damp := 2.0
@export_range(0.0, 20.0, 0.1) var fragment_angular_damp := 2.5
@export_range(-1.0, 1.0, 0.01) var vertical_impulse_bias := -0.5
@export_range(0.0, 2.0, 0.01) var gravity_scale := 1.35
@export_range(0.0, 30.0, 0.1) var default_cleanup_seconds := 5.0
@export var build_on_ready := true
@export var generated_root_name := "Fragments"
var _rebuild_in_editor := false
@export var rebuild_in_editor := false:
	set(value):
		_rebuild_in_editor = false
		if value:
			call_deferred("rebuild_fragments")
	get:
		return _rebuild_in_editor


func _ready() -> void:
	if build_on_ready and not _has_generated_fragments():
		if not Engine.is_editor_hint():
			rebuild_fragments()


func rebuild_fragments() -> void:
	if source_model == null:
		push_warning("FracturedPillar necesita un source_model con el GLB fracturado.")
		return

	_clear_generated_fragments()

	var fragments_root := Node3D.new()
	fragments_root.name = generated_root_name
	add_child(fragments_root)
	_set_scene_owner(fragments_root)

	var source_root := source_model.instantiate()
	add_child(source_root)

	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(source_root, mesh_instances)

	for mesh_instance in mesh_instances:
		if mesh_instance.mesh == null:
			continue

		var mesh_global_transform := mesh_instance.global_transform
		var body := RigidBody3D.new()
		body.name = "%s_Body" % mesh_instance.name
		body.mass = fragment_mass
		body.linear_damp = fragment_linear_damp
		body.angular_damp = fragment_angular_damp
		body.gravity_scale = gravity_scale
		body.freeze = true
		body.transform = fragments_root.global_transform.affine_inverse() * mesh_global_transform
		fragments_root.add_child(body)
		_set_scene_owner(body)

		var previous_parent := mesh_instance.get_parent()
		mesh_instance.owner = null
		previous_parent.remove_child(mesh_instance)
		body.add_child(mesh_instance)
		mesh_instance.transform = Transform3D.IDENTITY
		_set_scene_owner(mesh_instance)

		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "ConvexCollision"
		collision_shape.shape = mesh_instance.mesh.create_convex_shape(true, true)
		body.add_child(collision_shape)
		_set_scene_owner(collision_shape)

	source_root.queue_free()


func explode(origin: Vector3, impulse_strength := 8.0, cleanup_seconds := default_cleanup_seconds) -> void:
	if not _has_generated_fragments():
		rebuild_fragments()

	var bodies: Array[RigidBody3D] = []
	_collect_rigid_bodies(self, bodies)

	for body in bodies:
		body.freeze = false
		body.sleeping = false

		var direction := body.global_position - origin
		if direction.length_squared() < 0.001:
			direction = Vector3(randf() - 0.5, randf() * 0.5 + 0.25, randf() - 0.5)

		direction.y = 0.0
		if direction.length_squared() < 0.001:
			direction = Vector3(randf() - 0.5, 0.0, randf() - 0.5)

		direction = (direction.normalized() + Vector3.UP * vertical_impulse_bias).normalized()
		body.apply_central_impulse(direction * impulse_strength)
		body.apply_torque_impulse(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * impulse_strength * 0.12)

	if cleanup_seconds > 0.0 and is_inside_tree():
		get_tree().create_timer(cleanup_seconds).timeout.connect(queue_free)


func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)

	for child in node.get_children():
		_collect_mesh_instances(child, out)


func _collect_rigid_bodies(node: Node, out: Array[RigidBody3D]) -> void:
	if node is RigidBody3D:
		out.append(node)

	for child in node.get_children():
		_collect_rigid_bodies(child, out)


func _has_generated_fragments() -> bool:
	return get_node_or_null(generated_root_name) != null


func _clear_generated_fragments() -> void:
	var existing := get_node_or_null(generated_root_name)
	if existing == null:
		return

	remove_child(existing)
	existing.queue_free()


func _set_scene_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	var scene_root := get_tree().edited_scene_root
	if scene_root != null and node != scene_root:
		node.owner = scene_root
