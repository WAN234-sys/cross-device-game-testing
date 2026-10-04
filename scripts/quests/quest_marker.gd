extends Area3D
class_name QuestMarker
## A spot in the world tied to a quest.
##   mode "reach"   → first buddy to arrive completes the step
##   mode "survive" → adds seconds while at least one buddy is inside
##   mode "talk"    → (placed on a secondary NPC) counts when visited

@export var map_id: String = "kitchen_counter"
@export var quest_index: int = 0
@export var mode: String = "reach"
@export var radius: float = 2.0
@export var label: String = "📍"
@export var hint: String = ""

var _inside := 0
var _done := false
var _label: Label3D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new(); s.radius = radius; s.height = 3.0
	cs.shape = s
	cs.position.y = 1.5
	add_child(cs)
	_label = Label3D.new()
	_label.text = label + ("\n" + hint if hint else "")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 56
	_label.outline_size = 10
	_label.position.y = 2.6
	add_child(_label)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new(); t.inner_radius = radius - 0.15; t.outer_radius = radius
	ring.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.8, 1.0); m.emission_enabled = true; m.emission = Color(0.4, 0.7, 1)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.position.y = 0.05
	add_child(ring)
	body_entered.connect(func(b): if b is BuddyPlayer and b.is_multiplayer_authority(): _enter())
	body_exited.connect(func(b): if b is BuddyPlayer and b.is_multiplayer_authority(): _inside = maxi(_inside - 1, 0))

func _enter() -> void:
	_inside += 1
	if mode in ["reach", "talk"] and not _done and QuestTracker.is_active(map_id, quest_index):
		_done = true
		QuestTracker.add_count(map_id, quest_index, 1)

func _process(delta: float) -> void:
	visible = QuestManager.is_quest_available(map_id, quest_index) and not (quest_index in QuestManager.completed.get(map_id, []))
	if mode == "survive" and _inside > 0 and QuestTracker.is_active(map_id, quest_index):
		QuestTracker.add_count(map_id, quest_index, delta)
