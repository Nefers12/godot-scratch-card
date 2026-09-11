@tool
class_name ScratchCardBase
extends Node

const ScratchBrush = preload("res://addons/godot_scratch_card/resources/scratch_brush.gd")
const ScratchZone = preload("res://addons/godot_scratch_card/resources/scratch_zone.gd")
const ScratchCalculator = preload("res://addons/godot_scratch_card/scripts/scratch_calculator.gd")
const ScratchTextureGenerator = preload("res://addons/godot_scratch_card/scripts/texture_generator.gd")

signal total_scratched_updated(percentage: float)
signal card_validated()
signal zone_scratched(zone: ScratchZone, percentage: float)
signal zone_cleared(zone: ScratchZone)
signal card_completed()

@export var brush: ScratchBrush = null
@export var zones: Array[ScratchZone] = []
@export var viewport_size: Vector2i = Vector2i(512, 512):
	set(val):
		viewport_size = val.clamp(Vector2i(1, 1), Vector2i(16384, 16384))
		if sub_viewport != null:
			sub_viewport.size = viewport_size
			reset_card()

@export_range(0, 255) var scratch_threshold: int = 128
@export var update_interval_seconds: float = 0.08
@export var enable_card_validation: bool = true
@export_range(0.0, 1.0) var total_valid_threshold: float = 0.30
@export var enable_card_auto_reveal: bool = false
@export_range(0.0, 1.0) var total_auto_reveal_threshold: float = 0.85
@export_range(1, 4) var sample_step: int = 1

var sub_viewport: SubViewport = null
var mask_canvas: Node2D = null
var _calculator: ScratchCalculator = null
var _last_uv: Vector2 = Vector2(-1, -1)
var _update_timer: float = 0.0
var _strokes_to_draw: Array[Dictionary] = []
var _total_percentage: float = 0.0
var _is_card_validated: bool = false
var _is_card_completed: bool = false
var _is_dirty: bool = false

static func get_or_create(parent: Node) -> ScratchCardBase:
	var existing := parent.get_node_or_null("ScratchCardBase")
	if existing is ScratchCardBase:
		return existing
	var base := ScratchCardBase.new()
	base.name = "ScratchCardBase"
	parent.add_child(base)
	return base

func connect_forwarding(target: Node) -> void:
	if not total_scratched_updated.is_connected(target.total_scratched_updated.emit):
		total_scratched_updated.connect(target.total_scratched_updated.emit)
		card_validated.connect(target.card_validated.emit)
		zone_scratched.connect(target.zone_scratched.emit)
		zone_cleared.connect(target.zone_cleared.emit)
		card_completed.connect(target.card_completed.emit)

func sync_config(
	p_brush: ScratchBrush,
	p_zones: Array[ScratchZone],
	p_threshold: int,
	p_auto_reveal: bool,
	p_auto_reveal_threshold: float,
	p_sample_step: int
) -> void:
	brush = p_brush if p_brush != null else ScratchBrush.new()
	zones = p_zones
	scratch_threshold = p_threshold
	enable_card_auto_reveal = p_auto_reveal
	total_auto_reveal_threshold = p_auto_reveal_threshold
	sample_step = p_sample_step

static func validate_custom_material(mat: ShaderMaterial, context_name: String = "ScratchCard") -> void:
	if mat == null or mat.shader == null:
		return
	var code := mat.shader.code
	if not code.is_empty() and not code.contains("mask_texture"):
		push_warning("%s: custom_material shader is missing required uniform 'mask_texture'." % context_name)

static func apply_shader_params(
	material: ShaderMaterial,
	top_color: Color,
	top_texture: Texture2D,
	reward_texture: Texture2D,
	mask_texture: Texture2D = null
) -> void:
	if material == null:
		return
	material.set_shader_parameter("top_color", top_color)
	material.set_shader_parameter("use_top_texture", top_texture != null)
	if top_texture != null:
		material.set_shader_parameter("top_texture", top_texture)
	if reward_texture != null:
		material.set_shader_parameter("reward_texture", reward_texture)
	if mask_texture != null:
		material.set_shader_parameter("mask_texture", mask_texture)

static func setup_material(
	custom_mat: ShaderMaterial,
	default_shader_path: String,
	top_color: Color,
	top_texture: Texture2D,
	reward_texture: Texture2D,
	mask_texture: Texture2D = null,
	context_name: String = "ScratchCard"
) -> ShaderMaterial:
	var mat: ShaderMaterial = null
	if custom_mat != null:
		validate_custom_material(custom_mat, context_name)
		mat = custom_mat
	else:
		if not ResourceLoader.exists(default_shader_path):
			push_error("%s: Failed to load shader resource at %s" % [context_name, default_shader_path])
			return null
		var shader: Shader = load(default_shader_path)
		if shader == null:
			push_error("%s: Failed to load shader resource at %s" % [context_name, default_shader_path])
			return null
		mat = ShaderMaterial.new()
		mat.shader = shader

	apply_shader_params(mat, top_color, top_texture, reward_texture, mask_texture)
	return mat

