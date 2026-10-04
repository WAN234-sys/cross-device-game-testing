extends AnimatableBody3D
class_name PhaseGate
## A big gate between map phases. Opens when:
##   1. QuestManager says this map reached `phase` (quests done), AND
##   2. at least 2 buddies are in the game (co-op rule — solo can't pass gates).
## Shows what's still needed on a sign.

@export var map_id: String = "kitchen_counter"
@export var phase: int = 2
@export var width: float = 3.0
@export var height: float = 2.8

var is_open := false
var _closed_y := 0.0
var _sign: Label3D

func _ready() -> void:
	add_to_group("phase_gates")
	_closed_y = position.y
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(width, height, 0.6)
	cs.shape = box
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = box.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.5, 0.65); mat.metallic = 0.7; mat.roughness = 0.3
	mi.material_override = mat
	add_child(mi)
	# Stripes so it reads as a gate, not a wall
	for i in 3:
		var bar := MeshInstance3D.new()
		var bb := BoxMesh.new(); bb.size = Vector3(width + 0.05, 0.18, 0.65)
		bar.mesh = bb
		var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(1, 0.8, 0.1)
		bar.material_override = bmat
		bar.position.y = -height / 2.0 + 0.5 + i * 0.9
		add_child(bar)
	_sign = Label3D.new()
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.font_size = 44
	_sign.outline_size = 10
	_sign.position.y = height / 2.0 + 0.6
	add_child(_sign)
	QuestManager.phase_unlocked.connect(func(_m, _p): _refresh())
	GameManager.coop_state_changed.connect(func(_r): _refresh())
	_refresh()

func _refresh() -> void:
	var quests_ok := QuestManager.current_phase(map_id) >= phase
	var coop_ok := GameManager.is_coop_ready()
	if quests_ok and coop_ok:
		_open()
		return
	var need := []
	if not quests_ok:
		need.append("finish %d quests" % ((phase - 1) * 2 - QuestManager.quests_done(map_id)))
	if not coop_ok:
		need.append("a buddy (solo can't pass)")
	_sign.text = "🔒 PHASE %d\nNeeds: %s" % [phase, ", ".join(need)]

func _open() -> void:
	if is_open:
		return
	is_open = true
	_sign.text = "🔓 PHASE %d" % phase
	var t := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", _closed_y + height + 0.4, 1.2)
	AudioManager.play_boing(global_position)
