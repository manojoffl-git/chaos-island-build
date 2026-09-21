extends Node3D

const TSUNAMI_WAVE = preload("res://scenes/TsunamiWave.tscn")

var disaster_active: bool = false
var tsunami_duration: float = 120.0 # Default 2 minutes (120s)
var active_wave: Node3D = null

var blocks: Array[RigidBody3D] = []
var time_alive: float = 0.0

# UI References
var status_label: Label
var duration_slider: HSlider
var duration_value_label: Label
var trigger_button: Button
var disaster_panel: PanelContainer
var wave_progress_bar: ProgressBar

func _ready() -> void:
	call_deferred("_initialize_world")

func _initialize_world() -> void:
	await get_tree().process_frame
	var island = get_node_or_null("Island")
	var player: CharacterBody3D = $Player

	var spawn_xz: Vector2 = Vector2(0.0, 6.0)
	var spawn_y: float = 2.0
	if island != null and island.has_method("get_height_at"):
		spawn_y = island.get_height_at(spawn_xz.x, spawn_xz.y) + 1.2
	player.global_position = Vector3(spawn_xz.x, spawn_y, spawn_xz.y)
	player.velocity = Vector3.ZERO

	# Align world objects to procedural terrain
	if island != null and island.has_method("get_height_at"):
		var world_objects: Node3D = get_node_or_null("WorldObjects")
		if world_objects != null:
			_align_node_hierarchy_to_terrain(world_objects, island)

	blocks.clear()
	for node in get_tree().get_nodes_in_group("blocks"):
		if node is RigidBody3D:
			blocks.append(node as RigidBody3D)

	setup_ui()

func _align_node_hierarchy_to_terrain(parent: Node3D, island: Node) -> void:
	for child in parent.get_children():
		if child is Node3D:
			if child.get_child_count() > 0 and not (child is RigidBody3D or child is MeshInstance3D):
				_align_node_hierarchy_to_terrain(child, island)
			else:
				var pos: Vector3 = child.global_position
				var ground_h: float = island.get_height_at(pos.x, pos.z)
				if ground_h > -2.0:
					child.global_position.y = ground_h + max(0.2, child.position.y)
					if child is RigidBody3D:
						(child as RigidBody3D).linear_velocity = Vector3.ZERO
						(child as RigidBody3D).angular_velocity = Vector3.ZERO

func setup_ui() -> void:
	var ui: CanvasLayer = $UI
	status_label = ui.get_node_or_null("Status") as Label
	if status_label == null:
		status_label = Label.new()
		status_label.name = "Status"
		ui.add_child(status_label)

	status_label.offset_left = 28.0
	status_label.offset_top = 20.0
	status_label.offset_right = 800.0
	status_label.offset_bottom = 90.0
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.text = "CHAOS ISLAND 0.3 • Explore • E grab • R throw • F tsunami"

	_build_disaster_ui_panel(ui)

func _build_disaster_ui_panel(ui: CanvasLayer) -> void:
	# Check if panel already exists
	if ui.has_node("DisasterControlPanel"):
		disaster_panel = ui.get_node("DisasterControlPanel") as PanelContainer
		return

	disaster_panel = PanelContainer.new()
	disaster_panel.name = "DisasterControlPanel"
	ui.add_child(disaster_panel)

	# Position panel top-center / top-left nicely styled
	disaster_panel.offset_left = 28.0
	disaster_panel.offset_top = 95.0
	disaster_panel.offset_right = 380.0
	disaster_panel.offset_bottom = 325.0

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.18, 0.85)
	panel_style.border_color = Color(0.25, 0.65, 0.95, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	disaster_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	disaster_panel.add_child(vbox)

	# Panel Header
	var title_lbl = Label.new()
	title_lbl.text = "🌊 TSUNAMI EVENT CONTROL"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1))
	vbox.add_child(title_lbl)

	# Duration readout
	duration_value_label = Label.new()
	_update_duration_display()
	duration_value_label.add_theme_font_size_override("font_size", 13)
	duration_value_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1))
	vbox.add_child(duration_value_label)

	# Duration Slider (5s to 180s)
	duration_slider = HSlider.new()
	duration_slider.min_value = 5.0
	duration_slider.max_value = 180.0
	duration_slider.step = 1.0
	duration_slider.value = tsunami_duration
	duration_slider.value_changed.connect(_on_duration_slider_changed)
	vbox.add_child(duration_slider)

	# Preset Buttons Row
	var hbox_presets = HBoxContainer.new()
	hbox_presets.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox_presets)

	var presets: Array[Dictionary] = [
		{"label": "10s (Test)", "val": 10.0},
		{"label": "30s", "val": 30.0},
		{"label": "60s (1m)", "val": 60.0},
		{"label": "120s (2m)", "val": 120.0}
	]

	for preset in presets:
		var btn = Button.new()
		btn.text = preset.label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 11)
		var val: float = preset.val
		btn.pressed.connect(func(): _set_duration(val))
		hbox_presets.add_child(btn)

	# Trigger / Cancel Button
	trigger_button = Button.new()
	trigger_button.text = "🌊 START TSUNAMI EVENT"
	trigger_button.custom_minimum_size = Vector2(0, 32)
	trigger_button.add_theme_font_size_override("font_size", 13)
	trigger_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.45, 0.85, 0.9)
	btn_style.set_corner_radius_all(6)
	trigger_button.add_theme_stylebox_override("normal", btn_style)
	trigger_button.pressed.connect(_on_trigger_button_pressed)
	vbox.add_child(trigger_button)

	# Wave Progress Bar
	wave_progress_bar = ProgressBar.new()
	wave_progress_bar.min_value = 0.0
	wave_progress_bar.max_value = 1.0
	wave_progress_bar.value = 0.0
	wave_progress_bar.show_percentage = false
	wave_progress_bar.custom_minimum_size = Vector2(0, 8)
	wave_progress_bar.visible = false
	vbox.add_child(wave_progress_bar)

	# Object Rotation Sensitivity Section
	var sens_separator = HSeparator.new()
	vbox.add_child(sens_separator)

	var sens_lbl = Label.new()
	sens_lbl.name = "SensLabel"
	sens_lbl.text = "Object Rotation Sensitivity: 1.0x"
	sens_lbl.add_theme_font_size_override("font_size", 12)
	sens_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1))
	vbox.add_child(sens_lbl)

	var sens_slider = HSlider.new()
	sens_slider.min_value = 0.2
	sens_slider.max_value = 3.0
	sens_slider.step = 0.1
	sens_slider.value = 1.0
	sens_slider.value_changed.connect(func(v: float):
		var p = get_node_or_null("Player")
		if p != null and "object_rotation_sensitivity" in p:
			p.object_rotation_sensitivity = v
		sens_lbl.text = "Object Rotation Sensitivity: %.1fx" % [v]
	)
	vbox.add_child(sens_slider)

