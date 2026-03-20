# main.gd
extends Node3D

@onready var block_manager: Node3D = $BlockManager
@onready var camera: Camera3D = $Camera3D



var _orbit_angle_h := 0.4   # radians horizontal
var _orbit_angle_v := 0.6   # radians vertical
var _orbit_distance := 0.0
var _orbit_target := Vector3.ZERO

var _is_dragging := false
var _last_mouse := Vector2.ZERO

var _fly_speed := 10.0
var _velocity := Vector3.ZERO

func _ready() -> void:
	var centre : float = block_manager.CHUNK_SIZE / 2.0
	_orbit_distance = block_manager.CHUNK_SIZE * 0.1
	_orbit_target = Vector3(centre, 0, centre)
	_update_camera()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = event.position - _last_mouse
		_last_mouse = event.position
		_orbit_angle_h -= delta.x * 0.005
		_orbit_angle_v = clamp(_orbit_angle_v + delta.y * 0.005, 0.1, 1.4)
		_update_camera()

	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_is_dragging = event.pressed
				_last_mouse = event.position
			MOUSE_BUTTON_WHEEL_UP:
				_orbit_distance = max(3.0, _orbit_distance - 1.0)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_distance = min(30.0, _orbit_distance + 1.0)
				_update_camera()
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_raycast_block(event.position, false)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_raycast_block(event.position, true)

func _process(delta: float) -> void:
	var input := Vector3.ZERO

	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input.x += 1
	if Input.is_key_pressed(KEY_E):
		input.y += 1
	if Input.is_key_pressed(KEY_Q):
		input.y -= 1

	if input != Vector3.ZERO:
		# Move relative to camera's horizontal orientation
		var basis := Basis(Vector3.UP, _orbit_angle_h)
		_orbit_target += basis * input.normalized() * _fly_speed * delta
		_update_camera()

func _raycast_block(screen_pos: Vector2, place_mode: bool) -> void:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos).normalized()

	var step_size := 0.25
	var max_distance := 100.0
	var prev_coord: Vector3i = Vector3i(-9999, -9999, -9999)
	var distance := 0.0

	while distance < max_distance:
		var sample := origin + direction * distance
		var coord: Vector3i = block_manager.world_to_grid(sample)

		if block_manager.block_data.has(coord):
			if place_mode:
				block_manager.place_block(prev_coord)
			else:
				block_manager.hit_block(coord)
			return

		prev_coord = coord
		distance += step_size


func _update_camera() -> void:
	var offset := Vector3(
		cos(_orbit_angle_v) * sin(_orbit_angle_h),
		sin(_orbit_angle_v),
		cos(_orbit_angle_v) * cos(_orbit_angle_h)
	) * _orbit_distance
	camera.position = _orbit_target + offset
	camera.look_at(_orbit_target, Vector3.UP)
