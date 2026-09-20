extends Control

signal look_changed(value: Vector2)

var touch_id: int = -1
var last_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Do not consume mouse input on PC. Touch is handled through _unhandled_input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and touch_id == -1 and get_global_rect().has_point(touch.position):
			touch_id = touch.index
			last_position = touch.position
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == touch_id:
			touch_id = -1
			look_changed.emit(Vector2.ZERO)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == touch_id:
			var delta: Vector2 = drag.position - last_position
			last_position = drag.position
			look_changed.emit(delta)
			get_viewport().set_input_as_handled()
