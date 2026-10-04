extends Node
## Detects the device type and input method, so the UI can adapt:
## phones get touch controls + bigger buttons, laptops get keyboard prompts,
## controllers get button icons. Updates live when the player switches input.

signal input_method_changed(method: String)  # "keyboard" | "touch" | "gamepad"

var is_mobile: bool = false
var input_method: String = "keyboard"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var os := OS.get_name()
	is_mobile = os in ["Android", "iOS"] or (os == "Web" and DisplayServer.is_touchscreen_available())
	input_method = "touch" if is_mobile else "keyboard"

func _input(event: InputEvent) -> void:
	var detected := input_method
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		detected = "touch"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		detected = "gamepad"
	elif event is InputEventKey or event is InputEventMouseButton:
		detected = "keyboard"
	if detected != input_method:
		input_method = detected
		input_method_changed.emit(input_method)

## Returns the label to show for an action, e.g. "[E]", "Ⓐ", or "TAP".
func prompt_for(action: String) -> String:
	match input_method:
		"touch":
			return {"interact": "TAP ✋", "grab": "GRAB ✊", "high_five": "🙌", "jump": "JUMP"}.get(action, action.to_upper())
		"gamepad":
			return {"interact": "Ⓧ", "grab": "Ⓨ", "high_five": "ⓑ", "jump": "Ⓐ", "crouch": "Ⓡ"}.get(action, action)
		_:
			var events := InputMap.action_get_events(action) if InputMap.has_action(action) else []
			for e in events:
				if e is InputEventKey:
					return "[%s]" % OS.get_keycode_string((e as InputEventKey).keycode)
			return "[%s]" % action

## UI scale for readability: bigger on phones and when "Large Text" is on.
func ui_scale() -> float:
	var s := 1.4 if is_mobile else 1.0
	if SettingsManager.large_text:
		s *= 1.25
	return s
