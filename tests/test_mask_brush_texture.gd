extends GutTest

const ScratchCalculator = preload("res://addons/godot_scratch_card/scripts/scratch_calculator.gd")
const ScratchTextureGenerator = preload("res://addons/godot_scratch_card/scripts/texture_generator.gd")

func test_mask_brush_texture_is_white_with_alpha() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.0, 0.0, 1.0, 1.0))
	img.set_pixel(1, 0, Color(0.2, 0.4, 0.1, 0.5))
	img.set_pixel(0, 1, Color(1.0, 0.0, 0.0, 0.0))
	img.set_pixel(1, 1, Color(0.0, 0.0, 0.0, 1.0))
	var src := ImageTexture.create_from_image(img)

	var out := ScratchTextureGenerator.create_mask_brush_texture(src)
	assert_not_null(out, "converted texture")
	var res := out.get_image()
	assert_eq(res.get_pixel(0, 0).r8, 255, "opaque blue stamp -> R is 255")
	assert_eq(res.get_pixel(0, 0).a8, 255, "alpha kept (opaque)")
	assert_eq(res.get_pixel(1, 0).r8, 255, "semi-transparent -> R is 255")
	assert_almost_eq(res.get_pixel(1, 0).a, 0.5, 0.01, "alpha kept (semi-transparent)")
	assert_eq(res.get_pixel(0, 1).a8, 0, "alpha kept (transparent)")
	assert_eq(res.get_pixel(1, 1).r8, 255, "black stamp -> R is 255")

func test_mask_brush_texture_is_cached() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 1, 1))
	var src := ImageTexture.create_from_image(img)
	var a := ScratchTextureGenerator.create_mask_brush_texture(src)
	var b := ScratchTextureGenerator.create_mask_brush_texture(src)
	assert_same(a, b, "same source returns cached texture")
	assert_null(ScratchTextureGenerator.create_mask_brush_texture(null), "null source")

func test_colored_stamp_counts_as_scratched() -> void:
	var stamp := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	stamp.fill(Color(0.0, 0.0, 1.0, 1.0))
	var tex := ScratchTextureGenerator.create_mask_brush_texture(ImageTexture.create_from_image(stamp))
	var calc := ScratchCalculator.new()
	assert_almost_eq(calc.calculate_zone_percentage(stamp, Rect2(0, 0, 1, 1), 128), 0.0, 0.001, "raw blue stamp is not counted")
	assert_almost_eq(calc.calculate_zone_percentage(tex.get_image(), Rect2(0, 0, 1, 1), 128), 1.0, 0.001, "converted stamp is counted")
