extends Node3D

var disaster_active: bool = false
var blocks: Array[RigidBody3D] = []
var world_objects: Array[RigidBody3D] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var time_alive: float = 0.0
var status_label: Label

func _ready() -> void:
    rng.seed = 424242
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

func build_world() -> void:
    # IslandGenerator exclusively owns terrain. The old prototype hills are removed
    # so the procedural terrain controls the island shape completely.
    build_lake()
    build_trees()
    build_cemetery()
    build_props()
    build_building_materials()

func build_island() -> void:
    pass

func build_lake() -> void:
    var lake: Node3D = $Lake
    var water: MeshInstance3D = mesh_cylinder(5.5, 0.18, Color("#4ea9d6"), lake, Vector3(8.0, 0.22, -7.0), "LakeWater")
    water.scale = Vector3(1.35, 1.0, 0.8)
    mesh_box(Vector3(5.0, 0.22, 1.2), Color("#9b6b3e"), lake, Vector3(8.0, 0.42, -1.4), "Dock")
    for i in range(3):
        mesh_cylinder(0.12, 1.2, Color("#68452d"), lake, Vector3(6.0 + float(i) * 2.0, -0.1, -1.4), "DockPost")

func build_hills() -> void:
    # TerrainGenerator provides the only terrain hills now.
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
    tree.position = pos
    parent.add_child(tree)
    mesh_cylinder(0.28, 2.6, Color("#6b4a32"), tree, Vector3(0, 1.3, 0), "Trunk")
    mesh_sphere(1.45, Color("#3f7d3d"), tree, Vector3(0, 3.0, 0), "Leaves")
    var body: StaticBody3D = StaticBody3D.new()
    body.name = "Collision"
    tree.add_child(body)
    var col: CollisionShape3D = CollisionShape3D.new()
    var shape: CylinderShape3D = CylinderShape3D.new()
    shape.radius = 0.3
    shape.height = 2.6
    col.shape = shape
    col.position = Vector3(0, 1.3, 0)
    body.add_child(col)

func build_cemetery() -> void:
    var cemetery: Node3D = $Cemetery
    for i in range(12):
        var x: float = -8.0 + float(i % 4) * 4.0
        var z: float = -2.0 + float(i / 4) * 4.0
        mesh_box(Vector3(0.35, 1.6, 0.8), Color("#b6b0a4"), cemetery, Vector3(x, 0.8, z), "Grave_%02d" % i)
    mesh_box(Vector3(22, 0.5, 0.25), Color("#6f573f"), cemetery, Vector3(-2, 0.25, -6), "FenceFront")

func build_props() -> void:
    var props: Node3D = $Props
    for i in range(10):
        var body: RigidBody3D = RigidBody3D.new()
        body.name = "PhysicsProp_%02d" % i
        body.position = Vector3(-10.0 + float(i % 5) * 5.0, 1.0, 6.0 + float(i / 5) * 5.0)
        props.add_child(body)
        var shape: CollisionShape3D = CollisionShape3D.new()
        var box: BoxShape3D = BoxShape3D.new()
        box.size = Vector3(1.4, 1.4, 1.4)
        shape.shape = box
        body.add_child(shape)
        mesh_box(Vector3(1.4, 1.4, 1.4), Color("#d28b45") if i % 2 == 0 else Color("#6f8f55"), body)
        blocks.append(body)
        world_objects.append(body)

func build_building_materials() -> void:
    var build: Node3D = $BuildZone
    for i in range(12):
        var size: Vector3 = Vector3(2.0, 0.35, 0.8) if i % 2 == 0 else Vector3(0.8, 2.0, 0.8)
        var body: RigidBody3D = RigidBody3D.new()
        body.name = "Material_%02d" % i
        body.position = Vector3(8.0 + float(i % 4) * 2.0, 1.0, 7.0 + float(i / 4) * 2.0)
        build.add_child(body)
        var shape: CollisionShape3D = CollisionShape3D.new()
        var box: BoxShape3D = BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)
        mesh_box(size, Color("#9b6b3e"), body)
        blocks.append(body)
        world_objects.append(body)
