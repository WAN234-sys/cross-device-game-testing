extends Node
## Autoload-based network test (runs inside the real game loop, like players do).
## Activated only when launched with:  -- nettest host|client
## Host starts solo; client joins; both stand on plates, grab tokens, reach exit.

var role := ""
var t := 0.0
var step := 0
var failures: Array[String] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not "nettest" in args:
		queue_free()
		return
	role = "host" if "host" in args else "client"
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[%s] nettest start" % role)

func check(ok: bool, msg: String) -> void:
	print("[%s] %s %s" % [role, "PASS" if ok else "FAIL", msg])
	if not ok:
		failures.append(msg)

func me():
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			return p
	return null

func _process(delta: float) -> void:
	if step == 99:
		return
	t += delta
	match step:
		0:
			NetworkManager.local_player_name = role.capitalize()
			if role == "host":
				NetworkManager.start_solo("kitchen_counter")
				step = 1
			elif t > 1.5:
				NetworkManager.join_game("127.0.0.1")
				step = 1; t = 0.0
		1:
			if GameManager.player_data.size() >= 2 and get_tree().get_nodes_in_group("players").size() >= 2:
				step = 2; t = 0.0
			elif t > 20.0:
				check(false, "connect timeout (players=%d)" % GameManager.player_data.size()); _finish()
		2:
			if t > 1.0:
				check(GameManager.player_data.size() == 2, "2 players registered")
				check(get_tree().current_scene.name == "KitchenCounter", "in kitchen map")
				check(get_tree().get_nodes_in_group("players").size() == 2, "2 beans visible")
				check(GameManager.is_coop_ready(), "coop ready")
				var plates := get_tree().get_nodes_in_group("plates")
				var p = me()
				check(p != null, "own player exists")
				if p and plates.size() == 2:
					p.global_position = plates[0 if role == "host" else 1].global_position + Vector3(0, 0.3, 0)
				step = 3; t = 0.0
		3:
			if t > 2.5:
				var g := get_tree().get_nodes_in_group("gates")
				check(g.size() == 1 and g[0].is_open, "gate open on this screen")
				step = 4; t = 0.0
		4:
			# host walks to tokens 0,1 ; client to 2
			var mine := [0, 1] if role == "host" else [2]
			var idx := int(t / 0.7)
			var p = me()
			if p == null:
				check(false, "own player missing"); _finish(); return
			if idx < mine.size():
				for tok in get_tree().get_nodes_in_group("tokens"):
					if tok.token_index == mine[idx]:
						p.global_position = tok.global_position
			if t > 3.5:
				check(GameManager.tokens_found == 3, "3 tokens counted here (got %d)" % GameManager.tokens_found)
				check(get_tree().get_nodes_in_group("tokens").size() == 0, "token objects removed here")
				me().global_position = get_tree().current_scene.get_node("ExitZone").global_position
				step = 5; t = 0.0
		5:
			if not GameManager.is_playing:
				check(true, "game won (both at exit)")
				_finish()
			elif t > 5.0:
				check(false, "game did not end")
				_finish()

func _finish() -> void:
	step = 99
	print("[%s] DONE failures=%d" % [role, failures.size()])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1 if failures.size() else 0)
