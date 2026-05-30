extends Control

@onready var slot_1     : Button = $VBoxContainer/Slot1
@onready var slot_2     : Button = $VBoxContainer/Slot2
@onready var slot_3     : Button = $VBoxContainer/Slot3
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	slot_1.pressed.connect(_on_slot_pressed.bind(1))
	slot_2.pressed.connect(_on_slot_pressed.bind(2))
	slot_3.pressed.connect(_on_slot_pressed.bind(3))
	back_button.pressed.connect(_on_back_pressed)

func _on_slot_pressed(_slot_num: int) -> void:
	TransitionManager.transition_to("res://scenes/Final Boss_Scene.tscn")

func _on_back_pressed() -> void:
	TransitionManager.transition_to("res://scenes/main_menu.tscn")
