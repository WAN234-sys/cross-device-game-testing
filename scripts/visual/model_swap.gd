extends Node3D
class_name ModelSwap
## Replaces a sibling placeholder mesh with a detailed GLB model at runtime.
## Keeps collisions/scripts untouched. If the GLB is missing or not yet imported,
## the placeholder stays visible, so the game never breaks.
##
## Usage: add as a child of any object, set `model_path`, and optionally
## `placeholder` (the MeshInstance3D to hide) and `target_size` (meters).

@export_file("*.glb") var model_path: String = ""
@export var placeholder: NodePath
@export var target_size: float = 0.0   ## 0 = keep the model's native size
@export var y_offset: float = 0.0
@export var rotate_y_deg: float = 0.0
@export var tint: Color = Color(1, 1, 1, 0)  ## alpha > 0 recolors all surfaces (e.g. player color)

var model: Node3D

func _ready() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var scene := load(model_path) as PackedScene
	if scene == null:
		return
	model = scene.instantiate() as Node3D
	add_child(model)
	model.rotation_degrees.y = rotate_y_deg
	if target_size > 0.0:
		_fit_to_size(target_size)
	model.position.y += y_offset
	if tint.a > 0.0:
		apply_tint(tint)
	var ph := get_node_or_null(placeholder) as MeshInstance3D
	if ph:
		ph.visible = false
		# Keep placeholder children (eyes, labels) hidden too
		for c in ph.get_children():
			if c is VisualInstance3D:
				c.visible = false

func _fit_to_size(size: float) -> void:
	var aabb := _combined_aabb(model)
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if longest <= 0.0001:
		return
	var s := size / longest
	model.scale = Vector3.ONE * s
	# Sit the model's base on y = 0 of this node
	model.position.y = -aabb.position.y * s

func _combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in _meshes(root):
		# Transform from mesh space into root space by walking up the parent chain
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box: AABB = xf * mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_meshes(c))
	return out

## Recolor the model (used for per-player bean color).
func apply_tint(color: Color) -> void:
	if model == null:
		return
	for mi in _meshes(model):
		for i in mi.get_surface_override_material_count():
			var base := mi.get_active_material(i)
			var mat: StandardMaterial3D
			if base is StandardMaterial3D:
				mat = base.duplicate()
			else:
				mat = StandardMaterial3D.new()
			# Only tint the main body surface (largest/first); keep eyes etc.
			if i == 0:
				mat.albedo_color = color
			mi.set_surface_override_material(i, mat)
