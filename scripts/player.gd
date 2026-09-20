extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_speed: float = 7.5
@export var gravity: float = 18.0
@export var mouse_sensitivity: float = 0.0025
@export var camera_distance: float = 8.5
@export var camera_height: float = 4.0

var held: RigidBody3D = null
var camera_pitch: float = -0.34
var walk_time: float = 0.0
var was_moving: bool = false
var visual_root: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var body_visual: Node3D
var head_visual: Node3D

@onready var camera: Camera3D = $Camera

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    camera.current = true
    camera.position = Vector3(0.0, camera_height, camera_distance)
    camera.rotation = Vector3(camera_pitch, 0.0, 0.0)
    build_character()

func make_mat(color: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.82
    return material

func add_capsule(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3, node_name: String) -> MeshInstance3D:
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    mesh_node.name = node_name
    var mesh: CapsuleMesh = CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    mesh.rings = 4
    mesh_node.mesh = mesh
    mesh_node.material_override = make_mat(color)
    mesh_node.position = pos
    parent.add_child(mesh_node)
    return mesh_node

func add_sphere(parent: Node3D, radius: float, color: Color, pos: Vector3, node_name: String) -> MeshInstance3D:
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    mesh_node.name = node_name
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    mesh_node.mesh = mesh
    mesh_node.material_override = make_mat(color)
    mesh_node.position = pos
    parent.add_child(mesh_node)
    return mesh_node

func add_limb(pivot: Node3D, length: float, radius: float, color: Color, name: String) -> void:
    var limb: MeshInstance3D = MeshInstance3D.new()
    limb.name = name
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 1.08
    mesh.height = length
    mesh.radial_segments = 10
    limb.mesh = mesh
    limb.material_override = make_mat(color)
    limb.position = Vector3(0.0, -length * 0.5, 0.0)
    pivot.add_child(limb)

func build_character() -> void:
    visual_root = Node3D.new()
    visual_root.name = "CharacterVisual"
    add_child(visual_root)

    body_visual = Node3D.new()
    body_visual.name = "CapsuleBody"
    body_visual.position = Vector3(0, 1.25, 0)
    visual_root.add_child(body_visual)
    add_capsule(body_visual, 0.55, 1.65, Color("#e8a63b"), Vector3.ZERO, "Body")

    head_visual = Node3D.new()
    head_visual.name = "SphereHead"
    head_visual.position = Vector3(0, 2.45, 0)
    visual_root.add_child(head_visual)
    add_sphere(head_visual, 0.68, Color("#f1bd4d"), Vector3.ZERO, "Head")

    add_sphere(head_visual, 0.09, Color("#20252b"), Vector3(-0.23, 0.10, -0.60), "LeftEye")
    add_sphere(head_visual, 0.09, Color("#20252b"), Vector3(0.23, 0.10, -0.60), "RightEye")
    var beak: MeshInstance3D = add_sphere(head_visual, 0.16, Color("#d46f32"), Vector3(0, -0.08, -0.68), "Beak")
    beak.scale = Vector3(1.35, 0.65, 1.0)

    left_arm = Node3D.new()
    left_arm.name = "LeftArm"
    left_arm.position = Vector3(-0.62, 1.72, 0)
    visual_root.add_child(left_arm)
    add_limb(left_arm, 1.15, 0.12, Color("#e8a63b"), "ThinArm")
    add_sphere(left_arm, 0.15, Color("#f1bd4d"), Vector3(0, -1.15, 0), "Hand")

    right_arm = Node3D.new()
    right_arm.name = "RightArm"
    right_arm.position = Vector3(0.62, 1.72, 0)
    visual_root.add_child(right_arm)
    add_limb(right_arm, 1.15, 0.12, Color("#e8a63b"), "ThinArm")
    add_sphere(right_arm, 0.15, Color("#f1bd4d"), Vector3(0, -1.15, 0), "Hand")

    left_leg = Node3D.new()
    left_leg.name = "LeftLeg"
    left_leg.position = Vector3(-0.27, 0.55, 0)
    visual_root.add_child(left_leg)
    add_limb(left_leg, 1.15, 0.13, Color("#4d7199"), "ThinLeg")
    add_sphere(left_leg, 0.16, Color("#354c69"), Vector3(0, -1.16, -0.12), "Foot")

    right_leg = Node3D.new()
    right_leg.name = "RightLeg"
    right_leg.position = Vector3(0.27, 0.55, 0)
    visual_root.add_child(right_leg)
    add_limb(right_leg, 1.15, 0.13, Color("#4d7199"), "ThinLeg")
    add_sphere(right_leg, 0.16, Color("#354c69"), Vector3(0, -1.16, -0.12), "Foot")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera_pitch = clamp(camera_pitch - event.relative.y * mouse_sensitivity, -1.05, 0.18)
        camera.rotation.x = camera_pitch
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y)
    if direction.length() > 1.0:
        direction = direction.normalized()

    var world_direction: Vector3 = global_transform.basis * direction
    world_direction.y = 0.0
    if world_direction.length() > 0.001:
        world_direction = world_direction.normalized()

    var moving: bool = world_direction.length() > 0.01
    velocity.x = move_toward(velocity.x, world_direction.x * speed, speed * 8.0 * delta)
    velocity.z = move_toward(velocity.z, world_direction.z * speed, speed * 8.0 * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_speed

    if moving:
        walk_time += delta * 9.0
        var swing: float = sin(walk_time) * 0.55
        left_arm.rotation.x = swing
        right_arm.rotation.x = -swing
        left_leg.rotation.x = -swing
        right_leg.rotation.x = swing
        body_visual.position.y = 1.25 + abs(sin(walk_time * 2.0)) * 0.035
        head_visual.position.y = 2.45 + abs(sin(walk_time * 2.0)) * 0.045
    else:
        left_arm.rotation.x = lerp(left_arm.rotation.x, 0.0, delta * 8.0)
        right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, delta * 8.0)
        left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 8.0)
        right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 8.0)
        walk_time = 0.0

    # Tap E once to grab. Tap E again to drop. No holding required.
    # While held, the object follows the player every physics frame.
    # R throws the held object from the player's current position.
    if Input.is_action_just_pressed("grab"):
        if held == null:
            grab_nearest_block()
        else:
            release_block()

    if held != null:
        move_held_block()

    if Input.is_action_just_pressed("throw") and held != null:
        throw_block()

    move_and_slide()

