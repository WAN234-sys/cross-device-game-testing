extends Control
## Pre-game lobby — buddy cards, ready-up, map picker with descriptions,
## and a clear "need at least 2 buddies" rule.

@onready var player_list: VBoxContainer = %PlayerList
@onready var map_select: OptionButton = %MapSelect
@onready var start_btn: Button = %StartButton
@onready var leave_btn: Button = %LeaveButton
@onready var room_code_label: Label = %RoomCodeLabel
@onready var player_count_label: Label = %PlayerCountLabel

const MAP_DISPLAY := {
	"kitchen_counter": "🍳 Kitchen Counter",
	"toy_chest": "🧸 Toy Chest",
	"grandmas_attic": "🕸 Grandma's Attic",
	"garden_shed": "🌱 Garden Shed",
	"school_backpack": "🎒 School Backpack",
}
const MAP_BLURB := {
	"kitchen_counter": "🍳 4 phases · 6 quests · Cereal-box mazes, water puddles, falling forks. A crouton with terrible advice. ~15 min.",
	"toy_chest": "🧸 4 phases · 6 quests · Building blocks, wind-up soldiers, bouncy balls. A teddy who judges you. ~18 min.",
	"grandmas_attic": "🕸 4 phases · 6 quests · Cobweb slowdowns, cat paw patrols, dark rooms needing flashlights. ~20 min.",
	"garden_shed": "🌱 4 phases · 6 quests · Sprinkler floods, vine growth, mud patches. The ladybug therapist wants to talk. ~20 min.",
	"school_backpack": "🎒 4 phases · 6 quests · Eraser zones, pencil launchers, zipper walls. Hard mode. ~22 min.",
}

var ready_btn: Button
var blurb: Label
var local_ready := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_btn.visible = NetworkManager.is_host
	start_btn.pressed.connect(_on_start)
	leave_btn.pressed.connect(_on_leave)
	room_code_label.text = "Invite code: %s" % NetworkManager.room_code if NetworkManager.room_code else "Connected"

	var box := start_btn.get_parent()
	blurb = Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	blurb.modulate = Color(0.75, 0.82, 0.75)
	box.add_child(blurb)
	box.move_child(blurb, map_select.get_index() + 1)
	ready_btn = Button.new()
	ready_btn.toggle_mode = true
	ready_btn.text = "✋ I'm ready"
	ready_btn.toggled.connect(_on_ready_toggled)
	box.add_child(ready_btn)
	box.move_child(ready_btn, start_btn.get_index())

	for map_id in ProgressionManager.get_unlocked_maps():
		map_select.add_item(MAP_DISPLAY.get(map_id, map_id))
		map_select.set_item_metadata(map_select.item_count - 1, map_id)
	map_select.item_selected.connect(func(_i): _update_blurb())
	map_select.disabled = not NetworkManager.is_host
	_update_blurb()

	GameManager.player_joined.connect(func(_id): _refresh_players())
	GameManager.player_left.connect(func(_id): _refresh_players())
	GameManager.game_started.connect(_on_game_started)
	NetworkManager.ready_changed.connect(func(_id, _r): _refresh_players())
	_refresh_players()

func _update_blurb() -> void:
	if map_select.selected < 0:
		return
	blurb.text = MAP_BLURB.get(map_select.get_item_metadata(map_select.selected), "")

func _on_ready_toggled(on: bool) -> void:
	local_ready = on
	ready_btn.text = "✅ Ready!" if on else "✋ I'm ready"
	NetworkManager.set_ready(on)

func _refresh_players() -> void:
	for child in player_list.get_children():
		child.queue_free()
	var all_ready := true
	for peer_id in GameManager.player_data:
		var data: Dictionary = GameManager.player_data[peer_id]
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.17, 0.14)
		sb.border_color = data.get("color", Color.WHITE)
		sb.border_width_left = 6
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14; sb.content_margin_top = 6; sb.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		var hat: String = CosmeticManager.HAT_DISPLAY_NAMES.get(data.get("hat", "none"), "")
		var is_ready: bool = data.get("ready", false)
		all_ready = all_ready and is_ready
		l.text = "%s%s   %s   %s" % [data.get("name", "???"), "  👑 host" if peer_id == 1 else "", "🎩 " + hat if hat and hat != "No Hat" else "", "✅" if is_ready else "⏳"]
		card.add_child(l)
		player_list.add_child(card)
	var n := GameManager.player_data.size()
	var need := GameManager.MIN_PLAYERS_FOR_COOP
	if n < need:
		player_count_label.text = "%d / %d buddies — share the invite code! (need %d to finish a maze)" % [n, GameManager.MAX_PLAYERS, need]
	else:
		player_count_label.text = "%d / %d buddies%s" % [n, GameManager.MAX_PLAYERS, "  · everyone ready!" if all_ready else "  · waiting for ready-ups"]
	start_btn.text = "▶ Start" if n >= need else "▶ Start anyway (explore until a buddy joins)"

func _on_start() -> void:
	if map_select.selected < 0:
		return
	var map_id: String = map_select.get_item_metadata(map_select.selected)
	NetworkManager.request_start_game(map_id)

func _on_game_started() -> void:
	NetworkManager.load_map_scene(GameManager.current_map)

func _on_leave() -> void:
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
