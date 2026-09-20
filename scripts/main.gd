extends Node3D

var disaster_active: bool = false
var blocks: Array[RigidBody3D] = []
var world_objects: Array[RigidBody3D] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var time_alive: float = 0.0
var status_label: Label

func _ready() -> void:
    rng.seed = 424242
    call_deferred("_initialize_world")

func _initialize_world() -> void:
    # The island is a permanent MeshInstance3D in Main.tscn.
    # Nothing is generated at startup, so the terrain is always present.
    await get_tree().process_frame

    var player: CharacterBody3D = $Player
    player.global_position = Vector3(0.0, terrain_height(0.0, 6.0) + 0.08, 6.0)
    player.velocity = Vector3.ZERO

    build_world()
    setup_ui()

func mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func mesh_box(size: Vector3, color: Color, parent: Node3D, pos: Vector3 = Vector3.ZERO, name: String = "Box") -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = name
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = mat(color)
    node.position = pos
    parent.add_child(node)
    return node

func mesh_cylinder(radius: float, height: float, color: Color, parent: Node3D, pos: Vector3 = Vector3.ZERO, name: String = "Cylinder") -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = name
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    node.mesh = mesh
    node.material_override = mat(color)
    node.position = pos
    parent.add_child(node)
    return node

func mesh_sphere(radius: float, color: Color, parent: Node3D, pos: Vector3 = Vector3.ZERO, name: String = "Sphere") -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = name
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    node.mesh = mesh
    node.material_override = mat(color)
    node.position = pos
    parent.add_child(node)
    return node

func terrain_height(_x: float, _z: float) -> float:
    # The permanent island has a flat playable top at this height.
    return 0.18

func build_world() -> void:
    build_lake()
    build_trees()
    build_cemetery()
    build_props()
    build_building_materials()

func build_island() -> void:
    # Island terrain is now a permanent MeshInstance3D in Main.tscn.
    pass

func build_lake() -> void:
    var lake: Node3D = $Lake
    var water: MeshInstance3D = mesh_cylinder(5.5, 0.18, Color("#4ea9d6"), lake, Vector3(8.0, terrain_height(8.0, -7.0) + 0.12, -7.0), "LakeWater")
    water.scale = Vector3(1.35, 1.0, 0.8)
    var lake_y: float = terrain_height(8.0, -7.0)
    mesh_box(Vector3(5.0, 0.22, 1.2), Color("#9b6b3e"), lake, Vector3(8.0, lake_y + 0.42, -1.4), "Dock")
    for i in range(3):
        mesh_cylinder(0.12, 1.2, Color("#68452d"), lake, Vector3(6.0 + float(i) * 2.0, lake_y - 0.1, -1.4), "DockPost")

func build_hills() -> void:
    pass

func build_trees() -> void:
    var trees: Node3D = $Trees
    var tree_positions: Array[Vector3] = [
        Vector3(-16, 0, -4), Vector3(-14, 0, -1), Vector3(-17, 0, 3),
        Vector3(-12, 0, 7), Vector3(-8, 0, 15), Vector3(-4, 0, 13),
        Vector3(14, 0, 15), Vector3(18, 0, 12), Vector3(16, 0, 6),
        Vector3(19, 0, -7), Vector3(15, 0, -13), Vector3(11, 0, -15),
        Vector3(2, 0, 17), Vector3(-20, 0, 10)
    ]
    for i in range(tree_positions.size()):
        build_tree(trees, tree_positions[i], i)

