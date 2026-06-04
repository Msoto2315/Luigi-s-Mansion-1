extends SceneTree


func _initialize() -> void:
	var packed_scene := load("res://scenes/Fracturada.tscn") as PackedScene
	if packed_scene == null:
		push_error("No se pudo cargar res://scenes/Fracturada.tscn")
		quit(1)
		return

	var root_node := packed_scene.instantiate()
	root.add_child(root_node)

	await process_frame

	if root_node.has_method("rebuild_fragments"):
		root_node.call("rebuild_fragments")

	await process_frame

	_set_owner_recursive(root_node, root_node)
	_freeze_bodies(root_node)

	var output_scene := PackedScene.new()
	var pack_result := output_scene.pack(root_node)
	if pack_result != OK:
		push_error("No se pudo empacar la escena fracturada: %s" % pack_result)
		quit(1)
		return

	var save_result := ResourceSaver.save(output_scene, "res://scenes/Fracturada.scn")
	if save_result != OK:
		push_error("No se pudo guardar res://scenes/Fracturada.scn: %s" % save_result)
		quit(1)
		return

	print("Fracturada.scn generada con %d RigidBody3D." % _count_bodies(root_node))
	quit()


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root

	for child in node.get_children():
		_set_owner_recursive(child, scene_root)


func _freeze_bodies(node: Node) -> void:
	if node is RigidBody3D:
		node.freeze = true
		node.sleeping = true

	for child in node.get_children():
		_freeze_bodies(child)


func _count_bodies(node: Node) -> int:
	var count := 1 if node is RigidBody3D else 0
	for child in node.get_children():
		count += _count_bodies(child)
	return count
