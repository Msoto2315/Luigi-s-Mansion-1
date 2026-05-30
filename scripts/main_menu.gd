extends Control

@onready var title_logo : TextureRect = $TextureRect2
@onready var btn_start : Button = $Button

var _transition_started : bool = false
var _logo_start_y : float = 0.0
var _float_time : float = 0.0
var _is_floating : bool = false
var _logo_start_x : float = 0.0

func _ready() -> void:
	title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title_logo.modulate = Color(1, 1, 1, 0)
	title_logo.scale = Vector2(0.5, 0.5)
	_set_logo_blur(3.0)
	await get_tree().process_frame
	_logo_start_y = title_logo.position.y
	_logo_start_x = title_logo.position.x
	btn_start.modulate = Color(1, 1, 1, 0)
	btn_start.visible = true
	btn_start.pressed.connect(_trigger_transition)
	_play_logo_ascent()

func _process(delta: float) -> void:
	if not _is_floating: return
	_float_time += delta
	title_logo.position.y = _logo_start_y + sin(_float_time * 0.9) * 8.0
	title_logo.position.x = _logo_start_x + sin(_float_time * 0.4) * 2.0
	title_logo.rotation_degrees = sin(_float_time * 0.6) * 0.8
	
	# Glow dinámico: combinamos un brillo base con una pulsación de luz
	var intensity = 1.0 + (sin(_float_time * 2.0) * 0.3)
	title_logo.self_modulate = Color(intensity, intensity, 1.5 + intensity, 1.0)

func _set_logo_blur(value: float) -> void:
	var mat := title_logo.material as ShaderMaterial
	if mat: mat.set_shader_parameter("blur_strength", value)

func _play_logo_ascent() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(title_logo, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	# Blur se queda en 0.8 para mantener el toque etéreo/fantasmal
	tw.tween_method(_set_logo_blur, 3.0, 0.6, 2.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_show_press_start()
	_start_logo_float()

func _show_press_start() -> void:
	create_tween().tween_property(btn_start, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)

func _start_logo_float() -> void:
	_is_floating = true

func _unhandled_input(event: InputEvent) -> void:
	if _transition_started or btn_start.modulate.a < 0.8: return
	if (event is InputEventKey and event.is_pressed() and not event.is_echo()) or (event is InputEventMouseButton and event.is_pressed()):
		_trigger_transition()

func _trigger_transition() -> void:
	if _transition_started: return
	_transition_started = true
	_is_floating = false
	btn_start.disabled = true
	var tw_out := create_tween()
	tw_out.tween_property(btn_start, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	await tw_out.finished
	TransitionManager.transition_to("res://scenes/interfaz_archivos.tscn")
