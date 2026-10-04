extends SceneTree
## Loads every map scene headless, checks it builds, counts NPCs/quests/
## obstacles/phase gates, then verifies solo rules (gates stay shut).
## Run: godot --headless --path BuddyMaze -s tests/maps_test.gd

const MAPS := ["kitchen_counter", "toy_chest", "grandmas_attic", "garden_shed", "school_backpack"]

var fails := 0

func _check(ok: bool, msg: String) -> void:
	print(("  PASS " if ok else "  FAIL ") + msg)
	if not ok:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var gm = root.get_node("GameManager")
	var qm = root.get_node("QuestManager")
	gm.player_data = {1: {"name": "Tester", "color": Color.WHITE, "hat": "none"}}
	for map_id in MAPS:
		print("== %s ==" % map_id)
		var path: String = root.get_node("NetworkManager").MAP_SCENES[map_id]
		_check(ResourceLoader.exists(path), "scene exists")
		var ps: PackedScene = load(path)
		_check(ps != null, "scene loads")
		if ps == null:
			continue
		gm.start_game(map_id)
		var inst: Node = ps.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame
		var npcs := get_nodes_in_group("quest_npcs").filter(func(n): return inst.is_ancestor_of(n))
		var givers := npcs.filter(func(n): return n.quest_index >= 0)
		var obstacles := get_nodes_in_group("obstacles").filter(func(n): return inst.is_ancestor_of(n))
		var gates := get_nodes_in_group("phase_gates").filter(func(n): return inst.is_ancestor_of(n))
		var items := get_nodes_in_group("quest_items").filter(func(n): return inst.is_ancestor_of(n))
		var players := inst.get_node("Players").get_child_count()
		print("    npcs=%d quest_givers=%d obstacles=%d phase_gates=%d items=%d players=%d" % [npcs.size(), givers.size(), obstacles.size(), gates.size(), items.size(), players])
		_check(npcs.size() >= 3, "3+ NPCs")
		_check(givers.size() == 6, "6 quests assigned")
		_check(players == 1, "solo player spawned")
		if map_id != "kitchen_counter":
			_check(obstacles.size() >= 12, "12+ obstacles across phases")
			_check(gates.size() == 3, "3 phase gates (phases 2-4)")
			var all_shut := gates.all(func(g): return not g.is_open)
			_check(all_shut, "solo: phase gates stay shut")
			# Even with phase 4 quests done, solo can't pass
			qm.phases[map_id] = 4
			for g in gates:
				g._refresh()
			_check(gates.all(func(g): return not g.is_open), "solo + quests done: gates still shut")
			qm.phases.erase(map_id)
		inst.queue_free()
		await process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
