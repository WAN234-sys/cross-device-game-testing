extends Node3D
class_name ObstacleBase
## Base for all map hazards. Subclasses override _activate/_deactivate and
## _on_player_enter/_on_player_stay/_on_player_exit. The obstacle can be
## toggled on/off by phases or puzzle state.

@export var active: bool = true
@export var damage_cooldown: float = 1.0  # seconds between re-hits
@export var phase_required: int = 1  # only active at this phase or later

var _cooldowns: Dictionary = {}  # peer_id -> remaining seconds

func _ready() -> void:
	add_to_group("obstacles")
	if has_node("HitZone"):
		var zone: Area3D = $HitZone
		zone.body_entered.connect(func(b): if active and b is BuddyPlayer: _on_player_enter(b))
		zone.body_exited.connect(func(b): if b is BuddyPlayer: _on_player_exit(b))

func _process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0:
			_cooldowns.erase(id)
	if active:
		_tick(delta)

## Override in subclasses for per-frame behavior (patrol, animation, etc.)
func _tick(_delta: float) -> void:
	pass

func _on_player_enter(player: BuddyPlayer) -> void:
	_apply_effect(player)

func _on_player_exit(_player: BuddyPlayer) -> void:
	pass

func _apply_effect(player: BuddyPlayer) -> void:
	if _cooldowns.has(player.peer_id):
		return
	_cooldowns[player.peer_id] = damage_cooldown
	_hit(player)

## Override: what happens when a player touches this obstacle.
func _hit(_player: BuddyPlayer) -> void:
	pass
