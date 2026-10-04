extends CanvasLayer
## In-game HUD — timer, tokens, friendship meter, context prompts, co-op status,
## buddy roster, world pings, emote wheel, pause menu, and touch controls.

@onready var timer_label: Label = %TimerLabel
@onready var token_label: Label = %TokenLabel
@onready var friendship_bar: ProgressBar = %FriendshipBar
@onready var prompt_label: Label = %PromptLabel
@onready var notification_label: Label = %NotificationLabel
@onready var crosshair: Control = %Crosshair

var coop_banner: PanelContainer
var coop_label: Label
var roster: VBoxContainer
var emote_wheel: Control
var pause_menu: Control
var settings_panel: Control
var fps_label: Label
var ping_markers: Dictionary = {}  # id -> {node, world_pos, ttl}

const PING_STYLE := {
	"look": ["👀", "Look here"], "token": ["🪙", "Token!"], "plate": ["⬇", "Stand here"],
	"npc": ["💬", "Talk"], "help": ["🆘", "Help!"],
}

func _ready() -> void:
	add_to_group("hud")
	GameManager.token_collected.connect(_on_token)
	GameManager.all_tokens_collected.connect(_on_all_tokens)
	GameManager.friendship_meter_changed.connect(_on_friendship)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.coop_state_changed.connect(_on_coop_changed)
	GameManager.player_joined.connect(func(id): _refresh_roster(); _notify("%s joined the maze!" % _pname(id)))
	GameManager.player_left.connect(func(_id): _refresh_roster())
	GameManager.ping_placed.connect(_on_ping)
	GameManager.emote_played.connect(func(id, e): if id != multiplayer.get_unique_id(): _notify("%s: %s" % [_pname(id), e.capitalize()], 1.5))
	notification_label.visible = false
	prompt_label.text = ""
	_build_coop_banner()
	_build_roster()
	_build_emote_wheel()
	_build_pause_menu()
	_build_fps()
	_build_quest_panel()
	if DeviceManager.is_mobile:
		add_child(preload("res://scripts/ui/touch_controls.gd").new())
	_apply_scale()
	SettingsManager.settings_changed.connect(_apply_scale)
	_update_tokens()
	_refresh_roster()
	_on_coop_changed(GameManager.is_coop_ready())

func _apply_scale() -> void:
	var s := DeviceManager.ui_scale()
	for l: Label in [timer_label, token_label, prompt_label, notification_label]:
		l.add_theme_font_size_override("font_size", int(24 * s))
	fps_label.visible = SettingsManager.show_fps

func _process(_delta: float) -> void:
	if GameManager.is_playing:
		var remaining := GameManager.get_time_remaining()
		timer_label.text = "%d:%02d" % [int(remaining) / 60, int(remaining) % 60]
		if not GameManager.is_coop_ready():
			timer_label.text += "  ⏸"
		timer_label.modulate = Color.RED if remaining < 60 else Color.WHITE
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_update_pings(_delta)
	# Emote wheel: hold G (or the touch button) to open
	if Input.is_action_just_pressed("emote_wheel"):
		_open_wheel(true)
	elif Input.is_action_just_released("emote_wheel"):
		_open_wheel(false)
	if Input.is_action_just_pressed("pause_menu"):
		_toggle_pause()

# --- Public API used by the player controller ---

func show_prompt(text: String) -> void:
	prompt_label.text = text

func clear_prompt() -> void:
	prompt_label.text = ""

# --- Co-op status (solo explore vs. ready) ---

func _build_coop_banner() -> void:
	coop_banner = PanelContainer.new()
	coop_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	coop_banner.position.y = 60
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.8)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	coop_banner.add_theme_stylebox_override("panel", sb)
	coop_label = Label.new()
	coop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coop_banner.add_child(coop_label)
	add_child(coop_banner)

func _on_coop_changed(is_ready: bool) -> void:
	if is_ready:
		coop_label.text = "🤝 Buddies here! Puzzles are live."
		coop_label.modulate = Color(0.77, 0.94, 0.63)
		var t := create_tween()
		t.tween_interval(3.0)
		t.tween_property(coop_banner, "modulate:a", 0.0, 0.6)
	else:
		coop_banner.modulate.a = 1.0
		var code := NetworkManager.room_code
		coop_label.text = "🧭 Solo explore — gates need a buddy.  Invite code: %s" % (code if code else "—")
		coop_label.modulate = Color(1, 0.85, 0.4)

# --- Buddy roster (who's here, their color) ---

func _build_roster() -> void:
	roster = VBoxContainer.new()
	roster.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	roster.position = Vector2(-220, 70)
	roster.custom_minimum_size = Vector2(200, 0)
	add_child(roster)

