@tool
@icon("res://addons/godot_scratch_card/icon.png")
class_name ScratchCard3D
extends Node3D

const ScratchBrush = preload("res://addons/godot_scratch_card/resources/scratch_brush.gd")
const ScratchZone = preload("res://addons/godot_scratch_card/resources/scratch_zone.gd")
const ScratchCardBase = preload("res://addons/godot_scratch_card/scripts/scratch_card_base.gd")

signal total_scratched_updated(percentage: float)
signal card_validated()
signal zone_scratched(zone: ScratchZone, percentage: float)
signal zone_cleared(zone: ScratchZone)
signal card_completed()

@export var mesh_instance: MeshInstance3D = null
@export var area_3d: Area3D = null
@export var auto_handle_input: bool = false

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
		ScratchCardBase.validate_custom_material(val, "ScratchCard3D")
		if is_node_ready():
			_update_material()

@export var mesh_size: Vector2 = Vector2(0.8, 0.5):
	set(val):
		mesh_size = val
		_update_mesh_size()

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
var _is_scratching: bool = false

func _ready() -> void:
	_base_card = ScratchCardBase.get_or_create(self)
	_base_card.connect_forwarding(self)
	_sync_base_card()
	
	_setup_mesh_and_area()
	_update_material()
		
	await get_tree().process_frame
	if _base_card != null and _base_card.sub_viewport != null and _material != null:
		_material.set_shader_parameter("mask_texture", _base_card.sub_viewport.get_texture())

func _update_material() -> void:
	var mask_tex: Texture2D = _base_card.sub_viewport.get_texture() if _base_card != null and _base_card.sub_viewport != null else null
	var mat := ScratchCardBase.setup_material(
		custom_material,
		"res://addons/godot_scratch_card/shaders/scratch_3d.gdshader",
		top_color,
		top_texture,
		reward_texture,
		mask_tex,
		"ScratchCard3D"
	)
	if mat != null:
		_material = mat
		if mesh_instance != null:
			mesh_instance.material_override = _material

func _exit_tree() -> void:
	if _base_card != null and is_instance_valid(_base_card):
		_base_card.queue_free()
		_base_card = null

func _sync_base_card() -> void:
	if _base_card != null:
		_base_card.sync_config(brush, zones, scratch_threshold, enable_card_auto_reveal, total_auto_reveal_threshold, sample_step)

func get_base_card() -> ScratchCardBase:
	return _base_card

func _setup_mesh_and_area() -> void:
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var quad := QuadMesh.new()
		quad.size = mesh_size
		mesh_instance.mesh = quad
		add_child(mesh_instance)
		
	if area_3d == null:
		area_3d = Area3D.new()
		area_3d.name = "Area3D"
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(mesh_size.x, mesh_size.y, 0.02)
		col.shape = shape
		area_3d.add_child(col)
		add_child(area_3d)

func _update_mesh_size() -> void:
	if mesh_instance != null and mesh_instance.mesh is QuadMesh:
		(mesh_instance.mesh as QuadMesh).size = mesh_size
	if area_3d != null:
		for child in area_3d.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				(child.shape as BoxShape3D).size = Vector3(mesh_size.x, mesh_size.y, 0.02)

func scratch_at_world_point(world_hit_point: Vector3) -> void:
	if mesh_instance == null:
		return
		
	var local_point := mesh_instance.global_transform.affine_inverse() * world_hit_point
	var u := 0.5
	var v := 0.5
	
	if mesh_instance.mesh != null:
		var aabb := mesh_instance.mesh.get_aabb()
		var size_x := aabb.size.x if aabb.size.x > 0.0001 else mesh_size.x
		var size_y := aabb.size.y if aabb.size.y > 0.0001 else mesh_size.y
		u = (local_point.x - aabb.position.x) / size_x
		v = 1.0 - ((local_point.y - aabb.position.y) / size_y)
	else:
		u = (local_point.x / mesh_size.x) + 0.5
		v = (-local_point.y / mesh_size.y) + 0.5
	
	_base_card.scratch_at_uv(Vector2(u, v))

func stop_scratching() -> void:
	if _base_card != null:
		_base_card.stop_scratching()

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

func _unhandled_input(event: InputEvent) -> void:
	if not auto_handle_input or Engine.is_editor_hint():
		return
		
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
		
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_scratching = mb.pressed
			if _is_scratching:
				_raycast_scratch(camera, mb.position)
			else:
				stop_scratching()
	elif event is InputEventMouseMotion and _is_scratching:
		var mm := event as InputEventMouseMotion
		_raycast_scratch(camera, mm.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_is_scratching = st.pressed
		if _is_scratching:
			_raycast_scratch(camera, st.position)
		else:
			stop_scratching()
	elif event is InputEventScreenDrag and _is_scratching:
		var sd := event as InputEventScreenDrag
		_raycast_scratch(camera, sd.position)

func _raycast_scratch(camera: Camera3D, screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	var result := space_state.intersect_ray(query)
	if result.size() > 0 and (area_3d == null or result.collider == area_3d):
		scratch_at_world_point(result.position)
	else:
		stop_scratching()
