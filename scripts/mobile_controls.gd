extends CanvasLayer
@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var move_joystick: Control = $MoveJoystick
@onready var look_joystick: Control = $LookJoystick
var look_sensitivity := 0.012
var camera_pitch := -0.34
func _ready() -> void:
	camera_pitch = player.camera_pitch
	move_joystick.value_changed.connect(_on_move_changed)
	$Actions/Jump.pressed.connect(_jump)
	$Actions/Grab.pressed.connect(_grab)
	$Actions/Throw.pressed.connect(_throw)
	$Actions/Disaster.pressed.connect(_disaster)
func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	var look: Vector2 = look_joystick.value
	if look.length() > 0.01:
		player.rotate_y(-look.x * look_sensitivity)
		camera_pitch = clamp(camera_pitch - look.y * look_sensitivity, -1.05, 0.18)
		player.camera_pitch = camera_pitch
		player.camera.rotation.x = camera_pitch
func _on_move_changed(value: Vector2) -> void:
	player.mobile_move = value
func _jump() -> void:
	if player.is_on_floor(): player.velocity.y = player.jump_speed
func _grab() -> void:
	if player.held == null: player.grab_nearest_block()
	else: player.release_block()
func _throw() -> void:
	if player.held != null: player.throw_block()
func _disaster() -> void:
	get_parent().tsunami()
