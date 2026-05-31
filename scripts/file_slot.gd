extends Control

signal slot_selected(index: int)
@export var slot_index : int = 0

const SCALE_NORMAL   := Vector2(1.0, 1.0)
const SCALE_SELECTED := Vector2(1.08, 1.08)

@onready var frame_panel   : Panel       = $FramePanel
@onready var preview_rect  : TextureRect = $FramePanel/PreviewRect
@onready var label_name    : Label       = $FramePanel/LabelName
@onready var label_status  : Label       = $FramePanel/LabelStatus
@onready var label_ghosts  : Label       = $FramePanel/LabelGhosts
@onready var label_money   : Label       = $FramePanel/LabelMoney

var _save_data : Dictionary = {}
var _is_empty  : bool = true
var glow_time  : float = 0.0

func _process(delta: float) -> void:
	glow_time += delta
	var alpha := 0.0 + ((sin(glow_time * 1.2) + 1.0) * 0.425)
	label_name.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, alpha))
	label_name.queue_redraw()

func setup(data: Dictionary) -> void:
	_save_data = data
	_is_empty = data.is_empty()
	_refresh_visuals()

func set_selected(selected: bool) -> void:
	var target := SCALE_SELECTED if selected else SCALE_NORMAL
	var tw := create_tween()
	tw.tween_property(self, "scale", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	z_index = 10 if selected else 0
	_apply_border(selected)

func get_preview_texture() -> Texture2D:
	return preview_rect.texture

func _ready() -> void:
	pivot_offset = size / 2.0
	_apply_border(false)
	label_name.add_theme_color_override("font_color", Color.WHITE)
	label_name.add_theme_color_override("font_outline_color", Color.BLACK)
	label_name.add_theme_constant_override("outline_size", 4)
	label_name.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.8, 1.0))
	label_name.add_theme_constant_override("shadow_offset_x", 0)
	label_name.add_theme_constant_override("shadow_offset_y", 0)
	label_name.add_theme_constant_override("shadow_outline_size", 20)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_selected.emit(slot_index)

func _refresh_visuals() -> void:
	if slot_index < 3: label_name.text = "Archivo %d" % (slot_index + 1)
	if _is_empty or slot_index == 3:
		preview_rect.modulate = Color(0.35, 0.35, 0.55, 1)
		label_status.visible = (slot_index < 3)
		label_ghosts.visible = false
		label_money.visible = false
	else:
		preview_rect.modulate = Color.WHITE
		label_status.visible = false
		label_ghosts.visible = true
		label_money.visible = true
		label_ghosts.text = "👻 %d/50" % _save_data.get("ghosts", 0)
		label_money.text = "%d T" % _save_data.get("money", 0)

func _apply_border(selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.15, 1)
	var bw := 4 if selected else 2
	style.border_width_left = bw; style.border_width_right = bw
	style.border_width_top = bw; style.border_width_bottom = bw
	style.border_color = Color(0.35, 0.65, 1.0, 1.0) if selected else Color(0.18, 0.18, 0.32, 1.0)
	style.corner_radius_top_left = 7; style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7; style.corner_radius_bottom_right = 7
	if selected:
		style.shadow_color = Color(0.3, 0.6, 1.0, 0.5)
		style.shadow_size = 8
	frame_panel.add_theme_stylebox_override("panel", style)