func grab_nearest_block() -> void:
    var nearest: RigidBody3D = null
    var nearest_distance: float = 4.0
    var forward: Vector3 = -global_transform.basis.z
    for node in get_tree().get_nodes_in_group("blocks"):
        if node is RigidBody3D:
            var block: RigidBody3D = node as RigidBody3D
            var offset: Vector3 = block.global_position - global_position
            var distance: float = offset.length()
            var facing: float = forward.dot(offset.normalized()) if distance > 0.01 else 1.0
            if distance < nearest_distance and facing > -0.35:
                nearest = block
                nearest_distance = distance
    if nearest != null:
        held = nearest
        held.freeze = true
        held.sleeping = true
        move_held_block()

func move_held_block() -> void:
    if not is_instance_valid(held):
        held = null
        return
    # Recalculate the held position from the player's current transform,
    # so it follows correctly while walking and turning.
    held.global_position = global_position + (-global_transform.basis.z * 2.0) + Vector3.UP * 1.25
    held.global_rotation = Vector3.ZERO

func release_block() -> void:
    if not is_instance_valid(held):
        held = null
        return
    held.freeze = false
    held.sleeping = false
    held = null

func throw_block() -> void:
    if not is_instance_valid(held):
        held = null
        return
    # Make sure the object is at the player's current hand position before throwing.
    move_held_block()
    var block: RigidBody3D = held
    held = null
    block.freeze = false
    block.sleeping = false
    block.apply_central_impulse(-global_transform.basis.z * 12.0 + Vector3.UP * 5.0)
