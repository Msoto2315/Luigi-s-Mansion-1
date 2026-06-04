extends Control

const SCENE_GAME := "res://scenes/Final Boss_Scene.tscn"

@onready var video : VideoStreamPlayer = $VideoStreamPlayer
@onready var audio : AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	# Conectamos la señal de finalización del video
	video.finished.connect(_go_to_game)
	
	# Iniciamos ambos simultáneamente
	video.play()
	audio.play()
	
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	# Saltar cinemática con cualquier tecla o clic
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_go_to_game()
	elif event is InputEventMouseButton and event.is_pressed():
		_go_to_game()

func _go_to_game() -> void:
	set_process_unhandled_input(false)
	
	# Detenemos el audio para evitar que siga sonando durante la transición
	if audio.playing:
		audio.stop()
		
	TransitionManager.transition_to(SCENE_GAME)
