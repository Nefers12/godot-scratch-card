extends GutTest

const ScratchBrush = preload("res://addons/godot_scratch_card/resources/scratch_brush.gd")
const ScratchZone = preload("res://addons/godot_scratch_card/resources/scratch_zone.gd")
const ScratchCalculator = preload("res://addons/godot_scratch_card/scripts/scratch_calculator.gd")
const ScratchCardBase = preload("res://addons/godot_scratch_card/scripts/scratch_card_base.gd")

func test_null_image() -> void:
	var calc := ScratchCalculator.new()
	assert_almost_eq(calc.calculate_zone_percentage(null, Rect2(0, 0, 1, 1)), 0.0, 0.001, "null image")

func test_solid_images() -> void:
	var calc := ScratchCalculator.new()
	var black := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	black.fill(Color(0, 0, 0, 1))
	assert_almost_eq(calc.calculate_zone_percentage(black, Rect2(0, 0, 1, 1)), 0.0, 0.001, "black image")

	var white := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	white.fill(Color(1, 1, 1, 1))
	assert_almost_eq(calc.calculate_zone_percentage(white, Rect2(0, 0, 1, 1)), 1.0, 0.001, "white image")

func test_half_scratched_coverage() -> void:
	var calc := ScratchCalculator.new()
	var img := _create_half_image(100, 100)
	assert_almost_eq(calc.calculate_zone_percentage(img, Rect2(0, 0, 1, 1)), 0.5, 0.001, "half scratched")

func test_sub_rect_calculation() -> void:
	var calc := ScratchCalculator.new()
	var img := _create_half_image(100, 100)
	assert_almost_eq(calc.calculate_zone_percentage(img, Rect2(0.0, 0.0, 0.5, 1.0)), 1.0, 0.001, "left half")
	assert_almost_eq(calc.calculate_zone_percentage(img, Rect2(0.5, 0.0, 0.5, 1.0)), 0.0, 0.001, "right half")

func test_threshold_separation() -> void:
	var calc := ScratchCalculator.new()
	var gray := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	gray.fill(Color(100.0 / 255.0, 0, 0, 1))
	assert_almost_eq(calc.calculate_zone_percentage(gray, Rect2(0, 0, 1, 1), 50), 1.0, 0.001, "low threshold")
	assert_almost_eq(calc.calculate_zone_percentage(gray, Rect2(0, 0, 1, 1), 150), 0.0, 0.001, "high threshold")

func test_gdscript_fallback() -> void:
	var calc := ScratchCalculator.new()
	var img := _create_half_image(100, 100)
	var pct := calc._calculate_gdscript(img, Rect2(0.0, 0.0, 0.5, 1.0), 128)
	assert_almost_eq(pct, 1.0, 0.001, "gdscript fallback")

func test_state_serialization() -> void:
	var card: ScratchCardBase = autofree(ScratchCardBase.new())
	var zone := ScratchZone.new()
	zone.id = "test_zone"
	zone.scratched_percentage = 0.75
	zone.is_cleared = true
	zone.is_validated = true
	card.zones.append(zone)
	card._total_percentage = 0.42
	card._is_card_validated = true

	var state: Dictionary = card.save_state()
	assert_true(state.has("viewport_size") and state.has("zones") and state.has("mask_png"), "save_state keys")
	assert_true(state["viewport_size"] is Vector2i, "viewport_size is Vector2i")

	var restored: ScratchCardBase = autofree(ScratchCardBase.new())
	var restore_zone := ScratchZone.new()
	restore_zone.id = "test_zone"
	restored.zones.append(restore_zone)
	restored.restore_state(state)

	assert_almost_eq(restored._total_percentage, 0.42, 0.001, "restored total percentage")
	assert_true(restore_zone.is_cleared and restore_zone.is_validated, "restored zone flags")
	assert_almost_eq(restore_zone.scratched_percentage, 0.75, 0.001, "restored zone percentage")
	assert_eq(restored.viewport_size, card.viewport_size, "restored viewport_size Vector2i")

	var legacy_state := {
		"viewport_size": [256, 256],
		"total_percentage": 0.10,
		"zones": [],
		"mask_png": PackedByteArray()
	}
	var legacy_restored: ScratchCardBase = autofree(ScratchCardBase.new())
	legacy_restored.restore_state(legacy_state)
	assert_eq(legacy_restored.viewport_size, Vector2i(256, 256), "restore legacy viewport_size array")

func test_png_roundtrip() -> void:
	var calc := ScratchCalculator.new()
	var img := _create_half_image(100, 100)
	var buffer := img.save_png_to_buffer()

	var decoded := Image.new()
	var err := decoded.load_png_from_buffer(buffer)
	assert_eq(err, OK, "load png buffer")
	assert_almost_eq(calc.calculate_zone_percentage(decoded, Rect2(0, 0, 1, 1)), 0.5, 0.001, "decoded percentage")

func test_null_brush_initialization() -> void:
	var card: ScratchCardBase = autofree(ScratchCardBase.new())
	card.brush = null
	card._setup_mask_viewport()
	card.scratch_at_uv(Vector2(0.5, 0.5))
	assert_not_null(card.brush, "auto-instantiated brush")

