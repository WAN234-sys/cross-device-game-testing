extends Node
## Settings manager — persists audio, video, controls, and accessibility preferences.

signal settings_changed

const SAVE_PATH := "user://buddy_maze_settings.json"

# Audio
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var voice_volume: float = 1.0

# Video
var fullscreen: bool = false
var vsync: bool = true
var fov: float = 80.0
var show_fps: bool = false

# Controls
var mouse_sensitivity: float = 0.002
var invert_y: bool = false
var toggle_crouch: bool = true  # true = toggle, false = hold

# Accessibility
var screen_shake: bool = true
var subtitles: bool = true
var colorblind_mode: int = 0  # 0=off, 1=deuteranopia, 2=protanopia, 3=tritanopia
var large_text: bool = false
var reduce_motion: bool = false

var _cb_layer: CanvasLayer
var _cb_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	# Colorblind overlay sits above the 3D world, below menus
	_cb_layer = CanvasLayer.new()
	_cb_layer.layer = 1
	_cb_rect = ColorRect.new()
	_cb_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/colorblind.gdshader")
	_cb_rect.material = mat
	_cb_layer.add_child(_cb_rect)
	add_child(_cb_layer)
	_apply()

func _apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	AudioManager.music_volume = music_volume
	AudioManager.sfx_volume = sfx_volume
	AudioManager.voice_volume = voice_volume
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if _cb_rect:
		_cb_rect.visible = colorblind_mode != 0
		(_cb_rect.material as ShaderMaterial).set_shader_parameter("mode", colorblind_mode)
	settings_changed.emit()

func save_settings() -> void:
	var data := {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"voice_volume": voice_volume,
		"fullscreen": fullscreen,
		"vsync": vsync,
		"fov": fov,
		"show_fps": show_fps,
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"toggle_crouch": toggle_crouch,
		"screen_shake": screen_shake,
		"subtitles": subtitles,
		"colorblind_mode": colorblind_mode,
		"large_text": large_text,
		"reduce_motion": reduce_motion,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
	_apply()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	master_volume = data.get("master_volume", 1.0)
	music_volume = data.get("music_volume", 0.8)
	sfx_volume = data.get("sfx_volume", 1.0)
	voice_volume = data.get("voice_volume", 1.0)
	fullscreen = data.get("fullscreen", false)
	vsync = data.get("vsync", true)
	fov = data.get("fov", 80.0)
	show_fps = data.get("show_fps", false)
	mouse_sensitivity = data.get("mouse_sensitivity", 0.002)
	invert_y = data.get("invert_y", false)
	toggle_crouch = data.get("toggle_crouch", true)
	screen_shake = data.get("screen_shake", true)
	subtitles = data.get("subtitles", true)
	colorblind_mode = data.get("colorblind_mode", 0)
	large_text = data.get("large_text", false)
	reduce_motion = data.get("reduce_motion", false)
