extends CanvasLayer
## On-screen controls for phones/tablets: left joystick to move, right side
## drag to look, and big thumb buttons for jump, grab, use, crouch, high-five,
## emotes, and ping. Buttons trigger the same input actions as the keyboard,
## so all gameplay code works unchanged.

const STICK_RADIUS := 110.0

var _stick_base: Control
var _stick_knob: Control
var _stick_touch := -1
var _stick_center := Vector2.ZERO
var _look_touch := -1
var _look_last := Vector2.ZERO

func _ready() -> void:
	layer = 5
	var s := DeviceManager.ui_scale()
	_stick_base = _circle(Color(1, 1, 1, 0.12), STICK_RADIUS * 2)
	_stick_knob = _circle(Color(1, 1, 1, 0.35), 90)
	_stick_base.visible = false
	_stick_knob.visible = false
	add_child(_stick_base)
	add_child(_stick_knob)
	var buttons := [
		["JUMP", "jump", Vector2(-130, -150)],
		["GRAB", "grab", Vector2(-250, -110)],
		["USE", "interact", Vector2(-130, -280)],
		["DUCK", "crouch", Vector2(-260, -240)],
		["🙌", "high_five", Vector2(-370, -150)],
		["📍", "ping", Vector2(-380, -280)],
		["😀", "emote_wheel", Vector2(-120, -410)],
		["⏸", "pause_menu", Vector2(-90, 90)],
	]
	for b in buttons:
		_add_button(b[0], b[1], b[2], s)

func _circle(color: Color, size: float) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size))
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _add_button(label: String, action: String, offset: Vector2, s: float) -> void:
	var b := Button.new()
	b.text = label
	var size := 96.0 * s
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_font_size_override("font_size", int(22 * s))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.1, 0.55)
	sb.border_color = Color(0.77, 0.94, 0.63, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(size))
	b.add_theme_stylebox_override("normal", sb)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.77, 0.94, 0.63, 0.5)
	b.add_theme_stylebox_override("pressed", pressed)
	b.focus_mode = Control.FOCUS_NONE
	# Anchor to bottom-right (or top-right for pause)
	var top := offset.y > 0
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0 if top else 1.0
	b.anchor_bottom = b.anchor_top
	b.offset_left = offset.x * s
	b.offset_top = offset.y * s
	if action == "emote_wheel":
		b.pressed.connect(_toggle_wheel)
	else:
		b.button_down.connect(func(): Input.action_press(action))
		b.button_up.connect(func(): Input.action_release(action))
	add_child(b)

func _toggle_wheel() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toggle_wheel()

func _local_player() -> BuddyPlayer:
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			return p
	return null

func _input(event: InputEvent) -> void:
	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < vp.x * 0.4 and _stick_touch == -1:
				_stick_touch = event.index
				_stick_center = event.position
				_stick_base.position = _stick_center - _stick_base.size / 2
				_stick_knob.position = _stick_center - _stick_knob.size / 2
				_stick_base.visible = true
				_stick_knob.visible = true
			elif event.position.x >= vp.x * 0.4 and _look_touch == -1:
				_look_touch = event.index
				_look_last = event.position
		else:
			if event.index == _stick_touch:
				_stick_touch = -1
				_stick_base.visible = false
				_stick_knob.visible = false
				var p := _local_player()
				if p: p.touch_move = Vector2.ZERO
			elif event.index == _look_touch:
				_look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			var d: Vector2 = (event.position - _stick_center).limit_length(STICK_RADIUS)
			_stick_knob.position = _stick_center + d - _stick_knob.size / 2
			var p := _local_player()
			if p: p.touch_move = d / STICK_RADIUS
		elif event.index == _look_touch:
			var p := _local_player()
			if p: p.look((event.position - _look_last) * 1.6)
			_look_last = event.position
