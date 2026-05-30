extends Control

@onready var title_logo : TextureRect = $TextureRect2
@onready var btn_start  : Button      = $Button

var _transition_started : bool  = false
var _logo_start_y       : float = 0.0
var _press_start_tween  : Tween

func _ready() -> void:
	# ── Estado inicial: logo invisible y desplazado hacia abajo ──
	# El pivot_offset ya está configurado en la tscn (499, 197.5)
	title_logo.modulate = Color(1, 1, 1, 0)
	title_logo.scale    =  Vector2(0.47, 0.47)  # ligeramente más pequeño al inicio

	var mat := title_logo.material as ShaderMaterial
	mat.set_shader_parameter("blur_strength", 12.0)
	
	

	# Guardar posición Y original para usarla como destino de llegada
	# y configurar la posición de inicio (más abajo en pantalla)
	await get_tree().process_frame  # esperar para que el layout esté calculado
	_logo_start_y               = title_logo.position.y
	title_logo.position.y = _logo_start_y   # empieza 90px más abajo
	

	# Botón invisible al inicio
	btn_start.modulate = Color(1, 1, 1, 0)
	btn_start.visible  = true
	btn_start.pressed.connect(_trigger_transition)

	# Esperar un frame extra para que el TransitionManager termine su fade-in
	await get_tree().process_frame
	await get_tree().process_frame

	# Arrancar la secuencia
	_play_logo_ascent()
	
func _start_press_start_loop() -> void:
	var tw := create_tween().set_loops()

	# Aparece lentamente
	tw.tween_property(btn_start, "modulate:a", 1.0, 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Se mantiene visible
	tw.tween_interval(0.6)

	# Desaparece lentamente
	tw.tween_property(btn_start, "modulate:a", 0.25, 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Pausa pequeña
	tw.tween_interval(0.4)

# ================================================================
# ANIMACIÓN DEL TÍTULO — Efecto de Ascenso / Elevación
# El logo sube desde las sombras, fade-in + escala + posición
# Ease-out: arranca lento, gana velocidad, frena suavemente arriba
# ================================================================
func _play_logo_ascent() -> void:
	var mat := title_logo.material as ShaderMaterial

	var tw := create_tween()
	tw.set_parallel(true)   # posición, escala y alfa al mismo tiempo

	tw.tween_property(title_logo, "modulate:a", 1.0, 2.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tw.tween_property(title_logo, "scale", Vector2(0.50, 0.50), 2.4)  \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		

	await tw.finished
	
	# Fade del PRESS START lento y elegante
	_start_press_start_loop()

	# Flotación suave
	_start_logo_float()

# ================================================================
# FLOTACIÓN IDLE del logo — sube y baja suavemente en bucle
# ================================================================
func _start_logo_float() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(title_logo, "position:y", _logo_start_y - 7.0, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(title_logo, "position:y", _logo_start_y + 7.0, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ================================================================
# INPUT — cualquier tecla o clic dispara la transición
# ================================================================
func _unhandled_input(event: InputEvent) -> void:
	if _transition_started:
		return
	# Solo aceptar input cuando el botón ya sea visible (alpha > 0.8)
	if btn_start.modulate.a < 0.8:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_trigger_transition()
	elif event is InputEventMouseButton and event.is_pressed():
		_trigger_transition()

func _trigger_transition() -> void:
	if _transition_started:
		return
	_transition_started = true

	# Detener cualquier tween del botón
	if _press_start_tween:
		_press_start_tween.kill()

	btn_start.disabled = true

	# FADE-OUT suave del botón al salir (alpha 1 → 0 en 0.4 s)
	var tw_out := create_tween()
	tw_out.tween_property(btn_start, "modulate:a", 0.0, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw_out.finished

	# Ir a la interfaz de archivos con fundido a negro
	TransitionManager.transition_to("res://scenes/interfaz_archivos.tscn")
