extends CharacterBody3D

const HELD_HIGHLIGHT_SHADER = preload("res://shaders/HeldHighlight.gdshader")

@export var speed: float = 6.0
@export var jump_speed: float = 7.5
@export var gravity: float = 18.0
@export var mouse_sensitivity: float = 0.0025
@export var camera_distance: float = 7.5
@export var camera_height: float = 2.3
@export var mobile_look_sensitivity: float = 0.045
@export var turn_speed: float = 14.0
@export var max_grab_distance: float = 8.5
@export var hold_target_node: Node3D = null
@export var object_rotation_sensitivity: float = 1.0

var held: RigidBody3D = null
var held_rel_basis: Basis = Basis.IDENTITY
var held_custom_basis: Basis = Basis.IDENTITY
var is_rotating_held_object: bool = false
var mobile_rotate_object: Vector2 = Vector2.ZERO
var targeted_block: RigidBody3D = null

var can_weld: bool = false
var weld_targets: Array[RigidBody3D] = []

var held_highlight_mat: ShaderMaterial
var saved_mesh_materials: Dictionary = {}
var saved_shape_disabled: Dictionary = {}
var saved_collision_layer: int = 1
var saved_collision_mask: int = 1

var mobile_move: Vector2 = Vector2.ZERO
var mobile_look: Vector2 = Vector2.ZERO
var camera_yaw: float = 0.0
var camera_pitch: float = -0.30
var walk_time: float = 0.0
var idle_time: float = 0.0

var character_visual: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var body_visual: Node3D
var head_visual: Node3D
var tail_rig: Node3D

@onready var camera_mount: Node3D = get_node_or_null("CameraMount")
@onready var spring_arm: SpringArm3D = get_node_or_null("CameraMount/SpringArm3D") if has_node("CameraMount/SpringArm3D") else get_node_or_null("SpringArm3D")
@onready var camera: Camera3D = spring_arm.get_node("Camera") if spring_arm != null and spring_arm.has_node("Camera") else get_node_or_null("SpringArm3D/Camera")
@onready var hold_target: Node3D = (camera.get_node_or_null("HoldTarget") if camera != null else null)
@onready var grab_prompt: Label3D = get_node_or_null("GrabPrompt")
@onready var weld_prompt: Label3D = get_node_or_null("WeldPrompt")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if spring_arm != null:
		spring_arm.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	if camera != null:
		camera.current = true

	held_highlight_mat = ShaderMaterial.new()
	held_highlight_mat.shader = HELD_HIGHLIGHT_SHADER

	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true
	floor_stop_on_slope = true

	character_visual = $CharacterVisual
	left_arm = $CharacterVisual/LeftArm
	right_arm = $CharacterVisual/RightArm
	left_leg = $CharacterVisual/LeftLeg
	right_leg = $CharacterVisual/RightLeg
	body_visual = $CharacterVisual/Body
	head_visual = $CharacterVisual/HeadRig
	tail_rig = $CharacterVisual/TailRig

	if grab_prompt != null:
		grab_prompt.visible = false
	if weld_prompt != null:
		weld_prompt.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_button.pressed and held != null:
				is_rotating_held_object = true
			else:
				is_rotating_held_object = false
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			spring_arm.spring_length = clamp(spring_arm.spring_length - 0.5, 2.0, 16.0)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			spring_arm.spring_length = clamp(spring_arm.spring_length + 0.5, 2.0, 16.0)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if is_rotating_held_object and held != null:
			rotate_held_object(motion.relative)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			camera_yaw -= motion.relative.x * mouse_sensitivity
			camera_pitch = clamp(camera_pitch - motion.relative.y * mouse_sensitivity, -1.2, 0.45)
			if spring_arm != null:
				spring_arm.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				is_rotating_held_object = false
			elif key_event.keycode == KEY_C:
				mobile_weld()

func rotate_held_object(relative: Vector2) -> void:
	if held == null:
		return
	var rot_speed: float = mouse_sensitivity * object_rotation_sensitivity * 1.8
	var rot_pitch: float = -relative.y * rot_speed
	var rot_yaw: float = -relative.x * rot_speed
	var rot_step: Basis = Basis(Vector3.UP, rot_yaw) * Basis(Vector3.RIGHT, rot_pitch)
	held_custom_basis = (rot_step * held_custom_basis).orthonormalized()

