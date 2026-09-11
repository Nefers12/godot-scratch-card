@tool
@icon("res://addons/godot_scratch_card/icon.png")
class_name ScratchZone
extends Resource

@export var id: String = "zone_1"
@export var uv_rect: Rect2 = Rect2(0.1, 0.1, 0.8, 0.8)
@export var enable_validation: bool = true
@export_range(0.0, 1.0) var valid_threshold: float = 0.30
@export var enable_auto_reveal: bool = true
@export_range(0.0, 1.0) var auto_reveal_threshold: float = 0.65
@export var payload: Dictionary = {}

var scratched_percentage: float = 0.0
var is_validated: bool = false
var is_cleared: bool = false

signal percentage_changed(new_percentage: float)
signal zone_cleared()
signal zone_validated()

func update_percentage(new_pct: float) -> void:
	scratched_percentage = clampf(new_pct, 0.0, 1.0)
	percentage_changed.emit(scratched_percentage)
	
	if enable_validation and not is_validated and scratched_percentage >= valid_threshold:
		is_validated = true
		zone_validated.emit()
		
	if not is_cleared:
		if (enable_auto_reveal and scratched_percentage >= auto_reveal_threshold) or scratched_percentage >= 0.98:
			is_cleared = true
			zone_cleared.emit()

func reset() -> void:
	scratched_percentage = 0.0
	is_validated = false
	is_cleared = false
	percentage_changed.emit(0.0)

