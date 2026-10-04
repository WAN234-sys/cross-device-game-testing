extends Node
## Manages music, SFX, and proximity voice chat settings.

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var voice_volume: float = 1.0
var music_player: AudioStreamPlayer

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)

func play_sfx(stream: AudioStream, position: Vector3 = Vector3.ZERO, spatial: bool = false) -> void:
	if spatial:
		var player := AudioStreamPlayer3D.new()
		player.stream = stream
		player.volume_db = linear_to_db(sfx_volume)
		player.bus = &"SFX"
		player.global_position = position
		player.max_distance = 20.0
		player.finished.connect(player.queue_free)
		get_tree().current_scene.add_child(player)
		player.play()
	else:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = linear_to_db(sfx_volume)
		player.bus = &"SFX"
		player.finished.connect(player.queue_free)
		add_child(player)
		player.play()

func play_music(stream: AudioStream, fade_in: float = 1.0) -> void:
	music_player.stream = stream
	music_player.volume_db = -80.0
	music_player.play()
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), fade_in)

func stop_music(fade_out: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, fade_out)
	tween.tween_callback(music_player.stop)

# --- Named SFX (assets/audio/sfx/*.ogg, from Sound FX Starter Pack Vol. 1, royalty-free) ---

const SFX_DIR := "res://assets/audio/sfx/%s.ogg"
var _cache: Dictionary = {}
var _last_played: Dictionary = {}  # name -> msec, throttles spam

## Play a named sound. Spatial when a world position is given (and a scene exists).
func play_named(sfx_name: String, pos: Variant = null, min_gap_ms: int = 80) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -100000)) < min_gap_ms:
		return
	_last_played[sfx_name] = now
	if not _cache.has(sfx_name):
		var path := SFX_DIR % sfx_name
		_cache[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _cache[sfx_name]
	if stream == null:
		return
	var spatial: bool = pos is Vector3 and pos != Vector3.ZERO and get_tree().current_scene is Node3D
	play_sfx(stream, pos if pos is Vector3 else Vector3.ZERO, spatial)

# Comedy SFX shortcuts
func play_squeak(pos: Vector3) -> void:
	play_named("squeak", pos)

func play_boing(pos: Vector3) -> void:
	play_named("boing", pos)

func play_honk(pos: Vector3) -> void:
	play_named("honk", pos)

func play_slide_whistle(pos: Vector3) -> void:
	play_named("slide_whistle", pos)