func build_tree(parent: Node3D, pos: Vector3, index: int) -> void:
    var tree: Node3D = Node3D.new()
    tree.name = "Tree_%02d" % index
    tree.position = Vector3(pos.x, terrain_height(pos.x, pos.z), pos.z)
    parent.add_child(tree)
    mesh_cylinder(0.35, 3.2, Color("#6f472d"), tree, Vector3(0, 1.6, 0), "Trunk")
    mesh_sphere(1.7, Color("#2f7f46"), tree, Vector3(0, 3.4, 0), "LeafBall")
    mesh_sphere(1.15, Color("#3e9650"), tree, Vector3(0.9, 3.9, 0.1), "LeafBallSide")
    mesh_sphere(1.05, Color("#3e9650"), tree, Vector3(-0.8, 3.8, -0.1), "LeafBallSide")
    var body: StaticBody3D = StaticBody3D.new()
    body.name = "TreeCollision"
    tree.add_child(body)
    var col: CollisionShape3D = CollisionShape3D.new()
    var capsule: CapsuleShape3D = CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 3.2
    col.shape = capsule
    col.position = Vector3(0, 1.6, 0)
    body.add_child(col)

func build_cemetery() -> void:
    var cemetery: Node3D = $Cemetery
    var ground_y: float = terrain_height(-10.0, -7.0)
    cemetery.position.y = ground_y
    mesh_box(Vector3(11, 0.12, 8), Color("#4d8247"), cemetery, Vector3(-10, 0.17, -7), "CemeteryGround")
    for row in range(3):
        for col in range(4):
            var x: float = -14.0 + float(col) * 2.5
            var z: float = -9.5 + float(row) * 2.3
            var grave: Node3D = Node3D.new()
            grave.name = "Grave_%d_%d" % [row, col]
            grave.position = Vector3(x + 10.0, 0.25, z + 7.0)
            cemetery.add_child(grave)
            mesh_box(Vector3(0.65, 1.1, 0.22), Color("#d9d9cf"), grave, Vector3(0, 0.55, 0), "Tombstone")
            mesh_box(Vector3(0.75, 0.16, 0.18), Color("#d9d9cf"), grave, Vector3(0, 0.95, 0), "TombstoneTop")
            mesh_box(Vector3(0.16, 0.8, 0.20), Color("#d9d9cf"), grave, Vector3(0, 0.58, 0), "Cross")
            mesh_box(Vector3(0.7, 0.10, 1.1), Color("#4f3829"), grave, Vector3(0, 0.05, 0.9), "Dirt")
    mesh_box(Vector3(12, 0.25, 0.25), Color("#80572f"), cemetery, Vector3(0, 0.45, -4), "Fence")
    mesh_box(Vector3(12, 0.25, 0.25), Color("#80572f"), cemetery, Vector3(0, 0.45, 4), "Fence")

func build_props() -> void:
    var props: Node3D = $Props
    for i in range(12):
        var x: float = -8.0 + float((i * 7) % 17)
        var z: float = 2.0 + float((i * 5) % 14)
        var color: Color = [Color("#d9823b"), Color("#e6c44f"), Color("#4f9bd1"), Color("#b85d66")][i % 4]
        make_physics_box(props, Vector3(x, 0.0, z), Vector3(1.5, 1.5, 1.5), color, "Crate_%02d" % i)
    for i in range(5):
        var barrel: RigidBody3D = make_physics_cylinder(props, Vector3(11.0 + float(i) * 1.5, 0.0, 3.0), 0.55, 1.5, Color("#b66a39"), "Barrel_%02d" % i)
        barrel.rotation_degrees.z = 90.0
    for p in [Vector3(3, 0.0, 5), Vector3(-4, 0.0, 5)]:
        var y: float = terrain_height(p.x, p.z)
        mesh_box(Vector3(3.0, 0.25, 0.5), Color("#8b5a32"), props, Vector3(p.x, y + 0.82, p.z), "BenchSeat")
        mesh_box(Vector3(0.25, 0.8, 0.25), Color("#6c4327"), props, Vector3(p.x - 1.1, y + 0.0, p.z), "BenchLeg")
        mesh_box(Vector3(0.25, 0.8, 0.25), Color("#6c4327"), props, Vector3(p.x + 1.1, y + 0.0, p.z), "BenchLeg")
    var fire_y: float = terrain_height(0.0, 8.0)
    mesh_cylinder(1.1, 0.18, Color("#5a5a5a"), props, Vector3(0, fire_y + 0.25, 8), "FirePit")
    mesh_sphere(0.45, Color("#ff9b32"), props, Vector3(0, fire_y + 0.75, 8), "Fire")

