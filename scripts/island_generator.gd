@tool
class_name IslandGenerator
extends Node3D

const TREE_SCENE = preload("res://scenes/assets/Tree_Stylized.tscn")
const WOOD_PLANK_SCENE = preload("res://scenes/assets/WoodPlank.tscn")

@export var island_size: float = 280.0
@export var resolution: int = 120
@export var noise_seed: int = 42
@export var tree_count: int = 27
@export var wood_plank_count: int = 7
@export var hill_center: Vector2 = Vector2(45.0, -40.0)
@export var hill_radius: float = 48.0
@export var hill_height: float = 24.0
@export var path_width: float = 5.0
@export var terrain_material: Material

@export var regenerate_now: bool = false:
	set(val):
		if val:
			_init_noise()
			generate_island()

# Stylized Color Palette
@export var color_sand: Color = Color(0.94, 0.84, 0.54, 1.0)
@export var color_deep_green: Color = Color(0.18, 0.58, 0.16, 1.0)
@export var color_light_green: Color = Color(0.48, 0.82, 0.24, 1.0)
@export var color_dirt: Color = Color(0.60, 0.42, 0.24, 1.0)
@export var color_cliff: Color = Color(0.44, 0.34, 0.24, 1.0)

var mesh_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D

var _base_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _patch_noise: FastNoiseLite
var _dirt_noise: FastNoiseLite

func _ready() -> void:
	_init_noise()
	_setup_nodes()
	generate_island()

func _init_noise() -> void:
	_base_noise = FastNoiseLite.new()
	_base_noise.seed = noise_seed
	_base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base_noise.frequency = 0.008
	_base_noise.fractal_octaves = 3
	_base_noise.fractal_gain = 0.45

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = noise_seed + 101
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.025
	_detail_noise.fractal_octaves = 2

	_patch_noise = FastNoiseLite.new()
	_patch_noise.seed = noise_seed + 202
	_patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patch_noise.frequency = 0.035

	_dirt_noise = FastNoiseLite.new()
	_dirt_noise.seed = noise_seed + 303
	_dirt_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_dirt_noise.frequency = 0.040

func _setup_nodes() -> void:
	mesh_instance = get_node_or_null("IslandMesh") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "IslandMesh"
		add_child(mesh_instance)

	static_body = get_node_or_null("StaticBody3D") as StaticBody3D
	if static_body == null:
		static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		add_child(static_body)

	static_body.collision_layer = 1
	static_body.collision_mask = 1

	collision_shape = static_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		static_body.add_child(collision_shape)

	if terrain_material == null:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.90
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		terrain_material = mat

	if mesh_instance != null:
		mesh_instance.material_override = terrain_material

func calculate_island_radius(angle: float) -> float:
	var base_r: float = island_size * 0.45
	var wobble: float = sin(angle * 3.0 + 0.5) * 14.0 + sin(angle * 6.0 - 0.7) * 7.0 + sin(angle * 10.0 + 1.1) * 3.5
	return base_r + wobble

func get_path_factor(x: float, z: float) -> Dictionary:
	var offset: Vector2 = Vector2(x, z) - hill_center
	var r: float = offset.length()
	if r > hill_radius * 1.12 or r < 4.0:
		return {"distance": 9999.0, "weight": 0.0, "height": 0.0}

	var angle: float = atan2(offset.y, offset.x)
	if angle < 0.0:
		angle += TAU

	var spiral_loops: float = 2.0
	var r_outer: float = hill_radius * 0.92
	var r_inner: float = 6.0
	var min_dist_to_path: float = 9999.0
	var best_path_height: float = 0.0

	for k in range(-1, int(ceil(spiral_loops)) + 2):
		var t: float = (angle + float(k) * TAU) / (spiral_loops * TAU)
		if t >= 0.0 and t <= 1.0:
			var target_r: float = lerp(r_outer, r_inner, t)
			var dist: float = abs(r - target_r)
			if dist < min_dist_to_path:
				min_dist_to_path = dist
				best_path_height = lerp(4.0, hill_height + 1.5, t)

	var path_weight: float = clamp(1.0 - (min_dist_to_path / path_width), 0.0, 1.0)
	path_weight = path_weight * path_weight * (3.0 - 2.0 * path_weight)

	return {
		"distance": min_dist_to_path,
		"weight": path_weight,
		"height": best_path_height
	}

