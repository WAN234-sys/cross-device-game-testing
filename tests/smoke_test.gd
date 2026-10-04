extends SceneTree
## Headless smoke test: boots solo mode, loads the Kitchen Counter, spawns the
## player, simulates movement + puzzle logic, and checks the 2-player rule.
## Run: godot --headless --path . --script res://tests/smoke_test.gd

var failures: Array[String] = []
var frame := 0

func _initialize() -> void:
	print("[TEST] start")

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		print("  ✗ FAIL: ", msg)
		failures.append(msg)

func _process(_delta: float) -> bool:
	frame += 1
	var GM = root.get_node_or_null("GameManager")
	var NM = root.get_node_or_null("NetworkManager")
	match frame:
		2:
			check(GM != null and NM != null, "autoloads loaded")
			NM.local_player_name = "Tester"
			NM.start_solo("kitchen_counter")
		30:
			var map = current_scene
			check(map != null and map.name == "KitchenCounter", "kitchen map loaded (got %s)" % (map.name if map else "null"))
			var players = map.get_node_or_null("Players") if map else null
			check(players != null and players.get_child_count() == 1, "1 player spawned")
			check(GM.is_playing, "game is playing")
			check(not GM.is_coop_ready(), "solo = coop not ready")
			if players and players.get_child_count() > 0:
				var p = players.get_child(0)
				check(p.global_position.y > -1.0, "player above floor (y=%.2f)" % p.global_position.y)
				check(p.get_node_or_null("BeanModel") != null, "bean model node present")
		60:
			# Solo: plates should not open the gate
			var plates = get_nodes_in_group("plates")
			check(plates.size() == 2, "2 pressure plates placed (got %d)" % plates.size())
			check(get_nodes_in_group("tokens").size() == 3, "3 tokens placed")
			check(get_nodes_in_group("gates").size() == 1, "1 gate placed")
			for pl in plates:
				pl.current_players = 1
				pl._check_activation()
			var gate = get_nodes_in_group("gates")[0]
			check(not gate.is_open, "solo: gate stays closed with both plates pressed")
			check(GM.game_timer == 0.0, "solo: timer paused (%.2f)" % GM.game_timer)
		70:
			# Simulate a 2nd buddy joining
			GM.player_data[999] = {"name": "Buddy2", "color": Color.CORAL, "hat": "crown", "face": 1, "size": 1.1, "ready": false, "at_exit": false}
			GM.player_joined.emit(999)
		100:
			var map = current_scene
			check(GM.is_coop_ready(), "2 players = coop ready")
			check(map.get_node("Players").get_child_count() == 2, "2nd buddy spawned via drop-in")
			get_nodes_in_group("gate_puzzles")[0]._evaluate()
			check(get_nodes_in_group("gates")[0].is_open, "coop: gate opens with both plates")
		130:
			check(GM.game_timer > 0.0, "coop: timer running (%.2f)" % GM.game_timer)
			for i in 3:
				NM.request_token(i)
			NM.request_token(0)  # duplicate must not double-count
			check(GM.tokens_found == 3, "3 tokens collected, no double count (got %d)" % GM.tokens_found)
			GM.player_reached_exit(1)
			check(GM.is_playing, "1 of 2 at exit: game continues")
			GM.player_reached_exit(999)
			check(not GM.is_playing, "both at exit: game won")
			check("chef_hat" in GM.unlocked_hats, "chef hat unlocked on kitchen win")
		140:
			# Drop-out
			GM.player_data.erase(999)
			GM.player_left.emit(999)
		150:
			print("[TEST] %d failure(s)" % failures.size())
			for f in failures:
				print("   - ", f)
			quit(1 if failures.size() else 0)
	return false
