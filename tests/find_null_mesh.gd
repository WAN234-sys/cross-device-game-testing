extends SceneTree
## Lists MeshInstance3D nodes whose mesh is null or has 0 surfaces after the map + models load.

var frame := 0
func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		root.get_node("NetworkManager").start_solo("kitchen_counter")
	if frame == 30:
		_scan(current_scene)
		quit()
	return false

func _scan(n: Node) -> void:
	if n is MeshInstance3D:
		var m: Mesh = n.mesh
		if m == null or m.get_surface_count() == 0:
			print("EMPTY MESH: ", n.get_path(), " mesh=", m)
	for c in n.get_children():
		_scan(c)
