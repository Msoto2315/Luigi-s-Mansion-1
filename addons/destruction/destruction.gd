# SPDX-FileCopyrightText: 2023 Jummit
#
# SPDX-License-Identifier: MIT

@tool
@icon("destruction_icon.svg")
class_name Destruction
extends Node

## Handles destruction of the parent node.
##
## When [method destroy] is called, the parent node is freed and shards
## are added to the [member shard_container].

## A scene of the fragmented mesh containing multiple [MeshInstance3D]s.
@export var fragmented: PackedScene: set = set_fragmented
## The node where created shards are added to.
@onready @export var shard_container := get_node("../../")

@export_group("Animation")
## How many seconds until the shards fade away. Set to -1 to disable fading.
@export var fade_delay := 1.0
## How many seconds until the shards shrink. Set to -1 to disable shrinking.
@export var shrink_delay := 1.0
## How long the animation lasts before the shard is removed.
@export var animation_length := 3.0

@export_group("Collision")
## The [member RigidBody3D.collision_layer] set on the created shards.
@export_flags_3d_physics var collision_layer = 1
## The [member RigidBody3D.collision_mask] set on the created shards.
@export_flags_3d_physics var collision_mask = 1

@export_group("Physics Impulse")
## Downward bias for the destruction force. A positive value pushes shards downwards.
@export var downward_bias := 0.1
## Horizontal randomness (in radians) to add to the outward direction.
@export var horizontal_spread := 0.25
## Randomness ratio to blend with the direction.
@export var randomness_ratio := 0.2
## Gravity scale for the spawned shards.
@export var gravity_scale := 24.0
## Linear damp for the spawned shards.
@export var linear_damp := 0.0
## Angular damp for the spawned shards.
@export var angular_damp := 1.0
## Factor to shrink collision shapes slightly to prevent overlapping launch physics glitches.
@export var collision_shape_shrink_factor := 0.92

## Cached shard meshes (instantiated from [member fragmented]).
static var _cached_scenes := {}
## Cached collision shapes.
static var _cached_shapes := {}

var _modified_materials := {}

# Shared smoke shader (created once, reused by all particles)
static var _smoke_shader: Shader = null

## Remove the parent node and add shards to the shard container.
func destroy(explosion_power := 1.0) -> void:
	print("[Destruction] destroy() called on pillar: ", get_parent().name)
	var parent_node := get_parent() as Node3D
	if parent_node != null:
		_disable_collisions_recursive(parent_node)

	for shard in _get_shards():
		_add_shard(shard, explosion_power)
	get_parent().queue_free()


## Returns the list of shard meshes in the [member fragmented] scene.
func _get_shards() -> Array[Node]:
	if not fragmented in _cached_scenes:
		var instance = fragmented.instantiate()
		_cached_scenes[fragmented] = instance
		var meshes: Array[Node] = []
		_collect_mesh_instances(instance, meshes)
		for shard_mesh in meshes:
			_cached_shapes[shard_mesh] = shard_mesh.mesh.create_convex_shape()
	
	var meshes: Array[Node] = []
	_collect_mesh_instances(_cached_scenes[fragmented], meshes)
	return meshes


func set_fragmented(to: PackedScene) -> void:
	fragmented = to
	if is_inside_tree():
		get_tree().node_configuration_warning_changed.emit(self)


func _get_configuration_warnings() -> PackedStringArray:
	return ["No fragmented version set"] if not fragmented else []


