extends Node
## Tracks map completions, friendship score, and unlocks.

signal map_completed(map_name: String)
signal progression_updated

const SAVE_PATH := "user://buddy_maze_progression.json"

var completed_maps: Array[String] = []
var total_friendship_score: float = 0.0
var total_high_fives: int = 0
var total_games_played: int = 0
var best_times: Dictionary = {}  # map_name -> best_time_seconds

func _ready() -> void:
	_load()

func record_completion(map_name: String, time: float, friendship: float, high_fives: int) -> void:
	total_games_played += 1
	total_friendship_score += friendship
	total_high_fives += high_fives
	if map_name not in completed_maps:
		completed_maps.append(map_name)
	if map_name not in best_times or time < best_times[map_name]:
		best_times[map_name] = time
	_save()
	map_completed.emit(map_name)
	progression_updated.emit()

func is_map_unlocked(map_name: String) -> bool:
	match map_name:
		"kitchen_counter", "toy_chest", "grandmas_attic":
			return true  # Always available
		"garden_shed":
			return completed_maps.size() >= 2
		"school_backpack":
			return completed_maps.size() >= 4
		_:
			return false

func get_unlocked_maps() -> Array[String]:
	var maps: Array[String] = []
	for m in ["kitchen_counter", "toy_chest", "grandmas_attic", "garden_shed", "school_backpack"]:
		if is_map_unlocked(m):
			maps.append(m)
	return maps

func _save() -> void:
	var data := {
		"completed_maps": completed_maps,
		"total_friendship_score": total_friendship_score,
		"total_high_fives": total_high_fives,
		"total_games_played": total_games_played,
		"best_times": best_times,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	if data.has("completed_maps"):
		completed_maps.clear()
		for m in data["completed_maps"]:
			completed_maps.append(str(m))
	total_friendship_score = data.get("total_friendship_score", 0.0)
	total_high_fives = data.get("total_high_fives", 0)
	total_games_played = data.get("total_games_played", 0)
	best_times = data.get("best_times", {})
