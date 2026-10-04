extends AnimatableBody3D
class_name PuzzleGate
## A gate that slides up when its puzzle is solved.

@export var open_offset: Vector3 = Vector3(0, 3.2, 0)
@export var open_duration: float = 1.0

var is_open: bool = false
var _closed_position: Vector3

func _ready() -> void:
	add_to_group("gates")
	_closed_position = position
	_update_label()

func open() -> void:
	if is_open:
		return
	is_open = true
	var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _closed_position + open_offset, open_duration)
	AudioManager.play_boing(global_position)
	_update_label()

func close() -> void:
	if not is_open:
		return
	is_open = false
	var tween := create_tween()
	tween.tween_property(self, "position", _closed_position, open_duration * 0.5)
	_update_label()

func _update_label() -> void:
	var l := get_node_or_null("Label") as Label3D
	if l:
		l.visible = not is_open
