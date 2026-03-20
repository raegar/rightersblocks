# main.gd
extends Node3D

@onready var block_manager: Node3D = $BlockManager
@onready var camera: Camera3D = $Camera3D

var _orbit_distance := 14.0
var _orbit_angle_h := 0.4   # radians horizontal
var _orbit_angle_v := 0.6   # radians vertical
var _orbit_target := Vector3(8, 0, 8)  # centre of the 16x16 grid

var _is_dragging := false
var _last_mouse := Vector2.ZERO


func _ready() -> void:
	_update_camera()


func _input(event: InputEvent) -> void:
	# Middle mouse drag to orbit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			_last_mouse = event.position

	if event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = event.position - _last_mouse
		_last_mouse = event.position
		_orbit_angle_h -= delta.x * 0.005
		_orbit_angle_v = clamp(_orbit_angle_v + delta.y * 0.005, 0.1, 1.4)
		_update_camera()

	# Scroll to zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_distance = max(3.0, _orbit_distance - 1.0)
			_update_camera()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_distance = min(30.0, _orbit_distance + 1.0)
			_update_camera()

	# Left click — hit block
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_raycast_block(event.position, false)
		# Right click — place block on top of hit face
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_raycast_block(event.position, true)


func _raycast_block(screen_pos: Vector2, place_mode: bool) -> void:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 50.0)
	var result := space.intersect_ray(query)

	if result.is_empty():
		return

	var collider = result["collider"]
	if not collider.has_meta("grid_coord"):
		return

	var coord: Vector3i = collider.get_meta("grid_coord")
	var normal: Vector3 = result["normal"]

	if place_mode:
		var place_coord := coord + Vector3i(roundi(normal.x), roundi(normal.y), roundi(normal.z))
		block_manager.place_block(place_coord)
	else:
		block_manager.hit_block(coord)


func _update_camera() -> void:
	var offset := Vector3(
		cos(_orbit_angle_v) * sin(_orbit_angle_h),
		sin(_orbit_angle_v),
		cos(_orbit_angle_v) * cos(_orbit_angle_h)
	) * _orbit_distance
	camera.position = _orbit_target + offset
	camera.look_at(_orbit_target, Vector3.UP)
