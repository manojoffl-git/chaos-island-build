extends Node3D

## Chunked procedural island terrain.
## Designed for a large mobile-friendly island: low mesh density, shared materials,
## chunk-sized static collisions, and distance-based visual chunk culling.

const CHUNK_SIZE: int = 16
const CHUNK_COUNT: int = 8
const CELLS_PER_CHUNK: int = 8
const WORLD_SIZE: float = CHUNK_SIZE * CHUNK_COUNT
const HALF_WORLD: float = WORLD_SIZE * 0.5
const SEA_LEVEL: float = 0.0
const TERRAIN_BASE: float = 0.15
const MAX_HEIGHT: float = 9.0
const VIEW_DISTANCE: float = 145.0
const WATER_SIZE: float = 420.0

var terrain_material: StandardMaterial3D
var sand_material: StandardMaterial3D
var water_material: StandardMaterial3D
var chunks: Array[Node3D] = []
var player: Node3D
var noise: FastNoiseLite
var detail_noise: FastNoiseLite

func _ready() -> void:
    generate($".." if get_parent() != null else self)

func generate(parent: Node3D) -> void:
    terrain_material = make_material(Color("#5f9b55"), 0.92)
    sand_material = make_material(Color("#c7a66a"), 0.96)
    water_material = make_water_material()

    noise = FastNoiseLite.new()
    noise.seed = 17391
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.022
    noise.fractal_octaves = 4
    noise.fractal_lacunarity = 2.0
    noise.fractal_gain = 0.52

    detail_noise = FastNoiseLite.new()
    detail_noise.seed = 48127
    detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    detail_noise.frequency = 0.075
    detail_noise.fractal_octaves = 2
    detail_noise.fractal_gain = 0.45

    var terrain_root: Node3D = Node3D.new()
    terrain_root.name = "TerrainChunks"
    parent.add_child(terrain_root)

    for z in range(CHUNK_COUNT):
        for x in range(CHUNK_COUNT):
            var chunk: Node3D = build_chunk(terrain_root, x, z)
            chunks.append(chunk)

    build_ocean(parent)
    build_coast_details(parent)
    player = parent.get_node_or_null("Player")

func make_material(color: Color, roughness: float) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.cull_mode = BaseMaterial3D.CULL_BACK
    return m

func make_water_material() -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = Color("#3c91b6")
    m.roughness = 0.18
    m.metallic = 0.05
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color.a = 0.82
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func island_radius(x: float, z: float) -> float:
    # Slightly asymmetric radial boundary: broad north/east areas and coves.
    var nx: float = x / HALF_WORLD
    var nz: float = z / HALF_WORLD
    var angle: float = atan2(nz, nx)
    var lobe: float = 1.0 + 0.10 * sin(angle * 3.0 + 0.7) + 0.055 * sin(angle * 7.0 - 1.2)
    var ellipse: float = sqrt((nx * nx) * 0.92 + (nz * nz) * 1.08)
    return ellipse / lobe

func height_at(x: float, z: float) -> float:
    var r: float = island_radius(x, z)
    var coast_noise: float = noise.get_noise_2d(x, z) * 0.035
    r += coast_noise

    if r >= 1.0:
        return SEA_LEVEL - 0.18

    var edge: float = clamp((1.0 - r) / 0.18, 0.0, 1.0)
    var interior: float = clamp((1.0 - r) / 0.82, 0.0, 1.0)
    var broad: float = noise.get_noise_2d(x, z)
    var detail: float = detail_noise.get_noise_2d(x, z)

    # Broad hills + smaller rolling terrain. Coast smoothly falls to sea level.
    var hills: float = (broad * 0.5 + 0.5) * 5.2
    var rolling: float = detail * 1.15
    var ridge: float = max(0.0, broad - 0.18) * 2.8
    var center_bias: float = (1.0 - clamp(length(Vector2(x, z)) / (HALF_WORLD * 0.82), 0.0, 1.0)) * 1.8
    var height: float = TERRAIN_BASE + hills * interior + rolling * interior + ridge * interior + center_bias * interior
    height *= smoothstep(0.0, 1.0, edge)
    return max(SEA_LEVEL - 0.04, height)

