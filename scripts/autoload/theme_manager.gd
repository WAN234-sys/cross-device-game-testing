extends Node
## Sets a global dark theme for all UI controls so text is visible on the
## dark backgrounds. Runs as an autoload before any scene loads.

func _ready() -> void:
	var theme := Theme.new()

	# Default font color: light green/white
	theme.set_color("font_color", "Label", Color(0.93, 0.96, 0.88))
	theme.set_color("font_color", "Button", Color(0.93, 0.96, 0.88))
	theme.set_color("font_color", "LineEdit", Color(0.93, 0.96, 0.88))
	theme.set_color("font_color", "OptionButton", Color(0.93, 0.96, 0.88))
	theme.set_color("font_color", "ItemList", Color(0.93, 0.96, 0.88))
	theme.set_color("font_color", "CheckButton", Color(0.93, 0.96, 0.88))
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.6, 0.65, 0.58))

	# Button styles
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.22, 0.18)
	btn_normal.border_color = Color(0.3, 0.4, 0.3)
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(10)
	btn_normal.content_margin_left = 16; btn_normal.content_margin_right = 16
	btn_normal.content_margin_top = 10; btn_normal.content_margin_bottom = 10
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.22, 0.3, 0.22)
	btn_hover.border_color = Color(0.77, 0.94, 0.63)
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.15, 0.2, 0.15)
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := btn_normal.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.12, 0.14, 0.12)
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.45, 0.4))
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# LineEdit
	var input := StyleBoxFlat.new()
	input.bg_color = Color(0.12, 0.15, 0.12)
	input.border_color = Color(0.3, 0.38, 0.3)
	input.set_border_width_all(2)
	input.set_corner_radius_all(8)
	input.content_margin_left = 12; input.content_margin_right = 12
	input.content_margin_top = 8; input.content_margin_bottom = 8
	theme.set_stylebox("normal", "LineEdit", input)
	var input_focus := input.duplicate() as StyleBoxFlat
	input_focus.border_color = Color(0.77, 0.94, 0.63)
	theme.set_stylebox("focus", "LineEdit", input_focus)

	# OptionButton
	theme.set_stylebox("normal", "OptionButton", btn_normal.duplicate())
	theme.set_stylebox("hover", "OptionButton", btn_hover.duplicate())

	# ItemList
	var item_bg := StyleBoxFlat.new()
	item_bg.bg_color = Color(0.1, 0.13, 0.1)
	item_bg.set_corner_radius_all(6)
	theme.set_stylebox("panel", "ItemList", item_bg)
	theme.set_color("font_selected_color", "ItemList", Color(0.77, 0.94, 0.63))

	# PanelContainer
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.13, 0.1)
	panel.set_corner_radius_all(10)
	panel.set_border_width_all(1)
	panel.border_color = Color(0.2, 0.25, 0.2)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# ProgressBar
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.18, 0.15)
	bar_bg.set_corner_radius_all(4)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.77, 0.94, 0.63)
	bar_fill.set_corner_radius_all(4)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	# CheckButton
	theme.set_color("font_pressed_color", "CheckButton", Color(0.77, 0.94, 0.63))

	# HSlider
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.2, 0.24, 0.2)
	slider_bg.set_corner_radius_all(4)
	theme.set_stylebox("slider", "HSlider", slider_bg)

	# TabContainer
	var tab := StyleBoxFlat.new()
	tab.bg_color = Color(0.12, 0.15, 0.12)
	tab.set_corner_radius_all(6)
	theme.set_stylebox("panel", "TabContainer", tab)
	theme.set_color("font_selected_color", "TabContainer", Color(0.77, 0.94, 0.63))
	theme.set_color("font_unselected_color", "TabContainer", Color(0.5, 0.55, 0.5))

	# Apply globally
	get_tree().root.theme = theme
