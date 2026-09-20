extends Control

signal look_changed(value: Vector2)

var touch_id := -1
var last_position := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			last_position = event.position
			accept_event()
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			look_changed.emit(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		var delta := event.position - last_position
		last_position = event.position
		look_changed.emit(delta)
		accept_event()
