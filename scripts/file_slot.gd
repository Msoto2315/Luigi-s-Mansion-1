# ============================================================
# file_slot.gd — Tarjeta individual de archivo
# Adjunta a cada nodo SlotN dentro de interfaz_archivos.tscn
#
# Todo el layout visual está en la escena .tscn.
# Este script solo maneja: selección visual, datos de guardado
# y emitir la señal cuando el usuario hace clic.
# ============================================================
extends Control

signal slot_selected(index: int)

# ── Propiedad exportada: asígnala en el Inspector ────────────
@export var slot_index : int = 0

# ── Constantes de escala ─────────────────────────────────────
const SCALE_NORMAL   := Vector2(1.0,  1.0)
const SCALE_SELECTED := Vector2(1.08, 1.08)

# ── Referencias a nodos hijos (definidos en la escena .tscn) ─
@onready var frame_panel   : Panel       = $FramePanel
@onready var preview_rect  : TextureRect = $FramePanel/PreviewRect
@onready var label_name    : Label       = $FramePanel/LabelName
@onready var label_status  : Label       = $FramePanel/LabelStatus
@onready var label_ghosts  : Label       = $FramePanel/LabelGhosts
@onready var label_money   : Label       = $FramePanel/LabelMoney

# ── Estado interno ───────────────────────────────────────────
var _save_data : Dictionary = {}
var _is_empty  : bool       = true

# ════════════════════════════════════════════════════════════
# API PÚBLICA — llamada desde interfaz_archivos.gd
# ════════════════════════════════════════════════════════════

## Carga los datos del slot y actualiza los labels.
func setup(data: Dictionary) -> void:
	_save_data = data
	_is_empty  = data.is_empty()
	_refresh_visuals()


## Aplica/quita el estado "seleccionado" con animación de escala.
func set_selected(selected: bool) -> void:
	var target := SCALE_SELECTED if selected else SCALE_NORMAL
	var tw := create_tween()
	tw.tween_property(self, "scale", target, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	z_index = 10 if selected else 0
	_apply_border(selected)


## Devuelve la textura del preview (útil para pasarla al popup).
func get_preview_texture() -> Texture2D:
	return preview_rect.texture

# ════════════════════════════════════════════════════════════
# INTERNOS
# ════════════════════════════════════════════════════════════

func _ready() -> void:
	pivot_offset = size / 2.0
	_apply_border(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		slot_selected.emit(slot_index)


func _refresh_visuals() -> void:
	# LabelName: el texto base viene de la escena; aquí lo mantenemos
	# (para Opciones no se toca porque slot_index == 3)
	if slot_index < 3:
		label_name.text = "Archivo %d" % (slot_index + 1)

	if _is_empty or slot_index == 3:
		preview_rect.modulate = Color(0.35, 0.35, 0.55, 1)   # tinte oscuro si vacío
		label_status.visible  = (slot_index < 3)              # "Partida nueva" solo en archivos
		label_ghosts.visible  = false
		label_money.visible   = false
	else:
		preview_rect.modulate  = Color(1, 1, 1, 1)
		label_status.visible   = false
		label_ghosts.visible   = true
		label_money.visible    = true
		label_ghosts.text      = "👻 %d/50" % _save_data.get("ghosts", 0)
		label_money.text       = "%d T"     % _save_data.get("money",  0)


func _apply_border(selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.15, 1)
	var bw := 4 if selected else 2
	style.border_width_left   = bw
	style.border_width_right  = bw
	style.border_width_top    = bw
	style.border_width_bottom = bw
	style.border_color = Color(0.35, 0.65, 1.0, 1.0) if selected \
						else Color(0.18, 0.18, 0.32, 1.0)
	style.corner_radius_top_left     = 7
	style.corner_radius_top_right    = 7
	style.corner_radius_bottom_left  = 7
	style.corner_radius_bottom_right = 7
	if selected:
		style.shadow_color = Color(0.3, 0.6, 1.0, 0.5)
		style.shadow_size  = 8
	frame_panel.add_theme_stylebox_override("panel", style)
