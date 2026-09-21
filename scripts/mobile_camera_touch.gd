extends Control

signal look_changed(value: Vector2)

var touch_id: int = -1
var last_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		var viewport_w: float = get_viewport_rect().size.x
		# Only accept touches starting on the right half of the screen
		if touch.pressed and touch_id == -1:
			if touch.position.x >= viewport_w * 0.45 or (global_position.x + event.position.x) >= viewport_w * 0.45:
				touch_id = touch.index
				last_position = touch.position
				accept_event()
		elif not touch.pressed and touch.index == touch_id:
			touch_id = -1
			look_changed.emit(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		var delta: Vector2 = event.position - last_position
		last_position = event.position
		look_changed.emit(delta)
		accept_event()