## Turns a mesh shard into a rigid body and adds it to the
## [member shard_container].
func _add_shard(original: MeshInstance3D, explosion_power: float) -> void:
	var body := RigidBody3D.new()
	var mesh := MeshInstance3D.new()
	var shape := CollisionShape3D.new()
	body.add_child(mesh)
	body.add_child(shape)
	shard_container.add_child(body, true)
	
	var parent_node := get_parent() as Node3D
	var parent_transform := parent_node.global_transform
	var parent_scale := parent_transform.basis.get_scale()
	var parent_rotation := parent_transform.basis.orthonormalized()
	
	var relative_transform := _get_relative_transform(original, _cached_scenes[fragmented])
	var relative_pos := relative_transform.origin
	var relative_rot := relative_transform.basis.orthonormalized()
	
	body.global_position = parent_transform.origin + parent_rotation * (relative_pos * parent_scale)
	body.global_basis = parent_rotation * relative_rot
	
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask
	body.gravity_scale = gravity_scale
	body.linear_damp = linear_damp
	body.angular_damp = angular_damp
	
	# Enable contact reporting for impact smoke
	body.contact_monitor = true
	body.max_contacts_reported = 2
	var average_scale := (parent_scale.x + parent_scale.y + parent_scale.z) / 3.0
	body.body_entered.connect(_on_shard_collision.bind(body, average_scale))

	mesh.scale = original.scale * parent_scale
	shape.scale = original.scale * parent_scale * collision_shape_shrink_factor
	shape.shape = _cached_shapes[original]
	mesh.mesh = original.mesh
	
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	if fade_delay >= 0:
		var material = original.mesh.surface_get_material(0)
		if material is BaseMaterial3D:
			if not material in _modified_materials:
				var modified = material.duplicate()
				modified.flags_transparent = true
				tween.tween_property(modified,
						"albedo_color", Color(1, 1, 1, 0), animation_length - fade_delay)\
					.set_delay(fade_delay)\
					.set_trans(Tween.TRANS_EXPO)\
					.set_ease(Tween.EASE_OUT)
				_modified_materials[material] = modified
			mesh.material_override = _modified_materials[material]
		else:
			push_warning("Shard doesn't use a BaseMaterial3D, can't add transparency. Set fade_delay to -1 to remove this warning.")
	
	# Calculate outward direction from the center of the pillar (parent node) to the shard
	var global_diff := body.global_position - parent_transform.origin
	var outward_dir := Vector3(global_diff.x, 0.0, global_diff.z)
	if outward_dir.length_squared() < 0.0001:
		var angle := randf() * TAU
		outward_dir = Vector3(cos(angle), 0.0, sin(angle))
	else:
		outward_dir = outward_dir.normalized()

	# Add horizontal spread
	if horizontal_spread > 0.0:
		var angle_offset := randf_range(-horizontal_spread, horizontal_spread)
		outward_dir = outward_dir.rotated(Vector3.UP, angle_offset)

	# Combine outward direction with downward bias
	var base_dir := (outward_dir + Vector3.DOWN * downward_bias).normalized()

	# Add some general 3D randomness
	var random_dir := (Vector3(randf(), randf(), randf()) - Vector3.ONE / 2.0).normalized()
	var final_dir := (base_dir + random_dir * randomness_ratio).normalized()

	# Guarantee shards don't get pushed upwards
	if final_dir.y > 0.0:
		final_dir.y = 0.0
		final_dir = final_dir.normalized()

	body.apply_impulse(final_dir * explosion_power,
			-relative_pos.normalized())

	# Spawn a smoke puff at the shard's position, moving laterally/downward with the shard
	# Blend outward + slight downward so smoke follows the falling fragments
	var smoke_dir := (outward_dir + Vector3.DOWN * 0.4).normalized()
	_create_smoke_particles(body.global_position, 4, average_scale * 0.55,
			smoke_dir, animation_length)

	if shrink_delay >= 0:
		tween.tween_property(mesh, "scale", Vector3.ZERO, animation_length)\
				.set_delay(shrink_delay)
	tween.tween_callback(body.queue_free).set_delay(animation_length)


static func _random_direction() -> Vector3:
	return (Vector3(randf(), randf(), randf()) - Vector3.ONE / 2.0).normalized() * 2.0


func _collect_mesh_instances(node: Node, out: Array[Node]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)