func _refresh_roster() -> void:
	if roster == null:
		return
	for c in roster.get_children():
		c.queue_free()
	for id in GameManager.player_data:
		var d: Dictionary = GameManager.player_data[id]
		var row := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = d.get("color", Color.WHITE)
		var l := Label.new()
		l.text = "%s%s" % [d.get("name", "?"), "  ✅" if d.get("at_exit", false) else ""]
		row.add_child(dot)
		row.add_child(l)
		roster.add_child(row)

# --- Pings ---

func _on_ping(sender: int, pos: Vector3, kind: String) -> void:
	var style: Array = PING_STYLE.get(kind, PING_STYLE["look"])
	var l := Label.new()
	l.text = "%s\n%s · %s" % [style[0], _pname(sender), style[1]]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(20 * DeviceManager.ui_scale()))
	l.add_theme_color_override("font_color", GameManager.player_data.get(sender, {}).get("color", Color.WHITE))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	var key := str(sender)
	if ping_markers.has(key):
		ping_markers[key].node.queue_free()
	ping_markers[key] = {"node": l, "pos": pos, "ttl": 6.0}
	AudioManager.play_boing(pos)

func _update_pings(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	for key in ping_markers.keys():
		var p: Dictionary = ping_markers[key]
		p.ttl -= delta
		if p.ttl <= 0.0 or cam == null:
			p.node.queue_free()
			ping_markers.erase(key)
			continue
		var vp := get_viewport().get_visible_rect().size
		var behind := cam.is_position_behind(p.pos)
		var sp := cam.unproject_position(p.pos)
		if behind:
			sp = vp - sp  # mirror so off-screen pings point the right way
		# Clamp to the screen edge so pings are always visible
		sp.x = clampf(sp.x, 40, vp.x - 40)
		sp.y = clampf(sp.y, 60, vp.y - 60)
		p.node.position = sp - p.node.size / 2
		p.node.modulate.a = clampf(p.ttl, 0.0, 1.0)

# --- Emote wheel ---

const WHEEL := ["wave", "laugh", "heart", "help", "yes", "no", "follow", "wait"]
const WHEEL_ICONS := {"wave": "👋", "laugh": "😂", "heart": "❤️", "help": "🆘", "yes": "👍", "no": "👎", "follow": "👉", "wait": "✋"}

func _build_emote_wheel() -> void:
	emote_wheel = Control.new()
	emote_wheel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	emote_wheel.visible = false
	add_child(emote_wheel)
	var r := 130.0
	for i in WHEEL.size():
		var a := TAU * i / WHEEL.size() - PI / 2
		var b := Button.new()
		b.text = "%s\n%s" % [WHEEL_ICONS[WHEEL[i]], WHEEL[i].capitalize()]
		b.custom_minimum_size = Vector2(92, 72)
		b.position = Vector2(cos(a), sin(a)) * r - b.custom_minimum_size / 2
		var e: String = WHEEL[i]
		b.pressed.connect(func(): _send_emote(e))
		b.mouse_entered.connect(func(): _hover_emote = e)
		emote_wheel.add_child(b)

var _hover_emote := ""
func _open_wheel(open: bool) -> void:
	if open:
		_hover_emote = ""
		emote_wheel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		emote_wheel.visible = false
		if not DeviceManager.is_mobile and not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if _hover_emote:
			_send_emote(_hover_emote)

func _send_emote(e: String) -> void:
	NetworkManager.send_emote(e)
	if emote_wheel.visible and DeviceManager.is_mobile:
		emote_wheel.visible = false

## Touch controls call this to toggle the wheel with a tap
func toggle_wheel() -> void:
	emote_wheel.visible = not emote_wheel.visible

# --- Pause + settings ---

func _build_pause_menu() -> void:
	pause_menu = ColorRect.new()
	(pause_menu as ColorRect).color = Color(0, 0, 0, 0.6)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(320, 0)
	box.position = Vector2(-160, -160)
	box.add_theme_constant_override("separation", 12)
	pause_menu.add_child(box)
	var title := Label.new()
	title.text = "Paused — your buddies are still playing!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(title)
	if NetworkManager.room_code:
		var code := Label.new()
		code.text = "Invite code: %s" % NetworkManager.room_code
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(code)
	for item in [["Resume", _toggle_pause], ["Settings", _open_settings], ["Leave maze", _leave]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(0, 52 * DeviceManager.ui_scale())
		b.pressed.connect(item[1])
		box.add_child(b)
	add_child(pause_menu)

func _toggle_pause() -> void:
	if settings_panel and settings_panel.visible:
		settings_panel.visible = false
		return
	pause_menu.visible = not pause_menu.visible
	# Multiplayer never truly pauses the world; only local input stops.
	if not multiplayer.has_multiplayer_peer() or GameManager.player_data.size() <= 1:
		get_tree().paused = pause_menu.visible
	if not DeviceManager.is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_menu.visible else Input.MOUSE_MODE_CAPTURED

func _open_settings() -> void:
	if settings_panel == null:
		settings_panel = preload("res://scripts/ui/settings_panel.gd").new()
		settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(settings_panel)
	settings_panel.visible = true

func _leave() -> void:
	get_tree().paused = false
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _build_fps() -> void:
	fps_label = Label.new()
	fps_label.position = Vector2(20, 64)
	add_child(fps_label)

# --- Quests, phases, coins ---

var quest_box: VBoxContainer
var quest_list: Label
var phase_label: Label
var coin_label: Label

func _build_quest_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(16, -120)
	panel.custom_minimum_size = Vector2(300, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.7)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	quest_box = VBoxContainer.new()
	panel.add_child(quest_box)
	phase_label = Label.new()
	phase_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	quest_box.add_child(phase_label)
	coin_label = Label.new()
	quest_box.add_child(coin_label)
	quest_list = Label.new()
	quest_list.autowrap_mode = TextServer.AUTOWRAP_WORD
	quest_list.custom_minimum_size = Vector2(276, 0)
	quest_box.add_child(quest_list)
	add_child(panel)
	QuestTracker.list_changed.connect(_refresh_quests)
	QuestManager.coins_changed.connect(func(c): _refresh_quests(); _notify("🪙 +coins! Total: %d" % c))
	QuestManager.phase_unlocked.connect(func(_m, p): _refresh_quests(); _notify("🔓 Phase %d unlocked! (gate needs a buddy)" % p, 4.0))
	QuestManager.quest_completed.connect(func(_m, i): _refresh_quests(); _notify("✅ Quest %d done!" % (i + 1)))
	_refresh_quests()

func _refresh_quests() -> void:
	if quest_list == null:
		return
	var m := QuestTracker.current_map
	if m.is_empty():
		m = GameManager.current_map
	var done := QuestManager.quests_done(m)
	phase_label.text = "Phase %d / 4   ·   Quests %d / 6" % [QuestManager.current_phase(m), done]
	coin_label.text = "💰 Coins: %d" % QuestManager.coins
	var lines := []
	for i in QuestTracker.active.keys():
		var d := QuestTracker.describe(i)
		if d:
			lines.append("• " + d)
	if lines.is_empty():
		lines.append("Talk to NPCs with ❗ to get quests")
	quest_list.text = "\n".join(lines)

# --- Existing events ---

func _on_token(player_id: int, _index: int) -> void:
	_update_tokens()
	_notify("🪙 %s found a Friendship Token!" % _pname(player_id))

func _on_all_tokens() -> void:
	_notify("All tokens found! Get EVERYONE to the exit!")

func _on_friendship(value: float) -> void:
	friendship_bar.value = value * 100.0

func _on_game_ended(result: String) -> void:
	_show_results(result)

## End-of-run card: celebrates the team, not a single winner.
func _show_results(result: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(440, 0)
	box.position = Vector2(-220, -220)
	box.add_theme_constant_override("separation", 10)
	bg.add_child(box)
	var s := GameManager.get_score()
	var title := Label.new()
	title.text = "🎉 YOU ESCAPED TOGETHER!" if result == "win" else "⏰ Time's up, buddies!"
	title.add_theme_font_size_override("font_size", int(34 * DeviceManager.ui_scale()))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.text = "Time %d:%02d · Tokens %d/%d · High-fives %d · Buddies %d\nFriendship %d%%" % [int(s.time) / 60, int(s.time) % 60, s.tokens, GameManager.tokens_total, s.high_fives, s.players, int(s.friendship * 100)]
	box.add_child(stats)
	for u in GameManager.last_unlocks:
		var l := Label.new()
		l.text = "✨ " + u
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate = Color(1, 0.85, 0.3)
		box.add_child(l)
	var again := Button.new()
	again.text = "Back to menu"
	again.custom_minimum_size = Vector2(0, 52 * DeviceManager.ui_scale())
	again.pressed.connect(_leave)
	box.add_child(again)

func _update_tokens() -> void:
	token_label.text = "🪙 %d / %d" % [GameManager.tokens_found, GameManager.tokens_total]

func _notify(text: String, hold: float = 3.0) -> void:
	notification_label.text = text
	notification_label.visible = true
	notification_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(hold)
	tween.tween_property(notification_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): notification_label.visible = false)

func _pname(id: int) -> String:
	return GameManager.player_data.get(id, {}).get("name", "A buddy")
