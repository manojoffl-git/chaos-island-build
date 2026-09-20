@tool
extends Node3D

## Mobile-first procedural island.
## 192x192 landmass split into 12x12 chunks.
## Mostly flat playable land, gentle coastline, one large hill region.

const CHUNK_SIZE: int = 16
const CHUNK_COUNT: int = 12
const CELLS_PER_CHUNK: int = 10
const WORLD_SIZE: float = CHUNK_SIZE * CHUNK_COUNT
const HALF_WORLD: float = WORLD_SIZE * 0.5
const SEA_LEVEL: float = 0.0
const TERRAIN_BASE: float = 0.18
const VIEW_DISTANCE: float = 120.0
const COLLISION_DISTANCE: float = 80.0
const WATER_SIZE: float = 520.0

const HILL_CENTER := Vector2(42.0, -34.0)
const HILL_HEIGHT: float = 18.0
const HILL_RADIUS: float = 31.0

var terrain_material: StandardMaterial3D
var water_material: StandardMaterial3D
var chunks: Array[Node3D] = []
var player: Node3D
var noise: FastNoiseLite
var detail_noise: FastNoiseLite
var generated: bool = false

func _ready() -> void:
    call_deferred("_generate_after_frame")

func _generate_after_frame() -> void:
    await get_tree().process_frame
    if is_inside_tree() and not generated:
        generate(get_parent())

func generate(parent: Node3D) -> void:
    generated = false
    chunks.clear()

    for node_name in ["TerrainChunks", "Ocean", "CoastDetails"]:
        var old_node: Node = parent.get_node_or_null(node_name)
        if old_node != null:
            old_node.queue_free()

    var legacy_island: Node = parent.get_node_or_null("Island")
    if legacy_island != null:
        for child in legacy_island.get_children():
            child.queue_free()

    terrain_material = make_terrain_material()
    water_material = make_water_material()

    noise = FastNoiseLite.new()
    noise.seed = 17391
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.018
    noise.fractal_octaves = 3
    noise.fractal_lacunarity = 2.0
    noise.fractal_gain = 0.5

    detail_noise = FastNoiseLite.new()
    detail_noise.seed = 48127
    detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    detail_noise.frequency = 0.085
    detail_noise.fractal_octaves = 2
    detail_noise.fractal_gain = 0.45

    var terrain_root: Node3D = Node3D.new()
    terrain_root.name = "TerrainChunks"
    parent.add_child(terrain_root)

    for z in range(CHUNK_COUNT):
        for x in range(CHUNK_COUNT):
            chunks.append(build_chunk(terrain_root, x, z))

    build_ocean(parent)
    build_coast_details(parent)
    player = parent.get_node_or_null("Player")
    generated = true

func make_terrain_material() -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = Color("#5d9652")
    m.roughness = 0.96
    return m

func make_water_material() -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = Color("#3d8eaf")
    m.albedo_color.a = 0.84
    m.roughness = 0.2
    m.metallic = 0.03
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func island_radius(x: float, z: float) -> float:
    var nx: float = x / HALF_WORLD
    var nz: float = z / HALF_WORLD
    var angle: float = atan2(nz, nx)
    var coast_noise: float = noise.get_noise_2d(x * 0.55, z * 0.55) * 0.035
    var lobe: float = 1.0 + 0.075 * sin(angle * 3.0 + 0.8) + 0.035 * sin(angle * 7.0 - 1.1)
    var ellipse: float = sqrt((nx * nx) * 0.94 + (nz * nz) * 1.06)
    return (ellipse + coast_noise) / lobe

func height_at(x: float, z: float) -> float:
    var r: float = island_radius(x, z)
    if r >= 1.0:
        return SEA_LEVEL - 0.22

    var coast_factor: float = smoothstep(0.0, 1.0, clamp((1.0 - r) / 0.075, 0.0, 1.0))
    var interior: float = clamp((1.0 - r) / 0.20, 0.0, 1.0)

    var broad: float = noise.get_noise_2d(x, z)
    var detail: float = detail_noise.get_noise_2d(x, z)
    var gentle_terrain: float = broad * 0.22 + detail * 0.055
    var center_slope: float = (1.0 - clamp(Vector2(x, z).length() / (HALF_WORLD * 0.92), 0.0, 1.0)) * 0.18

    var hill_distance: float = Vector2(x, z).distance_to(HILL_CENTER)
    var hill_falloff: float = clamp(1.0 - hill_distance / HILL_RADIUS, 0.0, 1.0)
    hill_falloff = hill_falloff * hill_falloff * (3.0 - 2.0 * hill_falloff)
    var hill_noise: float = 0.82 + detail_noise.get_noise_2d(x * 0.7 + 90.0, z * 0.7 - 50.0) * 0.18
    var main_hill: float = HILL_HEIGHT * hill_falloff * hill_noise

    var height: float = TERRAIN_BASE + gentle_terrain * interior + center_slope * interior + main_hill
    height *= coast_factor
    return max(SEA_LEVEL - 0.04, height)

