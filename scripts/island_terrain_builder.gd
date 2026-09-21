@tool
extends Node3D
## Editor-time Chaos Island terrain generator.
## Builds real mesh geometry and a matching HeightMapShape3D for the 3D viewport.

@export_category("Terrain")
@export var generate_now: bool = false:
	set(value):
		if value:
			_build_terrain()
			generate_now = false

@export var grid_size: int = 97
@export var world_size: float = 4800.0
@export var island_radius: float = 2050.0
@export var mountain_height: float = 560.0

const TERRAIN_NODE := "GeneratedTerrain"
const COLLISION_NODE := "GeneratedTerrainCollision"

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_ensure_terrain")

func _ensure_terrain() -> void:
	if get_node_or_null(TERRAIN_NODE) == null:
		_build_terrain()

func _height(x: float, z: float) -> float:
	var a := atan2(z, x)
	var boundary := island_radius + 140.0 * sin(2.0 * a + 0.4) + 90.0 * sin(5.0 * a - 1.1) + 50.0 * sin(9.0 * a + 0.7)
	var r := Vector2(x / 1.03, z / 0.92).length()
	if r > boundary:
		return -100.0

	var edge := clamp((r - (boundary - 180.0)) / 180.0, 0.0, 1.0)
	var h := 18.0 * sin(x / 180.0) + 13.0 * sin(z / 210.0)
	h += 8.0 * sin((x + z) / 140.0) + 5.0 * sin((x - z) / 100.0)

	# Main asymmetric mountain.
	h += mountain_height * exp(-pow((x - 750.0) / 500.0, 2.0) - pow((z + 600.0) / 430.0, 2.0))
	# Secondary rise.
	h += 90.0 * exp(-pow((x + 1050.0) / 420.0, 2.0) - pow((z - 850.0) / 340.0, 2.0))
	h *= 1.0 - edge * 0.78

	# Winding climbable route carved around the main mountain.
	var d := Vector2(x - 750.0, z + 600.0)
	var rr := d.length()
	var aa := atan2(d.y, d.x)
	if aa < 0.0:
		aa += TAU
	var best := INF
	for k in range(-1, 5):
		var t := aa + TAU * float(k)
		best = min(best, abs(rr - (120.0 + 55.0 * t)))
	var path := 1.0 - smoothstep(6.0, 16.0, best)
	h -= path * 14.0

	if rr < 80.0:
		h = max(h, mountain_height - 60.0)
	if r > boundary - 30.0:
		h *= max(0.0, (boundary - r) / 30.0)

	return h - 8.514

func _build_terrain() -> void:
	var old := get_node_or_null(TERRAIN_NODE)
	if old:
		old.queue_free()
	var old_col := get_node_or_null(COLLISION_NODE)
	if old_col:
		old_col.queue_free()

	var n := maxi(grid_size, 33)
	var step := world_size / float(n - 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_make_material())

	var heights := PackedFloat32Array()
	heights.resize(n * n)

	for z_i in range(n):
		var z := -world_size * 0.5 + step * z_i
		for x_i in range(n):
			var x := -world_size * 0.5 + step * x_i
			var h := _height(x, z)
			if h < -90.0:
				h = 0.0
			heights[z_i * n + x_i] = h

	for z_i in range(n - 1):
		for x_i in range(n - 1):
			var x0 := -world_size * 0.5 + step * x_i
			var x1 := x0 + step
			var z0 := -world_size * 0.5 + step * z_i
			var z1 := z0 + step
			var p00 := Vector3(x0, heights[z_i * n + x_i], z0)
			var p10 := Vector3(x1, heights[z_i * n + x_i + 1], z0)
			var p11 := Vector3(x1, heights[(z_i + 1) * n + x_i + 1], z1)
			var p01 := Vector3(x0, heights[(z_i + 1) * n + x_i], z1)

			var center := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if Vector2(center.x / 1.03, center.y / 0.92).length() > island_radius + 160.0:
				continue

			_add_triangle(st, p00, p10, p11)
			_add_triangle(st, p00, p11, p01)

	st.generate_normals()
	var mesh := st.commit()
	var terrain := MeshInstance3D.new()
	terrain.name = TERRAIN_NODE
	terrain.mesh = mesh
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain)
	terrain.owner = owner if owner else get_tree().edited_scene_root

	var body := StaticBody3D.new()
	body.name = COLLISION_NODE
	add_child(body)
	body.owner = owner if owner else get_tree().edited_scene_root

	var shape := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = heights
	shape.shape = hm
	shape.scale = Vector3(step, 1.0, step)
	body.add_child(shape)
	shape.owner = body.owner

	if Engine.is_editor_hint():
		var scene_root := get_tree().edited_scene_root
		if scene_root:
			scene_root.set_meta("chaos_island_terrain_generated", true)

func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_color(_terrain_color(a))
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_color(_terrain_color(b))
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)
	st.set_color(_terrain_color(c))
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)

func _terrain_color(p: Vector3) -> Color:
	var patch := sin(p.x / 215.0) * sin(p.z / 245.0) + sin((p.x + p.z) / 205.0)
	if p.y < 3.0:
		return Color(0.82, 0.69, 0.40)
	if p.y > 160.0 and patch > 0.1:
		return Color(0.40, 0.23, 0.10)
	if patch > 0.65:
		return Color(0.30, 0.62, 0.12)
	return Color(0.055, 0.25, 0.055)

func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.96
	return mat
