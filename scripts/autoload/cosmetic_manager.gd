extends Node
## Manages hats, colors, and character cosmetics.

signal cosmetic_changed

var current_hat: String = "none"
var current_color: Color = Color.WHITE
var current_face: int = 0  # index into face expressions

const FACE_EXPRESSIONS := ["happy", "surprised", "determined", "silly", "sleepy"]
const FACE_ICONS := {"happy": "😊", "surprised": "😮", "determined": "😤", "silly": "😜", "sleepy": "😴"}

## All hats with how to unlock them — shown greyed out until earned.
const HAT_UNLOCK_HINTS := {
	"none": "Always available",
	"traffic_cone": "Starter hat",
	"chef_hat": "Win in the Kitchen Counter",
	"crown": "Win any map with 4+ buddies",
	"propeller": "Random win reward",
	"bucket": "Random win reward",
	"party": "Give 10 high-fives",
	"viking": "Random win reward",
	"fez": "Random win reward",
	"top_hat": "Win 5 games",
}

## Extra color swatches unlocked by playing (the 6 starters are free).
const ALL_COLORS := [
	Color.WHITE, Color.CORAL, Color.DODGER_BLUE, Color.MEDIUM_SPRING_GREEN, Color.GOLD, Color.ORCHID,
	Color("#ff8fab"), Color("#7b5cff"), Color("#00c2a8"), Color("#ff6b35"), Color("#2e2e3a"), Color("#a0e7e5"),
]

var current_size: float = 1.0  # body chunkiness 0.85–1.2, purely visual

const HAT_DISPLAY_NAMES := {
	"none": "No Hat",
	"traffic_cone": "Traffic Cone",
	"chef_hat": "Chef Hat",
	"crown": "Royal Crown",
	"propeller": "Propeller Cap",
	"bucket": "Bucket",
	"party": "Party Hat",
	"viking": "Viking Helmet",
	"fez": "Fancy Fez",
	"top_hat": "Top Hat",
}

func set_hat(hat_id: String) -> void:
	if hat_id in GameManager.unlocked_hats:
		current_hat = hat_id
		NetworkManager.local_player_hat = hat_id
		cosmetic_changed.emit()

func set_color(color: Color) -> void:
	if color in GameManager.unlocked_colors:
		current_color = color
		NetworkManager.local_player_color = color
		cosmetic_changed.emit()

func cycle_face() -> void:
	current_face = (current_face + 1) % FACE_EXPRESSIONS.size()
	cosmetic_changed.emit()

func get_face_name() -> String:
	return FACE_EXPRESSIONS[current_face]