func _ready() -> void:
	_ensure_brush()
	_calculator = ScratchCalculator.new()
	_setup_mask_viewport()

func _ensure_brush() -> void:
	if brush == null:
		brush = ScratchBrush.new()

class MaskCanvas extends Node2D:
	var card_ref: ScratchCardBase = null

	func _draw() -> void:
		if card_ref != null and is_instance_valid(card_ref):
			card_ref._render_mask_strokes(self)

func _setup_mask_viewport() -> void:
	if sub_viewport != null:
		return

	sub_viewport = SubViewport.new()
	sub_viewport.name = "MaskSubViewport"
	sub_viewport.size = viewport_size
	sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.transparent_bg = false
	add_child(sub_viewport)
	
	var canvas := MaskCanvas.new()
	canvas.name = "MaskCanvas"
	canvas.card_ref = self
	mask_canvas = canvas
	sub_viewport.add_child(mask_canvas)
	
	if is_inside_tree():
		await get_tree().process_frame
	reset_card()

func _exit_tree() -> void:
	if sub_viewport != null and is_instance_valid(sub_viewport):
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if sub_viewport != null and is_instance_valid(sub_viewport):
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _request_redraw() -> void:
	_is_dirty = true
	if mask_canvas != null and is_instance_valid(mask_canvas):
		mask_canvas.queue_redraw()

func _render_mask_strokes(canvas: Node2D) -> void:
	if not is_inside_tree():
		return
	_ensure_brush()
	for stroke in _strokes_to_draw:
		if stroke.has("restore_texture"):
			var res_tex: Texture2D = stroke["restore_texture"]
			if res_tex != null:
				canvas.draw_texture_rect(res_tex, Rect2(Vector2.ZERO, Vector2(viewport_size)), false)
			continue

		if stroke.has("rect"):
			var rect: Rect2 = stroke["rect"]
			var color: Color = stroke.get("color", Color.WHITE)
			canvas.draw_rect(rect, color, true)
			continue
			
		var from_pos: Vector2 = stroke["from"]
		var to_pos: Vector2 = stroke["to"]
		var stroke_radius: float = stroke["radius"]
		var stroke_color: Color = stroke["color"]
		var draw_color := stroke_color
		
		if brush != null:
			draw_color.a *= brush.opacity
			
		var active_tex: Texture2D = null
		if brush != null:
			if brush.custom_texture != null:
				active_tex = brush.custom_texture
			elif brush.hardness < 0.99:
				active_tex = ScratchTextureGenerator.create_default_brush_texture(stroke_radius, brush.hardness)
				
		if active_tex != null:
			var tex_size := active_tex.get_size()
			var scale_factor := (stroke_radius * 2.0) / maxf(tex_size.x, tex_size.y)
			var draw_size := tex_size * scale_factor
			var dist := from_pos.distance_to(to_pos)
			var step_dist := maxf(1.0, stroke_radius * 0.08)
			var steps := int(ceil(dist / step_dist)) if dist >= 0.5 else 0
			for i in range(steps + 1):
				var t := float(i) / float(steps) if steps > 0 else 0.0
				var pos := from_pos.lerp(to_pos, t)
				var rect_pos := pos - (draw_size * 0.5)
				canvas.draw_texture_rect(active_tex, Rect2(rect_pos, draw_size), false, draw_color)
		else:
			if from_pos.distance_to(to_pos) < 0.5:
				canvas.draw_circle(to_pos, stroke_radius, draw_color)
			else:
				canvas.draw_line(from_pos, to_pos, draw_color, stroke_radius * 2.0, true)
				canvas.draw_circle(from_pos, stroke_radius, draw_color)
				canvas.draw_circle(to_pos, stroke_radius, draw_color)
			
	_strokes_to_draw.clear()

func scratch_at_uv(uv: Vector2) -> void:
	_ensure_brush()
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	var pixel_pos := uv * Vector2(viewport_size)
	var b_radius := brush.radius if brush != null else 16.0
	var b_color := brush.stroke_color if brush != null else Color.WHITE
	
	if _last_uv.x >= 0.0 and _last_uv.y >= 0.0:
		var last_pixel_pos := _last_uv * Vector2(viewport_size)
		_strokes_to_draw.append({
			"from": last_pixel_pos,
			"to": pixel_pos,
			"radius": b_radius,
			"color": b_color
		})
	else:
		_strokes_to_draw.append({
			"from": pixel_pos,
			"to": pixel_pos,
			"radius": b_radius,
			"color": b_color
		})
		
	_last_uv = uv
	_request_redraw()

