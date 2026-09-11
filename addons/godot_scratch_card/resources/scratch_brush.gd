@tool
@icon("res://addons/godot_scratch_card/icon.png")
class_name ScratchBrush
extends Resource

@export_range(1.0, 200.0) var radius: float = 24.0
@export_range(0.01, 1.0) var opacity: float = 1.0
@export var custom_texture: Texture2D = null
@export_range(0.0, 1.0) var hardness: float = 1.0
@export var stroke_color: Color = Color.WHITE
