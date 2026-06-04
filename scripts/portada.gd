extends Control

@onready var title_logo    : TextureRect         = $TextureRect2
@onready var btn_start     : Button              = $Button
@onready var audio         : AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var audio_select  : AudioStreamPlayer2D = $AudioStreamPlayer2DSelect

var _transition_started : bool    = false
var _original_scale     : Vector2 = Vector2.ONE

func _ready() -> void:
	title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	btn_start.pressed.connect(_trigger_transition)
	set_process_unhandled_input(true)

	await get_tree().process_frame

	_original_scale       = title_logo.scale
	title_logo.position   = Vector2(297, 153)
	title_logo.modulate.a = 0.0
	title_logo.scale      = Vector2(_original_scale.x, 0.01)
	btn_start.modulate.a  = 0.0
	_set_blur(2.5)
	_start_intro()


func _set_blur(value: float) -> void:
	var mat := title_logo.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("blur_strength", value)


func _start_intro() -> void:
	await get_tree().create_timer(2.5).timeout

	audio.play()

	var logo_height := title_logo.size.y * _original_scale.y
	title_logo.position.y = 153.0 + logo_height

	var logo_tween := create_tween().set_parallel(true)
	logo_tween.tween_property(title_logo, "modulate:a", 1.0, 1.8) \
		.set_trans(Tween.TRANS_SINE)
	logo_tween.tween_property(title_logo, "scale", _original_scale, 2.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	logo_tween.tween_property(title_logo, "position:y", 153.0, 2.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	logo_tween.tween_method(_set_blur, 2.5, 0.5, 2.2) \
		.set_trans(Tween.TRANS_SINE)
	await logo_tween.finished

	title_logo.self_modulate = Color(1.20, 1.20, 2.20, 1.0)

	await get_tree().create_timer(0.75).timeout

	var start_tween := create_tween()
	start_tween.tween_property(btn_start, "modulate:a", 1.0, 6.0)
	await start_tween.finished

	_press_start_loop()


func _press_start_loop() -> void:
	while not _transition_started:
		var tween := create_tween()
		tween.tween_property(btn_start, "modulate:a", 1.0, 8.0)
		tween.tween_property(btn_start, "modulate:a", 0.0, 8.0)
		await tween.finished


func _unhandled_input(event: InputEvent) -> void:
	if _transition_started: return
	var pressed := (event is InputEventKey and event.is_pressed() and not event.is_echo()) \
				or (event is InputEventMouseButton and event.is_pressed())
	if pressed:
		_trigger_transition()


func _trigger_transition() -> void:
	if _transition_started: return
	_transition_started = true
	btn_start.disabled = true
	audio_select.play()
	TransitionManager.transition_to("res://scenes/menu_inicio.tscn")