func build_chunk(root: Node3D, cx: int, cz: int) -> Node3D:
    var chunk: Node3D = Node3D.new()
    chunk.name = "Chunk_%02d_%02d" % [cx, cz]
    root.add_child(chunk)

    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.name = "Terrain"
    var array_mesh: ArrayMesh = make_chunk_mesh(cx, cz)
    mesh_instance.mesh = array_mesh
    mesh_instance.material_override = terrain_material
    chunk.add_child(mesh_instance)

    var collision_body: StaticBody3D = StaticBody3D.new()
    collision_body.name = "Collision"
    collision_body.collision_layer = 1
    collision_body.collision_mask = 1
    chunk.add_child(collision_body)
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.shape = array_mesh.create_trimesh_shape()
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
            var h: float = height_at(wx, wz)
            verts.append(Vector3(wx, h, wz))
            normals.append(calculate_normal(wx, wz))
            uvs.append(Vector2(wx / 8.0, wz / 8.0))

    var row: int = CELLS_PER_CHUNK + 1
    for z in range(CELLS_PER_CHUNK):
        for x in range(CELLS_PER_CHUNK):
            var a: int = z * row + x
            var b: int = a + 1
            var c: int = a + row
            var d: int = c + 1
            indices.append(a)
            indices.append(c)
            indices.append(b)
            indices.append(b)
            indices.append(c)
            indices.append(d)

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
    var e: float = 0.65
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

    var shore_body: StaticBody3D = StaticBody3D.new()
    shore_body.name = "OceanFloor"
    ocean.add_child(shore_body)
    var floor_col: CollisionShape3D = CollisionShape3D.new()
    var floor_shape: BoxShape3D = BoxShape3D.new()
    floor_shape.size = Vector3(WATER_SIZE, 0.4, WATER_SIZE)
    floor_col.shape = floor_shape
    floor_col.position = Vector3(0.0, -1.0, 0.0)
    shore_body.add_child(floor_col)

func build_coast_details(parent: Node3D) -> void:
    # Lightweight shoreline stones: one shared mesh/material, no individual physics bodies.
    var coast: Node3D = Node3D.new()
    coast.name = "CoastDetails"
    parent.add_child(coast)
    var stone_mesh: SphereMesh = SphereMesh.new()
    stone_mesh.radius = 0.45
    stone_mesh.height = 0.5
    stone_mesh.radial_segments = 6
    stone_mesh.rings = 3
    var stone_mat: StandardMaterial3D = make_material(Color("#8b806d"), 1.0)
    var stone_count: int = 0
    for i in range(72):
        var a: float = TAU * float(i) / 72.0
        var radius: float = HALF_WORLD * (0.88 + 0.035 * sin(float(i) * 2.7))
        var x: float = cos(a) * radius
        var z: float = sin(a) * radius
        if island_radius(x, z) > 0.98:
            continue
        var stone: MeshInstance3D = MeshInstance3D.new()
        stone.mesh = stone_mesh
        stone.material_override = stone_mat
        stone.position = Vector3(x, max(0.02, height_at(x, z) + 0.05), z)
        var s: float = 0.65 + float((i * 17) % 9) * 0.07
        stone.scale = Vector3(s * 1.2, s * 0.65, s)
        coast.add_child(stone)
        stone_count += 1
        if stone_count >= 48:
            break

func _process(_delta: float) -> void:
    if player == null:
        player = get_tree().current_scene.get_node_or_null("Player")
        return
    # Chunk culling keeps distant terrain out of the renderer while retaining all static collision.
    var p: Vector3 = player.global_position
    var max_sq: float = VIEW_DISTANCE * VIEW_DISTANCE
    for chunk in chunks:
        var center: Vector3 = chunk.global_position + Vector3(HALF_WORLD - CHUNK_SIZE * 0.5, 0.0, HALF_WORLD - CHUNK_SIZE * 0.5)
        var dx: float = center.x - p.x
        var dz: float = center.z - p.z
        chunk.get_node("Terrain").visible = (dx * dx + dz * dz) <= max_sq
