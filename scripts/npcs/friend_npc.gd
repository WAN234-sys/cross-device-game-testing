extends CharacterBody3D
class_name FriendNPC
## Comedic NPC that gives terrible advice. Core friendslop humor.
## Wobbles, has exaggerated proportions, and speaks in text bubbles.

signal dialogue_started(npc: FriendNPC)
signal dialogue_ended(npc: FriendNPC)

@export var npc_name: String = "Breadwise"
@export var dialogue_lines: Array[String] = [
	"Ah, you want to cross the Great Sink? Easy!",
	"Just... hmm... have you tried NOT falling in?",
	"That's my best advice. I'm a crouton. I don't have hands.",
]
@export var wobble_speed: float = 3.0
@export var wobble_amount: float = 0.05

@onready var mesh: Node3D = get_node_or_null("Model") if has_node("Model") else get_node_or_null("NPCMesh")
@onready var speech_bubble: Label3D = $SpeechBubble
@onready var name_label: Label3D = $NameLabel
@onready var interact_area: Area3D = $InteractArea

var current_line: int = -1
var is_talking: bool = false

func _ready() -> void:
	if name_label:
		name_label.text = npc_name
	if speech_bubble:
		speech_bubble.visible = false

func _process(delta: float) -> void:
	# Idle wobble — like Jell-O (core friendslop visual)
	if mesh:
		mesh.rotation.z = sin(Time.get_ticks_msec() / 1000.0 * wobble_speed) * wobble_amount
		mesh.scale.y = 1.0 + sin(Time.get_ticks_msec() / 800.0) * 0.02

func interact(player: BuddyPlayer) -> void:
	if is_talking:
		_advance_dialogue()
	else:
		_start_dialogue()

func _start_dialogue() -> void:
	is_talking = true
	current_line = 0
	dialogue_started.emit(self)
	_show_line()

func _advance_dialogue() -> void:
	current_line += 1
	if current_line >= dialogue_lines.size():
		_end_dialogue()
	else:
		_show_line()

func _show_line() -> void:
	if speech_bubble and current_line < dialogue_lines.size():
		speech_bubble.visible = true
		speech_bubble.text = dialogue_lines[current_line]
		# Typewriter effect: reveal characters with a tween on visible_ratio-like counter
		var full_text: String = dialogue_lines[current_line]
		if _type_tween and _type_tween.is_valid():
			_type_tween.kill()
		speech_bubble.text = full_text
		if SettingsManager.reduce_motion:
			return
		_type_tween = create_tween()
		_type_tween.tween_method(func(n: int): speech_bubble.text = full_text.substr(0, n), 0, full_text.length(), full_text.length() * 0.03)

var _type_tween: Tween

func _end_dialogue() -> void:
	is_talking = false
	current_line = -1
	if speech_bubble:
		speech_bubble.visible = false
	dialogue_ended.emit(self)
