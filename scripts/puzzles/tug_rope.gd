extends Node3D
class_name TugRope
## Two players must pull opposite ends of a rope to open a gate.
## Each player holds interact on their end; progress only advances when BOTH pull.

signal gate_opened
signal progress_changed(value: float)

@export var pull_speed: float = 0.15
@export var decay_speed: float = 0.08

var progress: float = 0.0  # 0 to 1
var puller_a: BuddyPlayer = null
var puller_b: BuddyPlayer = null
var is_open: bool = false

@onready var end_a: Area3D = $EndA
@onready var end_b: Area3D = $EndB
@onready var rope_mesh: MeshInstance3D = $RopeMesh
@onready var gate: Node3D = $ConnectedGate

func _ready() -> void:
	end_a.body_entered.connect(func(body): if body is BuddyPlayer: puller_a = body)
	end_a.body_exited.connect(func(body): if body == puller_a: puller_a = null)
	end_b.body_entered.connect(func(body): if body is BuddyPlayer: puller_b = body)
	end_b.body_exited.connect(func(body): if body == puller_b: puller_b = null)

func _process(delta: float) -> void:
	if is_open:
		return

	var both_pulling := puller_a != null and puller_b != null
	if both_pulling:
		# Check both are holding interact
		var a_pulling := puller_a.is_multiplayer_authority() and Input.is_action_pressed("interact")
		var b_pulling := puller_b.is_multiplayer_authority() and Input.is_action_pressed("interact")
		# In multiplayer, we'd sync this via RPC. For now, local check:
		if a_pulling or b_pulling:
			progress = clampf(progress + pull_speed * delta, 0.0, 1.0)
		else:
			progress = clampf(progress - decay_speed * delta, 0.0, 1.0)
	else:
		progress = clampf(progress - decay_speed * delta, 0.0, 1.0)

	progress_changed.emit(progress)
	_update_visual()

	if progress >= 1.0:
		is_open = true
		gate_opened.emit()
		if gate and gate.has_method("open"):
			gate.open()
		AudioManager.play_boing(global_position)

func _update_visual() -> void:
	# Stretch/color the rope mesh based on progress
	if rope_mesh:
		rope_mesh.scale.x = 1.0 + progress * 0.5
		var mat: StandardMaterial3D = rope_mesh.get_surface_override_material(0)
		if mat:
			mat = mat.duplicate()
			mat.albedo_color = Color.YELLOW.lerp(Color.GREEN, progress)
			rope_mesh.set_surface_override_material(0, mat)
