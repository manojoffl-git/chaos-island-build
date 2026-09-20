extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_speed: float = 7.5
@export var gravity: float = 18.0
@export var mouse_sensitivity: float = 0.0025
@export var camera_distance: float = 8.5
@export var camera_height: float = 4.0
@export var mobile_look_sensitivity: float = 0.045

var held: RigidBody3D = null
var mobile_move: Vector2 = Vector2.ZERO
var mobile_look: Vector2 = Vector2.ZERO
var camera_pitch: float = -0.34
var walk_time: float = 0.0
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
	left_arm = $CharacterVisual/LeftArm
	right_arm = $CharacterVisual/RightArm
	left_leg = $CharacterVisual/LeftLeg
	right_leg = $CharacterVisual/RightLeg
	body_visual = $CharacterVisual/Body
	head_visual = $CharacterVisual/Head

func _input(event: InputEvent) -> void:
	# Mouse camera is handled globally so the mobile CameraTouch Control cannot block it.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		rotate_y(-motion.relative.x * mouse_sensitivity)
		camera_pitch = clamp(camera_pitch - motion.relative.y * mouse_sensitivity, -1.05, 0.18)
		camera.rotation.x = camera_pitch
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var keyboard_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_vector: Vector2 = mobile_move if mobile_move.length() > 0.01 else keyboard_vector
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
	if Input.is_action_just_pressed("grab"):
		mobile_grab()
	if held != null:
		move_held_block()
	if Input.is_action_just_pressed("throw"):
		mobile_throw()
	_apply_mobile_camera(delta)
	move_and_slide()

func _apply_mobile_camera(delta: float) -> void:
	if mobile_look.length() > 0.01:
		rotate_y(-mobile_look.x * mobile_look_sensitivity * delta * 60.0)
		camera_pitch = clamp(camera_pitch - mobile_look.y * mobile_look_sensitivity * delta * 60.0, -1.05, 0.18)
		camera.rotation.x = camera_pitch

func mobile_jump() -> void:
	if is_on_floor():
		velocity.y = jump_speed

func mobile_grab() -> void:
	if held == null:
		grab_nearest_block()
	else:
		release_block()

func mobile_throw() -> void:
	if held != null:
		throw_block()

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
	move_held_block()
	var block: RigidBody3D = held
	held = null
	block.freeze = false
	block.sleeping = false
	block.apply_central_impulse(-global_transform.basis.z * 12.0 + Vector3.UP * 5.0)
