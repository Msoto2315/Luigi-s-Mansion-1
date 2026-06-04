extends Node

const PAUSE_MENU_SCENE := preload("res://scenes/menu_pausa.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer        = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(menu)
