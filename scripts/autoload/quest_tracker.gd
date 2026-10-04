extends Node
## Runtime quest logic for the current map: checks goals every frame, keeps
## the HUD's quest list updated, and syncs completions through the host.
## (QuestManager = saved progress & coins; QuestTracker = live quest state.)

signal quest_ready(map_id: String, quest_index: int)   # goal met, turn in to NPC
signal list_changed

var active: Dictionary = {}     # quest_index -> QuestNPC
var ready_set: Dictionary = {}  # quest_index -> true
var counters: Dictionary = {}   # quest_index -> float (items, seconds)
var current_map := ""

func reset(map_id: String) -> void:
	current_map = map_id
	active.clear()
	ready_set.clear()
	counters.clear()
	list_changed.emit()

func is_active(map_id: String, i: int) -> bool:
	return map_id == current_map and active.has(i)

func is_ready(map_id: String, i: int) -> bool:
	return map_id == current_map and ready_set.has(i)

func activate(map_id: String, i: int, npc: Node) -> void:
	if map_id != current_map:
		reset(map_id)
	active[i] = npc
	list_changed.emit()

## Called by items, markers, zones.
func add_count(map_id: String, i: int, amount: float = 1.0) -> void:
	if map_id != current_map:
		return
	counters[i] = counters.get(i, 0.0) + amount
	list_changed.emit()

func _process(delta: float) -> void:
	if current_map.is_empty() or not GameManager.is_playing:
		return
	for i in active.keys():
		var npc = active[i]  # QuestNPC — weak type to avoid circular dep
		if not is_instance_valid(npc) or ready_set.has(i) or npc.is_done():
			continue
		var met := false
		match npc.quest_type:
			"collect", "reach", "talk":
				met = counters.get(i, 0.0) >= npc.target_count
			"survive":
				met = counters.get(i, 0.0) >= npc.target_count
			"plates":
				var plates := get_tree().get_nodes_in_group(npc.plate_group)
				met = plates.size() > 0 and plates.all(func(p): return p.is_active)
				if met and not GameManager.is_coop_ready():
					met = false  # co-op plates need a buddy
			"fetch":
				met = false  # completed directly when the carrier talks to the NPC
		if met:
			ready_set[i] = true
			quest_ready.emit(current_map, i)
			list_changed.emit()

func request_complete(map_id: String, i: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_complete_rpc.rpc_id(1, map_id, i)
	else:
		_host_complete(map_id, i)

@rpc("any_peer", "reliable")
func _complete_rpc(map_id: String, i: int) -> void:
	if multiplayer.is_server():
		_host_complete(map_id, i)

func _host_complete(map_id: String, i: int) -> void:
	if i in QuestManager.completed.get(map_id, []):
		return
	if multiplayer.has_multiplayer_peer():
		_apply_complete.rpc(map_id, i)
	else:
		_apply_complete(map_id, i)

@rpc("authority", "call_local", "reliable")
func _apply_complete(map_id: String, i: int) -> void:
	QuestManager.complete_quest(map_id, i)
	active.erase(i)
	ready_set.erase(i)
	list_changed.emit()

## Text for the HUD quest list.
func describe(i: int) -> String:
	var npc = active.get(i)  # QuestNPC — weak type to avoid circular dep
	if not is_instance_valid(npc):
		return ""
	var prog := ""
	match npc.quest_type:
		"collect": prog = " (%d/%d)" % [int(counters.get(i, 0)), npc.target_count]
		"survive": prog = " (%ds/%ds)" % [int(counters.get(i, 0)), npc.target_count]
		"fetch": prog = " — bring it to %s" % npc.npc_name
	if ready_set.has(i):
		prog = " — ✅ return to %s" % npc.npc_name
	return "%s%s" % [npc.quest_title, prog]
