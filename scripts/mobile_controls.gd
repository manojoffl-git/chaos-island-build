extends CanvasLayer

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var move_joystick: Control = $MoveJoystick
@onready var camera_touch: Control = $CameraTouch

func _ready() -> void:
	move_joystick.value_changed.connect(_on_move_changed)
	camera_touch.look_changed.connect(_on_camera_changed)
	$Actions/Jump.pressed.connect(_jump)
	$Actions/Grab.pressed.connect(_grab)
	$Actions/Throw.pressed.connect(_throw)
	$Actions/Disaster.pressed.connect(_disaster)

func _on_move_changed(value: Vector2) -> void:
	if is_instance_valid(player):
		player.mobile_move = value

func _on_camera_changed(delta: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var sensitivity := 0.012
	player.rotate_y(-delta.x * sensitivity)
	player.camera_pitch = clamp(player.camera_pitch - delta.y * sensitivity, -1.05, 0.18)
	player.camera.rotation.x = player.camera_pitch

func _jump() -> void:
	if is_instance_valid(player):
		player.mobile_jump()

func _grab() -> void:
	if is_instance_valid(player):
		player.mobile_grab()

func _throw() -> void:
	if is_instance_valid(player):
		player.mobile_throw()

func _disaster() -> void:
	get_parent().tsunami()