func build_chunk(root: Node3D, cx: int, cz: int) -> Node3D:
    var chunk: Node3D = Node3D.new()
    chunk.name = "Chunk_%02d_%02d" % [cx, cz]
    root.add_child(chunk)

    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.name = "Terrain"
    mesh_instance.mesh = make_chunk_mesh(cx, cz)
    mesh_instance.material_override = terrain_material
    chunk.add_child(mesh_instance)

    var collision_body: StaticBody3D = StaticBody3D.new()
    collision_body.name = "Collision"
    collision_body.collision_layer = 1
    collision_body.collision_mask = 1
    chunk.add_child(collision_body)

    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.name = "TerrainShape"
    collision.shape = mesh_instance.mesh.create_trimesh_shape()
    collision_body.add_child(collision)
    return chunk

func make_chunk_mesh(cx: int, cz: int) -> ArrayMesh:
    var verts: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    var uvs: PackedVector2Array = PackedVector2Array()
    var indices: PackedInt32Array = PackedInt32Array()
    var origin_x: float = float(cx * CHUNK_SIZE) - HALF_WORLD
    var origin_z: float = float(cz * CHUNK_SIZE) - HALF_WORLD
    var step: float = float(CHUNK_SIZE) / float(CELLS_PER_CHUNK)

    for z in range(CELLS_PER_CHUNK + 1):
        for x in range(CELLS_PER_CHUNK + 1):
            var wx: float = origin_x + float(x) * step
            var wz: float = origin_z + float(z) * step
            verts.append(Vector3(wx, height_at(wx, wz), wz))
            normals.append(calculate_normal(wx, wz))
            uvs.append(Vector2(wx / 8.0, wz / 8.0))

    var row: int = CELLS_PER_CHUNK + 1
    for z in range(CELLS_PER_CHUNK):
        for x in range(CELLS_PER_CHUNK):
            var a: int = z * row + x
            var b: int = a + 1
            var c: int = a + row
            var d: int = c + 1
            indices.append(a); indices.append(c); indices.append(b)
            indices.append(b); indices.append(c); indices.append(d)

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func calculate_normal(x: float, z: float) -> Vector3:
    var e: float = 0.8
    var h_l: float = height_at(x - e, z)
    var h_r: float = height_at(x + e, z)
    var h_d: float = height_at(x, z - e)
    var h_u: float = height_at(x, z + e)
    return Vector3(h_l - h_r, e * 2.0, h_d - h_u).normalized()

func build_ocean(parent: Node3D) -> void:
    var ocean: Node3D = Node3D.new()
    ocean.name = "Ocean"
    parent.add_child(ocean)

    var water: MeshInstance3D = MeshInstance3D.new()
    water.name = "OceanSurface"
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2(WATER_SIZE, WATER_SIZE)
    water.mesh = quad
    water.material_override = water_material
    water.position = Vector3(0.0, SEA_LEVEL - 0.05, 0.0)
    water.rotation_degrees.x = -90.0
    ocean.add_child(water)

func build_coast_details(parent: Node3D) -> void:
    var coast: Node3D = Node3D.new()
    coast.name = "CoastDetails"
    parent.add_child(coast)

    var stone_mesh: SphereMesh = SphereMesh.new()
    stone_mesh.radius = 0.42
    stone_mesh.height = 0.48
    stone_mesh.radial_segments = 6
    stone_mesh.rings = 3
    var stone_mat: StandardMaterial3D = make_terrain_material()
    stone_mat.albedo_color = Color("#807767")

    for i in range(64):
        var a: float = TAU * float(i) / 64.0
        var radius: float = HALF_WORLD * (0.92 + 0.018 * sin(float(i) * 2.9))
        var x: float = cos(a) * radius
        var z: float = sin(a) * radius
        if island_radius(x, z) >= 1.0:
            continue
        var stone: MeshInstance3D = MeshInstance3D.new()
        stone.mesh = stone_mesh
        stone.material_override = stone_mat
        stone.position = Vector3(x, max(0.03, height_at(x, z) + 0.05), z)
        var s: float = 0.55 + float((i * 13) % 8) * 0.08
        stone.scale = Vector3(s * 1.25, s * 0.65, s)
        coast.add_child(stone)

func _process(_delta: float) -> void:
    if not generated or chunks.is_empty() or Engine.is_editor_hint():
        return
    if player == null:
        player = get_tree().current_scene.get_node_or_null("Player")
        if player == null:
            return

    var p: Vector3 = player.global_position
    var view_sq: float = VIEW_DISTANCE * VIEW_DISTANCE
    var collision_sq: float = COLLISION_DISTANCE * COLLISION_DISTANCE

    for index in range(chunks.size()):
        var cx: int = index % CHUNK_COUNT
        var cz: int = index / CHUNK_COUNT
        var center_x: float = float(cx * CHUNK_SIZE) + CHUNK_SIZE * 0.5 - HALF_WORLD
        var center_z: float = float(cz * CHUNK_SIZE) + CHUNK_SIZE * 0.5 - HALF_WORLD
        var dx: float = center_x - p.x
        var dz: float = center_z - p.z
        var dist_sq: float = dx * dx + dz * dz
        var terrain: Node3D = chunks[index].get_node("Terrain")
        var collision_body: StaticBody3D = chunks[index].get_node("Collision")
        terrain.visible = dist_sq <= view_sq
        collision_body.collision_layer = 1 if dist_sq <= collision_sq else 0
        collision_body.collision_mask = 1 if dist_sq <= collision_sq else 0
