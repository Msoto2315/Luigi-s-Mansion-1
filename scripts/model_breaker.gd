@tool
extends Node3D
class_name ModelBreaker

@export_range(0.0, 200.0, 0.1) var impulse_strength := 65.0
@export var break_once := true
@export var detector_path: NodePath = ^"BreakDetector"
@export var trigger_groups: PackedStringArray = ["Bomba", "Bomb", "Player", "Browser", "Bowser"]
@export var trigger_name_parts: PackedStringArray = ["bomba", "bomb", "player", "browser", "bowser"]

var _broken := false
@onready var destruction: Node = get_node_or_null("Destruction")


func _ready() -> void:
	add_to_group("DestructiblePillar")

	if Engine.is_editor_hint():
		return

	_connect_detector()


func break_pillar(hit_source: Node = null) -> void:
	if _broken and break_once:
		return

	if destruction == null:
		push_warning("ModelBreaker necesita un nodo Destruction como hijo.")
		return

	_broken = true

	# Trigger destruction through the addon
	destruction.destroy(impulse_strength)


func _connect_detector() -> void:
	var detector := get_node_or_null(detector_path)
	if detector == null:
		push_warning("No se encontro el Area3D detector en %s." % detector_path)
		return

	if detector is Area3D:
		if not detector.body_entered.is_connected(_on_detector_body_entered):
			detector.body_entered.connect(_on_detector_body_entered)
		if not detector.area_entered.is_connected(_on_detector_area_entered):
			detector.area_entered.connect(_on_detector_area_entered)


func _on_detector_body_entered(body: Node3D) -> void:
	if _is_valid_trigger(body):
		break_pillar(body)


func _on_detector_area_entered(area: Area3D) -> void:
	if _is_valid_trigger(area):
		break_pillar(area)


func _is_valid_trigger(node: Node) -> bool:
	var current := node
	while current != null:
		for group_name in trigger_groups:
			if current.is_in_group(group_name):
				return true

		var lowercase_name := current.name.to_lower()
		for name_part in trigger_name_parts:
			if lowercase_name.contains(name_part.to_lower()):
				return true

		current = current.get_parent()

	return false
