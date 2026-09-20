extends CanvasLayer

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var move_joystick: Control = $MoveJoystick
@onready var look_joystick: Control = $LookJoystick

func _ready() -> void:
	move_joystick.value_changed.connect(_on_move_changed)
	$Actions/Jump.pressed.connect(_jump)
	$Actions/Grab.pressed.connect(_grab)
	$Actions/Throw.pressed.connect(_throw)
	$Actions/Disaster.pressed.connect(_disaster)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	player.mobile_look = look_joystick.value

func _on_move_changed(value: Vector2) -> void:
	player.mobile_move = value

func _jump() -> void:
	player.mobile_jump()

func _grab() -> void:
	player.mobile_grab()

func _throw() -> void:
	player.mobile_throw()

func _disaster() -> void:
	get_parent().tsunami()
