extends Control

const SCENE_GAME := "res://scenes/Cinematica 2.tscn"

@onready var video : VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	video.finished.connect(_go_to_game)
	video.play()
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	# Saltar cinemática con cualquier tecla o clic
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_go_to_game()
	elif event is InputEventMouseButton and event.is_pressed():
		_go_to_game()

func _go_to_game() -> void:
	set_process_unhandled_input(false)
	TransitionManager.transition_to(SCENE_GAME)
