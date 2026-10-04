extends Control
## Main menu — play solo (friends drop in), host, join, customize, settings.

@onready var name_input: LineEdit = %NameInput
@onready var address_input: LineEdit = %AddressInput
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var customize_btn: Button = %CustomizeButton
@onready var quit_btn: Button = %QuitButton
@onready var status_label: Label = %StatusLabel
@onready var room_code_label: Label = %RoomCodeLabel

const LOBBY_SCENE := "res://scenes/ui/lobby.tscn"
const CUSTOMIZE_SCENE := "res://scenes/ui/customize.tscn"

const LOADING_TIPS := [
	"Tip: Crouching lets friends stand on your head. Friendship!",
	"Tip: High-fiving fills the Friendship Meter. Do it often.",
	"Tip: Running into walls is funny. Do it on purpose.",
	"Tip: Breadwise the crouton has never given correct directions.",
	"Tip: The cat in Grandma's Attic is not dangerous. Just rude.",
	"Tip: You can throw your friends. Should you? Probably.",
	"Tip: Nobody escapes alone. That's the whole point.",
	"Tip: Press Q to ping a spot. Words are optional.",
	"Tip: Hold G for emotes. 👋😂❤️",
]

var settings_panel: Control
var solo_map: OptionButton
var shop_panel: Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	customize_btn.pressed.connect(_on_customize)
	quit_btn.pressed.connect(func(): get_tree().quit())
	quit_btn.visible = not DeviceManager.is_mobile and OS.get_name() != "Web"

	# New: Play Solo + Settings buttons, inserted above Host
	var center := host_btn.get_parent()
	var solo := Button.new()
	solo.text = "▶ Play Solo  (friends can drop in)"
	solo.tooltip_text = "Explore alone. Gates and the exit open once a buddy joins."
	solo.pressed.connect(_on_solo)
	center.add_child(solo)
	center.move_child(solo, host_btn.get_index())
	solo_map = OptionButton.new()
	for m in ProgressionManager.get_unlocked_maps():
		var d: Dictionary = MapContent.get_map(m)
		solo_map.add_item(d.get("display", m))
		solo_map.set_item_metadata(solo_map.item_count - 1, m)
	center.add_child(solo_map)
	center.move_child(solo_map, solo.get_index())
	var shop := Button.new()
	shop.text = "🏪 Buddy Shop  (💰 %d)" % QuestManager.coins
	shop.pressed.connect(_on_shop)
	center.add_child(shop)
	center.move_child(shop, quit_btn.get_index())
	var settings := Button.new()
	settings.text = "⚙ Settings"
	settings.pressed.connect(_on_settings)
	center.add_child(settings)
	center.move_child(settings, quit_btn.get_index())

	host_btn.text = "👥 Host Game"
	join_btn.text = "🔗 Join Game"
	customize_btn.text = "🎩 Customize Buddy"
	address_input.placeholder_text = "Friend's IP address (e.g. 192.168.1.20)"

	# Bigger, thumb-friendly buttons on phones
	var s := DeviceManager.ui_scale()
	for c in center.get_children():
		if c is Button or c is LineEdit:
			c.custom_minimum_size.y = 46 * s
			c.add_theme_font_size_override("font_size", int(18 * s))

	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_failed)
	NetworkManager.room_created.connect(func(code): room_code_label.text = "Room code: " + code)

	name_input.text = NetworkManager.local_player_name
	address_input.text = ""
	status_label.text = LOADING_TIPS[randi() % LOADING_TIPS.size()]

func _on_solo() -> void:
	_save_name()
	var m := "kitchen_counter"
	if solo_map and solo_map.selected >= 0:
		m = solo_map.get_item_metadata(solo_map.selected)
	status_label.text = "Entering %s… friends can join any time." % MapContent.get_map(m).get("display", m)
	NetworkManager.start_solo(m)

func _on_host() -> void:
	_save_name()
	status_label.text = "Creating room..."
	NetworkManager.host_game()

func _on_join() -> void:
	_save_name()
	var addr := address_input.text.strip_edges()
	if addr.is_empty():
		status_label.text = "Type your friend's IP address first. (Same Wi-Fi: they can find it in Settings → Network.)"
		address_input.grab_focus()
		return
	status_label.text = "Connecting to %s..." % addr
	NetworkManager.join_game(addr)

func _on_customize() -> void:
	_save_name()
	get_tree().change_scene_to_file(CUSTOMIZE_SCENE)

func _on_shop() -> void:
	if shop_panel == null:
		shop_panel = preload("res://scripts/ui/coin_shop.gd").new()
		add_child(shop_panel)
	shop_panel.visible = true

func _on_settings() -> void:
	if settings_panel == null:
		settings_panel = preload("res://scripts/ui/settings_panel.gd").new()
		add_child(settings_panel)
	settings_panel.visible = true

func _on_connected() -> void:
	# Solo mode loads the map directly; host/join go to the lobby
	if GameManager.is_playing:
		return
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_failed(reason: String) -> void:
	status_label.text = "Couldn't connect: %s\nCheck the IP, that you're on the same network, and that the host is in a lobby." % reason

func _save_name() -> void:
	var n := name_input.text.strip_edges()
	if n.length() > 0:
		NetworkManager.local_player_name = n.substr(0, 16)
