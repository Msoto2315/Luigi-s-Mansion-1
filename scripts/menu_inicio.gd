extends Control

const SCENE_MAIN_MENU := "res://scenes/portada.tscn"
const SCENE_POPUP      := "res://scenes/menu_options.tscn"
const SAVE_PATH        := "user://savegame.save"
const SLOT_REST_Y      := [120.0, 195.0, 270.0, 320.0]

@onready var slots_root  : Control         = $SlotsRoot
@onready var popup_layer : CanvasLayer     = $PopupLayer
@onready var label_title : Label           = $LabelTitle
@onready var label_sub   : Label           = $LabelSub
@onready var label_y     : Label           = $LabelY
@onready var label_x     : Label           = $LabelX
@onready var audio_bg    : AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var audio_sel   : AudioStreamPlayer2D = $AudioStreamPlayer2DSelect
@onready var audio_sel2  : AudioStreamPlayer2D = $AudioStreamPlayer2DSelect2

var _slots          : Array[Control]    = []
var _selected_index : int               = 0
var _save_data      : Array[Dictionary] = []
var glow_time       : float             = 0.0
var _sub_toggle     : bool              = false
var _fog_rect       : ColorRect

func _process(delta: float) -> void:
	glow_time += delta
	var pulse := (sin(glow_time * 1.2) + 1.0) * 0.425
	label_title.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, pulse))
	label_title.queue_redraw()
	label_y.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, pulse))
	label_x.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, pulse))
	label_sub.modulate.a = pulse
	if pulse < 0.01 and not _sub_toggle:
		_sub_toggle = true
		label_sub.text = "Pasa, la mansión es nuestra..." \
			if label_sub.text == "Pasa, la mansión es tuya..." \
			else "Pasa, la mansión es tuya..."
	elif pulse > 0.75:
		_sub_toggle = false

func _ready() -> void:
	if audio_bg:
		audio_bg.play()

	label_title.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, 1.0))
	label_title.add_theme_constant_override("shadow_offset_x", 0)
	label_title.add_theme_constant_override("shadow_offset_y", 0)
	label_title.add_theme_constant_override("shadow_outline_size", 35)
	label_sub.modulate.a = 1.0
	label_sub.text = "Pasa, la mansión es tuya..."

	# Sombra rosada en LabelY y LabelX
	for lbl in [label_y, label_x]:
		lbl.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, 1.0))
		lbl.add_theme_constant_override("shadow_offset_x", 0)
		lbl.add_theme_constant_override("shadow_offset_y", 0)
		lbl.add_theme_constant_override("shadow_outline_size", 20)

	_slots = [
		slots_root.get_node("Slot1"),
		slots_root.get_node("Slot2"),
		slots_root.get_node("Slot3"),
		slots_root.get_node("SlotOpciones"),
	]

	_load_save_data()
	for i in 3:
		_slots[i].setup(_save_data[i])
	for i in _slots.size():
		_slots[i].slot_selected.connect(_on_slot_selected)

	_create_fog_background()
	_animate_entrance()
	set_process_unhandled_input(true)

func _create_fog_background() -> void:
	_fog_rect = ColorRect.new()
	_fog_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fog_rect.anchor_right   = 1.0
	_fog_rect.anchor_bottom  = 1.0
	_fog_rect.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	# Z relativo al padre, valor negativo = detrás de todo
	_fog_rect.z_as_relative  = false
	_fog_rect.z_index        = 1
	var shader := load("res://assets/shaders/fog_background.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("speed", 0.85)
		mat.set_shader_parameter("fog_color", Color(0.06, 0.12, 0.38, 1.0))
		mat.set_shader_parameter("fog_alpha_min", 0.25)
		mat.set_shader_parameter("fog_alpha_max", 0.68)
		_fog_rect.material = mat
	add_child(_fog_rect)
	# Mover al primer hijo para que quede detrás de todo lo demás
	move_child(_fog_rect, 0)

func _load_save_data() -> void:
	_save_data = []
	if FileAccess.file_exists(SAVE_PATH):
		var f    := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data  = JSON.parse_string(f.get_as_text())
		f.close()
		if data is Array:
			_save_data = Array(data, TYPE_DICTIONARY, "", null)
	while _save_data.size() < 3:
		_save_data.append({})

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			_select_slot(wrapi(_selected_index - 1, 0, _slots.size()), true)
		KEY_RIGHT, KEY_D:
			_select_slot(wrapi(_selected_index + 1, 0, _slots.size()), true)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_open_slot(_selected_index)
		KEY_ESCAPE:
			TransitionManager.transition_to(SCENE_MAIN_MENU)

func _on_slot_selected(index: int) -> void:
	if _selected_index == index:
		_open_slot(index)
	else:
		_select_slot(index, true)

func _select_slot(index: int, _animate: bool = false) -> void:
	if _selected_index < _slots.size():
		_slots[_selected_index].set_selected(false)
	_selected_index = index
	_slots[_selected_index].set_selected(true)
	# Ocultar hints al mover el slot
	if label_y.visible or label_x.visible:
		var tw_hide := create_tween().set_parallel(true)
		tw_hide.tween_property(label_y, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		tw_hide.tween_property(label_x, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)

	if audio_sel and audio_sel.stream:
		audio_sel.seek(0.0)
		audio_sel.play()

func _open_slot(index: int) -> void:
	if index == 3:
		return
	if audio_sel2 and audio_sel2.stream:
		audio_sel2.seek(0.0)
		audio_sel2.play()
	SlotContext.slot_index      = index
	SlotContext.preview_texture = _slots[index].get_preview_texture()
	SlotContext.save_data       = _save_data
	TransitionManager.transition_to(SCENE_POPUP)

func _animate_entrance() -> void:
	for i in _slots.size():
		_slots[i].modulate.a  = 0.0
		_slots[i].position.y -= 40.0
	_slots[0].set_selected(true)
	await get_tree().create_timer(0.5).timeout
	for i in _slots.size():
		var slot   := _slots[i]
		var rest_y : float = SLOT_REST_Y[i]
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(slot, "modulate:a", 1.0,    0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(slot, "position:y", rest_y, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.10).timeout
