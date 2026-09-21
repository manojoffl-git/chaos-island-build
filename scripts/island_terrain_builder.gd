@tool
extends Node3D
## One-time editor baker. It creates REAL MeshInstance3D and StaticBody3D children.

@export_category("Terrain Baker")
@export var generate_now: bool = false:
	set(value):
		if value:
			_build_terrain()
			generate_now = false

@export var grid_size: int = 97
@export var world_size: float = 4800.0
@export var island_radius: float = 2050.0
@export var mountain_height: float = 560.0

const TERRAIN_NODE: StringName = &"GeneratedTerrain"
const COLLISION_NODE: StringName = &"GeneratedTerrainCollision"

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_ensure_terrain")

func _ensure_terrain() -> void:
	if get_node_or_null(TERRAIN_NODE) == null:
		_build_terrain()

func _height(x: float, z: float) -> float:
	var a: float = atan2(z, x)
	var boundary: float = island_radius + 140.0 * sin(2.0 * a + 0.4) + 90.0 * sin(5.0 * a - 1.1) + 50.0 * sin(9.0 * a + 0.7)
	var r: float = Vector2(x / 1.03, z / 0.92).length()
	if r > boundary:
		return -100.0

	var edge: float = clampf((r - (boundary - 180.0)) / 180.0, 0.0, 1.0)
	var h: float = 18.0 * sin(x / 180.0) + 13.0 * sin(z / 210.0)
	h += 8.0 * sin((x + z) / 140.0) + 5.0 * sin((x - z) / 100.0)

	# Large asymmetric main mountain.
	h += mountain_height * exp(-pow((x - 750.0) / 500.0, 2.0) - pow((z + 600.0) / 430.0, 2.0))
	# Secondary hill.
	h += 90.0 * exp(-pow((x + 1050.0) / 420.0, 2.0) - pow((z - 850.0) / 340.0, 2.0))
	h *= 1.0 - edge * 0.78

	# Spiral path carved into the mountain.
	var d: Vector2 = Vector2(x - 750.0, z + 600.0)
	var rr: float = d.length()
	var aa: float = atan2(d.y, d.x)
	if aa < 0.0:
		aa += TAU
	var best: float = INF
	for k: int in range(-1, 5):
		var t: float = aa + TAU * float(k)
		best = minf(best, absf(rr - (120.0 + 55.0 * t)))
	var path: float = 1.0 - smoothstep(6.0, 16.0, best)
	h -= path * 14.0

	if rr < 80.0:
		h = maxf(h, mountain_height - 60.0)
	if r > boundary - 30.0:
		h *= maxf(0.0, (boundary - r) / 30.0)
	return h - 8.514

func _build_terrain() -> void:
	if not Engine.is_editor_hint():
		return

	var old: Node = get_node_or_null(TERRAIN_NODE)
	if old != null:
		old.free()
	var old_collision: Node = get_node_or_null(COLLISION_NODE)
	if old_collision != null:
		old_collision.free()

	var n: int = maxi(grid_size, 33)
	var step: float = world_size / float(n - 1)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n * n)

	for zi: int in range(n):
		var z: float = -world_size * 0.5 + step * float(zi)
		for xi: int in range(n):
			var x: float = -world_size * 0.5 + step * float(xi)
			var h: float = _height(x, z)
			if h < -90.0:
				h = 0.0
			heights[zi * n + xi] = h

	# Build an actual ArrayMesh resource from terrain vertices.
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_make_material())

	for zi: int in range(n - 1):
		for xi: int in range(n - 1):
			var x0: float = -world_size * 0.5 + step * float(xi)
			var x1: float = x0 + step
			var z0: float = -world_size * 0.5 + step * float(zi)
			var z1: float = z0 + step
			var p00: Vector3 = Vector3(x0, heights[zi * n + xi], z0)
			var p10: Vector3 = Vector3(x1, heights[zi * n + xi + 1], z0)
			var p11: Vector3 = Vector3(x1, heights[(zi + 1) * n + xi + 1], z1)
			var p01: Vector3 = Vector3(x0, heights[(zi + 1) * n + xi], z1)
			var center: Vector2 = Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if Vector2(center.x / 1.03, center.y / 0.92).length() > island_radius + 160.0:
				continue
			_add_triangle(st, p00, p10, p11)
			_add_triangle(st, p00, p11, p01)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	if mesh == null:
		push_error("Terrain bake failed: no ArrayMesh was created.")
		return

	# Actual MeshInstance3D in the scene tree.
	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.name = TERRAIN_NODE
	terrain.mesh = mesh
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain)
	terrain.owner = _scene_owner()

	# Actual StaticBody3D + CollisionShape3D in the scene tree.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = COLLISION_NODE
	add_child(body)
	body.owner = _scene_owner()

	var collision: CollisionShape3D = CollisionShape3D.new()
	var height_map: HeightMapShape3D = HeightMapShape3D.new()
	height_map.map_width = n
	height_map.map_depth = n
	height_map.map_data = heights
	collision.shape = height_map
	collision.scale = Vector3(step, 1.0, step)
	body.add_child(collision)
	collision.owner = body.owner

	print("Chaos Island terrain baked: GeneratedTerrain MeshInstance3D + GeneratedTerrainCollision StaticBody3D")

func _scene_owner() -> Node:
	var root: Node = get_tree().edited_scene_root
	if root != null:
		return root
	return self

func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_color(_terrain_color(a))
	st.add_vertex(a)
	st.set_color(_terrain_color(b))
	st.add_vertex(b)
	st.set_color(_terrain_color(c))
	st.add_vertex(c)

func _terrain_color(p: Vector3) -> Color:
	var patch: float = sin(p.x / 215.0) * sin(p.z / 245.0) + sin((p.x + p.z) / 205.0)
	if p.y < 3.0:
		return Color(0.82, 0.69, 0.40)
	if p.y > 160.0 and patch > 0.1:
		return Color(0.40, 0.23, 0.10)
	if patch > 0.65:
		return Color(0.30, 0.62, 0.12)
	return Color(0.055, 0.25, 0.055)

func _make_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.96
	return mat
