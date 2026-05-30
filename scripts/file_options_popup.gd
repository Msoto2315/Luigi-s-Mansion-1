# ============================================================
# file_options_popup.gd — Popup de opciones del archivo
# Escena: res://scenes/file_options_popup.tscn
#
# Todo el layout visual está en la escena .tscn.
# Este script solo maneja: navegación teclado, highlight de
# la opción activa y emisión de la señal option_chosen.
# ============================================================
extends Control

signal option_chosen(action: String)   # "start" | "copy" | "delete" | "options" | "cancel"

# ── Referencias — todos existen en la escena .tscn ──────────
@onready var preview_image  : TextureRect = $PopupContainer/SlotPreview/PreviewImage
@onready var label_archivo  : Label       = $PopupContainer/SlotPreview/LabelArchivo
@onready var btn_start      : Button      = $PopupContainer/ButtonsPanel/VBox/BtnStart
@onready var btn_copy       : Button      = $PopupContainer/ButtonsPanel/VBox/BtnCopy
@onready var btn_delete     : Button      = $PopupContainer/ButtonsPanel/VBox/BtnDelete
@onready var btn_options    : Button      = $PopupContainer/ButtonsPanel/VBox/BtnOptions
@onready var select_arrow   : Label       = $PopupContainer/ButtonsPanel/SelectArrow

# ── Estado ───────────────────────────────────────────────────
var _current_option : int = 0
var _buttons : Array[Button]

# ════════════════════════════════════════════════════════════
# API PÚBLICA — llamada desde interfaz_archivos.gd
# ════════════════════════════════════════════════════════════

## Configura el popup con los datos del slot seleccionado.
## slot_index: 0-2, preview_tex: textura del TextureRect del slot (puede ser null)
func setup(slot_index: int, preview_tex: Texture2D) -> void:
	label_archivo.text    = "Archivo %d" % (slot_index + 1)
	preview_image.texture = preview_tex   # null = sin imagen (slot vacío)

# ════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ════════════════════════════════════════════════════════════

func _ready() -> void:
	_buttons = [btn_start, btn_copy, btn_delete, btn_options]

	btn_start.pressed.connect(func(): option_chosen.emit("start"))
	btn_copy.pressed.connect( func(): option_chosen.emit("copy"))
	btn_delete.pressed.connect(func(): option_chosen.emit("delete"))
	btn_options.pressed.connect(func(): option_chosen.emit("options"))

	# Animación de entrada
	modulate.a = 0.0
	scale      = Vector2(0.88, 0.88)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0,             0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale",      Vector2(1.0, 1.0), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_highlight_option(0)
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_UP:
			_current_option = wrapi(_current_option - 1, 0, _buttons.size())
			_highlight_option(_current_option)
		KEY_DOWN:
			_current_option = wrapi(_current_option + 1, 0, _buttons.size())
			_highlight_option(_current_option)
		KEY_ENTER, KEY_SPACE:
			_buttons[_current_option].pressed.emit()
		KEY_ESCAPE:
			option_chosen.emit("cancel")

# ════════════════════════════════════════════════════════════
# INTERNOS
# ════════════════════════════════════════════════════════════

func _highlight_option(index: int) -> void:
	# Mueve la flecha SelectArrow al botón activo
	var btn := _buttons[index]
	var arrow_y := btn.position.y + (btn.size.y - select_arrow.size.y) * 0.5
	select_arrow.position.y = arrow_y

	# Cambia color de todos los botones
	for i in _buttons.size():
		if i == index:
			_buttons[i].add_theme_color_override("font_color",       Color(0.25, 0.9, 1.0, 1))
			_buttons[i].add_theme_color_override("font_hover_color",  Color(0.25, 0.9, 1.0, 1))
		else:
			_buttons[i].remove_theme_color_override("font_color")
			_buttons[i].remove_theme_color_override("font_hover_color")
