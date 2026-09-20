extends Node3D

const TSUNAMI_WAVE = preload("res://scenes/TsunamiWave.tscn")

var disaster_active: bool = false
var blocks: Array[RigidBody3D] = []
var time_alive: float = 0.0
var status_label: Label

func _ready() -> void:
    call_deferred("_initialize_world")

func _initialize_world() -> void:
    await get_tree().process_frame
    var player: CharacterBody3D = $Player
    player.global_position = Vector3(0.0, 0.26, 6.0)
    player.velocity = Vector3.ZERO
    blocks.clear()
    for node in get_tree().get_nodes_in_group("blocks"):
        if node is RigidBody3D:
            blocks.append(node as RigidBody3D)
    setup_ui()

func setup_ui() -> void:
    status_label = $UI/Status
    status_label.text = "CHAOS ISLAND 0.3\nExplore • Grab E • Throw R • Trigger disaster F\nBuild a shelter and survive the tsunami!"

func _process(delta: float) -> void:
    time_alive += delta
    if status_label != null and not disaster_active:
        status_label.text = "CHAOS ISLAND 0.3\nExplore the island • E grab • R throw • F tsunami\nPermanent scene meshes • Physics objects ready"

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
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
            var offset: Vector3 = block.global_position
            var distance: float = offset.length()
            var direction: Vector3 = offset.normalized() if distance > 0.01 else Vector3.FORWARD
            block.apply_central_impulse(direction * (24.0 / (distance + 1.0)) + Vector3.UP * 11.0)
    var wave: Node3D = TSUNAMI_WAVE.instantiate()
    add_child(wave)
    var tween: Tween = create_tween()
    tween.tween_property(wave, "scale", Vector3(0.45, 1.0, 0.45), 1.2)
    tween.tween_callback(wave.queue_free)
    await get_tree().create_timer(5.0).timeout
    disaster_active = false
