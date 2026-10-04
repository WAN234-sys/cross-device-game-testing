extends ObstacleBase
class_name PatrolEnemy
## Walks a loop of points and bonks players on contact. Same motion on every
## machine because it's driven by the shared game clock, not local physics.

@export var patrol_points: Array[Vector3] = []
@export var speed: float = 3.0
@export var knockback: float = 10.0

var _lengths: Array[float] = []
var _total := 0.0

func _ready() -> void:
	super._ready()
	_ready_lengths()

## Recompute segment lengths. Called from _ready and by GenericMap after
## updating patrol_points on a deferred frame.
func _ready_lengths() -> void:
	_lengths.clear()
	_total = 0.0
	for i in patrol_points.size():
		var d := patrol_points[i].distance_to(patrol_points[(i + 1) % patrol_points.size()])
		_lengths.append(d)
		_total += d

func _tick(_delta: float) -> void:
	if patrol_points.size() < 2 or _total <= 0.0:
		return
	# Deterministic: position = f(time) so all peers agree without syncing
	var dist := fmod(Time.get_ticks_msec() / 1000.0 * speed + get_instance_id() % 7, _total)
	for i in patrol_points.size():
		if dist <= _lengths[i]:
			var a := patrol_points[i]
			var b := patrol_points[(i + 1) % patrol_points.size()]
			position = a.lerp(b, dist / _lengths[i])
			var dir := b - a
			if dir.length() > 0.01:
				rotation.y = atan2(dir.x, dir.z)
			return
		dist -= _lengths[i]

func _hit(player: BuddyPlayer) -> void:
	var d := player.global_position - global_position
	d.y = 0
	player.knock(d.normalized() * knockback + Vector3(0, 5, 0))
	AudioManager.play_honk(global_position)
