# block_manager.gd
extends Node3D

const CHUNK_SIZE := 64
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


const MAX_BLOCKS := 8192

var _free_slots: Array[int] = []


func _setup_multimesh() -> void:
	_mmi = MultiMeshInstance3D.new()
	add_child(_mmi)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.mesh = _make_box_mesh()
	_multimesh.instance_count = MAX_BLOCKS  # allocate once, never resize

	_mmi.multimesh = _multimesh

	# Hide all slots by default
	for i in MAX_BLOCKS:
		_hide_slot(i)
		_free_slots.append(i)

	var shader := Shader.new()
	shader.code = """
shader_type spatial;

void vertex() {
	COLOR = INSTANCE_CUSTOM;
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_multimesh.mesh.surface_set_material(0, mat)


func _hide_slot(idx: int) -> void:
	_multimesh.set_instance_transform(
		idx,
		Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	)
	_multimesh.set_instance_custom_data(idx, Color(0, 0, 0, 0))

func _make_box_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.95, 0.95, 0.95)
	return mesh


func _generate_flat_landscape() -> void:
	var coords: Array[Vector3i] = []
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			# Simple noise-style height using sine waves
			var height := int(
				sin(x * 0.3) * 2.0 +
				sin(z * 0.3) * 2.0 +
				sin(x * 0.15 + z * 0.15) * 3.0
			)
			# Fill vertically so there are no floating blocks
			for y in range(height + 1):
				coords.append(Vector3i(x, y, z))
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
	_hide_slot(state.instance_index)
	_free_slots.append(state.instance_index)  # return slot for reuse
	block_data.erase(coord)

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
	for coord in coords:
		if _free_slots.is_empty():
			push_error("No free MultiMesh slots remaining!")
			return

		var idx: int = _free_slots.pop_back()
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
