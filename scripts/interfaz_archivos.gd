extends Control

const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_GAME      := "res://scenes/Final Boss_Scene.tscn"
const SCENE_POPUP     := "res://scenes/file_options_popup.tscn"
const SAVE_PATH       := "user://savegame.save"
const SLOT_REST_Y     := [120.0, 195.0, 270.0, 320.0]

@onready var slots_root  : Control     = $SlotsRoot
@onready var popup_layer : CanvasLayer = $PopupLayer
@onready var btn_volver  : Button      = $BtnVolver
@onready var label_title : Label       = $LabelTitle
@onready var label_sub   : Label       = $LabelSub

var _slots          : Array[Control]    = []
var _selected_index : int               = 0
var _save_data      : Array[Dictionary] = []
var _popup_open     : bool              = false
var _popup_instance : Control           = null
var glow_time       : float             = 0.0
var _sub_toggle     : bool              = false

func _process(delta: float) -> void:
	glow_time += delta
	var pulse := 0.0 + ((sin(glow_time * 1.2) + 1.0) * 0.425)
	label_title.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, pulse))
	label_title.queue_redraw()
	label_sub.modulate.a = pulse
	
	if pulse < 0.01 and not _sub_toggle:
		_sub_toggle = true
		if label_sub.text == "Pasa, la mansión es tuya...":
			label_sub.text = "Pasa, la mansión es nuestra..."
		else:
			label_sub.text = "Pasa, la mansión es tuya..."
	elif pulse > 0.75:
		_sub_toggle = false

func _ready() -> void:
	label_title.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, 1.0))
	label_title.add_theme_constant_override("shadow_offset_x", 0)
	label_title.add_theme_constant_override("shadow_offset_y", 0)
	label_title.add_theme_constant_override("shadow_outline_size", 35)
	label_sub.modulate.a = 1.0
	label_sub.text = "Pasa, la mansión es tuya..."
	_slots = [slots_root.get_node("Slot1"), slots_root.get_node("Slot2"), slots_root.get_node("Slot3"), slots_root.get_node("SlotOpciones")]
	_load_save_data()
	for i in 3: _slots[i].setup(_save_data[i])
	for i in _slots.size(): _slots[i].slot_selected.connect(_on_slot_selected)
	_animate_entrance()
	set_process_unhandled_input(true)

func _load_save_data() -> void:
	_save_data = []
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		f.close()
		if data is Array: _save_data = Array(data, TYPE_DICTIONARY, "", null)
	while _save_data.size() < 3: _save_data.append({})

func _save_data_to_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_save_data))
	f.close()

func _unhandled_input(event: InputEvent) -> void:
	if _popup_open or not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_LEFT, KEY_A: _select_slot(wrapi(_selected_index - 1, 0, _slots.size()), true)
		KEY_RIGHT, KEY_D: _select_slot(wrapi(_selected_index + 1, 0, _slots.size()), true)
		KEY_ENTER, KEY_SPACE: _open_slot(_selected_index)
		KEY_ESCAPE: TransitionManager.transition_to(SCENE_MAIN_MENU)

func _on_slot_selected(index: int) -> void:
	if _selected_index == index: _open_slot(index)
	else: _select_slot(index, true)

func _select_slot(index: int, animate: bool) -> void:
	if _selected_index < _slots.size(): _slots[_selected_index].set_selected(false)
	_selected_index = index
	_slots[_selected_index].set_selected(true)

func _open_slot(index: int) -> void:
	if index == 3: return
	_popup_open = true
	_popup_instance = load(SCENE_POPUP).instantiate()
	popup_layer.add_child(_popup_instance)
	var preview_tex : Texture2D = _slots[index].get_preview_texture()
	_popup_instance.setup(index, preview_tex)
	_popup_instance.option_chosen.connect(_on_option_chosen.bind(index))

func _on_option_chosen(action: String, slot_index: int) -> void:
	_close_popup()
	match action:
		"start": _start_game(slot_index)
		"delete": _delete_slot(slot_index)

func _close_popup() -> void:
	if _popup_instance:
		var tw := create_tween()
		tw.tween_property(_popup_instance, "modulate:a", 0.0, 0.15)
		await tw.finished
		_popup_instance.queue_free()
		_popup_instance = null
	_popup_open = false

func _start_game(slot_index: int) -> void:
	if _save_data[slot_index].is_empty():
		_save_data[slot_index] = {"slot": slot_index, "ghosts": 0, "money": 0, "area": 1}
		_save_data_to_disk()
	TransitionManager.transition_to(SCENE_GAME)

func _delete_slot(slot_index: int) -> void:
	_save_data[slot_index] = {}
	_save_data_to_disk()
	_slots[slot_index].setup(_save_data[slot_index])
	_select_slot(slot_index, true)

func _animate_entrance() -> void:
	for i in _slots.size():
		_slots[i].modulate.a = 0.0
		_slots[i].position.y -= 40.0
	_slots[0].set_selected(true)
	await get_tree().create_timer(0.5).timeout
	for i in _slots.size():
		var slot := _slots[i]
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(slot, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(slot, "position:y", SLOT_REST_Y[i], 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.10).timeout
