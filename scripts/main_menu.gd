extends Control

@onready var title_logo : TextureRect = $TextureRect2
@onready var btn_start : Button = $Button

var _transition_started : bool = false
var _logo_start_y : float = 0.0

func _ready() -> void:
	# 1. EVITAR SNAPPING: Esto es vital para que no se pegue a píxeles enteros
	title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	title_logo.modulate = Color(1, 1, 1, 0)
	title_logo.scale = Vector2(0.5, 0.5)
	_set_logo_blur(3.0)
	
	await get_tree().process_frame
	_logo_start_y = title_logo.position.y
	
	btn_start.modulate = Color(1, 1, 1, 0)
	btn_start.visible = true
	btn_start.pressed.connect(_trigger_transition)
	
	_play_logo_ascent()

func _set_logo_blur(value: float) -> void:
	var mat := title_logo.material as ShaderMaterial
	if mat: mat.set_shader_parameter("blur_strength", value)

func _play_logo_ascent() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(title_logo, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_logo_blur, 3.0, 0.0, 2.5).set_trans(Tween.TRANS_SINE)
	
	await tw.finished
	_show_press_start()
	_start_logo_float()

func _show_press_start() -> void:
	create_tween().tween_property(btn_start, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)

func _start_logo_float() -> void:
	# 2. MOVIMIENTO SUB-PIXEL: Usamos un Tween con alta precisión
	var tw := create_tween().set_loops()
	# Al moverlo solo 2 píxeles, reducimos la agresividad del salto
	tw.tween_property(title_logo, "position:y", _logo_start_y - 2.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(title_logo, "position:y", _logo_start_y, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if _transition_started or btn_start.modulate.a < 0.8: return
	if (event is InputEventKey and event.is_pressed() and not event.is_echo()) or (event is InputEventMouseButton and event.is_pressed()):
		_trigger_transition()

func _trigger_transition() -> void:
	if _transition_started: return
	_transition_started = true
	btn_start.disabled = true
	var tw_out := create_tween()
	tw_out.tween_property(btn_start, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	await tw_out.finished
	TransitionManager.transition_to("res://scenes/interfaz_archivos.tscn")
