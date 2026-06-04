extends Control

const SCENE_NINTENDO := "res://scenes/Pantalla_Nintendo.tscn"

const NEGRO_PREVIO := 2.0

@onready var video : VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	# Empezar con el video invisible — negro total
	video.visible = false
	video.finished.connect(_ir_a_nintendo)
	set_process_unhandled_input(false)

	# Pausa en negro, luego aparece el video
	await get_tree().create_timer(NEGRO_PREVIO).timeout
	video.visible = true
	video.play()

	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	# Saltar intro con cualquier tecla o clic
	var skip := false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		skip = true
	elif event is InputEventMouseButton and event.is_pressed():
		skip = true

	if skip:
		set_process_unhandled_input(false)
		video.stop()
		_ir_a_nintendo()

func _ir_a_nintendo() -> void:
	set_process_unhandled_input(false)
	TransitionManager.transition_to(SCENE_NINTENDO)