func _get_relative_transform(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var current := node
	while current != null and current != root:
		if current is Node3D:
			t = current.transform * t
		current = current.get_parent()
	return t


func _on_shard_collision(other: Node, body: RigidBody3D, average_scale: float) -> void:
	# Impact smoke removed — each shard already carries its own smoke puff
	pass


# -------------------------------------------------------------------
# Build the procedural smoke shader code inline (no external file needed)
# -------------------------------------------------------------------
static func _get_smoke_shader() -> Shader:
	if _smoke_shader != null:
		return _smoke_shader
	_smoke_shader = Shader.new()
	_smoke_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;

uniform float smoke_density : hint_range(0.0, 1.0) = 0.85;
uniform vec4  smoke_color : source_color = vec4(0.78, 0.76, 0.74, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
	float a = hash(i);
	float b = hash(i + vec2(1.0,0.0));
	float c = hash(i + vec2(0.0,1.0));
	float d = hash(i + vec2(1.0,1.0));
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0; float a = 0.5; float total = 0.0;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		total += a;
		p = rot * p * 2.01 + vec2(4.7, 2.3);
		a *= 0.52;
	}
	return v / total;
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - 0.5;
	float dist = length(centered);
	float circle = 1.0 - smoothstep(0.30, 0.52, dist);
	if (circle < 0.001) discard;

	float t = TIME * 0.18;
	vec2 warp = vec2(
		fbm(uv * 2.8 + vec2(t * 0.7, t * 0.4)),
		fbm(uv * 2.8 + vec2(t * 0.5 + 3.1, t * 0.6 + 1.7))
	) - 0.5;
	vec2 warped_uv = uv + warp * 0.22;

	float n1 = fbm(warped_uv * 3.5 + vec2(t * 0.55, -t * 0.3));
	float n2 = fbm(warped_uv * 6.0 + vec2(-t * 0.42 + 5.0, t * 0.7));

	float cloud = n1 * 0.65 + n2 * 0.35;
	cloud = smoothstep(0.28, 0.75, cloud);

	float radial_bright = 1.0 - smoothstep(0.0, 0.40, dist) * 0.35;
	float alpha = circle * cloud * radial_bright * smoke_density * COLOR.a;
	alpha = clamp(alpha, 0.0, 1.0);

	vec3 col = mix(smoke_color.rgb * 0.72, smoke_color.rgb, cloud * radial_bright);
	ALBEDO = col * COLOR.rgb;
	ALPHA  = alpha;
}
"""
	return _smoke_shader


func _create_smoke_particles(pos: Vector3, amount: int, scale_factor: float,
			lateral_dir: Vector3, lifetime_seconds: float) -> void:
	if not is_instance_valid(shard_container) or not shard_container.is_inside_tree():
		return

	var particles := CPUParticles3D.new()

	# ---- Procedural grey smoke shader ----
	var mat := ShaderMaterial.new()
	mat.shader = _get_smoke_shader()
	mat.set_shader_parameter("smoke_density", 0.82)
	var brightness := randf_range(0.55, 0.72)  # darker grey
	mat.set_shader_parameter("smoke_color",
		Color(brightness, brightness * 0.96, brightness * 0.92, 1.0))

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	particles.mesh = quad

	# ---- Particle settings ----
	particles.amount        = 2
	particles.lifetime      = animation_length * 0.7         # match shard lifespan
	particles.one_shot      = true
	particles.explosiveness = 0.85
	particles.fixed_fps     = 0

	# Direction: lateral + slightly downward (follows falling shards)
	particles.direction = lateral_dir if lateral_dir.length_squared() > 0.01 else Vector3(1, 0, 0)
	particles.spread    = 90.0  # wider cone so it fills the pillar area
	particles.flatness  = 0.55   # allow some downward movement

	# Velocity — close to shard speed so smoke stays with the fragments
	particles.initial_velocity_min = 1.5 * scale_factor
	particles.initial_velocity_max = 2.0 * scale_factor

	# Damping: smoke decelerates and lingers in place
	particles.damping_min = 1.5
	particles.damping_max = 3.0

	# Gravity pulls smoke down with the shards — no upward drift
	particles.gravity = Vector3(0.0, -4.0 * scale_factor, 0.0)

	# Slow rotation — lazy billowing
	particles.angular_velocity_min = -8.0
	particles.angular_velocity_max =  8.0

	# Scale curve: expand quickly, stay large, shrink at the very end with the shard
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.00, 0.25))  # small at birth
	scale_curve.add_point(Vector2(0.15, 1.00))  # rapid expansion
	scale_curve.add_point(Vector2(0.55, 1.40))  # full billow — large cloud
	scale_curve.add_point(Vector2(0.80, 1.25))  # hold large
	scale_curve.add_point(Vector2(1.00, 0.30))  # shrink at end with shard
	particles.scale_amount_curve = scale_curve
	particles.scale_amount_min   = 2.5 * scale_factor   # much bigger base size
	particles.scale_amount_max   = 3.0 * scale_factor

	# Alpha ramp: appear fast, linger long, fade at the end in sync with shard
	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 0.6, 0.58, 0.0))       # invisible at spawn
	grad.add_point(0.06, Color(0.62, 0.60, 0.58, 0.80))  # appear fast
	grad.add_point(0.40, Color(0.58, 0.56, 0.54, 0.70))  # linger grey
	grad.add_point(0.50, Color(0.52, 0.50, 0.48, 0.45))  # start fading
	grad.set_color(1, Color(0.45, 0.43, 0.42, 0.0))      # gone at same time as shard
	particles.color_ramp = grad

	# ---- Add to scene ----
	shard_container.add_child(particles)
	particles.global_position = pos
	particles.emitting = true

	var cleanup_time: float = lifetime_seconds + 0.5
	get_tree().create_timer(cleanup_time).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _disable_collisions_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	elif node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_collisions_recursive(child)
