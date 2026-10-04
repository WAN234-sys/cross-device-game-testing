extends Node3D
class_name MapBase
## Base class for all maps. Every peer spawns every player locally from
## GameManager.player_data (same node names everywhere), and each player's
## MultiplayerSynchronizer streams its movement from its owner. No
## MultiplayerSpawner → no race when someone joins before the map has loaded.

@export var player_scene: PackedScene
@export var spawn_points: Array[Marker3D] = []
## Direction new players face (radians around Y).
@export var spawn_yaw: float = 0.0

@onready var players_node: Node3D = $Players
@onready var exit_zone: Area3D = $ExitZone

var _next_spawn := 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if DeviceManager.is_mobile else Input.MOUSE_MODE_CAPTURED
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_entered)
	for peer_id in GameManager.player_data:
		_spawn_player(peer_id)
	GameManager.player_joined.connect(_on_player_joined)
	GameManager.player_left.connect(_on_player_left)

func _on_player_joined(peer_id: int) -> void:
	if not players_node.has_node(str(peer_id)) and GameManager.player_data.has(peer_id):
		_spawn_player(peer_id)

func _on_player_left(peer_id: int) -> void:
	var p := players_node.get_node_or_null(str(peer_id))
	if p:
		p.queue_free()

func _spawn_player(peer_id: int) -> void:
	if not player_scene:
		push_error("No player_scene assigned to MapBase")
		return
	var player: BuddyPlayer = player_scene.instantiate()
	player.name = str(peer_id)
	player.peer_id = peer_id
	var data: Dictionary = GameManager.player_data.get(peer_id, {})
	player.player_name = data.get("name", "Player")
	player.player_color = data.get("color", Color.WHITE)
	player.player_hat = data.get("hat", "none")
	player.player_face = data.get("face", 0)
	player.player_size = data.get("size", 1.0)
	# Same slot on every peer: order by peer id so positions match
	var ids := GameManager.player_data.keys()
	ids.sort()
	var slot := maxi(ids.find(peer_id), 0)
	var pos := Vector3(slot * 2.0, 1.0, 0.0)
	if not spawn_points.is_empty():
		pos = spawn_points[slot % spawn_points.size()].position
	player.position = pos
	player.rotation.y = spawn_yaw
	player.set_multiplayer_authority(peer_id)
	players_node.add_child(player)

func _on_exit_entered(body: Node3D) -> void:
	if body is BuddyPlayer and body.is_multiplayer_authority():
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			NetworkManager.player_at_exit_rpc.rpc_id(1)
		else:
			GameManager.player_reached_exit(body.peer_id)
