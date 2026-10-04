extends SceneTree
## REAL network test: run two processes.
##   host:   godot --headless --path . --script res://tests/net_test.gd -- host
##   client: godot --headless --path . --script res://tests/net_test.gd -- client
## Host starts solo, client joins via ENet on 127.0.0.1, both walk onto plates,
## gate must open on BOTH, tokens sync, both reach exit â†’ win on BOTH.

var role := ""
var frame := 0
var failures: Array[String] = []
var GM; var NM

func _initialize() -> void:
	role = "host" if "host" in OS.get_cmdline_user_args() else "client"
	print("[%s] start" % role)

func check(cond: bool, msg: String) -> void:
	print("[%s] %s %s" % [role, "PASS" if cond else "FAIL", msg])
	if not cond:
		failures.append(msg)

func me():
	for p in get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			return p
	return null

func _finish() -> void:
	print("[%s] DONE failures=%d" % [role, failures.size()])
	quit(1 if failures.size() else 0)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		GM = root.get_node("GameManager"); NM = root.get_node("NetworkManager")
		NM.local_player_name = role.capitalize()
		if role == "host":
			NM.start_solo("kitchen_counter")
		else:
			NM.join_game("127.0.0.1")
	# Client keeps retrying until the host is up
	if role == "client" and frame % 60 == 0 and frame < 600 and GM.player_data.size() < 2:
		NM.join_game("127.0.0.1")
	if frame == 900:
		check(GM.player_data.size() == 2, "2 players registered (got %d)" % GM.player_data.size())
		check(current_scene != null and current_scene.name == "KitchenCounter", "in kitchen map")
		check(get_nodes_in_group("players").size() == 2, "2 bean nodes visible (got %d)" % get_nodes_in_group("players").size())
		check(GM.is_coop_ready(), "coop ready on this peer")
	# Each player stands on a different plate (host=A, client=B)
	if frame == 920:
		var plates = get_nodes_in_group("plates")
		var p = me()
		check(p != null, "own player exists")
		if p and plates.size() == 2:
			var target: Node3D = plates[0] if role == "host" else plates[1]
			p.global_position = target.global_position + Vector3(0, 0.3, 0)
	if frame == 1100:
		var gates = get_nodes_in_group("gates")
		check(gates.size() == 1 and gates[0].is_open, "gate OPEN (synced from host)")
	# Collect tokens: host takes 0 and 1, client takes 2 (by walking onto them)
	if frame == 1120:
		var p = me()
		for t in get_nodes_in_group("tokens"):
			if (role == "host" and t.token_index < 2) or (role == "client" and t.token_index == 2):
				p.global_position = t.global_position
				break
	if frame == 1180:
		var p = me()
		for t in get_nodes_in_group("tokens"):
			if role == "host" and t.token_index == 1:
				p.global_position = t.global_position
	if frame == 1400:
		check(GM.tokens_found == 3, "all 3 tokens counted on this peer (got %d)" % GM.tokens_found)
		check(get_nodes_in_group("tokens").size() == 0, "token objects removed on this peer")
		var exit_zone: Node3D = current_scene.get_node("ExitZone")
		me().global_position = exit_zone.global_position
	if frame == 1650:
		check(not GM.is_playing, "game ended (both at exit)")
		_finish()
	if frame > 1800:
		check(false, "timeout")
		_finish()
	return false
