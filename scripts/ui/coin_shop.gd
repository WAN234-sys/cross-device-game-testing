extends PanelContainer
## Coin shop — spend quest coins on hats, colors, emotes, and speed boosts.
## Opened from the main menu or pause menu. All purchases persist via
## CosmeticManager/QuestManager save files.

signal closed

## Hat ids must exist in CosmeticManager.HAT_DISPLAY_NAMES; colors are
## html hex from CosmeticManager.ALL_COLORS.
const SHOP_ITEMS := [
	{"id": "hat_propeller", "type": "hat", "name": "🧢 Propeller Cap", "cost": 10, "unlock": "propeller"},
	{"id": "hat_bucket", "type": "hat", "name": "🪣 Bucket", "cost": 10, "unlock": "bucket"},
	{"id": "hat_fez", "type": "hat", "name": "🎩 Fancy Fez", "cost": 15, "unlock": "fez"},
	{"id": "hat_viking", "type": "hat", "name": "⚔ Viking Helmet", "cost": 20, "unlock": "viking"},
	{"id": "hat_party", "type": "hat", "name": "🥳 Party Hat", "cost": 15, "unlock": "party"},
	{"id": "hat_chef", "type": "hat", "name": "👨‍🍳 Chef Hat", "cost": 20, "unlock": "chef_hat"},
	{"id": "hat_tophat", "type": "hat", "name": "🎩 Top Hat", "cost": 30, "unlock": "top_hat"},
	{"id": "hat_crown", "type": "hat", "name": "👑 Royal Crown", "cost": 50, "unlock": "crown"},
	{"id": "color_pink", "type": "color", "name": "🩷 Bubblegum", "cost": 8, "unlock": "ff8fab"},
	{"id": "color_purple", "type": "color", "name": "💜 Grape", "cost": 8, "unlock": "7b5cff"},
	{"id": "color_teal", "type": "color", "name": "🩵 Teal", "cost": 8, "unlock": "00c2a8"},
	{"id": "color_orange", "type": "color", "name": "🧡 Tangerine", "cost": 8, "unlock": "ff6b35"},
	{"id": "color_ink", "type": "color", "name": "🖤 Ink", "cost": 12, "unlock": "2e2e3a"},
	{"id": "color_mint", "type": "color", "name": "🤍 Mint", "cost": 8, "unlock": "a0e7e5"},
]

var grid: GridContainer
var coin_label: Label
var _buttons := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_CENTER)
	custom_minimum_size = Vector2(520, 440)
	size = custom_minimum_size
	position = -size / 2
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.1, 0.95)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	var title := Label.new()
	title.text = "🏪 Buddy Shop"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	coin_label = Label.new()
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(coin_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for item in SHOP_ITEMS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(230, 44)
		var id: String = item["id"]
		btn.pressed.connect(func(): _buy(id))
		grid.add_child(btn)
		_buttons[id] = btn
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): visible = false; closed.emit())
	vbox.add_child(close_btn)
	_refresh()
	QuestManager.coins_changed.connect(func(_c): _refresh())

func _refresh() -> void:
	coin_label.text = "💰 Coins: %d" % QuestManager.coins
	for item in SHOP_ITEMS:
		var btn: Button = _buttons[item["id"]]
		var owned := _owns(item)
		if owned:
			btn.text = "%s  ✅ owned" % item["name"]
			btn.disabled = true
		elif QuestManager.coins < int(item["cost"]):
			btn.text = "%s  💰%d (need %d more)" % [item["name"], item["cost"], int(item["cost"]) - QuestManager.coins]
			btn.disabled = true
		else:
			btn.text = "%s  💰%d" % [item["name"], item["cost"]]
			btn.disabled = false

func _owns(item: Dictionary) -> bool:
	match item["type"]:
		"hat":
			return item["unlock"] in GameManager.unlocked_hats
		"color":
			return Color.html(item["unlock"]) in GameManager.unlocked_colors
	return false

func _buy(id: String) -> void:
	var item: Dictionary = {}
	for i in SHOP_ITEMS:
		if i["id"] == id:
			item = i
			break
	if item.is_empty():
		return
	if not QuestManager.spend_coins(int(item["cost"])):
		return
	if _owns(item):
		return
	match item["type"]:
		"hat":
			GameManager.unlocked_hats.append(item["unlock"])
		"color":
			GameManager.unlocked_colors.append(Color.html(item["unlock"]))
	GameManager._save_game()
	AudioManager.play_boing(Vector3.ZERO)
	_refresh()
