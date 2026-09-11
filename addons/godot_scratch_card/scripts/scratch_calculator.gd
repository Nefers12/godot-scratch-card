class_name ScratchCalculator
extends RefCounted

var _rust_calculator: RefCounted = null

func _init() -> void:
	if ClassDB.class_exists("ScratchNativeCalculator"):
		_rust_calculator = ClassDB.instantiate("ScratchNativeCalculator")

func calculate_zone_percentage(image: Image, uv_rect: Rect2, threshold: int = 128, step: int = 1) -> float:
	if image == null:
		return 0.0
	uv_rect = uv_rect.abs()
	threshold = clampi(threshold, 0, 255)
		
	if _rust_calculator != null and _rust_calculator.has_method("calculate_zone_scratched_percentage"):
		var pct: float = _rust_calculator.call(
			"calculate_zone_scratched_percentage",
			image,
			threshold,
			uv_rect
		)
		return clampf(pct, 0.0, 1.0)
		
	return _calculate_gdscript(image, uv_rect, threshold, step)

func _calculate_gdscript(image: Image, uv_rect: Rect2, threshold: int, step: int = 1) -> float:
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
		
	var width := image.get_width()
	var height := image.get_height()
	if width == 0 or height == 0:
		return 0.0
		
	var start_x := clampi(int(clampf(uv_rect.position.x, 0.0, 1.0) * width), 0, width)
	var end_x := clampi(int(clampf(uv_rect.position.x + uv_rect.size.x, 0.0, 1.0) * width), 0, width)
	var start_y := clampi(int(clampf(uv_rect.position.y, 0.0, 1.0) * height), 0, height)
	var end_y := clampi(int(clampf(uv_rect.position.y + uv_rect.size.y, 0.0, 1.0) * height), 0, height)
	
	if end_x <= start_x or end_y <= start_y:
		return 0.0
		
	var data := image.get_data()
	if data.is_empty():
		return 0.0
		
	var actual_step := maxi(1, step)
	var byte_step := actual_step * 4
	var scratched_count := 0
	var total_sampled := 0

	# Full-image fast path
	if start_x == 0 and end_x == width and start_y == 0 and end_y == height:
		total_sampled = ceili(float(data.size()) / float(byte_step))
		for idx in range(0, data.size(), byte_step):
			if data[idx] >= threshold:
				scratched_count += 1
	else:
		var row_stride := width * 4
		var row_bytes := (end_x - start_x) * 4
		var x_offset := start_x * 4
		var rows := ceili(float(end_y - start_y) / float(actual_step))
		var cols := ceili(float(row_bytes) / float(byte_step))
		total_sampled = rows * cols

		for y in range(start_y, end_y, actual_step):
			var row_start := y * row_stride + x_offset
			for idx in range(row_start, row_start + row_bytes, byte_step):
				if data[idx] >= threshold:
					scratched_count += 1
					
	return float(scratched_count) / float(maxi(1, total_sampled))

