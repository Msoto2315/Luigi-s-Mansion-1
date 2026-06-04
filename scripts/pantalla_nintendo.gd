extends Control

@onready var audio : AudioStreamPlayer2D = $AudioNintendo

func _ready() -> void:
	await get_tree().process_frame

	# Reproducir el sonido al aparecer la pantalla
	audio.play()

	# Esperar los 2.5 seg y pasar al menú
	await get_tree().create_timer(  
		
		
		
		2.5).timeout
	TransitionManager.transition_to("res://scenes/portada.tscn")
