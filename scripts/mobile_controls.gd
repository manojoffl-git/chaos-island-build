extends CanvasLayer

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var move_joystick: Control = $MoveJoystick
@onready var rotate_joystick: Control = get_node_or_null("RotateJoystick")
@onready var camera_touch: Control = $CameraTouch
@onready var weld_button: Button = get_node_or_null("Actions/Weld")

func _ready() -> void:
	move_joystick.value_changed.connect(_on_move_changed)
	if rotate_joystick != null:
		rotate_joystick.value_changed.connect(_on_rotate_changed)
		rotate_joystick.visible = false
	if weld_button != null:
		weld_button.pressed.connect(_weld)
		weld_button.visible = false
	camera_touch.look_changed.connect(_on_camera_changed)
	$Actions/Jump.pressed.connect(_jump)
	$Actions/Grab.pressed.connect(_grab)
	$Actions/Throw.pressed.connect(_throw)
	$Actions/Disaster.pressed.connect(_disaster)

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		if rotate_joystick != null:
			var should_show_rotate: bool = (player.held != null)
			if rotate_joystick.visible != should_show_rotate:
				rotate_joystick.visible = should_show_rotate
				if not should_show_rotate:
					player.mobile_rotate_object = Vector2.ZERO

		if weld_button != null:
			var should_show_weld: bool = (player.held != null and "can_weld" in player and player.can_weld)
			if weld_button.visible != should_show_weld:
				weld_button.visible = should_show_weld

func _on_move_changed(value: Vector2) -> void:
	if is_instance_valid(player):
		player.mobile_move = value

func _on_rotate_changed(value: Vector2) -> void:
	if is_instance_valid(player):
		player.mobile_rotate_object = value

func _on_camera_changed(delta: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var sensitivity: float = 0.005
	player.camera_yaw -= delta.x * sensitivity
	player.camera_pitch = clamp(player.camera_pitch - delta.y * sensitivity, -1.2, 0.45)
	if player.spring_arm != null:
		player.spring_arm.rotation = Vector3(player.camera_pitch, player.camera_yaw, 0.0)

func _jump() -> void:
	if is_instance_valid(player):
		player.mobile_jump()

func _grab() -> void:
	if is_instance_valid(player):
		player.mobile_grab()

func _throw() -> void:
	if is_instance_valid(player):
		player.mobile_throw()

func _weld() -> void:
	if is_instance_valid(player) and player.has_method("mobile_weld"):
		player.mobile_weld()

func _disaster() -> void:
	get_parent().tsunami()
