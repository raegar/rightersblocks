# block_manager.gd
extends Node3D

const CHUNK_SIZE := 16
const MAX_HITS := 3
const BLOCK_COLORS := [
	Color(0.4, 0.8, 0.3),  # 0 hits  - healthy green
	Color(0.9, 0.8, 0.2),  # 1 hit   - yellow
	Color(0.9, 0.4, 0.1),  # 2 hits  - orange
]

# Vector3i -> BlockState
var block_data: Dictionary = {}
# Vector3i -> StaticBody3D
var _colliders: Dictionary = {}

var _multimesh: MultiMesh
var _mmi: MultiMeshInstance3D

class BlockState:
	var hits: int = 0
	var instance_index: int = -1  # index into the MultiMesh buffer


func _ready() -> void:
	_setup_multimesh()
	_generate_flat_landscape()
	_build_colliders()


func _setup_multimesh() -> void:
	_mmi = MultiMeshInstance3D.new()
	add_child(_mmi)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.mesh = _make_box_mesh()

	_mmi.multimesh = _multimesh

	# Shader that reads per-instance custom data as the albedo colour
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

void vertex() {
	// INSTANCE_CUSTOM is the vec4 set by set_instance_custom_data()
	COLOR = INSTANCE_CUSTOM;
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_multimesh.mesh.surface_set_material(0, mat)


func _make_box_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.95, 0.95, 0.95)
	return mesh


func _generate_flat_landscape() -> void:
	var coords: Array[Vector3i] = []
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			coords.append(Vector3i(x, 0, z))
	_allocate_instances(coords)


# --- Public API ---

func place_block(coord: Vector3i) -> void:
	if block_data.has(coord):
		return
	_allocate_instances([coord])
	_add_collider(coord)


func hit_block(coord: Vector3i) -> void:
	if not block_data.has(coord):
		return
	var state: BlockState = block_data[coord]
	state.hits += 1
	print("Block %s hit — %d/%d" % [coord, state.hits, MAX_HITS])
	if state.hits >= MAX_HITS:
		remove_block(coord)
	else:
		_refresh_instance(coord, state)


func remove_block(coord: Vector3i) -> void:
	if not block_data.has(coord):
		return
	var state: BlockState = block_data[coord]
	_multimesh.set_instance_transform(
		state.instance_index,
		Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	)
	_multimesh.set_instance_custom_data(state.instance_index, Color(0, 0, 0, 0))
	block_data.erase(coord)

	# Remove the matching collider
	if _colliders.has(coord):
		_colliders[coord].queue_free()
		_colliders.erase(coord)

	print("Block %s removed" % coord)


func get_block_state(coord: Vector3i) -> BlockState:
	return block_data.get(coord, null)


# --- Internal helpers ---

func _build_colliders() -> void:
	for coord in block_data.keys():
		_add_collider(coord)


func _add_collider(coord: Vector3i) -> void:
	var body := StaticBody3D.new()
	body.name = "col_%d_%d_%d" % [coord.x, coord.y, coord.z]
	body.position = Vector3(coord)
	body.set_meta("grid_coord", coord)

	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	add_child(body)

	_colliders[coord] = body


func _allocate_instances(coords: Array[Vector3i]) -> void:
	var existing := _multimesh.instance_count
	_multimesh.instance_count = existing + coords.size()

	for i in coords.size():
		var coord: Vector3i = coords[i]
		var idx := existing + i

		var state := BlockState.new()
		state.instance_index = idx
		block_data[coord] = state

		_refresh_instance(coord, state)


func _refresh_instance(coord: Vector3i, state: BlockState) -> void:
	var pos := Vector3(coord.x, coord.y, coord.z)
	_multimesh.set_instance_transform(
		state.instance_index,
		Transform3D(Basis(), pos)
	)
	var col: Color = BLOCK_COLORS[state.hits] if state.hits < BLOCK_COLORS.size() else BLOCK_COLORS[BLOCK_COLORS.size() - 1]
	_multimesh.set_instance_custom_data(state.instance_index, col)


func world_to_grid(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		roundi(world_pos.x),
		roundi(world_pos.y),
		roundi(world_pos.z)
	)
