extends ObstacleBase
class_name SlowZone
## Slows the player (cobweb, mud, sticky floor). Effect while inside the zone.

@export var slow_multiplier: float = 0.35

## Uses the player's speed-modifier table so overlapping zones and
## disconnects can never leave a player permanently slowed.
func _on_player_enter(player: BuddyPlayer) -> void:
	player.speed_mods[get_instance_id()] = slow_multiplier

func _on_player_exit(player: BuddyPlayer) -> void:
	player.speed_mods.erase(get_instance_id())
