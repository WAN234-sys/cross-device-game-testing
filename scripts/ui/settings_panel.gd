extends PanelContainer
## Settings panel — usable from the main menu and the in-game pause menu.
## Tabs: Sound, Display, Controls, Accessibility. Changes apply instantly
## and are saved when the panel closes.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 520) * minf(DeviceManager.ui_scale(), 1.3)
	position = -custom_minimum_size / 2
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.11, 0.09, 0.97)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(0.77, 0.94, 0.63, 0.6)
	sb.set_border_width_all(2)
	sb.content_margin_left = 22; sb.content_margin_right = 22
	sb.content_margin_top = 18; sb.content_margin_bottom = 18
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var title := Label.new()
	title.text = "⚙ Settings"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var S := SettingsManager
	var sound := _page(tabs, "🔊 Sound")
	_slider(sound, "Master volume", 0, 1, S.master_volume, func(v): S.master_volume = v)
	_slider(sound, "Music", 0, 1, S.music_volume, func(v): S.music_volume = v)
	_slider(sound, "Sound effects", 0, 1, S.sfx_volume, func(v): S.sfx_volume = v)
	_slider(sound, "Voice chat", 0, 1, S.voice_volume, func(v): S.voice_volume = v)

	var display := _page(tabs, "🖥 Display")
	_toggle(display, "Fullscreen", S.fullscreen, func(v): S.fullscreen = v)
	_toggle(display, "VSync (smoother, less tearing)", S.vsync, func(v): S.vsync = v)
	_slider(display, "Field of view", 60, 110, S.fov, func(v): S.fov = v, 1.0)
	_toggle(display, "Show FPS counter", S.show_fps, func(v): S.show_fps = v)

	var controls := _page(tabs, "🎮 Controls")
	_slider(controls, "Look sensitivity", 0.0005, 0.006, S.mouse_sensitivity, func(v): S.mouse_sensitivity = v, 0.0001)
	_toggle(controls, "Invert look up/down", S.invert_y, func(v): S.invert_y = v)
	_toggle(controls, "Crouch is a toggle (off = hold)", S.toggle_crouch, func(v): S.toggle_crouch = v)
	var keys := Label.new()
	keys.text = "Move WASD · Jump Space · Sprint Shift · Crouch Ctrl\nGrab F · Use/Throw E · High-five H · Emotes G · Ping Q / middle-click"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD
	keys.modulate = Color(0.75, 0.8, 0.75)
	controls.add_child(keys)

	var access := _page(tabs, "♿ Accessibility")
	_toggle(access, "Screen shake", S.screen_shake, func(v): S.screen_shake = v)
	_toggle(access, "Reduce motion (no wobble/bounce)", S.reduce_motion, func(v): S.reduce_motion = v)
	_toggle(access, "Large text", S.large_text, func(v): S.large_text = v)
	_toggle(access, "Subtitles for NPC voices", S.subtitles, func(v): S.subtitles = v)
	var cb := OptionButton.new()
	for o in ["Colorblind filter: Off", "Deuteranopia (red-green)", "Protanopia (red-green)", "Tritanopia (blue-yellow)"]:
		cb.add_item(o)
	cb.selected = S.colorblind_mode
	cb.item_selected.connect(func(i): S.colorblind_mode = i; S.save_settings())
	access.add_child(cb)

	var done := Button.new()
	done.text = "Save & close"
	done.custom_minimum_size = Vector2(0, 48)
	done.pressed.connect(func(): S.save_settings(); visible = false)
	root.add_child(done)

func _page(tabs: TabContainer, name_: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name_
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	scroll.add_child(v)
	tabs.add_child(scroll)
	return v

func _slider(parent: Control, label: String, lo: float, hi: float, value: float, on_change: Callable, step: float = 0.01) -> void:
	var row := VBoxContainer.new()
	var l := Label.new()
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = step; s.value = value
	s.custom_minimum_size = Vector2(0, 32)
	var fmt := func(v: float) -> String:
		return "%s: %d%%" % [label, roundi((v - lo) / (hi - lo) * 100.0)] if hi <= 1.0 or step < 0.01 else "%s: %d" % [label, roundi(v)]
	l.text = fmt.call(value)
	s.value_changed.connect(func(v): on_change.call(v); l.text = fmt.call(v); SettingsManager.save_settings())
	row.add_child(s)
	parent.add_child(row)

func _toggle(parent: Control, label: String, value: bool, on_change: Callable) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = value
	c.custom_minimum_size = Vector2(0, 40)
	c.toggled.connect(func(v): on_change.call(v); SettingsManager.save_settings())
	parent.add_child(c)
