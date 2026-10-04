extends ObstacleBase
class_name DarkRoom
## Makes a zone pitch black. Only players near a "flashlight carrier" can see.
## Other players see a fog. Used in Grandma's Attic.

@export var fog_density: float = 0.95
@export var light_radius: float = 8.0

var _fog_env: Environment
var _light: OmniLight3D

func _ready() -> void:
	super._ready()
	# The darkness is added by enabling fog on the WorldEnvironment.
	# This is a placeholder: real implementation would use a shader or
	# per-player viewport darkening. For now, add a spotlight to the first
	# player who enters.

func _on_player_enter(player: BuddyPlayer) -> void:
	if not player.is_multiplayer_authority():
		return
	# Give the player a flashlight if they don't have one
	if not player.has_node("Flashlight"):
		var light := SpotLight3D.new()
		light.name = "Flashlight"
		light.spot_range = light_radius
		light.spot_angle = 35.0
		light.light_energy = 2.5
		light.shadow_enabled = true
		player.get_node("Head/Camera3D").add_child(light)

func _on_player_exit(player: BuddyPlayer) -> void:
	var fl := player.get_node_or_null("Head/Camera3D/Flashlight")
	if fl:
		fl.queue_free()
