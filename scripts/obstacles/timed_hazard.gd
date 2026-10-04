extends ObstacleBase
class_name TimedHazard
## Cycles ON/OFF on a shared clock, so every player sees the same timing.
## Falling forks, sprinklers, eraser sweeps, zipper walls, steam vents.
## A ⚠️ warning appears just before it turns on.

@export var on_duration: float = 2.5
@export var off_duration: float = 3.5
@export var warning_time: float = 1.0
@export var phase_offset: float = 0.0

var _is_on := false

@onready var visual: Node3D = get_node_or_null("Visual")
@onready var warning_label: Label3D = get_node_or_null("WarningLabel")

func _ready() -> void:
	super._ready()
	_apply(false)

func _process(delta: float) -> void:
	super._process(delta)
	var cycle := on_duration + off_duration
	var t := fmod(Time.get_ticks_msec() / 1000.0 + phase_offset, cycle)
	var on := t >= off_duration
	if warning_label:
		warning_label.visible = (not on) and t >= off_duration - warning_time
	if on != _is_on:
		_apply(on)
	# Keep hitting players who stand in it while it's on
	if _is_on and has_node("HitZone"):
		for b in ($HitZone as Area3D).get_overlapping_bodies():
			if b is BuddyPlayer:
				_apply_effect(b)

func _apply(on: bool) -> void:
	_is_on = on
	active = on
	if visual:
		visual.visible = on

func _hit(player: BuddyPlayer) -> void:
	var away := player.global_position - global_position
	away.y = 0
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	player.knock(away.normalized() * 7.0 + Vector3(0, 6, 0))
	AudioManager.play_slide_whistle(global_position)
