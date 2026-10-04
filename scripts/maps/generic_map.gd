extends MapBase
class_name GenericMap
## Builds any map from MapContent + MazeGen: walls per phase color, phase
## gates, coop gate + plates, tokens, NPCs with their quests, quest items and
## markers, obstacles, props, and the exit. One script → 5 maps.

const PLATE := preload("res://scenes/puzzles/pressure_plate.tscn")
const TOKEN := preload("res://scenes/puzzles/friendship_token.tscn")
const GATE := preload("res://scenes/puzzles/gate.tscn")
const HUD := preload("res://scenes/ui/game_hud.tscn")

@export var map_id: String = "toy_chest"
@export var seed: int = 1

const CELL := 3.0
const WALL_H := 2.8
## Wall colors per phase (lighter = earlier) per map theme
const THEMES := {
	"kitchen_counter": [Color(0.98, 0.62, 0.18), Color(0.35, 0.78, 0.38), Color(0.95, 0.3, 0.25), Color(0.4, 0.55, 0.95)],
	"toy_chest": [Color(0.95, 0.3, 0.3), Color(0.25, 0.55, 0.95), Color(1, 0.85, 0.2), Color(0.3, 0.8, 0.45)],
	"grandmas_attic": [Color(0.6, 0.48, 0.38), Color(0.5, 0.42, 0.55), Color(0.42, 0.38, 0.35), Color(0.32, 0.3, 0.4)],
	"garden_shed": [Color(0.45, 0.7, 0.3), Color(0.6, 0.45, 0.25), Color(0.35, 0.6, 0.35), Color(0.75, 0.55, 0.3)],
	"school_backpack": [Color(0.3, 0.45, 0.85), Color(0.9, 0.55, 0.75), Color(0.95, 0.8, 0.3), Color(0.55, 0.85, 0.85)],
}
const FLOOR := {
	"kitchen_counter": Color(0.92, 0.88, 0.8), "toy_chest": Color(0.85, 0.75, 0.6),
	"grandmas_attic": Color(0.55, 0.47, 0.38), "garden_shed": Color(0.45, 0.35, 0.25),
	"school_backpack": Color(0.75, 0.78, 0.85),
}
const NPC_MODELS := "res://assets/models/environment/npcs/%s.glb"
const ITEM_ICONS := {
	"salt": "🧂", "sugar": "🧊", "button": "🔘", "spring": "🌀", "photo": "🖼", "needle": "🪡",
	"yarn": "🧶", "seed": "🌰", "apple_core": "🍎", "water_drop": "💧", "eraser_piece": "🩷",
	"tape": "📏", "glue_cap": "🧢",
}

var gen := MazeGen.new()
var grid: PackedStringArray
var data: Dictionary
var origin := Vector3.ZERO

func _ready() -> void:
	data = MapContent.get_map(map_id)
	QuestTracker.reset(map_id)
	grid = gen.generate(seed)
	origin = Vector3(-(grid[0].length() * CELL) / 2.0, 0, -(grid.size() * CELL) / 2.0)
	_build_world()
	_place_gates()
	_place_puzzles()
	_place_npcs_and_quests()
	_place_obstacles()
	_place_exit()
	add_child(HUD.instantiate())
	GameManager.tokens_total = 3
	super._ready()

func cell_pos(c: Vector2i) -> Vector3:
	return origin + Vector3((c.x + 0.5) * CELL, 0, (c.y + 0.5) * CELL)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

