# slot_context.gd — Autoload para pasar datos entre escenas.
# Registrar en Project > Autoload como "SlotContext"
extends Node

var slot_index      : int                = -1
var preview_texture : Texture2D          = null
var save_data       : Array[Dictionary]  = []
