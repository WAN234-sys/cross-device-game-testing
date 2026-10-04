extends Area3D
class_name PressurePlate
## Lights up when a buddy stands on it. Several plates far apart (see
## MultiPlateController) are what force teamwork — one player can't cover both.

signal activated
signal deactivated

@export var required_players: int = 1
@export var plate_color: Color = Color(1, 0.82, 0.1)
@export var active_color: Color = Color(0.35, 1, 0.45)

@onready var label: Label3D = get_node_or_null("RequiredLabel")

var current_players: int = 0
var is_active: bool = false
var _glow: OmniLight3D
var _ring: MeshInstance3D
var _ring_mat := StandardMaterial3D.new()

func _ready() -> void:
	add_to_group("plates")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Always-visible glowing ring on top of the model so state is obvious,
	# even after the GLB model replaces the placeholder.
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.15
	_ring.mesh = torus
	_ring.position.y = 0.18
	_ring_mat.emission_enabled = true
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _ring_mat
	add_child(_ring)
	_glow = OmniLight3D.new()
	_glow.position.y = 0.6
	_glow.omni_range = 3.5
	add_child(_glow)
	_update_visual()

func _on_body_entered(body: Node3D) -> void:
	if body is BuddyPlayer:
		current_players += 1
		_check_activation()

func _on_body_exited(body: Node3D) -> void:
	if body is BuddyPlayer:
		current_players = maxi(current_players - 1, 0)
		_check_activation()

func _check_activation() -> void:
	var was_active := is_active
	is_active = current_players >= required_players
	_update_visual()
	if is_active and not was_active:
		activated.emit()
		AudioManager.play_boing(global_position)
	elif not is_active and was_active:
		deactivated.emit()

func _update_visual() -> void:
	var c := active_color if is_active else plate_color
	_ring_mat.albedo_color = c
	_ring_mat.emission = c
	_ring_mat.emission_energy_multiplier = 2.5 if is_active else 0.8
	_glow.light_color = c
	_glow.light_energy = 2.0 if is_active else 0.6
	var ph := get_node_or_null("PlateMesh") as MeshInstance3D
	if ph and ph.visible:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		ph.material_override = m
	if label:
		label.text = "✅" if is_active else "⬇ stand here"
		label.modulate = c
