@tool
class_name ScratchTextureGenerator
extends RefCounted

static var _brush_cache: Dictionary = {}

static func create_default_brush_texture(radius: float = 32.0, hardness: float = 1.0) -> ImageTexture:
	var key := Vector2(snappedf(radius, 0.5), snappedf(hardness, 0.01))
	if _brush_cache.has(key):
		return _brush_cache[key]
		
	var r_int := int(ceil(radius))
	var size := r_int * 2
	if size <= 0:
		size = 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var inner_radius := radius * clampf(hardness, 0.0, 1.0)
	
	for y in range(size):
		for x in range(size):
			var pixel_center := Vector2(float(x) + 0.5, float(y) + 0.5)
			var dist := pixel_center.distance_to(center)
			if dist <= radius:
				var alpha := 1.0
				if hardness < 0.99 and dist > inner_radius and radius > inner_radius:
					alpha = 1.0 - smoothstep(inner_radius, radius, dist)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	var tex := ImageTexture.create_from_image(img)
	_brush_cache[key] = tex
	return tex

static func clear_brush_cache() -> void:
	_brush_cache.clear()
