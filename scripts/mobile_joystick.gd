extends Control
signal value_changed(value: Vector2)
@export var radius := 92.0
@export var knob_radius := 38.0
var touch_id := -1
var value := Vector2.ZERO
var knob := Vector2.ZERO
func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_update_value(event.position)
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			value = Vector2.ZERO
			knob = Vector2.ZERO
			value_changed.emit(value)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_update_value(event.position)
func _update_value(pos: Vector2) -> void:
	var offset := pos - size * 0.5
	if offset.length() > radius:
		offset = offset.normalized() * radius
	knob = offset
	value = offset / radius
	if value.length() < 0.12:
		value = Vector2.ZERO
	value_changed.emit(value)
	queue_redraw()
func _draw() -> void:
	var center := size * 0.5
	draw_circle(center + Vector2(0, 6), radius + 4, Color(0, 0, 0, 0.28))
	draw_circle(center, radius, Color(0.05, 0.07, 0.09, 0.62))
	draw_arc(center, radius - 3, 0.0, TAU, 64, Color(1, 1, 1, 0.13), 3.0)
	draw_circle(center + knob + Vector2(0, 4), knob_radius, Color(0, 0, 0, 0.3))
	draw_circle(center + knob, knob_radius, Color(1, 0.78, 0.12, 0.92))
	draw_arc(center + knob, knob_radius - 3, 0.0, TAU, 48, Color(1, 0.94, 0.68, 0.8), 2.0)
