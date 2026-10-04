extends FriendNPC
class_name QuestNPC
## An NPC that gives a quest. Talk (E) to read the briefing; when the quest's
## goal is met, talk again to turn it in. A floating icon shows state:
##   ❗ quest available   🔒 locked (later phase)   ⏳ in progress   ✅ done
##
## Quest types (set quest_type):
##   "fetch"    — carry `fetch_item` (a QuestItem) back to this NPC
##   "collect"  — pick up `target_count` QuestItems with `fetch_item` id
##   "plates"   — all plates in group `plate_group` pressed at once (co-op)
##   "reach"    — any buddy reaches the QuestMarker with id `marker_id`
##   "survive"  — stay inside zone `marker_id` for `target_count` seconds
##   "talk"     — talk to NPC named `talk_to` then come back

@export var map_id: String = "kitchen_counter"
@export var quest_index: int = 0
@export var quest_title: String = "A small favor"
@export var quest_type: String = "fetch"
@export var fetch_item: String = ""
@export var target_count: int = 1
@export var plate_group: String = ""
@export var marker_id: String = ""
@export var talk_to: String = ""
@export_multiline var intro_lines: Array[String] = []
@export_multiline var done_lines: Array[String] = ["Thanks, buddy!"]
@export var locked_line: String = "Come back later. I'm busy being important."

var _icon: Label3D
var _accepted := false

func _ready() -> void:
	super._ready()
	add_to_group("quest_npcs")
	_icon = Label3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.font_size = 96
	_icon.outline_size = 12
	_icon.no_depth_test = true
	_icon.position = Vector3(0, 2.3, 0)
	add_child(_icon)
	QuestManager.quest_completed.connect(func(_m, _i): _refresh_icon())
	QuestManager.phase_unlocked.connect(func(_m, _p): _refresh_icon())
	QuestTracker.quest_ready.connect(func(m, i): if m == map_id and i == quest_index: _refresh_icon())
	_refresh_icon()

func is_done() -> bool:
	return quest_index in QuestManager.completed.get(map_id, [])

func _refresh_icon() -> void:
	if is_done():
		_icon.text = "✅"
	elif not QuestManager.is_quest_available(map_id, quest_index):
		_icon.text = "🔒"
	elif QuestTracker.is_ready(map_id, quest_index):
		_icon.text = "❓"  # come turn it in
	elif _accepted or QuestTracker.is_active(map_id, quest_index):
		_icon.text = "⏳"
	else:
		_icon.text = "❗"

func interact(player: BuddyPlayer) -> void:
	if is_talking:
		_advance_dialogue()
		return
	if is_done():
		dialogue_lines = done_lines
	elif not QuestManager.is_quest_available(map_id, quest_index):
		dialogue_lines = [locked_line, "(Finish more quests to unlock phase %d.)" % QuestManager.quest_phase(quest_index)]
	elif quest_type == "fetch" and player.carried_item == fetch_item:
		player.carried_item = ""
		player.update_carry_visual()
		QuestTracker.request_complete(map_id, quest_index)
		dialogue_lines = done_lines
	elif QuestTracker.is_ready(map_id, quest_index):
		QuestTracker.request_complete(map_id, quest_index)
		dialogue_lines = done_lines
	else:
		_accepted = true
		QuestTracker.activate(map_id, quest_index, self)
		dialogue_lines = intro_lines + ["Quest: %s" % quest_title]
	_start_dialogue()
	_refresh_icon()
