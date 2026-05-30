extends Control

func _ready() -> void:
	# Esperar a que el árbol esté listo y el Autoload exista
	await get_tree().process_frame

	# Mostrar la pantalla Nintendo 2 segundos y pasar al menú
	await get_tree().create_timer(2.5).timeout
	TransitionManager.transition_to("res://scenes/main_menu.tscn")