func test_scratch_rect_and_reveal_zone() -> void:
	var card: ScratchCardBase = autofree(ScratchCardBase.new())
	card.viewport_size = Vector2i(100, 100)
	var zone := ScratchZone.new()
	zone.id = "rect_zone"
	zone.uv_rect = Rect2(0.2, 0.2, 0.4, 0.4)
	card.zones.append(zone)

	card.scratch_rect(Rect2(0.1, 0.1, 0.3, 0.3))
	assert_gt(card._strokes_to_draw.size(), 0, "scratch_rect queued stroke")
	var stroke: Dictionary = card._strokes_to_draw[-1]
	assert_true(stroke.has("rect"), "stroke has rect key")
	assert_true(stroke["rect"] is Rect2, "stroke rect is Rect2")

	card.reveal_zone(zone)
	assert_true(card._strokes_to_draw[-1].has("rect"), "reveal_zone queued rect stroke")
	assert_almost_eq(zone.scratched_percentage, 1.0, 0.001, "reveal_zone set 100% percentage")

func test_scratch_random() -> void:
	var card: ScratchCardBase = autofree(ScratchCardBase.new())
	card.viewport_size = Vector2i(200, 200)

	card.scratch_random(0.0, 10)
	assert_true(card._strokes_to_draw.is_empty(), "scratch_random 0.0 queued nothing")

	card.scratch_random(0.5, 5)
	assert_eq(card._strokes_to_draw.size(), 5, "scratch_random queued 5 strokes")
	for s in card._strokes_to_draw:
		assert_true(s.has("radius") and s["radius"] > 0.0, "stroke has positive radius")

func _create_half_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	for y in range(h):
		for x in range(w / 2):
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	return img

func test_zone_reset_signal() -> void:
	var zone := ScratchZone.new()
	watch_signals(zone)
	zone.update_percentage(0.5)
	assert_signal_emitted_with_parameters(zone, "percentage_changed", [0.5])
	zone.reset()
	assert_almost_eq(zone.scratched_percentage, 0.0, 0.001, "zone reset percentage")
	assert_signal_emitted_with_parameters(zone, "percentage_changed", [0.0])

func test_negative_uv_rect_handling() -> void:
	var calc := ScratchCalculator.new()
	var img := _create_half_image(100, 100)
	var pct := calc.calculate_zone_percentage(img, Rect2(0.5, 1.0, -0.5, -1.0))
	assert_almost_eq(pct, 1.0, 0.001, "negative size rect normalized")

func test_reveal_zone_and_all_signals() -> void:
	var card: ScratchCardBase = autofree(ScratchCardBase.new())
	var zone := ScratchZone.new()
	zone.id = "sig_zone"
	card.zones.append(zone)
	watch_signals(card)
	watch_signals(zone)

	card.reveal_zone(zone)
	assert_signal_emitted(zone, "zone_cleared")
	assert_signal_emitted_with_parameters(card, "zone_cleared", [zone])
	assert_true(zone.is_cleared)

	zone.reset()
	card.reveal_all()
	assert_signal_emitted(card, "card_completed")
	assert_almost_eq(card._total_percentage, 1.0, 0.001)

func test_restore_state_signals() -> void:
	var card: ScratchCardBase = autofree(ScratchCardBase.new())
	var zone := ScratchZone.new()
	zone.id = "restored_zone"
	card.zones.append(zone)
	watch_signals(card)
	watch_signals(zone)

	var saved := {
		"total_percentage": 0.8,
		"zones": [{"id": "restored_zone", "scratched_percentage": 0.8, "is_validated": true, "is_cleared": false}],
	}
	card.restore_state(saved)
	assert_signal_emitted_with_parameters(card, "total_scratched_updated", [0.8])
	assert_signal_emitted_with_parameters(zone, "percentage_changed", [0.8])

func test_setup_material() -> void:
	var mat := ScratchCardBase.setup_material(
		null,
		"res://addons/godot_scratch_card/shaders/scratch_2d.gdshader",
		Color.WHITE,
		null,
		null
	)
	assert_not_null(mat, "successfully loaded default shader")
	assert_eq(mat.get_shader_parameter("top_color"), Color.WHITE)

	var null_mat := ScratchCardBase.setup_material(
		null,
		"res://non_existent_path.gdshader",
		Color.WHITE,
		null,
		null
	)
	assert_null(null_mat, "returns null on nonexistent shader without crashing")
	for e in get_errors():
		e.handled = true

func test_soft_brush_single_tap() -> void:
	var card: ScratchCardBase = autofree(ScratchCardBase.new())
	card.brush = ScratchBrush.new()
	card.brush.hardness = 0.5
	card._setup_mask_viewport()
	card.scratch_at_uv(Vector2(0.5, 0.5))
	var stroke: Dictionary = card._strokes_to_draw[-1]
	assert_true(stroke.has("from") and stroke.has("to"), "stroke has from and to keys")
	assert_eq(stroke["from"], stroke["to"], "from == to on single tap")


