extends Control

const COLOR_NORMAL        := Color("BCEEEB")
const COLOR_SELECTED_TEXT := Color("021410")

const SCENE_INTERFAZ := "res://scenes/menu_inicio.tscn"
const SCENE_GAME     := "res://scenes/Cinematica 1.tscn"
const SAVE_PATH      := "user://savegame.save"

@onready var label_archivo : Label       = $LabelArchivo
@onready var preview_image : TextureRect = $SlotPreview/PreviewImage

@onready var btn_start   : Button = $ButtonsPanel/VBox/BtnStart
@onready var btn_copy    : Button = $ButtonsPanel/VBox/BtnCopy
@onready var btn_delete  : Button = $ButtonsPanel/VBox/BtnDelete
@onready var btn_options : Button = $ButtonsPanel/VBox/BtnOptions

@onready var audio_bg    : AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var audio_move  : AudioStreamPlayer2D = $AudioStreamPlayer2DSelect
@onready var audio_confirm : AudioStreamPlayer2D = $AudioStreamPlayer2DSelect2

var _current         : int   = 0
var _slot_index      : int   = 0
var _save_data       : Array[Dictionary] = []
var _buttons         : Array[Button]
var _glow_time       : float = 0.0
var _panel_glow_time : float = 0.0

var _fog_rect : ColorRect

const C_THICK  := 5.0
const C_LEN    := 30.0
const C_RADIUS := 14.0
const C_COLOR  := Color(0.35, 0.65, 1.0, 1.0)

var _corner_nodes  : Array[Panel] = []
var _corner_tween  : Tween
var _corner_glow_t : float = 0.0

func _ready() -> void:
	_buttons = [btn_start, btn_copy, btn_delete, btn_options]
	_slot_index = SlotContext.slot_index if SlotContext.slot_index >= 0 else 0
	_save_data  = SlotContext.save_data

	while _save_data.size() < 3:
		_save_data.append({})

	for btn in _buttons:
		btn.pressed.connect(func(): _on_action(btn.name.to_lower().replace("btn", "")))

	label_archivo.text    = "Archivo %d" % (_slot_index + 1)
	preview_image.texture = SlotContext.preview_texture

	label_archivo.add_theme_color_override("font_color",         Color.WHITE)
	label_archivo.add_theme_color_override("font_outline_color", Color.BLACK)
	label_archivo.add_theme_constant_override("outline_size",         4)
	label_archivo.add_theme_constant_override("shadow_outline_size", 20)
	label_archivo.add_theme_constant_override("shadow_offset_x",      0)
	label_archivo.add_theme_constant_override("shadow_offset_y",      0)

	if has_node("ButtonsPanel"):
		_apply_panel_style($ButtonsPanel)

	for btn in _buttons:
		var fp : Panel = btn.get_node_or_null("FramePanel")
		if fp:
			fp.visible = false

	# Audio de fondo
	if audio_bg and audio_bg.stream:
		audio_bg.play()

	_create_fog_background()

	modulate.a = 0.0
	position.x = 100.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_property(self, "position:x", 0.0, 0.35)
	await tw.finished

	await get_tree().process_frame
	_highlight(0)
	set_process_unhandled_input(true)


