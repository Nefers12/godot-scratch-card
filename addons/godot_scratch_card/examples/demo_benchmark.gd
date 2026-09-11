extends Control

const ScratchCalculator = preload("res://addons/godot_scratch_card/scripts/scratch_calculator.gd")

@onready var label_status: Label = $MarginContainer/VBoxContainer/LabelStatus
@onready var label_gdscript: Label = $MarginContainer/VBoxContainer/HBoxResults/PanelGDScript/VBox/LabelTimeGDScript
@onready var label_rust: Label = $MarginContainer/VBoxContainer/HBoxResults/PanelRust/VBox/LabelTimeRust
@onready var label_speedup: Label = $MarginContainer/VBoxContainer/LabelSpeedup
@onready var btn_benchmark: Button = $MarginContainer/VBoxContainer/HBoxButtons/BtnBenchmark
@onready var btn_demo_2d: Button = $MarginContainer/VBoxContainer/HBoxButtons/BtnDemo2D
@onready var btn_demo_3d: Button = $MarginContainer/VBoxContainer/HBoxButtons/BtnDemo3D
@onready var log_box: RichTextLabel = $MarginContainer/VBoxContainer/LogBox

var _test_image: Image = null
var _calculator: ScratchCalculator = null
var _rust_calc: RefCounted = null

func _ready() -> void:
	btn_benchmark.pressed.connect(_run_benchmark)
	btn_demo_2d.pressed.connect(func(): get_tree().change_scene_to_file("res://addons/godot_scratch_card/examples/demo_2d_scratch.tscn"))
	btn_demo_3d.pressed.connect(func(): get_tree().change_scene_to_file("res://addons/godot_scratch_card/examples/demo_3d_scratch.tscn"))
	
	_create_test_image()
	_calculator = ScratchCalculator.new()
	
	if ClassDB.class_exists("ScratchNativeCalculator"):
		_rust_calc = ClassDB.instantiate("ScratchNativeCalculator")
		label_status.text = "Rust GDExtension module loaded"
		label_status.add_theme_color_override("font_color", Color.FOREST_GREEN)
	else:
		label_status.text = "Rust module not loaded (GDScript fallback active)"
		label_status.add_theme_color_override("font_color", Color.DARK_ORANGE)
		btn_benchmark.disabled = true
		
	_log("Benchmark ready.")

func _create_test_image() -> void:
	_test_image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	_test_image.fill(Color(1, 1, 1, 1))

func _run_benchmark() -> void:
	if _test_image == null or _rust_calc == null or _calculator == null:
		return
		
	_log("\nRunning benchmark (100 iterations on 512x512 image)...")
	btn_benchmark.disabled = true
	await get_tree().process_frame
	
	var iterations := 100
	var uv_rect := Rect2(0.0, 0.0, 1.0, 1.0)
	
	var start_gd := Time.get_ticks_usec()
	var dummy_pct_gd := 0.0
	for i in range(iterations):
		dummy_pct_gd = _calculator._calculate_gdscript(_test_image, uv_rect, 128)
	var time_gd_usec := Time.get_ticks_usec() - start_gd
	var time_gd_ms := time_gd_usec / 1000.0
	
	var start_rust := Time.get_ticks_usec()
	var dummy_pct_rust := 0.0
	for i in range(iterations):
		dummy_pct_rust = _rust_calc.call(
			"calculate_zone_scratched_percentage",
			_test_image,
			128,
			uv_rect
		)
	var time_rust_usec := Time.get_ticks_usec() - start_rust
	var time_rust_ms := time_rust_usec / 1000.0
	
	label_gdscript.text = "%.2f ms" % time_gd_ms
	label_rust.text = "%.2f ms" % time_rust_ms
	
	var speedup := 1.0
	if time_rust_ms > 0.001:
		speedup = time_gd_ms / time_rust_ms
		
	label_speedup.text = "Speedup: %.1fx" % speedup
	
	_log("GDScript (100 runs): %.2f ms" % time_gd_ms)
	_log("Rust GDExtension (100 runs): %.2f ms" % time_rust_ms)
	_log("Speedup factor: %.1fx" % speedup)
	
	btn_benchmark.disabled = false

func _log(text: String) -> void:
	if log_box != null:
		log_box.append_text(text + "\n")


