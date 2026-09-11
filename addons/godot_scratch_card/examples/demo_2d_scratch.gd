extends Control

@onready var scratch_card: ScratchCard2D = $MarginContainer/HBoxContainer/CardContainer/ScratchCard2D
@onready var progress_bar: ProgressBar = $MarginContainer/HBoxContainer/Panel/VBoxContainer/ProgressBar
@onready var label_status: Label = $MarginContainer/HBoxContainer/Panel/VBoxContainer/LabelStatus
@onready var chk_auto_reveal: CheckBox = $MarginContainer/HBoxContainer/Panel/VBoxContainer/ChkAutoReveal
@onready var slider_threshold: HSlider = $MarginContainer/HBoxContainer/Panel/VBoxContainer/HBoxSlider/SliderThreshold
@onready var label_threshold: Label = $MarginContainer/HBoxContainer/Panel/VBoxContainer/HBoxSlider/LabelThreshold
@onready var slider_valid: HSlider = $MarginContainer/HBoxContainer/Panel/VBoxContainer/HBoxValidSlider/SliderValid
@onready var label_valid: Label = $MarginContainer/HBoxContainer/Panel/VBoxContainer/HBoxValidSlider/LabelValid
@onready var btn_reset: Button = $MarginContainer/HBoxContainer/Panel/VBoxContainer/BtnReset
@onready var btn_reveal: Button = $MarginContainer/HBoxContainer/Panel/VBoxContainer/BtnReveal
@onready var btn_switch_3d: Button = $MarginContainer/HBoxContainer/Panel/VBoxContainer/BtnSwitch3D
@onready var btn_benchmark: Button = $MarginContainer/HBoxContainer/Panel/VBoxContainer/BtnBenchmark
@onready var log_label: RichTextLabel = $MarginContainer/HBoxContainer/Panel/VBoxContainer/LogLabel

var _demo_zone: ScratchZone = null

func _ready() -> void:
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_reveal.pressed.connect(_on_reveal_pressed)
	btn_switch_3d.pressed.connect(_on_switch_3d_pressed)
	if btn_benchmark != null:
		btn_benchmark.pressed.connect(_on_benchmark_pressed)
	
	_demo_zone = ScratchZone.new()
	_demo_zone.id = "Jackpot Zone"
	_demo_zone.uv_rect = Rect2(0.15, 0.20, 0.70, 0.60)
	_demo_zone.enable_auto_reveal = true
	_demo_zone.auto_reveal_threshold = 0.60
	_demo_zone.enable_validation = true
	_demo_zone.valid_threshold = 0.25
	
	_demo_zone.zone_validated.connect(func(): _log("Zone '%s' now valid (>=%d%% scratched)!" % [_demo_zone.id, int(_demo_zone.valid_threshold * 100)]))
	
	scratch_card.zones = [_demo_zone]
	
	chk_auto_reveal.toggled.connect(_on_auto_reveal_toggled)
	slider_threshold.value_changed.connect(_on_threshold_changed)
	slider_valid.value_changed.connect(_on_valid_threshold_changed)
	
	chk_auto_reveal.button_pressed = _demo_zone.enable_auto_reveal
	slider_threshold.value = _demo_zone.auto_reveal_threshold * 100.0
	slider_valid.value = _demo_zone.valid_threshold * 100.0
	
	scratch_card.enable_card_auto_reveal = _demo_zone.enable_auto_reveal
	scratch_card.total_auto_reveal_threshold = _demo_zone.auto_reveal_threshold

	_update_threshold_label(slider_threshold.value)
	_update_valid_label(slider_valid.value)
	
	scratch_card.total_scratched_updated.connect(_on_total_scratched)
	scratch_card.zone_cleared.connect(_on_zone_cleared)
	scratch_card.card_completed.connect(_on_card_completed)
	
	_log("2D demo ready.")

func _on_auto_reveal_toggled(toggled_on: bool) -> void:
	if _demo_zone != null:
		_demo_zone.enable_auto_reveal = toggled_on
	scratch_card.enable_card_auto_reveal = toggled_on
	_log("Auto-reveal: %s" % ("enabled" if toggled_on else "disabled"))

func _on_threshold_changed(new_val: float) -> void:
	if _demo_zone != null:
		_demo_zone.auto_reveal_threshold = new_val / 100.0
	scratch_card.total_auto_reveal_threshold = new_val / 100.0
	_update_threshold_label(new_val)

func _on_valid_threshold_changed(new_val: float) -> void:
	if _demo_zone != null:
		_demo_zone.valid_threshold = new_val / 100.0
		_update_valid_label(new_val)

func _update_threshold_label(val: float) -> void:
	label_threshold.text = "Auto-Reveal Threshold: %d%%" % int(val)

func _update_valid_label(val: float) -> void:
	label_valid.text = "Valid Threshold: %d%%" % int(val)

func _on_total_scratched(pct: float) -> void:
	progress_bar.value = pct * 100.0
	label_status.text = "Scratched: %.1f%%" % (pct * 100.0)

func _on_zone_cleared(zone: ScratchZone) -> void:
	_log("Zone cleared: %s" % zone.id)

func _on_card_completed() -> void:
	scratch_card.reveal_all()
	_log("Card fully uncovered.")

func _on_reset_pressed() -> void:
	scratch_card.reset_card()
	_log("Card reset.")

func _on_reveal_pressed() -> void:
	scratch_card.reveal_all()
	_log("Revealed all.")

func _on_switch_3d_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/godot_scratch_card/examples/demo_3d_scratch.tscn")

func _on_benchmark_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/godot_scratch_card/examples/demo_benchmark_rust_vs_gdscript.tscn")

func _log(text: String) -> void:
	if log_label != null:
		log_label.append_text(text + "\n")

