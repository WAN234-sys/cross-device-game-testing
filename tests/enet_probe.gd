extends SceneTree
## Minimal ENet check using the SceneTree's multiplayer API directly.

var role := ""
var frame := 0
var mp: MultiplayerAPI

func _initialize() -> void:
	role = "host" if "host" in OS.get_cmdline_user_args() else "client"

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		mp = get_multiplayer()
		print("[%s] mp=%s" % [role, mp])
		var peer := ENetMultiplayerPeer.new()
		var err: int = peer.create_server(7890, 4) if role == "host" else peer.create_client("127.0.0.1", 7890)
		print("[%s] create err=%s" % [role, error_string(err)])
		mp.multiplayer_peer = peer
		mp.peer_connected.connect(func(id): print("[%s] peer_connected %d" % [role, id]))
		mp.connected_to_server.connect(func(): print("[%s] connected id=%d" % [role, mp.get_unique_id()]))
		# Also check what an autoload sees
		var nm = root.get_node("NetworkManager")
		print("[%s] autoload sees same mp? %s" % [role, nm.multiplayer == mp])
	if frame == 300:
		print("[%s] status=%d peers=%s" % [role, mp.multiplayer_peer.get_connection_status(), mp.get_peers()])
		quit()
	return false
