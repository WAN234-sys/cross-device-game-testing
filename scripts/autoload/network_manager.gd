extends Node
## Handles multiplayer networking — ENet for desktop, WebRTC for web.
## Room codes, player sync, and host authority.

signal connection_succeeded
signal connection_failed(reason: String)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal room_created(code: String)
signal ready_changed(peer_id: int, is_ready: bool)

const DEFAULT_PORT := 7890
const MAX_CLIENTS := 9  # +1 host = 10

var room_code: String = ""
var is_host: bool = false
var local_player_name: String = "Player"
var local_player_color: Color = Color.WHITE
var local_player_hat: String = "none"

# --- Room Code Generation ---

func _generate_room_code() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 4:
		code += CHARS[randi() % CHARS.length()]
	return code

# --- Host ---

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if err != OK:
		connection_failed.emit("Could not create server: " + error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	room_code = _generate_room_code()

	_connect_signals()

	# Register host as player
	_register_local_player(1)
	room_created.emit(room_code)
	connection_succeeded.emit()
	print("[Network] Hosting on port %d — room code: %s" % [DEFAULT_PORT, room_code])

# --- Join ---

func join_game(address: String = "127.0.0.1") -> void:
	# Clean up previous attempt
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, DEFAULT_PORT)
	if err != OK:
		connection_failed.emit("Could not connect: " + error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	_connect_signals()

# --- Disconnect ---

func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	room_code = ""
	GameManager.player_data.clear()

# --- Callbacks ---

func _on_connected_to_server() -> void:
	_register_local_player(multiplayer.get_unique_id())
	connection_succeeded.emit()
	print("[Network] Connected to server as peer %d" % multiplayer.get_unique_id())

## Solo play: enter a map alone to explore. Co-op gates stay locked until a
## friend joins, so the game still requires 2+ players to finish.
func start_solo(map_name: String) -> void:
	disconnect_game()
	var peer := ENetMultiplayerPeer.new()
	# Host on the default port so friends can drop in mid-run
	if peer.create_server(DEFAULT_PORT, MAX_CLIENTS) == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		room_code = _generate_room_code()
		_connect_signals()
		room_created.emit(room_code)
	_register_local_player(1)
	GameManager.start_game(map_name)
	load_map_scene(map_name)

## Late joiners: when someone joins during a run, tell them which map is live.
@rpc("authority", "reliable")
func sync_running_game(map_name: String) -> void:
	GameManager.start_game(map_name)
	load_map_scene(map_name)

const MAP_SCENES := {
	"kitchen_counter": "res://scenes/maps/kitchen_counter/kitchen_counter.tscn",
	"toy_chest": "res://scenes/maps/toy_chest/toy_chest.tscn",
	"grandmas_attic": "res://scenes/maps/grandmas_attic/grandmas_attic.tscn",
	"garden_shed": "res://scenes/maps/garden_shed/garden_shed.tscn",
	"school_backpack": "res://scenes/maps/school_backpack/school_backpack.tscn",
}

func load_map_scene(map_name: String) -> bool:
	var path: String = MAP_SCENES.get(map_name, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Map scene not built yet: " + map_name)
		return false
	get_tree().change_scene_to_file(path)
	return true

func _connect_signals() -> void:
	var m := multiplayer
	if not m.peer_connected.is_connected(_on_peer_connected):
		m.peer_connected.connect(_on_peer_connected)
	if not m.peer_disconnected.is_connected(_on_peer_disconnected):
		m.peer_disconnected.connect(_on_peer_disconnected)
	if not m.connected_to_server.is_connected(_on_connected_to_server):
		m.connected_to_server.connect(_on_connected_to_server)
	if not m.connection_failed.is_connected(_on_connection_failed):
		m.connection_failed.connect(_on_connection_failed)
	if not m.server_disconnected.is_connected(_on_server_disconnected):
		m.server_disconnected.connect(_on_server_disconnected)

func _on_connection_failed() -> void:
	connection_failed.emit("Connection to server failed.")

func _on_server_disconnected() -> void:
	disconnect_game()
	connection_failed.emit("Server disconnected.")

func _on_peer_connected(peer_id: int) -> void:
	player_connected.emit(peer_id)
	GameManager.player_joined.emit(peer_id)
	# Send our info to the new peer
	rpc_id(peer_id, &"receive_player_info", multiplayer.get_unique_id(), local_player_name, local_player_color.to_html(), local_player_hat, CosmeticManager.current_face, CosmeticManager.current_size)
	# Drop-in: if a run is already going, pull the newcomer into it
	if is_host and GameManager.is_playing:
		sync_running_game.rpc_id(peer_id, GameManager.current_map)
	print("[Network] Peer %d connected" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id in GameManager.player_data:
		GameManager.player_data.erase(peer_id)
	player_disconnected.emit(peer_id)
	GameManager.player_left.emit(peer_id)
	print("[Network] Peer %d disconnected" % peer_id)

# --- Player Registration ---

func _register_local_player(peer_id: int) -> void:
	GameManager.player_data[peer_id] = {
		"name": local_player_name,
		"color": local_player_color,
		"hat": local_player_hat,
		"face": CosmeticManager.current_face,
		"size": CosmeticManager.current_size,
		"ready": false,
		"at_exit": false,
	}

@rpc("any_peer", "reliable")
func receive_player_info(_claimed_id: int, player_name: String, color_hex: String, hat: String, face: int = 0, size: float = 1.0) -> void:
	# Trust the transport's sender id, not the claimed one (prevents spoofing)
	var peer_id := multiplayer.get_remote_sender_id()
	GameManager.player_data[peer_id] = {
		"name": player_name.strip_edges().substr(0, 16) if player_name.strip_edges() else "Buddy",
		"color": Color.html(color_hex) if Color.html_is_valid(color_hex) else Color.WHITE,
		"hat": hat if hat in CosmeticManager.HAT_DISPLAY_NAMES else "none",
		"face": clampi(face, 0, CosmeticManager.FACE_EXPRESSIONS.size() - 1),
		"size": clampf(size, 0.85, 1.2),
		"ready": false,
		"at_exit": false,
	}
	GameManager.player_joined.emit(peer_id)

# --- Game RPCs ---

@rpc("authority", "reliable")
func start_game_rpc(map_name: String) -> void:
	GameManager.start_game(map_name)

func request_start_game(map_name: String) -> void:
	if is_host:
		start_game_rpc.rpc(map_name)

## Quest item pickups: everyone hides the item once anyone grabs it.
func broadcast_item_taken(path: NodePath) -> void:
	if multiplayer.has_multiplayer_peer():
		item_taken_rpc.rpc(path)
	else:
		item_taken_rpc(path)

@rpc("any_peer", "call_local", "reliable")
func item_taken_rpc(path: NodePath) -> void:
	var n := get_tree().root.get_node_or_null(path)
	if n and n.has_method("take_visual"):
		n.take_visual()

## Gate state: host decides, everyone applies.
func broadcast_gate(gate_path: NodePath, open: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		gate_rpc.rpc(gate_path, open)
	else:
		gate_rpc(gate_path, open)

@rpc("authority", "call_local", "reliable")
func gate_rpc(gate_path: NodePath, open: bool) -> void:
	var g := get_tree().root.get_node_or_null(gate_path) as PuzzleGate
	if g == null:
		return
	if open:
		g.open()
	else:
		g.close()

## Token flow: player asks host → host validates once → everyone hides it.
var _taken_tokens := {}

func request_token(token_index: int) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_host_take_token(multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1, token_index)
	else:
		collect_token_rpc.rpc_id(1, token_index)

@rpc("any_peer", "reliable")
func collect_token_rpc(token_index: int) -> void:
	if multiplayer.is_server():
		_host_take_token(multiplayer.get_remote_sender_id(), token_index)

func _host_take_token(sender: int, token_index: int) -> void:
	if _taken_tokens.has(token_index) or not GameManager.is_playing:
		return
	_taken_tokens[token_index] = sender
	if multiplayer.has_multiplayer_peer():
		token_taken_rpc.rpc(sender, token_index)
	else:
		token_taken_rpc(sender, token_index)

@rpc("authority", "call_local", "reliable")
func token_taken_rpc(sender: int, token_index: int) -> void:
	GameManager.collect_token(sender, token_index)
	for t in get_tree().get_nodes_in_group("tokens"):
		if t.token_index == token_index:
			t.collect_visual()

@rpc("any_peer", "reliable")
func high_five_rpc(target_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	GameManager.register_high_five(sender, target_id)

func set_ready(is_ready: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		ready_rpc.rpc(is_ready)
	else:
		_apply_ready(1, is_ready)

@rpc("any_peer", "call_local", "reliable")
func ready_rpc(is_ready: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	_apply_ready(sender, is_ready)

func _apply_ready(peer_id: int, is_ready: bool) -> void:
	if peer_id in GameManager.player_data:
		GameManager.player_data[peer_id]["ready"] = is_ready
	ready_changed.emit(peer_id, is_ready)

@rpc("any_peer", "call_local", "reliable")
func emote_rpc(emote: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	GameManager.emote_played.emit(sender, emote)

@rpc("any_peer", "call_local", "reliable")
func ping_rpc(pos: Vector3, kind: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	GameManager.ping_placed.emit(sender, pos, kind)

## Send an emote or ping to everyone (works offline too).
func send_emote(emote: String) -> void:
	if multiplayer.has_multiplayer_peer():
		emote_rpc.rpc(emote)
	else:
		GameManager.emote_played.emit(1, emote)

func send_ping(pos: Vector3, kind: String) -> void:
	if multiplayer.has_multiplayer_peer():
		ping_rpc.rpc(pos, kind)
	else:
		GameManager.ping_placed.emit(1, pos, kind)

@rpc("any_peer", "reliable")
func player_at_exit_rpc() -> void:
	if multiplayer.is_server():
		GameManager.player_reached_exit(multiplayer.get_remote_sender_id())

## Host tells everyone how the run ended, so every screen shows the result.
@rpc("authority", "reliable")
func game_over_rpc(result: String) -> void:
	if GameManager.is_playing:
		GameManager.end_game(result)