func get_height_at(x: float, z: float) -> float:
	if _base_noise == null:
		_init_noise()

	var p: Vector2 = Vector2(x, z)
	var angle: float = atan2(p.y, p.x)
	var max_r: float = calculate_island_radius(angle)
	var dist_from_center: float = p.length()

	# Far ocean seabed
	if dist_from_center >= max_r + 14.0:
		return -5.0

	var norm_dist: float = dist_from_center / max_r
	var falloff: float = 1.0 - smoothstep(0.72, 1.0, norm_dist)

	# Base terrain: gentle rolling plains elevated well above sea level
	var n_val: float = _base_noise.get_noise_2d(x, z) * 0.5 + 0.5
	var d_val: float = _detail_noise.get_noise_2d(x, z) * 0.5 + 0.5
	var base_h: float = (n_val * 4.5 + d_val * 2.0 + 3.2) * falloff

	# Shoreline smooth beach slope
	if norm_dist > 0.82:
		var beach_t: float = (norm_dist - 0.82) / (1.0 - 0.82)
		base_h = lerp(base_h, -3.0, clamp(beach_t, 0.0, 1.0))

	# Hill elevation
	var hill_offset: Vector2 = p - hill_center
	var hill_dist: float = hill_offset.length()
	var hill_elevation: float = 0.0

	if hill_dist < hill_radius * 1.2:
		var hill_t: float = clamp(hill_dist / hill_radius, 0.0, 1.0)
		var dome: float = exp(-pow(hill_t * 1.95, 2.0))
		hill_elevation = dome * hill_height

		# Flat summit plateau
		if hill_dist < 8.0:
			hill_elevation = max(hill_elevation, hill_height * 0.98)

	var total_height: float = base_h + hill_elevation

	# Winding spiral path
	if hill_dist < hill_radius * 1.12:
		var path_info: Dictionary = get_path_factor(x, z)
		var p_weight: float = path_info["weight"]
		if p_weight > 0.001:
			var path_h: float = path_info["height"]
			total_height = lerp(total_height, path_h, p_weight * 0.85)

	return total_height