func _physics_process(delta: float) -> void:
	var keyboard_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_vector: Vector2 = mobile_move if mobile_move.length() > 0.01 else keyboard_vector

	# Movement relative to camera yaw
	var cam_basis: Basis = Basis(Vector3.UP, camera_yaw)
	var move_dir: Vector3 = cam_basis * Vector3(input_vector.x, 0.0, input_vector.y)
	move_dir.y = 0.0
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	var moving: bool = move_dir.length() > 0.01

	if moving:
		# Smoothly rotate character visual towards movement direction
		var target_angle: float = atan2(-move_dir.x, -move_dir.z)
		character_visual.rotation.y = lerp_angle(character_visual.rotation.y, target_angle, delta * turn_speed)

		velocity.x = move_toward(velocity.x, move_dir.x * speed, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * speed, speed * 8.0 * delta)

		walk_time += delta * 9.0
		idle_time = 0.0
		var swing: float = sin(walk_time) * 0.55
		left_arm.rotation.x = swing
		right_arm.rotation.x = -swing
		left_leg.rotation.x = -swing
		right_leg.rotation.x = swing
		body_visual.position.y = 1.25 + abs(sin(walk_time * 2.0)) * 0.035
		head_visual.position.y = 2.45 + abs(sin(walk_time * 2.0)) * 0.045
		head_visual.rotation = head_visual.rotation.lerp(Vector3.ZERO, delta * 8.0)
		tail_rig.rotation.y = lerp(tail_rig.rotation.y, 0.0, delta * 8.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)
		walk_time = 0.0
		idle_time += delta
		_update_idle_animation(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed

	if Input.is_action_just_pressed("grab"):
		mobile_grab()

	# Mobile rotation of held object
	if held != null and mobile_rotate_object.length() > 0.01:
		var rot_speed: float = 3.0 * object_rotation_sensitivity * delta
		var rot_pitch: float = -mobile_rotate_object.y * rot_speed
		var rot_yaw: float = -mobile_rotate_object.x * rot_speed
		var rot_step: Basis = Basis(Vector3.UP, rot_yaw) * Basis(Vector3.RIGHT, rot_pitch)
		held_custom_basis = (rot_step * held_custom_basis).orthonormalized()

	if held != null:
		move_held_block()
		_check_weld_overlap()
	else:
		can_weld = false
		weld_targets.clear()
		if weld_prompt != null:
			weld_prompt.visible = false

	if Input.is_action_just_pressed("throw"):
		mobile_throw()

	_update_crosshair_targeting()
	_apply_mobile_camera(delta)
	move_and_slide()

func _update_crosshair_targeting() -> void:
	if held != null:
		targeted_block = null
		if grab_prompt != null:
			grab_prompt.visible = false
		return

	var cam: Camera3D = camera
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var ray_origin: Vector3 = cam.project_ray_origin(screen_center)
	var ray_dir: Vector3 = cam.project_ray_normal(screen_center)

	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 35.0)
	ray_query.exclude = [self.get_rid()]
	ray_query.collide_with_bodies = true
	ray_query.collide_with_areas = false

	var hit: Dictionary = space_state.intersect_ray(ray_query)
	var candidate: RigidBody3D = null

	if not hit.is_empty():
		var collider = hit["collider"]
		if collider is RigidBody3D and collider.is_in_group("blocks"):
			var dist: float = global_position.distance_to(collider.global_position)
			if dist <= max_grab_distance:
				candidate = collider

	targeted_block = candidate
	if grab_prompt != null:
		if targeted_block != null:
			grab_prompt.global_position = targeted_block.global_position + Vector3.UP * 0.9
			grab_prompt.visible = true
		else:
			grab_prompt.visible = false

func _check_weld_overlap() -> void:
	if not is_instance_valid(held):
		can_weld = false
		weld_targets.clear()
		if weld_prompt != null:
			weld_prompt.visible = false
		return

	var targets: Array[RigidBody3D] = []
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shapes: Array[Node] = held.find_children("*", "CollisionShape3D", true, false)

	for shape_node in shapes:
		if shape_node is CollisionShape3D and shape_node.shape != null:
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = shape_node.shape
			query.transform = shape_node.global_transform
			query.exclude = [self.get_rid(), held.get_rid()]
			query.collide_with_bodies = true
			query.collide_with_areas = false
			query.margin = 0.15

			var intersections: Array[Dictionary] = space_state.intersect_shape(query, 16)
			for hit in intersections:
				var collider = hit.get("collider")
				if collider is RigidBody3D and collider.is_in_group("blocks") and collider != held:
					if not targets.has(collider):
						targets.append(collider)

	# Fallback distance check for closest proximity contact
	if targets.is_empty():
		var closest_node: RigidBody3D = null
		var min_dist: float = 3.5
		for node in get_tree().get_nodes_in_group("blocks"):
			if node is RigidBody3D and node != held and is_instance_valid(node):
				var d: float = held.global_position.distance_to(node.global_position)
				if d < min_dist:
					min_dist = d
					closest_node = node as RigidBody3D
		if closest_node != null:
			targets.append(closest_node)

	targets.sort_custom(func(a: RigidBody3D, b: RigidBody3D):
		return held.global_position.distance_to(a.global_position) < held.global_position.distance_to(b.global_position)
	)

	weld_targets = targets
	can_weld = (weld_targets.size() > 0)

	if weld_prompt != null:
		if can_weld:
			var contact_pos: Vector3 = (held.global_position + weld_targets[0].global_position) * 0.5 + Vector3.UP * 0.75
			weld_prompt.global_position = contact_pos
			weld_prompt.visible = true
		else:
			weld_prompt.visible = false