func scratch_circle(uv: Vector2, radius_px: float = -1.0) -> void:
	_ensure_brush()
	var b_radius := brush.radius if brush != null else 16.0
	var b_color := brush.stroke_color if brush != null else Color.WHITE
	var active_radius := radius_px if radius_px > 0.0 else b_radius
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	var pixel_pos := uv * Vector2(viewport_size)
	_strokes_to_draw.append({
		"from": pixel_pos,
		"to": pixel_pos,
		"radius": active_radius,
		"color": b_color
	})
	_request_redraw()

func scratch_rect(uv_rect: Rect2) -> void:
	uv_rect = uv_rect.abs()
	var start_pixel := uv_rect.position.clamp(Vector2.ZERO, Vector2.ONE) * Vector2(viewport_size)
	var end_pixel := (uv_rect.position + uv_rect.size).clamp(Vector2.ZERO, Vector2.ONE) * Vector2(viewport_size)
	var rect_pixel := Rect2(start_pixel, end_pixel - start_pixel)
	_strokes_to_draw.append({
		"rect": rect_pixel,
		"color": Color.WHITE
	})
	_request_redraw()

func scratch_random(target_percentage: float = 0.5, stroke_count: int = 15) -> void:
	target_percentage = clampf(target_percentage, 0.0, 1.0)
	if target_percentage <= 0.0:
		return
	if target_percentage >= 0.99:
		reveal_all()
		return

	_ensure_brush()
	var b_color := brush.stroke_color if brush != null else Color.WHITE
	var actual_strokes := maxi(1, stroke_count)

	var vp_w := float(viewport_size.x)
	var vp_h := float(viewport_size.y)
	var total_area := vp_w * vp_h
	if total_area <= 0.0:
		return

	var needed_area := -log(1.0 - minf(target_percentage, 0.98)) * total_area
	var area_per_stroke := needed_area / float(actual_strokes)

	var avg_length := 0.3 * minf(vp_w, vp_h)
	var calculated_radius := clampf(area_per_stroke / (2.0 * avg_length), 4.0, minf(vp_w, vp_h) * 0.35)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(actual_strokes):
		var start_uv := Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.08, 0.92))
		var angle := rng.randf_range(0.0, TAU)
		var stroke_len := avg_length * rng.randf_range(0.7, 1.3)
		var offset := Vector2(cos(angle), sin(angle)) * (stroke_len / minf(vp_w, vp_h))
		var end_uv := (start_uv + offset).clamp(Vector2.ZERO, Vector2.ONE)

		var from_pixel := start_uv * Vector2(viewport_size)
		var to_pixel := end_uv * Vector2(viewport_size)
		var stroke_radius := calculated_radius * rng.randf_range(0.85, 1.15)

		_strokes_to_draw.append({
			"from": from_pixel,
			"to": to_pixel,
			"radius": stroke_radius,
			"color": b_color
		})
	_request_redraw()


func stop_scratching() -> void:
	_last_uv = Vector2(-1, -1)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if not _is_dirty:
		return

	_update_timer += delta
	if _update_timer >= update_interval_seconds:
		_update_timer = 0.0
		_is_dirty = false
		_recalculate_scratched_percentages()

func _recalculate_scratched_percentages() -> void:
	if sub_viewport == null or DisplayServer.get_name() == "headless":
		return
		
	var mask_tex := sub_viewport.get_texture()
	if mask_tex == null:
		return
		
	var img := mask_tex.get_image()
	if img == null or img.is_empty():
		return
		
	var full_rect := Rect2(0, 0, 1, 1)
	var prev_total := _total_percentage
	_total_percentage = _calculator.calculate_zone_percentage(img, full_rect, scratch_threshold, sample_step)
	
	if absf(_total_percentage - prev_total) > 0.0005 or _total_percentage == 1.0:
		total_scratched_updated.emit(_total_percentage)
		
	if enable_card_validation and not _is_card_validated and _total_percentage >= total_valid_threshold:
		_is_card_validated = true
		card_validated.emit()
		
	if enable_card_auto_reveal and not _is_card_completed and _total_percentage >= total_auto_reveal_threshold:
		reveal_all()
	
	var all_cleared := true
	for zone in zones:
		var zone_pct: float = _calculator.calculate_zone_percentage(img, zone.uv_rect, scratch_threshold, sample_step)
		var prev_cleared := zone.is_cleared
		var prev_zone_pct := zone.scratched_percentage
		
		zone.update_percentage(zone_pct)
		
		if absf(zone_pct - prev_zone_pct) > 0.0005 or zone_pct == 1.0:
			zone_scratched.emit(zone, zone_pct)
		
		if not prev_cleared and zone.is_cleared:
			reveal_zone(zone)
			zone_cleared.emit(zone)
			
		if not zone.is_cleared:
			all_cleared = false
			
	if not _is_card_completed and all_cleared and zones.size() > 0:
		_is_card_completed = true
		card_completed.emit()

