extends Area3D
class_name QuestItem
## A pickup for quests. Two modes:
##   carry = true  → the toucher carries it (shown above head) for "fetch" quests
##   carry = false → counts toward a "collect" quest when touched, then vanishes

@export var item_id: String = "salt"
@export var label: String = "🧂"
@export var map_id: String = "kitchen_counter"
@export var quest_index: int = 0
@export var carry: bool = true
@export var model_path: String = ""
@export var model_size: float = 0.8

var _taken := false
var _pivot: Node3D

func _ready() -> void:
	add_to_group("quest_items")
	collision_layer = 8
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new(); s.radius = 0.9
	shape.shape = s
	add_child(shape)
	_pivot = Node3D.new()
	add_child(_pivot)
	var icon := Label3D.new()
	icon.text = label
	icon.font_size = 128
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.position.y = 0.6
	_pivot.add_child(icon)
	if model_path and ResourceLoader.exists(model_path):
		var m := ModelSwap.new()
		m.model_path = model_path
		m.target_size = model_size
		_pivot.add_child(m)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1, 0.9, 0.5)
	glow.omni_range = 3.0
	add_child(glow)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	if not SettingsManager.reduce_motion:
		_pivot.rotation.y += delta * 1.5
		_pivot.position.y = sin(Time.get_ticks_msec() / 400.0) * 0.12

func _on_body(b: Node3D) -> void:
	if _taken or not (b is BuddyPlayer) or not b.is_multiplayer_authority():
		return
	if not QuestManager.is_quest_available(map_id, quest_index):
		return
	if carry:
		if b.carried_item != "":
			return  # hands full
		b.carried_item = item_id
		b.update_carry_visual(label)
	else:
		QuestTracker.add_count(map_id, quest_index, 1)
	NetworkManager.broadcast_item_taken(get_path())

## Called on all peers when the host confirms the pickup.
func take_visual() -> void:
	if _taken:
		return
	_taken = true
	set_deferred("monitoring", false)
	AudioManager.play_boing(global_position)
	queue_free()
