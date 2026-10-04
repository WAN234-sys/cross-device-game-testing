extends SceneTree
## Renders the game with a real GPU and saves screenshots to user:// for review.

var frame := 0
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_user_data_dir()

func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("SHOT: ", path)

func _process(_d: float) -> bool:
	frame += 1
	match frame:
		30:
			_shot("01_main_menu")
		35:
			root.get_node("NetworkManager").start_solo("kitchen_counter")
		120:
			_shot("02_kitchen_spawn")
		125:
			# Turn left toward Breadwise and the room exit
			var p = current_scene.get_node("Players").get_child(0)
			p.rotation.y += PI / 4
		180:
			_shot("03_kitchen_view")
		185:
			# Bird's-eye view of the whole maze
			var p = current_scene.get_node("Players").get_child(0)
			p.set_physics_process(false)
			p.global_position = Vector3(0, 34, 22)
			p.rotation.y = 0
			p.get_node("Head").rotation.x = -1.0
		240:
			_shot("04_overview")
		245:
			root.get_node("NetworkManager").disconnect_game()
			change_scene_to_file("res://scenes/ui/main_menu.tscn")
		290:
			_shot("05_main_menu_themed")
			quit()
	return false
