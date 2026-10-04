extends MapBase
## Kitchen Counter — first map. MazeBuilder lays out the walls, then this
## script places plates, tokens, gate, NPC, exit, and decorative props.

const PLATE := preload("res://scenes/puzzles/pressure_plate.tscn")
const TOKEN := preload("res://scenes/puzzles/friendship_token.tscn")
const GATE := preload("res://scenes/puzzles/gate.tscn")
const NPC := preload("res://scenes/npcs/breadwise.tscn")
const HUD := preload("res://scenes/ui/game_hud.tscn")

@onready var maze: MazeBuilder = $Maze

func _ready() -> void:
	maze.build()
	spawn_yaw = maze.spawn_yaw
	for p in maze.spawn_points:
		var m := Marker3D.new()
		$Spawns.add_child(m)
		m.position = p
		spawn_points.append(m)

	var plates: Array[PressurePlate] = []
	for pos in maze.plate_positions:
		var plate: PressurePlate = PLATE.instantiate()
		add_child(plate)
		plate.position = pos
		plates.append(plate)

	for i in maze.token_positions.size():
		var token: FriendshipToken = TOKEN.instantiate()
		token.token_index = i
		add_child(token)
		token.position = maze.token_positions[i]
	GameManager.tokens_total = maze.token_positions.size()

	var gate: PuzzleGate = GATE.instantiate()
	add_child(gate)
	gate.position = maze.gate_position + Vector3(0, 1.3, 0)
	var ctrl := MultiPlateController.new()
	ctrl.plates = plates
	ctrl.gate = gate
	add_child(ctrl)

	var npc: Node3D = NPC.instantiate()
	add_child(npc)
	npc.position = maze.npc_position

	$ExitZone.position = maze.exit_position + Vector3(0, 1.0, 0)
	_place_props()
	_place_quest_npcs()
	add_child(HUD.instantiate())
	QuestTracker.reset("kitchen_counter")
	GameManager.tokens_total = maze.token_positions.size()
	super._ready()

## Place quest NPCs and items from MapContent. Kitchen uses the old MazeBuilder
## layout, so positions are relative to the maze's walkable cells.
func _place_quest_npcs() -> void:
	var data: Dictionary = MapContent.get_map("kitchen_counter")
	if data.is_empty():
		return
	# maze.cell_size is the cell size from MazeBuilder
	var npcs_data: Array = data.get("npcs", [])
	var npc_by_id := {}
	# Place each NPC near the maze's npc/plate/token positions
	var spots := [maze.npc_position, maze.plate_positions[0] + Vector3(2, 0, 0)]
	if maze.plate_positions.size() > 1:
		spots.append(maze.plate_positions[1] + Vector3(2, 0, 0))
	for i in npcs_data.size():
		var def: Dictionary = npcs_data[i]
		var npc := QuestNPC.new()
		npc.npc_name = def["name"]
		npc.map_id = "kitchen_counter"
		npc.dialogue_lines.assign(def.get("lines", []))
		npc.quest_index = -1
		_add_npc_body(npc, def)
		add_child(npc)
		npc.position = spots[i % spots.size()] + Vector3(i * 1.6, 0, 0)
		npc_by_id[def["id"]] = npc
	# Place quests
	var quests: Array = data.get("quests", [])
	var item_spots := _random_walkable_spots(quests.size() * 2)
	var spot_i := 0
	var given := {}
	for qi in quests.size():
		var q: Dictionary = quests[qi]
		var owner: QuestNPC = npc_by_id.get(q["npc"])
		if owner == null:
			continue
		# One quest per NPC body: extra quests get a helper standing beside the owner
		var giver: QuestNPC = owner
		if given.has(owner):
			giver = QuestNPC.new()
			giver.npc_name = "%s (task %d)" % [owner.npc_name, qi + 1]
			giver.map_id = "kitchen_counter"
			_add_npc_body(giver, {})
			add_child(giver)
			giver.position = owner.position + Vector3(1.6 * given[owner], 0, 0)
			given[owner] += 1
		else:
			given[owner] = 1
		giver.quest_index = qi
		giver.quest_title = q["title"]
		giver.quest_type = q["type"]
		giver.intro_lines.assign(q.get("intro", []))
		giver.done_lines.assign(["Nice work, buddy! ✨"])
		giver.fetch_item = q.get("item", "")
		giver.target_count = int(q.get("count", 1))
		giver.plate_group = q.get("group", "")
		# Place quest objects
		match q["type"]:
			"fetch":
				var it := QuestItem.new()
				it.item_id = q["item"]
				it.label = GenericMap.ITEM_ICONS.get(q["item"], "📦")
				it.map_id = "kitchen_counter"; it.quest_index = qi; it.carry = true
				add_child(it)
				it.position = item_spots[spot_i % item_spots.size()] + Vector3(0, 0.8, 0)
				spot_i += 1
			"collect":
				for k in int(q.get("count", 3)):
					var it := QuestItem.new()
					it.item_id = q["item"]
					it.label = GenericMap.ITEM_ICONS.get(q["item"], "✨")
					it.map_id = "kitchen_counter"; it.quest_index = qi; it.carry = false
					add_child(it)
					it.position = item_spots[spot_i % item_spots.size()] + Vector3(0, 0.8, 0)
					spot_i += 1
			"reach":
				var m := QuestMarker.new()
				m.map_id = "kitchen_counter"; m.quest_index = qi; m.mode = "reach"
				m.label = "📜"; m.hint = q["title"]
				add_child(m)
				m.position = item_spots[spot_i % item_spots.size()]
				spot_i += 1
			"survive":
				var m := QuestMarker.new()
				m.map_id = "kitchen_counter"; m.quest_index = qi; m.mode = "survive"; m.radius = 4.0
				m.label = "⏱"; m.hint = "Stay here together!"
				add_child(m)
				m.position = maze.npc_position + Vector3(4, 0, 4)
			"talk":
				var target: QuestNPC = npc_by_id.get(q.get("talk_to", ""))
				if target:
					var m := QuestMarker.new()
					m.map_id = "kitchen_counter"; m.quest_index = qi; m.mode = "talk"; m.radius = 1.6
					m.label = "💬"; m.hint = "Listen to %s" % target.npc_name
					add_child(m)
					m.position = target.position + Vector3(0, 0, 1.6)

