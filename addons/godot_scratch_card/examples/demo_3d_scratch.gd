extends Node3D

@onready var scratch_card_3d: ScratchCard3D = $ScratchCard3D
@onready var progress_bar: ProgressBar = $CanvasLayer/Panel/VBoxContainer/ProgressBar
@onready var label_status: Label = $CanvasLayer/Panel/VBoxContainer/LabelStatus
@onready var chk_auto_reveal: CheckBox = $CanvasLayer/Panel/VBoxContainer/ChkAutoReveal
@onready var slider_threshold: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxSlider/SliderThreshold
@onready var label_threshold: Label = $CanvasLayer/Panel/VBoxContainer/HBoxSlider/LabelThreshold
@onready var slider_valid: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxValidSlider/SliderValid
@onready var label_valid: Label = $CanvasLayer/Panel/VBoxContainer/HBoxValidSlider/LabelValid
@onready var btn_reset: Button = $CanvasLayer/Panel/VBoxContainer/BtnReset
@onready var btn_reveal: Button = $CanvasLayer/Panel/VBoxContainer/BtnReveal
@onready var btn_switch_2d: Button = $CanvasLayer/Panel/VBoxContainer/BtnSwitch2D
@onready var btn_benchmark: Button = $CanvasLayer/Panel/VBoxContainer/BtnBenchmark
@onready var log_label: RichTextLabel = $CanvasLayer/Panel/VBoxContainer/LogLabel

var _demo_zone: ScratchZone = null

func _ready() -> void:
	scratch_card_3d.auto_handle_input = true
	btn_reset.pressed.connect(func(): scratch_card_3d.reset_card())
	btn_reveal.pressed.connect(func(): scratch_card_3d.reveal_all())
	btn_switch_2d.pressed.connect(func(): get_tree().change_scene_to_file("res://addons/godot_scratch_card/examples/demo_2d_scratch.tscn"))
	if btn_benchmark != null:
		btn_benchmark.pressed.connect(func(): get_tree().change_scene_to_file("res://addons/godot_scratch_card/examples/demo_benchmark_rust_vs_gdscript.tscn"))
	
	_demo_zone = ScratchZone.new()
	_demo_zone.id = "3D Reward Zone"
	_demo_zone.uv_rect = Rect2(0.1, 0.1, 0.8, 0.8)
	_demo_zone.enable_auto_reveal = true
	_demo_zone.auto_reveal_threshold = 0.60
	_demo_zone.enable_validation = true
	_demo_zone.valid_threshold = 0.25
	_demo_zone.zone_validated.connect(func(): _log("Zone '%s' now valid (>=%d%% scratched)!" % [_demo_zone.id, int(_demo_zone.valid_threshold * 100)]))
	
	scratch_card_3d.zones = [_demo_zone]
	
	if chk_auto_reveal != null:
		chk_auto_reveal.toggled.connect(_on_auto_reveal_toggled)
		chk_auto_reveal.button_pressed = _demo_zone.enable_auto_reveal
	if slider_threshold != null:
		slider_threshold.value_changed.connect(_on_threshold_changed)
		slider_threshold.value = _demo_zone.auto_reveal_threshold * 100.0
		_update_threshold_label(slider_threshold.value)
	if slider_valid != null:
		slider_valid.value_changed.connect(_on_valid_threshold_changed)
		slider_valid.value = _demo_zone.valid_threshold * 100.0
		_update_valid_label(slider_valid.value)
	
	scratch_card_3d.enable_card_auto_reveal = _demo_zone.enable_auto_reveal
	scratch_card_3d.total_auto_reveal_threshold = _demo_zone.auto_reveal_threshold

	scratch_card_3d.total_scratched_updated.connect(_on_total_scratched)
	scratch_card_3d.zone_cleared.connect(_on_zone_cleared)
	scratch_card_3d.card_completed.connect(_on_card_completed)
	
	_log("3D demo ready.")

func _on_auto_reveal_toggled(toggled_on: bool) -> void:
	if _demo_zone != null:
		_demo_zone.enable_auto_reveal = toggled_on
	scratch_card_3d.enable_card_auto_reveal = toggled_on
	_log("Auto-reveal: %s" % ("enabled" if toggled_on else "disabled"))

func _on_threshold_changed(new_val: float) -> void:
	if _demo_zone != null:
		_demo_zone.auto_reveal_threshold = new_val / 100.0
	scratch_card_3d.total_auto_reveal_threshold = new_val / 100.0
	_update_threshold_label(new_val)

func _on_valid_threshold_changed(new_val: float) -> void:
	if _demo_zone != null:
		_demo_zone.valid_threshold = new_val / 100.0
		_update_valid_label(new_val)

func _update_threshold_label(val: float) -> void:
	if label_threshold != null:
		label_threshold.text = "Auto-Reveal Threshold: %d%%" % int(val)

func _update_valid_label(val: float) -> void:
	if label_valid != null:
		label_valid.text = "Valid Threshold: %d%%" % int(val)

func _on_total_scratched(pct: float) -> void:
	progress_bar.value = pct * 100.0
	label_status.text = "Scratched: %.1f%%" % (pct * 100.0)

func _on_zone_cleared(zone: ScratchZone) -> void:
	_log("Zone cleared: %s" % zone.id)

func _on_card_completed() -> void:
	scratch_card_3d.reveal_all()
	_log("Card fully uncovered.")

func _log(text: String) -> void:
	if log_label != null:
		log_label.append_text(text + "\n")


