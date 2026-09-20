extends Control

signal look_changed(value: Vector2)

var touch_id: int = -1
var last_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# This control only handles finger input. PC mouse input is handled globally by Player.
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and touch_id == -1:
			touch_id = touch.index
			last_position = touch.position
			accept_event()
		elif not touch.pressed and touch.index == touch_id:
			touch_id = -1
			look_changed.emit(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == touch_id:
			var delta: Vector2 = drag.position - last_position
			last_position = drag.position
			look_changed.emit(delta)
			accept_event()
