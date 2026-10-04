extends Control
## Character customization — live 3D preview you can spin, colors, hats,
## faces, and body size. Locked items show how to earn them.

@onready var color_grid: GridContainer = %ColorGrid
@onready var hat_list: ItemList = %HatList
@onready var preview_label: Label = %PreviewLabel
@onready var back_btn: Button = %BackButton

var viewport: SubViewport
var preview_root: Node3D
var bean: ModelSwap
var hat_slot: Node3D
var face_label: Label3D
var _drag := false

func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	_build_preview()
	_build_colors()
	_build_hats()
	_build_face_and_size()
	_refresh()

# --- 3D preview ---

func _build_preview() -> void:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(320, 320) * minf(DeviceManager.ui_scale(), 1.2)
	var center := color_grid.get_parent()
	center.add_child(holder)
	center.move_child(holder, preview_label.get_index())
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	holder.add_child(viewport)
	preview_root = Node3D.new()
	viewport.add_child(preview_root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.8, 2.6)
	cam.look_at_from_position(cam.position, Vector3(0, 0.65, 0))
	viewport.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.environment.ambient_light_energy = 0.7
	viewport.add_child(env)
	# Bean: placeholder capsule underneath in case the GLB isn't imported yet
	var ph := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4; cap.height = 1.0
	ph.mesh = cap
	ph.position.y = 0.5
	ph.material_override = StandardMaterial3D.new()
	ph.name = "Placeholder"
	preview_root.add_child(ph)
	bean = ModelSwap.new()
	bean.model_path = "res://assets/models/characters/player_bean.glb"
	bean.placeholder = NodePath("../Placeholder")
	bean.target_size = 1.1
	bean.rotate_y_deg = 180.0
	preview_root.add_child(bean)
	hat_slot = Node3D.new()
	hat_slot.position.y = 1.15
	preview_root.add_child(hat_slot)
	face_label = Label3D.new()
	face_label.position = Vector3(0, 0.75, 0.45)
	face_label.font_size = 96
	face_label.pixel_size = 0.004
	preview_root.add_child(face_label)
	holder.gui_input.connect(_on_preview_input)

func _on_preview_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		_drag = ev.pressed
	elif (ev is InputEventMouseMotion and _drag) or ev is InputEventScreenDrag:
		preview_root.rotate_y(ev.relative.x * 0.012)

func _process(delta: float) -> void:
	if not _drag and preview_root and not SettingsManager.reduce_motion:
		preview_root.rotate_y(delta * 0.6)

# --- Colors ---

func _build_colors() -> void:
	color_grid.columns = 6
	var s := DeviceManager.ui_scale()
	for c: Color in CosmeticManager.ALL_COLORS:
		var unlocked := c in GameManager.unlocked_colors
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52) * s
		b.tooltip_text = "Tap to wear" if unlocked else "🔒 Unlock by winning games"
		var sb := StyleBoxFlat.new()
		sb.bg_color = c if unlocked else c.darkened(0.7)
		sb.set_corner_radius_all(int(26 * s))
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.text = "" if unlocked else "🔒"
		b.disabled = not unlocked
		b.pressed.connect(func(): CosmeticManager.set_color(c); _refresh())
		color_grid.add_child(b)

# --- Hats ---

func _build_hats() -> void:
	hat_list.clear()
	for h in CosmeticManager.HAT_DISPLAY_NAMES:
		var unlocked: bool = h in GameManager.unlocked_hats
		var label: String = CosmeticManager.HAT_DISPLAY_NAMES[h]
		hat_list.add_item(label if unlocked else "🔒 %s — %s" % [label, CosmeticManager.HAT_UNLOCK_HINTS.get(h, "")])
		var i := hat_list.item_count - 1
		hat_list.set_item_metadata(i, h)
		hat_list.set_item_disabled(i, not unlocked)
	hat_list.item_selected.connect(func(i): CosmeticManager.set_hat(hat_list.get_item_metadata(i)); _refresh())

# --- Face + body size ---

func _build_face_and_size() -> void:
	var center := color_grid.get_parent()
	var row := HBoxContainer.new()
	var face_btn := Button.new()
	face_btn.text = "Change face 😊"
	face_btn.pressed.connect(func(): CosmeticManager.cycle_face(); _refresh())
	row.add_child(face_btn)
	var size_l := Label.new()
	size_l.text = "  Chunkiness"
	row.add_child(size_l)
	var slider := HSlider.new()
	slider.min_value = 0.85; slider.max_value = 1.2; slider.step = 0.05
	slider.value = CosmeticManager.current_size
	slider.custom_minimum_size = Vector2(140, 32)
	slider.value_changed.connect(func(v): CosmeticManager.current_size = v; _refresh())
	row.add_child(slider)
	var random := Button.new()
	random.text = "🎲 Surprise me"
	random.pressed.connect(_randomize)
	row.add_child(random)
	center.add_child(row)
	center.move_child(row, back_btn.get_index())

func _randomize() -> void:
	CosmeticManager.set_color(GameManager.unlocked_colors.pick_random())
	CosmeticManager.set_hat(GameManager.unlocked_hats.pick_random())
	for i in randi() % 5:
		CosmeticManager.cycle_face()
	_refresh()

func _refresh() -> void:
	var face: String = CosmeticManager.get_face_name()
	preview_label.text = "%s — %s %s" % [NetworkManager.local_player_name, CosmeticManager.HAT_DISPLAY_NAMES.get(CosmeticManager.current_hat, "No Hat"), CosmeticManager.FACE_ICONS.get(face, "")]
	preview_label.add_theme_color_override("font_color", CosmeticManager.current_color)
	if bean:
		bean.tint = CosmeticManager.current_color
		bean.apply_tint(CosmeticManager.current_color)
		var ph := preview_root.get_node_or_null("Placeholder") as MeshInstance3D
		if ph:
			(ph.material_override as StandardMaterial3D).albedo_color = CosmeticManager.current_color
		var sz := CosmeticManager.current_size
		preview_root.scale = Vector3(sz, 1.0 + (1.0 - sz) * 0.4, sz)
		face_label.text = CosmeticManager.FACE_ICONS.get(face, "")
		for c in hat_slot.get_children():
			c.queue_free()
		var path: String = BuddyPlayer.HAT_MODELS.get(CosmeticManager.current_hat, "")
		if path and ResourceLoader.exists(path):
			var hat := ModelSwap.new()
			hat.model_path = path
			hat.target_size = 0.45
			hat_slot.add_child(hat)
