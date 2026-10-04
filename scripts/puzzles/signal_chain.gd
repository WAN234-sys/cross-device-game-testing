extends Node3D
class_name SignalChain
## One player sees a code on a screen, shouts it to another player at a keypad.
## Uses proximity voice chat naturally — no shared screen information.

signal code_entered_correctly
signal code_entered_wrong

@export var code_length: int = 4

var secret_code: String = ""
var entered_code: String = ""
var is_solved: bool = false

@onready var code_display: Label3D = $CodeDisplay  # Only visible from one side
@onready var keypad_display: Label3D = $KeypadDisplay
@onready var keypad_buttons: Node3D = $KeypadButtons

func _ready() -> void:
	_generate_code()
	if keypad_display:
		keypad_display.text = "_ " .repeat(code_length).strip_edges()
	# Code display is only visible from a specific angle/room

func _generate_code() -> void:
	secret_code = ""
	for i in code_length:
		secret_code += str(randi() % 10)
	if code_display:
		code_display.text = secret_code

func enter_digit(digit: String) -> void:
	if is_solved or entered_code.length() >= code_length:
		return
	entered_code += digit
	_update_keypad_display()
	AudioManager.play_squeak(global_position)

	if entered_code.length() >= code_length:
		if entered_code == secret_code:
			is_solved = true
			code_entered_correctly.emit()
			if keypad_display:
				keypad_display.text = "OPEN!"
				keypad_display.modulate = Color.GREEN
		else:
			code_entered_wrong.emit()
			# Reset after a delay
			await get_tree().create_timer(1.0).timeout
			entered_code = ""
			_update_keypad_display()

func _update_keypad_display() -> void:
	if keypad_display:
		var display := ""
		for i in code_length:
			if i < entered_code.length():
				display += entered_code[i] + " "
			else:
				display += "_ "
		keypad_display.text = display.strip_edges()

# Called by keypad button interactables
func interact(player: BuddyPlayer) -> void:
	# The keypad area — player presses interact while looking at a digit button
	pass  # Individual digit buttons call enter_digit()
