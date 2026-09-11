@tool
@icon("res://addons/godot_scratch_card/icon.png")
class_name ScratchCard2D
extends Control

const ScratchBrush = preload("res://addons/godot_scratch_card/resources/scratch_brush.gd")
const ScratchZone = preload("res://addons/godot_scratch_card/resources/scratch_zone.gd")
const ScratchCardBase = preload("res://addons/godot_scratch_card/scripts/scratch_card_base.gd")

signal total_scratched_updated(percentage: float)
signal card_validated()
signal zone_scratched(zone: ScratchZone, percentage: float)
signal zone_cleared(zone: ScratchZone)
signal card_completed()

@export var brush: ScratchBrush = null:
	set(val):
		brush = val
		_sync_base_card()
			
@export var zones: Array[ScratchZone] = []:
	set(val):
		zones = val
		_sync_base_card()

@export_range(0, 255) var scratch_threshold: int = 128:
	set(val):
		scratch_threshold = val
		_sync_base_card()

@export var top_color: Color = Color(0.7, 0.73, 0.78, 1.0):
	set(val):
		top_color = val
		if _material != null:
			_material.set_shader_parameter("top_color", top_color)

@export var top_texture: Texture2D = null:
	set(val):
		top_texture = val
		if _material != null:
			_material.set_shader_parameter("use_top_texture", top_texture != null)
			if top_texture != null:
				_material.set_shader_parameter("top_texture", top_texture)

@export var reward_texture: Texture2D = null:
	set(val):
		reward_texture = val
		if _material != null and reward_texture != null:
			_material.set_shader_parameter("reward_texture", reward_texture)

@export var custom_material: ShaderMaterial = null:
	set(val):
		custom_material = val
		ScratchCardBase.validate_custom_material(val, "ScratchCard2D")
		if is_node_ready():
			_update_material()

@export var enable_card_auto_reveal: bool = false:
	set(val):
		enable_card_auto_reveal = val
		_sync_base_card()

@export_range(0.0, 1.0) var total_auto_reveal_threshold: float = 0.85:
	set(val):
		total_auto_reveal_threshold = val
		_sync_base_card()

@export_range(1, 4) var sample_step: int = 1:
	set(val):
		sample_step = val
		_sync_base_card()

var _base_card: ScratchCardBase = null
var _material: ShaderMaterial = null
var _is_pressed: bool = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	
	_base_card = ScratchCardBase.get_or_create(self)
	_base_card.connect_forwarding(self)
	_sync_base_card()
	
	_update_material()
	
	await get_tree().process_frame
	if _base_card != null and _base_card.sub_viewport != null and _material != null:
		_material.set_shader_parameter("mask_texture", _base_card.sub_viewport.get_texture())
		queue_redraw()

func _update_material() -> void:
	var mask_tex: Texture2D = _base_card.sub_viewport.get_texture() if _base_card != null and _base_card.sub_viewport != null else null
	var mat := ScratchCardBase.setup_material(
		custom_material,
		"res://addons/godot_scratch_card/shaders/scratch_2d.gdshader",
		top_color,
		top_texture,
		reward_texture,
		mask_tex,
		"ScratchCard2D"
	)
	if mat != null:
		_material = mat
		material = _material
	queue_redraw()

func _exit_tree() -> void:
	if _base_card != null and is_instance_valid(_base_card):
		_base_card.queue_free()
		_base_card = null

func _sync_base_card() -> void:
	if _base_card != null:
		_base_card.sync_config(brush, zones, scratch_threshold, enable_card_auto_reveal, total_auto_reveal_threshold, sample_step)

func get_base_card() -> ScratchCardBase:
	return _base_card

func _draw() -> void:
	if size.x > 0.0 and size.y > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
		
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_pressed = mb.pressed
			if _is_pressed:
				_handle_scratch_pos(mb.position)
			else:
				_base_card.stop_scratching()
				
	elif event is InputEventMouseMotion and _is_pressed:
		var mm := event as InputEventMouseMotion
		_handle_scratch_pos(mm.position)
		
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_is_pressed = st.pressed
		if _is_pressed:
			_handle_scratch_pos(st.position)
		else:
			_base_card.stop_scratching()
			
	elif event is InputEventScreenDrag and _is_pressed:
		var sd := event as InputEventScreenDrag
		_handle_scratch_pos(sd.position)

func _handle_scratch_pos(local_pos: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var uv := local_pos / size
	_base_card.scratch_at_uv(uv)

func reset_card() -> void:
	if _base_card != null:
		_base_card.reset_card()

func reveal_all() -> void:
	if _base_card != null:
		_base_card.reveal_all()

func reveal_zone(zone: ScratchZone) -> void:
	if _base_card != null:
		_base_card.reveal_zone(zone)

func scratch_circle(uv: Vector2, radius_px: float = -1.0) -> void:
	if _base_card != null:
		_base_card.scratch_circle(uv, radius_px)

func scratch_rect(uv_rect: Rect2) -> void:
	if _base_card != null:
		_base_card.scratch_rect(uv_rect)

func scratch_random(target_percentage: float = 0.5, stroke_count: int = 15) -> void:
	if _base_card != null:
		_base_card.scratch_random(target_percentage, stroke_count)

func save_state() -> Dictionary:
	if _base_card != null:
		return _base_card.save_state()
	return {}

func restore_state(data: Dictionary) -> void:
	if _base_card != null:
		_base_card.restore_state(data)