func _add_npc_body(npc: QuestNPC, def: Dictionary) -> void:
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new(); shape.radius = 0.5; shape.height = 1.4
	cs.shape = shape; cs.position.y = 0.7
	npc.add_child(cs)
	npc.collision_layer = 16
	var ph := MeshInstance3D.new(); ph.name = "NPCMesh"
	var cap := CapsuleMesh.new(); cap.radius = 0.45; cap.height = 1.2
	ph.mesh = cap; ph.position.y = 0.6
	npc.add_child(ph)
	var bubble := Label3D.new(); bubble.name = "SpeechBubble"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED; bubble.font_size = 36; bubble.outline_size = 8
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD; bubble.width = 600; bubble.position.y = 2.9
	npc.add_child(bubble)
	var nl := Label3D.new(); nl.name = "NameLabel"
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; nl.font_size = 44; nl.outline_size = 8; nl.position.y = 1.8
	npc.add_child(nl)
	var ia := Area3D.new(); ia.name = "InteractArea"
	npc.add_child(ia)

## Pick random walkable cells from the maze for placing quest items.
func _random_walkable_spots(count: int) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var cs_val := maze.cell_size
	var ox := -(maze.rows[0].length() * cs_val) / 2.0
	var oz := -(maze.rows.size() * cs_val) / 2.0
	for z in maze.rows.size():
		for x in maze.rows[z].length():
			if maze.rows[z][x] != "#":
				spots.append(Vector3(x * cs_val + cs_val / 2.0 + ox, 0, z * cs_val + cs_val / 2.0 + oz))
	# Shuffle deterministically and return first `count`
	for i in range(spots.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp := spots[i]; spots[i] = spots[j]; spots[j] = tmp
	return spots.slice(0, mini(count, spots.size()))

## Giant kitchen objects ringing the maze — players are bug-sized.
func _place_props() -> void:
	var props := [
		["salt_shaker", 7.0], ["pepper_shaker", 7.0], ["coffee_mug", 6.0],
		["faucet", 9.0], ["paper_towels", 9.0], ["oil_bottle", 10.0],
		["knife_rack", 9.0], ["sponge_pad", 4.0], ["spoon_bridge", 8.0],
	]
	var w := maze.rows[0].length() * maze.cell_size
	var h := maze.rows.size() * maze.cell_size
	var r := maxf(w, h) / 2.0 + 7.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # same layout for every player
	for i in props.size():
		var path := "res://assets/models/environment/kitchen/%s.glb" % props[i][0]
		if not ResourceLoader.exists(path):
			continue
		var swap := ModelSwap.new()
		swap.model_path = path
		swap.target_size = props[i][1]
		swap.rotate_y_deg = rng.randf() * 360.0
		add_child(swap)
		var a := TAU * i / props.size() + 0.3
		swap.position = Vector3(cos(a) * r, 0, sin(a) * r)