func _create_fog_background() -> void:
	_fog_rect = ColorRect.new()
	_fog_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fog_rect.anchor_right   = 1.0
	_fog_rect.anchor_bottom  = 1.0
	_fog_rect.offset_right   = 0.0
	_fog_rect.offset_bottom  = 0.0
	_fog_rect.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_fog_rect.z_as_relative  = false
	_fog_rect.z_index        = 1
	var shader := load("res://assets/shaders/fog_background.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		# Más velocidad y más visible que antes
		mat.set_shader_parameter("speed",         1.2)
		mat.set_shader_parameter("fog_color",     Color(0.06, 0.12, 0.38, 1.0))
		mat.set_shader_parameter("fog_alpha_min", 0.30)
		mat.set_shader_parameter("fog_alpha_max", 0.75)
		_fog_rect.material = mat
	add_child(_fog_rect)
	move_child(_fog_rect, 1)


func _highlight(index: int) -> void:
	_current = index
	for i in _buttons.size():
		var btn   := _buttons[i]
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left     = 12
		style.corner_radius_top_right    = 12
		style.corner_radius_bottom_left  = 12
		style.corner_radius_bottom_right = 12
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2

		if i == index:
			style.bg_color     = Color(0.54, 0.53, 1.00, 0.22)
			style.border_color = Color(0.75, 0.73, 1.00, 0.55)
			btn.add_theme_color_override("font_color", COLOR_SELECTED_TEXT)
		else:
			style.bg_color     = Color(0.04, 0.08, 0.22, 0.10)
			style.border_color = Color(0.25, 0.45, 0.80, 0.25)
			btn.add_theme_color_override("font_color", COLOR_NORMAL)

		btn.add_theme_stylebox_override("normal",  style)
		btn.add_theme_stylebox_override("hover",   style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus",   style)

		var fp : Panel = btn.get_node_or_null("FramePanel")
		if fp:
			fp.visible = false

	_rebuild_corners(_buttons[index])


func _rebuild_corners(btn: Button) -> void:
	for n in _corner_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_corner_nodes.clear()
	if _corner_tween:
		_corner_tween.kill()

	await get_tree().process_frame
	var r := btn.get_global_rect()

	var panels_def := [
		{ "pos":  Vector2(r.position.x,        r.position.y),
		  "size": Vector2(C_LEN,   C_THICK),
		  "tl": C_RADIUS, "tr": 0.0, "bl": 0.0, "br": 0.0 },
		{ "pos":  Vector2(r.position.x,        r.position.y + C_THICK),
		  "size": Vector2(C_THICK, C_LEN - C_THICK),
		  "tl": 0.0, "tr": 0.0, "bl": 0.0, "br": 0.0 },
		{ "pos":  Vector2(r.end.x - C_LEN,     r.position.y),
		  "size": Vector2(C_LEN,   C_THICK),
		  "tl": 0.0, "tr": C_RADIUS, "bl": 0.0, "br": 0.0 },
		{ "pos":  Vector2(r.end.x - C_THICK,   r.position.y + C_THICK),
		  "size": Vector2(C_THICK, C_LEN - C_THICK),
		  "tl": 0.0, "tr": 0.0, "bl": 0.0, "br": 0.0 },
		{ "pos":  Vector2(r.position.x,        r.end.y - C_THICK),
		  "size": Vector2(C_LEN,   C_THICK),
		  "tl": 0.0, "tr": 0.0, "bl": C_RADIUS, "br": 0.0 },
		{ "pos":  Vector2(r.position.x,        r.end.y - C_LEN),
		  "size": Vector2(C_THICK, C_LEN - C_THICK),
		  "tl": 0.0, "tr": 0.0, "bl": 0.0, "br": 0.0 },
		{ "pos":  Vector2(r.end.x - C_LEN,     r.end.y - C_THICK),
		  "size": Vector2(C_LEN,   C_THICK),
		  "tl": 0.0, "tr": 0.0, "bl": 0.0, "br": C_RADIUS },
		{ "pos":  Vector2(r.end.x - C_THICK,   r.end.y - C_LEN),
		  "size": Vector2(C_THICK, C_LEN - C_THICK),
		  "tl": 0.0, "tr": 0.0, "bl": 0.0, "br": 0.0 },
	]

	for pd in panels_def:
		var p  := Panel.new()
		var st := StyleBoxFlat.new()
		var c  := C_COLOR
		c.a = 0.0
		st.bg_color                   = c
		st.corner_radius_top_left     = int(pd["tl"])
		st.corner_radius_top_right    = int(pd["tr"])
		st.corner_radius_bottom_left  = int(pd["bl"])
		st.corner_radius_bottom_right = int(pd["br"])
		st.border_width_left   = 0
		st.border_width_right  = 0
		st.border_width_top    = 0
		st.border_width_bottom = 0
		p.add_theme_stylebox_override("panel", st)
		p.global_position = pd["pos"]
		p.size            = pd["size"]
		p.mouse_filter    = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		_corner_nodes.append(p)

	_start_corner_blink()


func _start_corner_blink() -> void:
	_corner_glow_t = 0.0
	var tw := create_tween()
	tw.tween_method(
		func(t: float):
			for node in _corner_nodes:
				if is_instance_valid(node):
					var st := node.get_theme_stylebox("panel") as StyleBoxFlat
					if st: st.bg_color.a = t,
		0.0, 1.0, 0.15
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_glow_time       += delta
	_panel_glow_time += delta
	_corner_glow_t   += delta

	var pulse := (sin(_glow_time * 1.2) + 1.0) * 0.5
	label_archivo.add_theme_color_override(
		"font_shadow_color", Color(0.7, 0.35, 0.0, pulse)
	)

	if _corner_nodes.size() > 0:
		var corner_pulse := (sin(_corner_glow_t * 3.5) + 1.0) * 0.5
		var shadow_alpha := 0.25 + corner_pulse * 0.75
		var shadow_sz    := int(8.0 + corner_pulse * 14.0)
		for node in _corner_nodes:
			if is_instance_valid(node):
				var st := node.get_theme_stylebox("panel") as StyleBoxFlat
				if st:
					st.shadow_color = Color(0.3, 0.7, 1.0, shadow_alpha)
					st.shadow_size  = shadow_sz


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_UP:
				_highlight(wrapi(_current - 1, 0, _buttons.size()))
				if audio_move and audio_move.stream:
					audio_move.seek(0.0)
					audio_move.play()
			KEY_DOWN:
				_highlight(wrapi(_current + 1, 0, _buttons.size()))
				if audio_move and audio_move.stream:
					audio_move.seek(0.0)
					audio_move.play()
			KEY_ENTER, KEY_SPACE:
				if audio_confirm and audio_confirm.stream:
					audio_confirm.seek(0.0)
					audio_confirm.play()
				_buttons[_current].emit_signal("pressed")
			KEY_ESCAPE:
				TransitionManager.transition_to(SCENE_INTERFAZ)


func _apply_panel_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.02, 0.08, 0.30, 0.70)
	style.corner_radius_top_left     = 18
	style.corner_radius_top_right    = 18
	style.corner_radius_bottom_left  = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color        = Color(0.45, 0.65, 1.0, 0.9)
	panel.add_theme_stylebox_override("panel", style)


func _on_action(action: String) -> void:
	# Sonido de confirmar al hacer click en cualquier botón
	if audio_confirm and audio_confirm.stream:
		audio_confirm.seek(0.0)
		audio_confirm.play()
	match action:
		"start":  _start_game()
		"delete":
			_delete_slot()
			TransitionManager.transition_to(SCENE_INTERFAZ)
		_: TransitionManager.transition_to(SCENE_INTERFAZ)


func _start_game() -> void:
	if _save_data[_slot_index].is_empty():
		_save_data[_slot_index] = {"slot": _slot_index, "ghosts": 0, "money": 0, "area": 1}
	SlotContext.save_data = _save_data
	_write_save(_save_data)
	TransitionManager.transition_to(SCENE_GAME)


func _delete_slot() -> void:
	_save_data[_slot_index] = {}
	SlotContext.save_data    = _save_data
	_write_save(_save_data)


func _write_save(data: Array[Dictionary]) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