func make_physics_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, object_name: String) -> RigidBody3D:
    var body: RigidBody3D = RigidBody3D.new()
    body.name = object_name
    body.position = Vector3(pos.x, terrain_height(pos.x, pos.z) + size.y * 0.5 + 0.06, pos.z)
    body.mass = 1.2
    body.linear_damp = 0.25
    body.angular_damp = 0.4
    body.add_to_group("blocks")
    parent.add_child(body)
    var mesh: MeshInstance3D = mesh_box(size, color, body, Vector3.ZERO, "Mesh")
    mesh.material_override = mat(color)
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    blocks.append(body)
    world_objects.append(body)
    return body

func make_physics_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, object_name: String) -> RigidBody3D:
    var body: RigidBody3D = RigidBody3D.new()
    body.name = object_name
    body.position = Vector3(pos.x, terrain_height(pos.x, pos.z) + height * 0.5 + 0.06, pos.z)
    body.mass = 1.5
    body.linear_damp = 0.3
    body.angular_damp = 0.45
    body.add_to_group("blocks")
    parent.add_child(body)
    mesh_cylinder(radius, height, color, body, Vector3.ZERO, "Mesh")
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: CylinderShape3D = CylinderShape3D.new()
    shape.radius = radius
    shape.height = height
    collision.shape = shape
    body.add_child(collision)
    blocks.append(body)
    world_objects.append(body)
    return body

func build_building_materials() -> void:
    var builds: Node3D = $BuildZone
    for i in range(8):
        var x: float = -2.0 + float(i % 4) * 1.8
        var z: float = -2.0
        var p: Vector3 = Vector3(x, 0.0, z)
        var colors: Array[Color] = [Color("#a86b3f"), Color("#d9a441"), Color("#7b8791"), Color("#78a85b")]
        make_physics_box(builds, p, Vector3(1.5, 1.0, 1.0), colors[i % colors.size()], "BuildMaterial_%02d" % i)

func setup_ui() -> void:
    status_label = $UI/Status
    status_label.text = "CHAOS ISLAND 0.3\nExplore • Grab E • Throw R • Trigger disaster F\nBuild a shelter and survive the tsunami!"

func _process(delta: float) -> void:
    time_alive += delta
    if status_label != null and not disaster_active:
        status_label.text = "CHAOS ISLAND 0.3\nExplore the island • E grab • R throw • F tsunami\nLake • Cemetery • Trees • Build Zone"

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F:
            tsunami()

func tsunami() -> void:
    if disaster_active:
        return
    disaster_active = true
    status_label.text = "⚠ TSUNAMI! SURVIVE! ⚠"
    var player: CharacterBody3D = $Player
    player.velocity.y = 16.0
    for block in blocks:
        if is_instance_valid(block):
            var offset: Vector3 = block.global_position - Vector3(0, 0, 0)
            var distance: float = offset.length()
            var direction: Vector3 = offset.normalized() if distance > 0.01 else Vector3.FORWARD
            var impulse: Vector3 = direction * (24.0 / (distance + 1.0)) + Vector3.UP * 11.0
            block.apply_central_impulse(impulse)
    var wave: Node3D = Node3D.new()
    wave.name = "TsunamiWave"
    add_child(wave)
    for side in range(4):
        var w: MeshInstance3D
        if side < 2:
            w = mesh_box(Vector3(1.0, 3.0, 38.0), Color("#58b9e8"), wave, Vector3(-20.0 if side == 0 else 20.0, 1.5, 0), "Wave")
        else:
            w = mesh_box(Vector3(38.0, 3.0, 1.0), Color("#58b9e8"), wave, Vector3(0, 1.5, -20.0 if side == 2 else 20.0), "Wave")
    var tween: Tween = create_tween()
    tween.tween_property(wave, "scale", Vector3(0.45, 1.0, 0.45), 1.2)
    tween.tween_callback(wave.queue_free)
    await get_tree().create_timer(5.0).timeout
    disaster_active = false