func _set_duration(val: float) -> void:
	tsunami_duration = clamp(val, 5.0, 180.0)
	if duration_slider != null:
		duration_slider.value = tsunami_duration
	_update_duration_display()

func _on_duration_slider_changed(value: float) -> void:
	tsunami_duration = value
	_update_duration_display()

func _update_duration_display() -> void:
	if duration_value_label == null:
		return
	var mins: int = int(tsunami_duration) / 60
	var secs: int = int(tsunami_duration) % 60
	if mins > 0:
		duration_value_label.text = "Duration: %ds (%dm %02ds)" % [int(tsunami_duration), mins, secs]
	else:
		duration_value_label.text = "Duration: %ds (Test Speed)" % [int(tsunami_duration)]

func _on_trigger_button_pressed() -> void:
	if disaster_active:
		cancel_tsunami()
	else:
		tsunami()

func _process(delta: float) -> void:
	time_alive += delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		if disaster_active:
			cancel_tsunami()
		else:
			tsunami()

func tsunami() -> void:
	if disaster_active:
		return
	disaster_active = true

	if trigger_button != null:
		trigger_button.text = "⏹ CANCEL TSUNAMI"
		var cancel_style = StyleBoxFlat.new()
		cancel_style.bg_color = Color(0.85, 0.25, 0.25, 0.9)
		cancel_style.set_corner_radius_all(6)
		trigger_button.add_theme_stylebox_override("normal", cancel_style)

	if wave_progress_bar != null:
		wave_progress_bar.visible = true
		wave_progress_bar.value = 0.0

	# Spawn TsunamiWave
	active_wave = TSUNAMI_WAVE.instantiate()
	add_child(active_wave)
	active_wave.wave_progress.connect(_on_wave_progress)
	active_wave.wave_finished.connect(_on_wave_finished)
	active_wave.start_wave(tsunami_duration)

func cancel_tsunami() -> void:
	if not disaster_active:
		return
	if is_instance_valid(active_wave):
		active_wave.queue_free()
		active_wave = null
	_reset_disaster_ui("Tsunami cancelled.")

func _on_wave_progress(progress: float, current_pos: Vector3, dist_to_center: float) -> void:
	if wave_progress_bar != null:
		wave_progress_bar.value = progress

	var eta: float = max(0.0, (1.0 - progress) * tsunami_duration)
	if status_label != null:
		if dist_to_center > 15.0:
			status_label.text = "⚠ TSUNAMI APPROACHING! Distance: %dm | ETA: %.1fs\nFind high ground or build a barrier!" % [int(dist_to_center), eta]
			status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
		elif dist_to_center >= -25.0:
			status_label.text = "🌊 TSUNAMI SWEEPING OVER ISLAND! HOLD ON!\nETA to clear: %.1fs" % [eta]
			status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1))
		else:
			status_label.text = "🌊 TSUNAMI PASSING INTO OCEAN: %dm\nTime until all clear: %.1fs" % [int(abs(dist_to_center)), eta]
			status_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 1))

func _on_wave_finished() -> void:
	active_wave = null
	_reset_disaster_ui("✅ TSUNAMI PASSED! Island survived.\nPress F or tap button to trigger again.")

func _reset_disaster_ui(final_message: String = "") -> void:
	disaster_active = false
	if trigger_button != null:
		trigger_button.text = "🌊 START TSUNAMI EVENT"
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.12, 0.45, 0.85, 0.9)
		btn_style.set_corner_radius_all(6)
		trigger_button.add_theme_stylebox_override("normal", btn_style)

	if wave_progress_bar != null:
		wave_progress_bar.visible = false

	if status_label != null:
		status_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		if final_message != "":
			status_label.text = final_message
		else:
			status_label.text = "CHAOS ISLAND 0.3 • Explore • E grab • R throw • F tsunami"