func reveal_zone(zone: ScratchZone) -> void:
	var norm_rect := zone.uv_rect.abs()
	var start_pixel := norm_rect.position.clamp(Vector2.ZERO, Vector2.ONE) * Vector2(viewport_size)
	var end_pixel := (norm_rect.position + norm_rect.size).clamp(Vector2.ZERO, Vector2.ONE) * Vector2(viewport_size)
	var rect_pixel := Rect2(start_pixel, end_pixel - start_pixel)
	_strokes_to_draw.append({
		"rect": rect_pixel,
		"color": Color.WHITE
	})
	_request_redraw()
	var was_cleared := zone.is_cleared
	zone.update_percentage(1.0)
	if not was_cleared:
		zone.is_cleared = true
		zone_cleared.emit(zone)

func reveal_all() -> void:
	_strokes_to_draw.append({
		"rect": Rect2(Vector2.ZERO, Vector2(viewport_size)),
		"color": Color.WHITE
	})
	_request_redraw()
	for z in zones:
		var was_cleared := z.is_cleared
		z.update_percentage(1.0)
		if not was_cleared:
			z.is_cleared = true
			zone_cleared.emit(z)
	_total_percentage = 1.0
	total_scratched_updated.emit(1.0)
	if not _is_card_validated:
		_is_card_validated = true
		card_validated.emit()
	if not _is_card_completed:
		_is_card_completed = true
		card_completed.emit()

func reset_card() -> void:
	_strokes_to_draw.clear()
	_last_uv = Vector2(-1, -1)
	_is_card_validated = false
	_is_card_completed = false
	_total_percentage = 0.0
	
	for z in zones:
		z.reset()
		
	if sub_viewport != null:
		sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		
	_strokes_to_draw.append({
		"rect": Rect2(Vector2.ZERO, Vector2(viewport_size)),
		"color": Color.BLACK
	})
	_request_redraw()
	total_scratched_updated.emit(0.0)

func save_state() -> Dictionary:
	var mask_png_data := PackedByteArray()
	if sub_viewport != null and DisplayServer.get_name() != "headless":
		var tex := sub_viewport.get_texture()
		if tex != null:
			var img := tex.get_image()
			if img != null and not img.is_empty():
				mask_png_data = img.save_png_to_buffer()
				
	var zones_state: Array[Dictionary] = []
	for z in zones:
		zones_state.append({
			"id": z.id,
			"scratched_percentage": z.scratched_percentage,
			"is_validated": z.is_validated,
			"is_cleared": z.is_cleared
		})
		
	return {
		"viewport_size": viewport_size,
		"total_percentage": _total_percentage,
		"is_card_validated": _is_card_validated,
		"is_card_completed": _is_card_completed,
		"zones": zones_state,
		"mask_png": mask_png_data
	}

func restore_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.has("viewport_size"):
		var sz = data["viewport_size"]
		if sz is Vector2i:
			viewport_size = sz
		elif sz is Array and sz.size() == 2:
			viewport_size = Vector2i(int(sz[0]), int(sz[1]))
		if sub_viewport != null:
			sub_viewport.size = viewport_size
				
	if data.has("total_percentage"):
		_total_percentage = float(data["total_percentage"])
		total_scratched_updated.emit(_total_percentage)
	if data.has("is_card_validated"):
		_is_card_validated = bool(data["is_card_validated"])
	if data.has("is_card_completed"):
		_is_card_completed = bool(data["is_card_completed"])
		
	if data.has("zones"):
		var zones_data: Array = data["zones"]
		for z_dict in zones_data:
			var z_id: String = z_dict.get("id", "")
			for z in zones:
				if z.id == z_id:
					z.scratched_percentage = float(z_dict.get("scratched_percentage", 0.0))
					z.is_validated = bool(z_dict.get("is_validated", false))
					z.is_cleared = bool(z_dict.get("is_cleared", false))
					z.percentage_changed.emit(z.scratched_percentage)
					break
					
	if data.has("mask_png"):
		var png_data: PackedByteArray = data["mask_png"]
		if not png_data.is_empty():
			var img := Image.new()
			var err := img.load_png_from_buffer(png_data)
			if err == OK:
				_strokes_to_draw.clear()
				_last_uv = Vector2(-1, -1)
				var tex := ImageTexture.create_from_image(img)
				if sub_viewport != null:
					sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
				_strokes_to_draw.append({
					"restore_texture": tex
				})
				_request_redraw()
