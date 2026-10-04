extends Area3D
class_name FriendshipToken
## Collectible token. The host is the source of truth: a touch asks the host,
## the host counts it once and tells everyone to hide that token.

@export var token_index: int = 0

var is_collected: bool = false
var _t := 0.0

@onready var visual: Node3D = _make_pivot()

## Wrap the visuals in a pivot so bobbing never fights ModelSwap's offsets.
func _make_pivot() -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	for n in ["TokenMesh", "Model"]:
		var c := get_node_or_null(n)
		if c:
			c.reparent(pivot, false)
	return pivot

func _ready() -> void:
	add_to_group("tokens")
	body_entered.connect(_on_body_entered)
	_t = token_index * 1.3

func _process(delta: float) -> void:
	if is_collected:
		return
	_t += delta
	visual.rotation.y += delta * 2.0
	if not SettingsManager.reduce_motion:
		visual.position.y = sin(_t * 2.0) * 0.15

func _on_body_entered(body: Node3D) -> void:
	if is_collected or not (body is BuddyPlayer):
		return
	if not body.is_multiplayer_authority():
		return  # only the toucher's own machine reports it
	NetworkManager.request_token(token_index)

## Called on every peer by the host once the token is confirmed.
func collect_visual() -> void:
	if is_collected:
		return
	is_collected = true
	set_deferred("monitoring", false)
	AudioManager.play_honk(global_position)
	var tween := create_tween()
	if SettingsManager.reduce_motion:
		tween.tween_interval(0.05)
	else:
		tween.tween_property(visual, "scale", Vector3(1.6, 1.6, 1.6), 0.12)
		tween.tween_property(visual, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
