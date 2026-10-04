extends RefCounted
class_name MazeGen
## Deterministic 4-phase maze generator. Every map uses the same proven
## structure, with its own seed so corridors differ per map:
##
##   ┌──────────── Phase 1 ───────────┐ (spawn, NPC1, 2 quests, free to roam)
##   └────────── PHASE GATE 2 ────────┘
##   ┌──────────── Phase 2 ───────────┐ (NPC2, plates A/B far apart, tokens)
##   └────────── PHASE GATE 3 ────────┘
##   ┌──────────── Phase 3 ───────────┐ (NPC3, survive arena, obstacles)
##   └────────── PHASE GATE 4 ────────┘
##   ┌──────────── Phase 4 ───────────┐ (final corridor, coop gate G, exit E)
##
## Each phase band is a recursive-backtracker maze (always fully connected),
## joined to the next band ONLY through its gate cell. So:
##   - everything in a phase is reachable from that phase's entrance
##   - you cannot reach phase N+1 without passing gate N+1
## Output: rows of chars, plus named points.

const W := 31          # odd; maze cells live on odd coordinates
const BAND_H := 13     # rows per phase band (odd)

var rows: Array[PackedByteArray] = []
var points := {}       # name -> Vector2i
var phase_gate_cells := {}  # phase -> Vector2i
var walkable_by_phase := {} # phase -> Array[Vector2i]
var rng := RandomNumberGenerator.new()

func generate(seed: int) -> PackedStringArray:
	rng.seed = seed
	var H := BAND_H * 4 + 1
	rows.clear()
	for z in H:
		var r := PackedByteArray()
		r.resize(W)
		r.fill(35)  # '#'
		rows.append(r)
	for phase in range(1, 5):
		var top := (phase - 1) * BAND_H + 1
		_carve_band(top, top + BAND_H - 2)
		# Open a few extra loops so it's not a single long corridor (friendlier for groups)
		for i in 6:
			var x := rng.randi_range(1, (W - 3) / 2) * 2
			var z := rng.randi_range(0, (BAND_H - 3) / 2) * 2 + top + 1
			if z < top + BAND_H - 1:
				_cell_set(x, z, 46)
		# Carve a 5x3 open room in the middle of each band (for NPCs/arenas)
		var rx := W / 2 - 2
		var rz := top + BAND_H / 2 - 1
		for zz in range(rz, rz + 3):
			for xx in range(rx, rx + 5):
				_cell_set(xx, zz, 46)
		var cells: Array[Vector2i] = []
		for zz in range(top, top + BAND_H - 1):
			for xx in range(1, W - 1):
				if _cell_get(xx, zz) == 46:
					cells.append(Vector2i(xx, zz))
		walkable_by_phase[phase] = cells
		# Gate between this band and the next: one cell in the wall row
		if phase < 4:
			var wall_z := top + BAND_H - 1
			var gx := rng.randi_range(1, (W - 3) / 2) * 2 + 1
			_cell_set(gx, wall_z, 71)  # 'G' placeholder for phase gate
			# make sure the cells right above/below are open
			_cell_set(gx, wall_z - 1, 46)
			_cell_set(gx, wall_z + 1, 46)
			phase_gate_cells[phase + 1] = Vector2i(gx, wall_z)
	_place_points()
	var out := PackedStringArray()
	for r in rows:
		out.append(r.get_string_from_ascii())
	return out

func _cell_get(x: int, z: int) -> int:
	return rows[z][x]

func _cell_set(x: int, z: int, v: int) -> void:
	rows[z][x] = v

## Recursive backtracker on odd coordinates inside [top, bottom].
func _carve_band(top: int, bottom: int) -> void:
	var start := Vector2i(1, top)
	var stack: Array[Vector2i] = [start]
	_cell_set(start.x, start.y, 46)
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var dirs := [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
		dirs.shuffle()  # uses global RNG; reseed below for determinism
		var moved := false
		var order := [0, 1, 2, 3]
		for i in range(3, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = order[i]; order[i] = order[j]; order[j] = tmp
		for idx in order:
			var d: Vector2i = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)][idx]
			var n := c + d
			if n.x < 1 or n.x > W - 2 or n.y < top or n.y > bottom:
				continue
			if _cell_get(n.x, n.y) == 35:
				_cell_set(c.x + d.x / 2, c.y + d.y / 2, 46)
				_cell_set(n.x, n.y, 46)
				stack.append(n)
				moved = true
				break
		if not moved:
			stack.pop_back()

func _far_cell(phase: int, from: Vector2i, exclude: Array) -> Vector2i:
	var best := from
	var best_d := -1
	for c in walkable_by_phase[phase]:
		if c in exclude:
			continue
		var d := absi(c.x - from.x) + absi(c.y - from.y)
		if d > best_d:
			best_d = d; best = c
	return best

func _pick(phase: int, exclude: Array) -> Vector2i:
	var cells: Array = walkable_by_phase[phase]
	for i in 200:
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if not (c in exclude):
			return c
	return cells[0]

func _room_center(phase: int) -> Vector2i:
	var top := (phase - 1) * BAND_H + 1
	return Vector2i(W / 2, top + BAND_H / 2)

func _place_points() -> void:
	var used: Array = []
	var p1_center := _room_center(1)
	points["S"] = Vector2i(1, 1)
	used.append(points["S"])
	points["N1"] = p1_center + Vector2i(1, 0); used.append(points["N1"])
	# Phase 2: plates as far apart as possible + NPC2 in its room
	var a := _far_cell(2, _room_center(2), used); used.append(a)
	var b := _far_cell(2, a, used); used.append(b)
	points["A"] = a; points["B"] = b
	points["N2"] = _room_center(2) + Vector2i(1, 0); used.append(points["N2"])
	# Phase 3: NPC3 + survive arena (room center)
	points["N3"] = _room_center(3) + Vector2i(1, 0); used.append(points["N3"])
	points["ARENA"] = _room_center(3) + Vector2i(-1, 0); used.append(points["ARENA"])
	# Phase 4: exit as far from the gate as possible, coop gate G one step before it
	var g4: Vector2i = phase_gate_cells[4]
	var e := _far_cell(4, g4, used)
	points["E"] = e; used.append(e)
	# Tokens: one per phase 2..4 (phase 1 stays a gentle intro)
	points["T1"] = _pick(2, used); used.append(points["T1"])
	points["T2"] = _pick(3, used); used.append(points["T2"])
	points["T3"] = _pick(4, used); used.append(points["T3"])
	# Quest spots spread over phases
	for i in 8:
		var ph := 1 + (i % 4)
		points["Q%d" % i] = _pick(ph, used); used.append(points["Q%d" % i])
	# Obstacle spots: 4 per phase
	for ph in range(1, 5):
		for i in 4:
			var key := "O%d_%d" % [ph, i]
			points[key] = _pick(ph, used); used.append(points[key])

## Phase (1..4) a grid cell belongs to.
static func phase_of(z: int) -> int:
	return clampi((z - 1) / BAND_H + 1, 1, 4)