func generate_island() -> void:
	if _base_noise == null:
		_init_noise()
	_setup_nodes()

	var half_size: float = island_size * 0.5
	var step_size: float = island_size / float(resolution)
	var num_verts_1d: int = resolution + 1
	var total_verts: int = num_verts_1d * num_verts_1d

	var grid_verts: PackedVector3Array = PackedVector3Array()
	grid_verts.resize(total_verts)

	var grid_colors: PackedColorArray = PackedColorArray()
	grid_colors.resize(total_verts)

	var grid_uvs: PackedVector2Array = PackedVector2Array()
	grid_uvs.resize(total_verts)

	# 1. Compute positions, colors, UVs
	for iz in range(num_verts_1d):
		var z: float = -half_size + float(iz) * step_size
		for ix in range(num_verts_1d):
			var x: float = -half_size + float(ix) * step_size
			var idx: int = iz * num_verts_1d + ix

			var h: float = get_height_at(x, z)
			var pos: Vector3 = Vector3(x, h, z)
			grid_verts[idx] = pos
			grid_uvs[idx] = Vector2((x + half_size) / island_size, (z + half_size) / island_size)

			# Shore sand
			var sand_factor: float = 1.0 - smoothstep(0.2, 1.8, h)

			# Light green grass patches
			var patch_val: float = _patch_noise.get_noise_2d(x, z) * 0.5 + 0.5
			var light_green_factor: float = smoothstep(0.50, 0.78, patch_val)

			# Random dirt patches
			var dirt_val: float = _dirt_noise.get_noise_2d(x, z) * 0.5 + 0.5
			var dirt_factor: float = smoothstep(0.58, 0.88, dirt_val)

			# Spiral path dirt trail
			var path_info: Dictionary = get_path_factor(x, z)
			var path_w: float = path_info["weight"]
			if path_w > 0.08:
				dirt_factor = max(dirt_factor, path_w)

			var col: Color = color_deep_green.lerp(color_light_green, light_green_factor)
			col = col.lerp(color_dirt, dirt_factor)
			col = col.lerp(color_sand, sand_factor)

			grid_colors[idx] = col

	# 2. Build SurfaceTool mesh with upward-facing CCW triangles
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(total_verts):
		st.set_color(grid_colors[i])
		st.set_uv(grid_uvs[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(grid_verts[i])

	# Add triangle indices with FRONT-FACING Counter-Clockwise order (i00, i10, i01) and (i10, i11, i01)
	for iz in range(resolution):
		for ix in range(resolution):
			var i00: int = iz * num_verts_1d + ix
			var i10: int = iz * num_verts_1d + (ix + 1)
			var i01: int = (iz + 1) * num_verts_1d + ix
			var i11: int = (iz + 1) * num_verts_1d + (ix + 1)

			var v00: Vector3 = grid_verts[i00]
			var v10: Vector3 = grid_verts[i10]
			var v01: Vector3 = grid_verts[i01]
			var v11: Vector3 = grid_verts[i11]

			if v00.y < -3.5 and v10.y < -3.5 and v01.y < -3.5 and v11.y < -3.5:
				continue

			# Front face 1 (Top-Left -> Top-Right -> Bottom-Left: CCW facing UP)
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i01)

			# Front face 2 (Top-Right -> Bottom-Right -> Bottom-Left: CCW facing UP)
			st.add_index(i10)
			st.add_index(i11)
			st.add_index(i01)

	# Generate smooth surface normals pointing up
	st.generate_normals()

	var mesh: ArrayMesh = st.commit()
	mesh_instance.mesh = mesh

	if terrain_material != null:
		mesh_instance.material_override = terrain_material

	# Generate physics collision shape
	if collision_shape != null and mesh != null:
		var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
		collision_shape.shape = shape

	# 3. Procedural Tree Placement
	_spawn_procedural_trees()

	# 4. Procedural Wood Plank Placement
	_spawn_procedural_wood_planks()

func _spawn_procedural_trees() -> void:
	var trees_parent: Node3D = get_node_or_null("Trees") as Node3D
	if trees_parent == null:
		trees_parent = Node3D.new()
		trees_parent.name = "Trees"
		add_child(trees_parent)
	else:
		for child in trees_parent.get_children():
			child.queue_free()

	if tree_count <= 0 or TREE_SCENE == null:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed + 9876

	var placed_positions: Array[Vector2] = []
	var attempts: int = 0
	var max_attempts: int = 2500
	var min_spacing: float = 8.5

	var player_spawn: Vector2 = Vector2(0.0, 6.0)
	var lake_pos: Vector2 = Vector2(8.0, -7.0)
	var cemetery_pos: Vector2 = Vector2(-12.0, -9.5)

	while placed_positions.size() < tree_count and attempts < max_attempts:
		attempts += 1
		var angle: float = rng.randf_range(0.0, TAU)
		var max_r: float = calculate_island_radius(angle)
		var r: float = sqrt(rng.randf()) * (max_r * 0.78)

		var x: float = cos(angle) * r
		var z: float = sin(angle) * r
		var pos_2d: Vector2 = Vector2(x, z)

		# 1. Height checks: on green grass meadows, above sand beach and below sheer peaks
		var h: float = get_height_at(x, z)
		if h < 2.0 or h > 22.5:
			continue

		# 2. Avoid player spawn clearing
		if pos_2d.distance_to(player_spawn) < 8.0:
			continue

		# 3. Avoid lake and cemetery clearings
		if pos_2d.distance_to(lake_pos) < 9.0 or pos_2d.distance_to(cemetery_pos) < 8.0:
			continue

		# 4. Avoid spiral mountain path
		var path_info: Dictionary = get_path_factor(x, z)
		if path_info["weight"] > 0.12:
			continue

		# 5. Check spacing with existing trees
		var too_close: bool = false
		for existing in placed_positions:
			if pos_2d.distance_to(existing) < min_spacing:
				too_close = true
				break

		if too_close:
			if attempts > 1500:
				min_spacing = max(5.5, min_spacing - 0.2)
			continue

		placed_positions.append(pos_2d)

		# Instantiate tree
		var tree: Node3D = TREE_SCENE.instantiate() as Node3D
		tree.position = Vector3(x, h - 0.05, z)
		tree.rotation.y = rng.randf_range(0.0, TAU)
		var s: float = rng.randf_range(0.85, 1.25)
		tree.scale = Vector3(s, s, s)
		trees_parent.add_child(tree)

func _spawn_procedural_wood_planks() -> void:
	var planks_parent: Node3D = get_node_or_null("WoodPlanks") as Node3D
	if planks_parent == null:
		planks_parent = Node3D.new()
		planks_parent.name = "WoodPlanks"
		add_child(planks_parent)
	else:
		for child in planks_parent.get_children():
			child.queue_free()

	if wood_plank_count <= 0 or WOOD_PLANK_SCENE == null:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed + 5544

	# 7 curated strategic locations across the island: building areas, shores, and plains
	var target_spots: Array[Vector2] = [
		Vector2(-4.0, 3.2),    # Build zone 1
		Vector2(-6.2, 1.5),    # Build zone 2
		Vector2(18.0, 12.5),   # Beach shoreline east
		Vector2(-22.0, 6.0),   # Beach shoreline west
		Vector2(14.0, -16.0),  # Southern meadow
		Vector2(-12.0, 19.0),  # Northern meadow
		Vector2(30.0, -24.0)   # Mountain slope approach
	]

	for i in range(min(wood_plank_count, target_spots.size())):
		var spot: Vector2 = target_spots[i]
		# Add subtle random offset
		var x: float = spot.x + rng.randf_range(-1.2, 1.2)
		var z: float = spot.y + rng.randf_range(-1.2, 1.2)
		var h: float = get_height_at(x, z)

		var plank: RigidBody3D = WOOD_PLANK_SCENE.instantiate() as RigidBody3D
		plank.position = Vector3(x, h + 0.25, z)
		plank.rotation.y = rng.randf_range(0.0, TAU)
		planks_parent.add_child(plank)
