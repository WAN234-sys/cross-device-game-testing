extends Node
## Manages quests, coins, and phase progression across all maps.
## Each map has 6 quests and 4 phases. Completing 2 quests earns coins and may
## unlock the next phase gate. All state persists to disk.

signal quest_completed(map_id: String, quest_index: int)
signal coins_changed(total: int)
signal phase_unlocked(map_id: String, phase: int)
signal quest_progress(map_id: String, quest_index: int, current: int, target: int)

const SAVE_PATH := "user://buddy_maze_quests.json"
const QUESTS_PER_MAP := 6
const COINS_EVERY := 2  # earn coins after every 2nd quest
const COIN_REWARD := 5
const FINAL_COIN_REWARD := 10

var coins: int = 0
## map_id -> [completed quest indices]
var completed: Dictionary = {}
## map_id -> highest unlocked phase (1-4)
var phases: Dictionary = {}
## Runtime quest progress: map_id -> { quest_index: { current, target } }
var progress: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()

## How many quests done on this map.
func quests_done(map_id: String) -> int:
	return (completed.get(map_id, []) as Array).size()

## Current phase for a map (1-4). Phase 1 is always open.
func current_phase(map_id: String) -> int:
	return int(phases.get(map_id, 1))

## Which phase a quest belongs to (1-indexed).
func quest_phase(quest_index: int) -> int:
	if quest_index < 2: return 1
	if quest_index < 4: return 2
	return 3  # quests 4,5 are phase 3; quest 6 (index 5) completion → opens phase 4

## Can the player attempt this quest right now?
func is_quest_available(map_id: String, quest_index: int) -> bool:
	if quest_index in completed.get(map_id, []):
		return false  # already done
	return current_phase(map_id) >= quest_phase(quest_index)

## Set incremental progress (e.g. "collected 2 of 3 items")
func set_progress(map_id: String, quest_index: int, current: int, target: int) -> void:
	if not progress.has(map_id):
		progress[map_id] = {}
	progress[map_id][quest_index] = {"current": current, "target": target}
	quest_progress.emit(map_id, quest_index, current, target)

## Mark a quest as complete. Awards coins every 2 quests.
func complete_quest(map_id: String, quest_index: int) -> void:
	if not completed.has(map_id):
		completed[map_id] = []
	if quest_index in completed[map_id]:
		return
	completed[map_id].append(quest_index)
	quest_completed.emit(map_id, quest_index)

	var done := quests_done(map_id)
	# Coins every 2 quests; final quest gives a bonus
	if done % COINS_EVERY == 0:
		var reward := FINAL_COIN_REWARD if done >= QUESTS_PER_MAP else COIN_REWARD
		coins += reward
		coins_changed.emit(coins)

	# Phase unlocking
	var new_phase := current_phase(map_id)
	if done >= 2 and new_phase < 2:
		new_phase = 2
	if done >= 4 and new_phase < 3:
		new_phase = 3
	if done >= 6 and new_phase < 4:
		new_phase = 4
	if new_phase > current_phase(map_id):
		phases[map_id] = new_phase
		phase_unlocked.emit(map_id, new_phase)

	_save()

## Spend coins (returns true if affordable).
func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	_save()
	return true

func _save() -> void:
	var data := {"coins": coins, "completed": completed, "phases": phases}
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
	coins = int(data.get("coins", 0))
	completed = data.get("completed", {})
	phases = data.get("phases", {})
