extends Node
## Global game state manager — friendslop core loop.
## Tracks tokens, timers, players, and map completion.

signal token_collected(player_id: int, token_index: int)
signal all_tokens_collected
signal game_started
signal game_ended(result: String)  # "win" | "timeout" | "quit"
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal friendship_meter_changed(value: float)
signal coop_state_changed(is_coop_ready: bool)  # false = solo explore mode
signal emote_played(peer_id: int, emote: String)
signal ping_placed(peer_id: int, position: Vector3, kind: String)

const MAX_PLAYERS := 10
const MIN_PLAYERS_FOR_COOP := 2
## In solo mode the timer is paused so a lone player isn't punished while waiting.
var solo_timer_paused := true
const TOKENS_PER_MAP := 3
const DEFAULT_TIME_LIMIT := 600.0  # 10 minutes

# --- State ---
var current_map: String = ""
var tokens_found: int = 0
var tokens_total: int = TOKENS_PER_MAP
var game_timer: float = 0.0
var time_limit: float = DEFAULT_TIME_LIMIT
var is_playing: bool = false
var friendship_meter: float = 0.0  # 0.0 to 1.0
var player_data: Dictionary = {}  # peer_id -> { name, color, hat, ready, at_exit }
var high_fives_given: int = 0

# Cosmetics the local player has unlocked (saved to disk)
var unlocked_hats: Array[String] = ["none", "traffic_cone"]
var unlocked_colors: Array[Color] = [
	Color.WHITE, Color.CORAL, Color.DODGER_BLUE,
	Color.MEDIUM_SPRING_GREEN, Color.GOLD, Color.ORCHID
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_save()
	_ready_signals()

func _ready_signals() -> void:
	player_joined.connect(func(_id): _check_coop())
	player_left.connect(func(_id): _check_coop())

## True when enough buddies are here for co-op puzzles and the exit to work.
func is_coop_ready() -> bool:
	return player_data.size() >= MIN_PLAYERS_FOR_COOP

var _last_coop := false
func _check_coop() -> void:
	var now := is_coop_ready()
	if now != _last_coop:
		_last_coop = now
		coop_state_changed.emit(now)

func _process(delta: float) -> void:
	if not is_playing:
		return
	if solo_timer_paused and not is_coop_ready():
		return  # Explore freely while waiting for friends
	game_timer += delta
	var is_authority := not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if game_timer >= time_limit and is_authority:
		end_game("timeout")

# --- Game Flow ---

## Per-map time limits (seconds). Bigger maps need more time.
const MAP_TIME_LIMITS := {
	"kitchen_counter": 900.0,
	"toy_chest": 1080.0,
	"grandmas_attic": 1200.0,
	"garden_shed": 1200.0,
	"school_backpack": 1320.0,
}

func start_game(map_name: String) -> void:
	last_unlocks.clear()
	NetworkManager._taken_tokens.clear()
	current_map = map_name
	tokens_found = 0
	game_timer = 0.0
	friendship_meter = 0.0
	high_fives_given = 0
	time_limit = MAP_TIME_LIMITS.get(map_name, DEFAULT_TIME_LIMIT)
	is_playing = true
	for id in player_data:
		player_data[id]["at_exit"] = false
	_last_coop = is_coop_ready()
	game_started.emit()
	coop_state_changed.emit(_last_coop)

func collect_token(player_id: int, token_index: int) -> void:
	if not is_playing:
		return
	tokens_found += 1
	token_collected.emit(player_id, token_index)
	if tokens_found >= tokens_total:
		all_tokens_collected.emit()

func register_high_five(_from_id: int, _to_id: int) -> void:
	high_fives_given += 1
	friendship_meter = clampf(friendship_meter + 0.08, 0.0, 1.0)
	friendship_meter_changed.emit(friendship_meter)

func player_reached_exit(peer_id: int) -> void:
	if peer_id in player_data:
		player_data[peer_id]["at_exit"] = true
	# Nobody escapes alone: need 2+ players, all tokens, and everyone at the exit
	if tokens_found >= tokens_total and is_coop_ready():
		var all_at_exit := true
		for id in player_data:
			if not player_data[id].get("at_exit", false):
				all_at_exit = false
				break
		if all_at_exit:
			end_game("win")

func end_game(result: String) -> void:
	if not is_playing:
		return
	is_playing = false
	# Host broadcasts the outcome so clients end the run too
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		NetworkManager.game_over_rpc.rpc(result)
	if result == "win":
		ProgressionManager.record_completion(current_map, game_timer, friendship_meter, high_fives_given)
		# Earned unlocks (match the hints shown in Customize)
		if current_map == "kitchen_counter":
			_unlock_hat("chef_hat")
		if player_data.size() >= 4:
			_unlock_hat("crown")
		if ProgressionManager.total_high_fives >= 10:
			_unlock_hat("party")
		if ProgressionManager.total_games_played >= 5:
			_unlock_hat("top_hat")
		# Plus one random surprise hat and a new color each win
		var random_hats := ["propeller", "bucket", "viking", "fez"].filter(func(h): return h not in unlocked_hats)
		if not random_hats.is_empty():
			_unlock_hat(random_hats.pick_random())
		for c: Color in CosmeticManager.ALL_COLORS:
			if c not in unlocked_colors:
				unlocked_colors.append(c)
				last_unlocks.append("New color!")
				break
	_save_game()
	game_ended.emit(result)

## Shown on the results screen, then cleared.
var last_unlocks: Array[String] = []

func _unlock_hat(hat: String) -> void:
	if hat not in unlocked_hats:
		unlocked_hats.append(hat)
		last_unlocks.append("New hat: %s" % CosmeticManager.HAT_DISPLAY_NAMES.get(hat, hat))

func get_time_remaining() -> float:
	return maxf(time_limit - game_timer, 0.0)

func get_score() -> Dictionary:
	return {
		"tokens": tokens_found,
		"time": game_timer,
		"high_fives": high_fives_given,
		"friendship": friendship_meter,
		"players": player_data.size()
	}

# --- Persistence ---

const SAVE_PATH := "user://buddy_maze_save.json"

func _save_game() -> void:
	var data := {
		"unlocked_hats": unlocked_hats,
		"unlocked_colors": unlocked_colors.map(func(c: Color) -> String: return c.to_html()),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	if data.has("unlocked_hats"):
		unlocked_hats.clear()
		for h in data["unlocked_hats"]:
			unlocked_hats.append(str(h))
	if data.has("unlocked_colors"):
		unlocked_colors.clear()
		for hex: String in data["unlocked_colors"]:
			unlocked_colors.append(Color.html(hex))