func mobile_weld() -> void:
	if not can_weld or held == null or weld_targets.is_empty():
		return
	weld_held_object()

func weld_held_object() -> void:
	if not is_instance_valid(held) or weld_targets.is_empty():
		return

	var base_body: RigidBody3D = weld_targets[0]
	if not is_instance_valid(base_body):
		return

	# Synchronously transfer held object geometry and collision into base body as a unified solid piece
	var held_children: Array[Node] = []
	for child in held.get_children():
		held_children.append(child)

	for child in held_children:
		if child is Node3D:
			var g_xform: Transform3D = child.global_transform
			held.remove_child(child)
			base_body.add_child(child)
			child.global_transform = g_xform

			# Restore solid physics & default materials
			if child is CollisionShape3D:
				child.disabled = false
			for cs in child.find_children("*", "CollisionShape3D", true, false):
				if cs is CollisionShape3D:
					cs.disabled = false

			if child is MeshInstance3D:
				child.material_override = saved_mesh_materials.get(child, null)
			for mi in child.find_children("*", "MeshInstance3D", true, false):
				if mi is MeshInstance3D:
					mi.material_override = saved_mesh_materials.get(mi, null)

	# Add mass to base structure
	base_body.mass += held.mass
	base_body.freeze = false
	base_body.sleeping = false

	# Clean up held object
	remove_collision_exception_with(held)
	remove_collision_exception_with(base_body)
	held.queue_free()
	held = null

	saved_mesh_materials.clear()
	saved_shape_disabled.clear()
	can_weld = false
	weld_targets.clear()
	is_rotating_held_object = false
	mobile_rotate_object = Vector2.ZERO

	if weld_prompt != null:
		weld_prompt.visible = false

func _get_active_hold_target() -> Node3D:
	if hold_target_node != null:
		return hold_target_node
	if hold_target != null:
		return hold_target
	if camera != null:
		var cam_ht = camera.get_node_or_null("HoldTarget")
		if cam_ht != null:
			return cam_ht
		return camera
	return self

func _update_idle_animation(delta: float) -> void:
	var breath: float = sin(idle_time * 2.2)
	var sway: float = sin(idle_time * 1.35)
	var slow_sway: float = sin(idle_time * 0.8)
	body_visual.position.y = lerp(body_visual.position.y, 1.25 + breath * 0.025, delta * 5.0)
	head_visual.position.y = lerp(head_visual.position.y, 2.45 + breath * 0.035, delta * 5.0)
	left_arm.rotation.x = lerp(left_arm.rotation.x, 0.045 + sway * 0.035, delta * 5.0)
	right_arm.rotation.x = lerp(right_arm.rotation.x, -0.045 - sway * 0.035, delta * 5.0)
	left_leg.rotation.x = lerp(left_leg.rotation.x, -0.018 + slow_sway * 0.012, delta * 4.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x, 0.018 - slow_sway * 0.012, delta * 4.0)
	head_visual.rotation.y = lerp(head_visual.rotation.y, sin(idle_time * 0.72) * 0.035, delta * 3.5)
	head_visual.rotation.z = lerp(head_visual.rotation.z, sin(idle_time * 0.58) * 0.018, delta * 3.5)
	tail_rig.rotation.y = lerp(tail_rig.rotation.y, sin(idle_time * 1.7) * 0.08, delta * 4.0)
	tail_rig.rotation.x = lerp(tail_rig.rotation.x, deg_to_rad(-8.0) + sin(idle_time * 1.2) * 0.025, delta * 4.0)

