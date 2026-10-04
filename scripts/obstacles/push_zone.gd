extends ObstacleBase
class_name PushZone
## Pushes players along a direction while inside (puddle, wind, conveyor).

@export var push_direction: Vector3 = Vector3(0, 0, 1)
@export var push_force: float = 6.0

var _inside: Dictionary = {}

func _on_player_enter(player: BuddyPlayer) -> void:
	_inside[player.get_instance_id()] = player
	AudioManager.play_boing(global_position)

func _on_player_exit(player: BuddyPlayer) -> void:
	_inside.erase(player.get_instance_id())

func _tick(delta: float) -> void:
	for p in _inside.values():
		if is_instance_valid(p) and p.is_multiplayer_authority():
			p.impulse += push_direction.normalized() * push_force * delta * 3.0
