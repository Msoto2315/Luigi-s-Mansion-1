extends Control

@onready var btn_continue : Button              = $MenuChoices/BtnContinue
@onready var btn_quit     : Button              = $MenuChoices/BtnQuit
@onready var ghost_left   : TextureRect         = $MenuChoices/GhostLeft
@onready var ghost_right  : TextureRect         = $MenuChoices/GhostRight
@onready var audio_move   : AudioStreamPlayer2D = $AudioStreamPlayer2DSelect
@onready var audio_confirm: AudioStreamPlayer2D = $AudioStreamPlayer2DSelect2

var _current : int   = 0
var _glow_t  : float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_continue.pressed.connect(_continuar)
	btn_quit.pressed.connect(_salir)
	ghost_left.visible  = false
	ghost_right.visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				abrir_menu()
				get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_continuar()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		_current = 1 - _current
		_play_move()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		_play_confirm()
		if _current == 0: _continuar()
		else:              _salir()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_UP, KEY_W:
				_current = 0
				_play_move()
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S:
				_current = 1
				_play_move()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_play_confirm()
				if _current == 0: _continuar()
				else:              _salir()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_glow_t += delta
	var pulse    := (sin(_glow_t * 3.0) + 1.0) * 0.5
	var col_sel  := Color(1.0, 1.0, 1.0, lerpf(0.75, 1.0, pulse))
	var col_idle := Color(0.88, 0.84, 0.94, 0.55)
	btn_continue.add_theme_color_override("font_color", col_sel  if _current == 0 else col_idle)
	btn_quit.add_theme_color_override(    "font_color", col_sel  if _current == 1 else col_idle)
	var target_y : float = 9.0 if _current == 0 else 75.0
	ghost_left.position.y  = lerpf(ghost_left.position.y,  target_y, 0.25)
	ghost_right.position.y = lerpf(ghost_right.position.y, target_y, 0.25)


func abrir_menu() -> void:
	visible = true
	get_tree().paused = true
	_current = 0
	_glow_t  = 0.0
	ghost_left.visible  = true
	ghost_right.visible = true
	btn_continue.grab_focus()
	_play_confirm()


func cerrar_menu() -> void:
	visible = false
	get_tree().paused = false


func _continuar() -> void:
	_play_confirm()
	cerrar_menu()


func _salir() -> void:
	_play_confirm()
	get_tree().paused = false
	get_tree().quit()


func _play_move() -> void:
	if audio_move and audio_move.stream:
		audio_move.seek(0.0)
		audio_move.play()


func _play_confirm() -> void:
	if audio_confirm and audio_confirm.stream:
		audio_confirm.seek(0.0)
		audio_confirm.play()
