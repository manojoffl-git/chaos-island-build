class_name TsunamiWave
extends Node3D

signal wave_progress(progress: float, current_pos: Vector3, distance_to_center: float)
signal wave_finished

@export var duration: float = 120.0
@export var spawn_radius: float = 380.0
@export var wave_height: float = 36.0
@export var wave_width: float = 520.0
@export var push_force: float = 35.0

var start_pos: Vector3 = Vector3.ZERO
var end_pos: Vector3 = Vector3.ZERO
var travel_dir: Vector3 = Vector3.FORWARD
var elapsed: float = 0.0
var is_active: bool = false

var _player: CharacterBody3D
var _blocks: Array[RigidBody3D] = []

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		_player = get_parent().get_node_or_null("Player") as CharacterBody3D

	for node in get_tree().get_nodes_in_group("blocks"):
		if node is RigidBody3D:
			_blocks.append(node as RigidBody3D)

func start_wave(custom_duration: float = -1.0) -> void:
	if custom_duration > 0.0:
		duration = custom_duration

	# Random ocean direction
	var angle: float = randf() * TAU
	start_pos = Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
	end_pos = -start_pos
	travel_dir = (end_pos - start_pos).normalized()

	global_position = start_pos
	look_at(global_position + travel_dir, Vector3.UP)

	elapsed = 0.0
	is_active = true

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	elapsed += delta
	var t: float = clamp(elapsed / duration, 0.0, 1.0)
	global_position = start_pos.lerp(end_pos, t)

	var dist_to_center: float = global_position.length()
	if travel_dir.dot(global_position) > 0.0:
		dist_to_center = -dist_to_center # Moving away from center

	wave_progress.emit(t, global_position, dist_to_center)

	# Dynamic water physics push on player and objects
	_apply_wave_physics(delta)

	if t >= 1.0:
		is_active = false
		wave_finished.emit()
		queue_free()

func _apply_wave_physics(delta: float) -> void:
	var wave_speed: float = (start_pos.distance_to(end_pos)) / max(0.1, duration)
	var wave_impact_dist: float = 24.0

	# 1. Player water interaction
	if is_instance_valid(_player):
		var to_player: Vector3 = _player.global_position - global_position
		var forward_dist: float = travel_dir.dot(to_player)
		var lateral_dist: float = abs((travel_dir.cross(Vector3.UP)).dot(to_player))

		if abs(forward_dist) < wave_impact_dist and lateral_dist < (wave_width * 0.48):
			# Push player with surging water force
			var push_power: float = clamp(1.0 - (abs(forward_dist) / wave_impact_dist), 0.0, 1.0)
			_player.velocity += (travel_dir * (wave_speed * 1.5 + 8.0) + Vector3.UP * 14.0) * push_power * delta * 18.0
			_player.velocity.y = min(_player.velocity.y, 22.0)

	# 2. Rigid body blocks & props interaction
	for block in _blocks:
		if is_instance_valid(block) and not block.freeze:
			var to_block: Vector3 = block.global_position - global_position
			var forward_dist: float = travel_dir.dot(to_block)
			var lateral_dist: float = abs((travel_dir.cross(Vector3.UP)).dot(to_block))

			if abs(forward_dist) < wave_impact_dist and lateral_dist < (wave_width * 0.48):
				var push_power: float = clamp(1.0 - (abs(forward_dist) / wave_impact_dist), 0.0, 1.0)
				var impulse: Vector3 = (travel_dir * (wave_speed * 2.0 + push_force) + Vector3.UP * 12.0) * push_power
				block.apply_central_impulse(impulse * delta * 12.0)
