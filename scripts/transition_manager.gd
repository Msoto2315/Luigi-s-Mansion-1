extends Node

var _canvas  : CanvasLayer
var _overlay : ColorRect
var _tween   : Tween
var _busy    : bool = false

const FADE_DURATION := 1.4

func _ready() -> void:
	_canvas       = CanvasLayer.new()
	_canvas.layer = 100
	_canvas.name  = "FadeCanvas"
	add_child(_canvas)

	_overlay              = ColorRect.new()
	_overlay.color        = Color.BLACK
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# CORRECCIÓN: empieza completamente NEGRO (alpha 1) — pantalla negra antes de todo
	_overlay.modulate     = Color(1, 1, 1, 1)
	_canvas.add_child(_overlay)

	# Fade-in automático: negro → escena inicial (Pantalla Nintendo)
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	_do_fade_in()

# ── API pública ────────────────────────────────────────────────
func transition_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _do_fade_out()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame   # 2 frames para garantizar carga
	await _do_fade_in()
	_busy = false

# ── Fade-in: negro opaco → transparente ───────────────────────
func _do_fade_in() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate     = Color(1, 1, 1, 1)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate", Color(1, 1, 1, 0), FADE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await _tween.finished

# ── Fade-out: transparente → negro opaco ──────────────────────
func _do_fade_out() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.modulate     = Color(1, 1, 1, 0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate", Color(1, 1, 1, 1), FADE_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await _tween.finished
