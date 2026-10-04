extends Node3D
class_name MazeBuilder
## Builds a real maze from an ASCII layout at runtime: walls, floor tiles,
## and markers for plates, tokens, gate, NPC, spawn, and exit.
## Same layout on every machine (deterministic), so multiplayer stays in sync.
##
## Legend:
##   #  wall (cereal box)         .  floor
##   S  spawn area                E  exit portal
##   A/B pressure plates (both needed together)
##   G  gate (opens when A+B pressed)
##   T  friendship token          N  NPC (Breadwise)
##   P  decorative prop spot

@export var cell_size: float = 3.0
@export var wall_height: float = 2.6
@export_multiline var layout: String = """
#####################
#.........#.........#
#.........#....T....#
#.........#.........#
#....S....###.#######
#.................N.#
#...#.#########.###.#
#...#.#.......#...#.#
#.A.#.#...T...#...#.#
#...#.#.......#.B.#.#
#...#.#.......#...#.#
#####.#...#...#####.#
#.....#...#.........#
#..T..#...####G######
#.....#######.......#
#.....#######....E..#
#####################
"""

@export var wall_model_a: String = "res://assets/models/environment/kitchen/cereal_box.glb"
@export var wall_model_b: String = "res://assets/models/environment/kitchen/cereal_box_2.glb"

## Players face this way on spawn (radians; 0 = -Z). PI faces +Z = deeper into the maze.
## Players face +Z on spawn (deeper into the maze corridor).
@export var spawn_yaw: float = 0.0

## Filled in during build for MapBase / puzzle wiring.
var spawn_points: Array[Vector3] = []
var plate_positions: Array[Vector3] = []
var token_positions: Array[Vector3] = []
var gate_position := Vector3.ZERO
var npc_position := Vector3.ZERO
var exit_position := Vector3.ZERO
var rows: PackedStringArray

func build() -> void:
	rows = layout.strip_edges().split("\n")
	var origin := Vector3(-(rows[0].length() * cell_size) / 2.0, 0, -(rows.size() * cell_size) / 2.0)
	var wall_mat_a := _mat(Color(0.98, 0.62, 0.18))
	var wall_mat_b := _mat(Color(0.35, 0.78, 0.38))
	var floor_mat := _mat(Color(0.9, 0.86, 0.78))
	var path_mat := _mat(Color(0.85, 0.8, 0.7))
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(cell_size, wall_height, cell_size)
	var wall_shape := BoxShape3D.new()
	wall_shape.size = wall_box.size
	var walls := StaticBody3D.new()
	walls.name = "MazeWalls"
	add_child(walls)

	# One big floor
	var floor_body := StaticBody3D.new()
	floor_body.name = "MazeFloor"
	var fs := BoxShape3D.new()
	fs.size = Vector3(rows[0].length() * cell_size + 20, 1, rows.size() * cell_size + 20)
	var fc := CollisionShape3D.new(); fc.shape = fs; fc.position.y = -0.5
	floor_body.add_child(fc)
	var fm := MeshInstance3D.new()
	var fmesh := BoxMesh.new(); fmesh.size = fs.size
	fm.mesh = fmesh; fm.position.y = -0.5; fm.material_override = floor_mat
	floor_body.add_child(fm)
	add_child(floor_body)

	var wall_index := 0
	for z in rows.size():
		var row: String = rows[z]
		for x in row.length():
			var c := row[x]
			var center := origin + Vector3((x + 0.5) * cell_size, 0, (z + 0.5) * cell_size)
			match c:
				"#":
					# Collision
					var cs := CollisionShape3D.new()
					cs.shape = wall_shape
					cs.position = center + Vector3(0, wall_height / 2.0, 0)
					walls.add_child(cs)
					# Visual: alternate two cereal colors, tiny height jitter for character
					var mi := MeshInstance3D.new()
					mi.mesh = wall_box
					mi.material_override = wall_mat_a if (x + z) % 3 else wall_mat_b
					mi.position = cs.position
					walls.add_child(mi)
					wall_index += 1
				"S": spawn_points.append(center + Vector3(0, 0.3, 0))
				"A", "B": plate_positions.append(center)
				"T": token_positions.append(center + Vector3(0, 1.0, 0))
				"G": gate_position = center
				"N": npc_position = center
				"E": exit_position = center
			# Slightly darker floor tile on walkable cells → visible paths
			if c != "#":
				var tile := MeshInstance3D.new()
				var tm := PlaneMesh.new(); tm.size = Vector2(cell_size * 0.96, cell_size * 0.96)
				tile.mesh = tm
				tile.material_override = path_mat
				tile.position = center + Vector3(0, 0.01, 0)
				add_child(tile)
	# Spawn slots: walkable cells nearest the S cell (never inside a wall)
	if not spawn_points.is_empty():
		var base := spawn_points[0]
		var open: Array[Vector3] = []
		for z in rows.size():
			for x in rows[z].length():
				if rows[z][x] in [".", "S"]:
					open.append(cell_to_world(x, z) + Vector3(0, 0.3, 0))
		open.sort_custom(func(a, b): return a.distance_to(base) < b.distance_to(base))
		spawn_points = open.slice(0, 10)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	return m

## Converts a grid cell to world space (used by tests).
func cell_to_world(x: int, z: int) -> Vector3:
	var origin := Vector3(-(rows[0].length() * cell_size) / 2.0, 0, -(rows.size() * cell_size) / 2.0)
	return origin + Vector3((x + 0.5) * cell_size, 0, (z + 0.5) * cell_size)