func _build_world() -> void:
	var theme: Array = THEMES.get(map_id, THEMES["toy_chest"])
	var mats := []
	for c in theme:
		mats.append(_mat(c))
		mats.append(_mat(c.darkened(0.15)))
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	add_child(walls)
	var box := BoxMesh.new(); box.size = Vector3(CELL, WALL_H, CELL)
	var shape := BoxShape3D.new(); shape.size = box.size
	# One MultiMesh per material keeps draw calls low (phones!)
	var per_mat := {}
	for z in grid.size():
		for x in grid[z].length():
			if grid[z][x] != "#":
				continue
			var p := cell_pos(Vector2i(x, z)) + Vector3(0, WALL_H / 2.0, 0)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = p
			walls.add_child(cs)
			var ph := MazeGen.phase_of(z) - 1
			var mi := ph * 2 + ((x + z) % 2)
			if not per_mat.has(mi):
				per_mat[mi] = []
			per_mat[mi].append(p)
	for mi in per_mat:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		mm.instance_count = per_mat[mi].size()
		for i in per_mat[mi].size():
			mm.set_instance_transform(i, Transform3D(Basis(), per_mat[mi][i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats[mi]
		walls.add_child(mmi)
	# Floor
	var floor_body := StaticBody3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(grid[0].length() * CELL + 30, 1, grid.size() * CELL + 30)
	var fc := CollisionShape3D.new(); fc.shape = fs; fc.position.y = -0.5
	floor_body.add_child(fc)
	var fm := MeshInstance3D.new(); var fmesh := BoxMesh.new(); fmesh.size = fs.size
	fm.mesh = fmesh; fm.position.y = -0.5
	fm.material_override = _mat(FLOOR.get(map_id, Color(0.8, 0.8, 0.8)))
	floor_body.add_child(fm)
	add_child(floor_body)
	# Spawns
	for i in 10:
		var m := Marker3D.new()
		$Spawns.add_child(m)
		var s: Vector2i = gen.points["S"]
		m.position = cell_pos(s) + Vector3((i % 3) * 0.9, 0.4, (i / 3) * 0.9)
		spawn_points.append(m)
	spawn_yaw = PI  # face into the maze (+Z)

func _place_gates() -> void:
	for phase in gen.phase_gate_cells:
		var g := PhaseGate.new()
		g.map_id = map_id
		g.phase = phase
		g.width = CELL
		add_child(g)
		g.position = cell_pos(gen.phase_gate_cells[phase]) + Vector3(0, WALL_H / 2.0, 0)

func _place_puzzles() -> void:
	var plates: Array[PressurePlate] = []
	for key in ["A", "B"]:
		var p: PressurePlate = PLATE.instantiate()
		add_child(p)
		p.position = cell_pos(gen.points[key])
		plates.append(p)
	# Coop gate in the final band blocks the exit corridor
	var g: PuzzleGate = GATE.instantiate()
	add_child(g)
	var e: Vector2i = gen.points["E"]
	g.position = cell_pos(e) + Vector3(0, 1.4, -CELL)
	var ctrl := MultiPlateController.new()
	ctrl.plates = plates
	ctrl.gate = g
	add_child(ctrl)
	for i in 3:
		var t: FriendshipToken = TOKEN.instantiate()
		t.token_index = i
		add_child(t)
		t.position = cell_pos(gen.points["T%d" % (i + 1)]) + Vector3(0, 1.0, 0)

func _place_npcs_and_quests() -> void:
	var npc_cells := ["N1", "N2", "N3"]
	var npc_by_id := {}
	var npcs: Array = data.get("npcs", [])
	for i in npcs.size():
		var def: Dictionary = npcs[i]
		var npc := QuestNPC.new()
		npc.npc_name = def["name"]
		npc.map_id = map_id
		npc.dialogue_lines.assign(def.get("lines", []))
		npc.quest_index = -1  # filled below for the quest-giver role
		_add_npc_body(npc, def)
		add_child(npc)
		npc.position = cell_pos(gen.points[npc_cells[i % 3]])
		npc_by_id[def["id"]] = npc
	# Each quest is given by its NPC. One NPC can hold several quests, so
	# extra quests get a sibling "helper" NPC standing next to them.
	var quests: Array = data.get("quests", [])
	var given := {}
	for qi in quests.size():
		var q: Dictionary = quests[qi]
		var owner: QuestNPC = npc_by_id.get(q["npc"])
		if owner == null:
			continue
		var giver: QuestNPC = owner
		if given.has(owner):
			giver = QuestNPC.new()
			giver.npc_name = "%s (task %d)" % [owner.npc_name, qi + 1]
			_add_npc_body(giver, {"model": "npc_breadwise"})
			add_child(giver)
			giver.position = owner.position + Vector3(1.6 * given[owner], 0, 0)
			given[owner] += 1
		else:
			given[owner] = 1
		giver.map_id = map_id
		giver.quest_index = qi
		giver.quest_title = q["title"]
		giver.quest_type = q["type"]
		giver.intro_lines.assign(q.get("intro", []))
		giver.done_lines.assign(["Nice work, buddy! ✨"])
		giver.fetch_item = q.get("item", "")
		giver.target_count = int(q.get("count", 1))
		giver.plate_group = q.get("group", "")
		giver.marker_id = q.get("marker", "")
		_spawn_quest_objects(qi, q, npc_by_id)

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
	var path: String = NPC_MODELS % def.get("model", "npc_breadwise")
	if ResourceLoader.exists(path):
		var m := ModelSwap.new()
		m.name = "Model"
		m.model_path = path
		m.placeholder = NodePath("../NPCMesh")
		m.target_size = 1.3
		npc.add_child(m)
	var bubble := Label3D.new(); bubble.name = "SpeechBubble"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED; bubble.font_size = 36; bubble.outline_size = 8
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD; bubble.width = 600; bubble.position.y = 2.9
	npc.add_child(bubble)
	var nl := Label3D.new(); nl.name = "NameLabel"
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; nl.font_size = 44; nl.outline_size = 8; nl.position.y = 1.8
	npc.add_child(nl)
	var ia := Area3D.new(); ia.name = "InteractArea"
	npc.add_child(ia)

var _q_spot := 0
func _next_spot(min_phase: int) -> Vector3:
	# Quest objects appear in the phase the quest belongs to (or later)
	for i in 8:
		var key := "Q%d" % ((_q_spot + i) % 8)
		var c: Vector2i = gen.points[key]
		if MazeGen.phase_of(c.y) >= min_phase:
			_q_spot = (_q_spot + i + 1) % 8
			return cell_pos(c)
	_q_spot += 1
	return cell_pos(gen.points["Q%d" % (_q_spot % 8)])

func _spawn_quest_objects(qi: int, q: Dictionary, npc_by_id: Dictionary) -> void:
	var phase := QuestManager.quest_phase(qi)
	match q["type"]:
		"fetch":
			var it := QuestItem.new()
			it.item_id = q["item"]; it.label = ITEM_ICONS.get(q["item"], "📦")
			it.map_id = map_id; it.quest_index = qi; it.carry = true
			add_child(it)
			it.position = _next_spot(phase) + Vector3(0, 0.8, 0)
		"collect":
			for k in int(q.get("count", 3)):
				var it := QuestItem.new()
				it.item_id = q["item"]; it.label = ITEM_ICONS.get(q["item"], "✨")
				it.map_id = map_id; it.quest_index = qi; it.carry = false
				add_child(it)
				it.position = _next_spot(phase) + Vector3(0, 0.8, 0)
		"reach":
			var m := QuestMarker.new()
			m.map_id = map_id; m.quest_index = qi; m.mode = "reach"; m.label = "📜"; m.hint = q["title"]
			add_child(m)
			m.position = _next_spot(phase)
		"survive":
			var m := QuestMarker.new()
			m.map_id = map_id; m.quest_index = qi; m.mode = "survive"; m.radius = 4.0
			m.label = "⏱"; m.hint = "Stay here together!"
			add_child(m)
			m.position = cell_pos(gen.points["ARENA"])
		"talk":
			var target: QuestNPC = npc_by_id.get(q.get("talk_to", ""))
			if target:
				var m := QuestMarker.new()
				m.map_id = map_id; m.quest_index = qi; m.mode = "talk"; m.radius = 1.6
				m.label = "💬"; m.hint = "Listen to %s" % target.npc_name
				add_child(m)
				m.position = target.position + Vector3(0, 0, 1.6)

func _place_obstacles() -> void:
	# Each map's obstacle list is reused as "flavours": we drop 4 per phase
	# (16 total) cycling through that map's own obstacle types.
	var defs: Array = data.get("obstacles", [])
	if defs.is_empty():
		return
	var n := 0
	for ph in range(1, 5):
		for i in 4:
			var def: Dictionary = defs[n % defs.size()]
			n += 1
			var c: Vector2i = gen.points["O%d_%d" % [ph, i]]
			var o := _make_obstacle(def, ph)
			if o == null:
				continue
			add_child(o)
			o.position = cell_pos(c)

func _make_obstacle(def: Dictionary, ph: int) -> ObstacleBase:
	var o: ObstacleBase
	var color := Color(0.4, 0.7, 1, 0.5)
	var icon := "⚠️"
	match def["type"]:
		"push":
			var p := PushZone.new()
			var d: Array = def.get("dir", [0, 0, 1])
			p.push_direction = Vector3(d[0], d[1], d[2])
			p.push_force = def.get("force", 6)
			o = p; color = Color(0.3, 0.6, 1, 0.45); icon = "💨"
		"slow":
			var s := SlowZone.new()
			s.slow_multiplier = def.get("factor", 0.4)
			o = s; color = Color(0.85, 0.85, 0.85, 0.5); icon = "🕸"
		"timed":
			var t := TimedHazard.new()
			t.on_duration = def.get("on", 2.5); t.off_duration = def.get("off", 3.5)
			t.phase_offset = def.get("offset", 0.0) + ph
			o = t; color = Color(1, 0.35, 0.2, 0.55); icon = "🔥"
		"patrol":
			var e := PatrolEnemy.new()
			e.speed = def.get("speed", 3.0); e.knockback = def.get("knock", 10.0)
			o = e; color = Color(0.9, 0.2, 0.6, 1); icon = "🤖"
		"dark":
			o = DarkRoom.new(); color = Color(0.05, 0.05, 0.1, 0.7); icon = "🌑"
		_:
			return null
	o.name = "Obstacle_%s" % def["type"]
	var zone := Area3D.new(); zone.name = "HitZone"
	zone.collision_layer = 0; zone.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new(); sh.size = Vector3(CELL * 0.95, 2.0, CELL * 0.95)
	cs.shape = sh; cs.position.y = 1.0
	zone.add_child(cs)
	o.add_child(zone)
	var vis := MeshInstance3D.new(); vis.name = "Visual"
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.emission_enabled = true; m.emission = Color(color.r, color.g, color.b); m.emission_energy_multiplier = 0.4
	if def["type"] == "patrol":
		var cap := CapsuleMesh.new(); cap.radius = 0.5; cap.height = 1.4
		vis.mesh = cap; vis.position.y = 0.7
	else:
		var pm := BoxMesh.new(); pm.size = Vector3(CELL * 0.95, 0.12, CELL * 0.95)
		vis.mesh = pm; vis.position.y = 0.06
	vis.material_override = m
	o.add_child(vis)
	var warn := Label3D.new(); warn.name = "WarningLabel"
	warn.text = icon; warn.font_size = 90; warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.position.y = 1.6
	o.add_child(warn)
	if def["type"] == "patrol":
		# Patrol inside its own corridor: walk to neighbouring open cells
		var pts: Array[Vector3] = []
		var base: Vector2i = Vector2i.ZERO
		for k in gen.points:
			if gen.points[k] is Vector2i and cell_pos(gen.points[k]).is_equal_approx(Vector3.ZERO):
				pass
		(o as PatrolEnemy).patrol_points = pts  # filled after placement
		o.ready.connect(func(): _fill_patrol(o as PatrolEnemy), CONNECT_ONE_SHOT)
	return o

## After placement: walk up to 4 cells in a straight open line each way.
func _fill_patrol(e: PatrolEnemy) -> void:
	var c := Vector2i(int(round((e.position.x - origin.x) / CELL - 0.5)), int(round((e.position.z - origin.z) / CELL - 0.5)))
	var best: Array[Vector3] = [e.position, e.position]
	var gw := grid[0].length() if grid.size() > 0 else 0
	var gh := grid.size()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for dir: Vector2i in dirs:
		var a := c; var b := c
		for i in 4:
			var n: Vector2i = a - dir
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh: break
			if grid[n.y][n.x] == "#": break
			a = n
		for i in 4:
			var n: Vector2i = b + dir
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh: break
			if grid[n.y][n.x] == "#": break
			b = n
		if (b - a).length() > (best[1] - best[0]).length() / CELL:
			best = [cell_pos(a), cell_pos(b)]
	e.patrol_points = best
	e._ready_lengths()

func _place_exit() -> void:
	$ExitZone.position = cell_pos(gen.points["E"]) + Vector3(0, 1.0, 0)
