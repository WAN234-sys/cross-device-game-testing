extends Node
class_name MultiPlateController
## Opens a gate only while ALL its pressure plates are pressed at once.
## Plates are far apart, so it always takes 2+ buddies. The host decides and
## tells everyone, so the gate state is identical on every screen.

@export var plates: Array[PressurePlate] = []
@export var gate: PuzzleGate
@export var stay_open: bool = true

var _solved := false

func _ready() -> void:
	add_to_group("gate_puzzles")
	for p in plates:
		p.activated.connect(_evaluate)
		p.deactivated.connect(_evaluate)
	GameManager.coop_state_changed.connect(func(_r): _evaluate())

func _evaluate() -> void:
	if _solved and stay_open:
		return
	# Only the host (or offline) decides
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not GameManager.is_coop_ready():
		return
	var all_on := plates.size() > 0
	for p in plates:
		if not p.is_active:
			all_on = false
			break
	if all_on:
		_solved = true
		NetworkManager.broadcast_gate(gate.get_path(), true)
	elif not stay_open:
		NetworkManager.broadcast_gate(gate.get_path(), false)