func _apply_mobile_camera(delta: float) -> void:
	if mobile_look.length() > 0.01:
		camera_yaw -= mobile_look.x * mobile_look_sensitivity * delta * 60.0
		camera_pitch = clamp(camera_pitch - mobile_look.y * mobile_look_sensitivity * delta * 60.0, -1.2, 0.45)
		if spring_arm != null:
			spring_arm.rotation = Vector3(camera_pitch, camera_yaw, 0.0)

func mobile_jump() -> void:
	if is_on_floor():
		velocity.y = jump_speed

func mobile_grab() -> void:
	if held == null:
		if targeted_block != null:
			grab_block(targeted_block)
	else:
		release_block()

func mobile_throw() -> void:
	if held != null:
		throw_block()

func grab_block(block: RigidBody3D) -> void:
	if not is_instance_valid(block):
		return
	held = block
	held.freeze = true
	held.sleeping = true
	held_custom_basis = Basis.IDENTITY
	is_rotating_held_object = false
	mobile_rotate_object = Vector2.ZERO

	var target_node: Node3D = _get_active_hold_target()
	held_rel_basis = target_node.global_transform.basis.inverse() * held.global_transform.basis

	add_collision_exception_with(held)
	held.add_collision_exception_with(self)

	_apply_held_state(held)

	if grab_prompt != null:
		grab_prompt.visible = false
	targeted_block = null

	move_held_block()

func move_held_block() -> void:
	if not is_instance_valid(held):
		held = null
		return
	var target_node: Node3D = _get_active_hold_target()
	held.global_position = target_node.global_position
	held.global_transform.basis = (target_node.global_transform.basis * held_rel_basis * held_custom_basis).orthonormalized()

func release_block() -> void:
	if not is_instance_valid(held):
		held = null
		return
	var block: RigidBody3D = held
	_restore_held_state(block)
	remove_collision_exception_with(block)
	block.remove_collision_exception_with(self)
	block.freeze = false
	block.sleeping = false
	held = null
	can_weld = false
	weld_targets.clear()
	is_rotating_held_object = false
	mobile_rotate_object = Vector2.ZERO
	if weld_prompt != null:
		weld_prompt.visible = false

func throw_block() -> void:
	if not is_instance_valid(held):
		held = null
		return
	var block: RigidBody3D = held
	_restore_held_state(block)
	remove_collision_exception_with(block)
	block.remove_collision_exception_with(self)
	held = null
	block.freeze = false
	block.sleeping = false
	can_weld = false
	weld_targets.clear()
	is_rotating_held_object = false
	mobile_rotate_object = Vector2.ZERO
	if weld_prompt != null:
		weld_prompt.visible = false

	# Throw in camera aim direction
	var cam: Camera3D = camera
	var throw_dir: Vector3 = -cam.global_transform.basis.z if cam != null else -character_visual.global_transform.basis.z
	throw_dir.y = max(-0.15, throw_dir.y) # Prevent throwing straight down
	block.apply_central_impulse(throw_dir.normalized() * 16.0 + Vector3.UP * 4.0)

func _apply_held_state(block: RigidBody3D) -> void:
	saved_mesh_materials.clear()
	saved_shape_disabled.clear()
	saved_collision_layer = block.collision_layer
	saved_collision_mask = block.collision_mask

	# 1. Deactivate collision completely while held
	block.collision_layer = 0
	block.collision_mask = 0
	var shapes: Array[Node] = block.find_children("*", "CollisionShape3D", true, false)
	for shape in shapes:
		if shape is CollisionShape3D:
			saved_shape_disabled[shape] = shape.disabled
			shape.disabled = true

	# 2. Apply lesser alpha & glowing border highlight across all child meshes
	var meshes: Array[Node] = block.find_children("*", "MeshInstance3D", true, false)

	for mesh in meshes:
		if mesh is MeshInstance3D:
			saved_mesh_materials[mesh] = mesh.material_override
			mesh.material_override = held_highlight_mat

func _restore_held_state(block: RigidBody3D) -> void:
	if not is_instance_valid(block):
		saved_mesh_materials.clear()
		saved_shape_disabled.clear()
		return

	# 1. Restore collision
	block.collision_layer = saved_collision_layer
	block.collision_mask = saved_collision_mask
	for shape in saved_shape_disabled.keys():
		if is_instance_valid(shape):
			shape.disabled = saved_shape_disabled[shape]
	saved_shape_disabled.clear()

	# 2. Restore original materials
	for mesh in saved_mesh_materials.keys():
		if is_instance_valid(mesh):
			mesh.material_override = saved_mesh_materials[mesh]
	saved_mesh_materials.clear()
