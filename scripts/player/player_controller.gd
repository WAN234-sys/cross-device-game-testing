extends CharacterBody3D
class_name BuddyPlayer
## First-person friendslop player controller.
## Physics-based movement, grab, crouch (buddy boost), high-five, and comedic wobble.

signal pratfalled
signal grabbed_object(obj: Node3D)
signal released_object
signal high_fived(target: BuddyPlayer)

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_force: float = 7.0
@export var mouse_sensitivity: float = 0.002
@export var grab_range: float = 3.0
@export var throw_force: float = 10.0

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var grab_ray: RayCast3D = $Head/Camera3D/GrabRay
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var hat_mount: Node3D = $Head/HatMount
@onready var name_label: Label3D = $NameLabel
@onready var grab_joint: Generic6DOFJoint3D = $GrabJoint
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var peer_id: int = 1
var player_color: Color = Color.WHITE
var player_hat: String = "none"
var player_name: String = "Player"
var player_face: int = 0
var player_size: float = 1.0
## Movement multipliers from obstacles/boosts (id -> factor). Product is applied.
var speed_mods: Dictionary = {}
## Item carried for fetch quests (shown floating above the head)
var carried_item: String = ""

var impulse := Vector3.ZERO
var _safe_pos := Vector3(0, 2, 0)

## Obstacles call this. Only the owning machine moves the body; others ask it.
func knock(force: Vector3) -> void:
	if is_multiplayer_authority():
		impulse += Vector3(force.x, 0, force.z)
		velocity.y = maxf(velocity.y, force.y)
	elif multiplayer.has_multiplayer_peer():
		_knock_rpc.rpc_id(peer_id, force)

@rpc("any_peer", "reliable")
func _knock_rpc(force: Vector3) -> void:
	if is_multiplayer_authority():
		impulse += Vector3(force.x, 0, force.z)
		velocity.y = maxf(velocity.y, force.y)

## Shows the carried quest item floating above this buddy's head.
func update_carry_visual(icon: String = "") -> void:
	var l := get_node_or_null("CarryIcon") as Label3D
	if carried_item == "":
		if l:
			l.queue_free()
		return
	if l == null:
		l = Label3D.new()
		l.name = "CarryIcon"
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 110
		l.position.y = 2.1
		add_child(l)
	l.text = icon if icon else "📦"

func speed_factor() -> float:
	var f := 1.0
	for v in speed_mods.values():
		f *= v
	return f

var is_crouching: bool = false
var is_grabbing: bool = false
var grabbed_body: RigidBody3D = null
var wobble_time: float = 0.0
var pratfall_cooldown: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 15.0)

func _ready() -> void:
	add_to_group("players")
	camera.fov = SettingsManager.fov
	SettingsManager.settings_changed.connect(func(): camera.fov = SettingsManager.fov)
	GameManager.emote_played.connect(_on_emote)
	if is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if DeviceManager.is_mobile else Input.MOUSE_MODE_CAPTURED
		# First-person: don't render your own body/hat on your camera (layer 2 = own body)
		camera.cull_mask &= ~(1 << 1)
	else:
		camera.current = false
		# Remote players: disable input processing
		set_process_input(false)

	_apply_cosmetics()
	if is_multiplayer_authority():
		# Deferred so the bean GLB and hat (instantiated in children's _ready) exist first
		_set_layer_recursive.call_deferred(self, 2)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)

## Shared look function: mouse, touch drag, and gamepad stick all call this.
func look(relative: Vector2) -> void:
	var sens := SettingsManager.mouse_sensitivity
	var y_dir := -1.0 if SettingsManager.invert_y else 1.0
	rotate_y(-relative.x * sens)
	head.rotate_x(-relative.y * sens * y_dir)
	head.rotation.x = clampf(head.rotation.x, -PI / 2.5, PI / 2.5)

## Virtual joystick input (set by touch controls); combined with keyboard.
var touch_move := Vector2.ZERO

## --- Network sync: owner streams its transform; others smoothly follow ---
const SYNC_RATE := 20.0
var _sync_t := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _has_net := false

@rpc("any_peer", "unreliable_ordered")
func _net_state(pos: Vector3, yaw: float, pitch: float, crouch: bool) -> void:
	# Only accept updates from this player's owner
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_net_pos = pos; _net_yaw = yaw; _net_pitch = pitch
	if crouch != is_crouching:
		_toggle_crouch()
	if not _has_net:
		global_position = pos
		_has_net = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		if _has_net:
			global_position = global_position.lerp(_net_pos, minf(1.0, delta * 15.0))
			rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 15.0))
			head.rotation.x = lerp_angle(head.rotation.x, _net_pitch, minf(1.0, delta * 15.0))
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_sync_t += delta
		if _sync_t >= 1.0 / SYNC_RATE:
			_sync_t = 0.0
			_net_state.rpc(global_position, rotation.y, head.rotation.x, is_crouching)

	# Gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		AudioManager.play_squeak(global_position)

	# Movement
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	# Gamepad left stick + phone joystick
	input_dir += Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)) * float(DeviceManager.input_method == "gamepad")
	input_dir += touch_move
	input_dir = input_dir.limit_length(1.0)
	# Gamepad right stick look
	if DeviceManager.input_method == "gamepad":
		var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if rs.length() > 0.15:
			look(rs * 900.0 * delta)

	var speed := (sprint_speed if Input.is_action_pressed("sprint") else move_speed) * speed_factor()
	if is_crouching:
		speed *= 0.4

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 4 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 4 * delta)
	# Knockback from obstacles decays over ~0.4 s instead of being erased by input
	velocity.x += impulse.x
	velocity.z += impulse.z
	impulse = impulse.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))

	move_and_slide()
	# Fell off the map? Respawn at the last safe spot instead of falling forever.
	if global_position.y < -15.0:
		global_position = _safe_pos
		velocity = Vector3.ZERO
		impulse = Vector3.ZERO
	elif is_on_floor():
		_safe_pos = global_position

	# Comedic wobble when idle
	if direction.length() < 0.1 and is_on_floor():
		wobble_time += delta * 2.0
		body_mesh.rotation.z = sin(wobble_time * 3.0) * 0.03
	else:
		wobble_time = 0.0
		body_mesh.rotation.z = lerp(body_mesh.rotation.z, 0.0, 10.0 * delta)

	# Pratfall detection — running into a wall
	pratfall_cooldown = maxf(pratfall_cooldown - delta, 0.0)
	if is_on_wall() and velocity.length() > 4.0 and pratfall_cooldown <= 0.0:
		_do_pratfall()

	# Crouch (for buddy boost)
	if SettingsManager.toggle_crouch:
		if Input.is_action_just_pressed("crouch"):
			_toggle_crouch()
	else:
		var want := Input.is_action_pressed("crouch")
		if want != is_crouching:
			_toggle_crouch()

	# Grab / Release
	if Input.is_action_just_pressed("grab"):
		if is_grabbing:
			_release_grab(false)
		else:
			_try_grab()

	# Throw
	if Input.is_action_just_pressed("interact") and is_grabbing:
		_release_grab(true)

	# High-five
	if Input.is_action_just_pressed("high_five"):
		_try_high_five()

	# Interact with puzzles, NPCs, items
	if Input.is_action_just_pressed("interact") and not is_grabbing:
		_try_interact()

	# Ping: mark a spot for friends ("look here!")
	if Input.is_action_just_pressed("ping"):
		_place_ping()

	_update_look_prompt()

# --- Pings (non-verbal communication, works without voice chat) ---

func _place_ping() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_basis.z * 40.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var kind := "look"
	var c: Object = hit.get("collider")
	if c is FriendshipToken:
		kind = "token"
	elif c is PressurePlate:
		kind = "plate"
	elif c is FriendNPC:
		kind = "npc"
	NetworkManager.send_ping(hit.position, kind)

## Context prompt under the crosshair: tells players what they can do.
func _update_look_prompt() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var text := ""
	if is_grabbing:
		text = "%s Throw   %s Drop" % [DeviceManager.prompt_for("interact"), DeviceManager.prompt_for("grab")]
	elif interact_ray.is_colliding():
		var c := interact_ray.get_collider()
		if c is BuddyPlayer:
			text = "%s High-five %s" % [DeviceManager.prompt_for("high_five"), c.player_name]
		elif c is FriendNPC:
			text = "%s Talk to %s" % [DeviceManager.prompt_for("interact"), c.npc_name]
		elif c and c.has_method("interact"):
			text = "%s Use" % DeviceManager.prompt_for("interact")
	elif grab_ray.is_colliding() and grab_ray.get_collider() is RigidBody3D:
		text = "%s Grab" % DeviceManager.prompt_for("grab")
	hud.show_prompt(text)

# --- Crouch / Buddy Boost ---

func _toggle_crouch() -> void:
	is_crouching = not is_crouching
	var target_height := 0.6 if is_crouching else 1.0
	var tween := create_tween()
	tween.tween_property(collision_shape, "shape:height", target_height, 0.2)
	tween.parallel().tween_property(head, "position:y", 0.3 if is_crouching else 0.8, 0.2)
	# When crouching, other players can jump on your head (buddy boost)

func is_boostable() -> bool:
	return is_crouching and is_on_floor()

# --- Grab System (REPO-style physics grabbing) ---

func _try_grab() -> void:
	if not grab_ray.is_colliding():
		return
	var collider := grab_ray.get_collider()
	if collider is RigidBody3D:
		grabbed_body = collider
		is_grabbing = true
		# Attach via joint for physics-based carrying
		grab_joint.node_a = get_path()
		grab_joint.node_b = grabbed_body.get_path()
		grabbed_object.emit(grabbed_body)

func _release_grab(do_throw: bool) -> void:
	if grabbed_body:
		grab_joint.node_a = NodePath()
		grab_joint.node_b = NodePath()
		if do_throw:
			var throw_dir := -camera.global_basis.z.normalized()
			grabbed_body.apply_impulse(throw_dir * throw_force)
			AudioManager.play_boing(grabbed_body.global_position)
		grabbed_body = null
	is_grabbing = false
	released_object.emit()

# --- High-Five (friendship mechanic) ---

func _try_high_five() -> void:
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
	if collider is BuddyPlayer and collider != self:
		high_fived.emit(collider)
		# Sync over network
		if multiplayer.has_multiplayer_peer():
			NetworkManager.high_five_rpc.rpc(collider.peer_id)
		else:
			GameManager.register_high_five(peer_id, collider.peer_id)
		# Play comedy SFX
		AudioManager.play_honk(global_position)

# --- Interact (puzzles, NPCs, items) ---

func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
	if collider.has_method("interact"):
		collider.interact(self)

# --- Pratfall (comedy) ---

func _do_pratfall() -> void:
	pratfall_cooldown = 3.0
	AudioManager.play_slide_whistle(global_position)
	pratfalled.emit()
	if not SettingsManager.screen_shake or SettingsManager.reduce_motion:
		return
	# Screen shake + wobble
	var tween := create_tween()
	tween.tween_property(camera, "rotation:z", 0.3, 0.1)
	tween.tween_property(camera, "rotation:z", -0.2, 0.1)
	tween.tween_property(camera, "rotation:z", 0.0, 0.2)

# --- Emotes (expressive bubbles above the buddy's head) ---

const EMOTES := {
	"wave": "👋", "laugh": "😂", "heart": "❤️", "help": "🆘",
	"yes": "👍", "no": "👎", "follow": "👉", "wait": "✋",
}

func _on_emote(sender_id: int, emote: String) -> void:
	if sender_id != peer_id:
		return
	var bubble := Label3D.new()
	bubble.text = EMOTES.get(emote, "❓")
	bubble.font_size = 128
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.position = Vector3(0, 2.0, 0)
	add_child(bubble)
	var t := create_tween()
	if SettingsManager.reduce_motion:
		t.tween_interval(1.6)
	else:
		bubble.scale = Vector3.ZERO
		t.tween_property(bubble, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(bubble, "position:y", 2.4, 1.4)
	t.tween_property(bubble, "modulate:a", 0.0, 0.4)
	t.tween_callback(bubble.queue_free)
	# A tiny happy hop
	if not SettingsManager.reduce_motion and body_mesh:
		var hop := create_tween()
		hop.tween_property(body_mesh, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
		hop.tween_property(body_mesh, "scale", Vector3(0.9, 1.15, 0.9), 0.1)
		hop.tween_property(body_mesh, "scale", Vector3.ONE, 0.12)

# --- Cosmetics ---

const HAT_MODELS := {
	"traffic_cone": "res://assets/models/items/hat_traffic_cone.glb",
	"chef_hat": "res://assets/models/items/hat_chef.glb",
	"crown": "res://assets/models/items/hat_crown.glb",
	"propeller": "res://assets/models/items/hat_propeller.glb",
	"bucket": "res://assets/models/items/hat_bucket.glb",
	"party": "res://assets/models/items/hat_party.glb",
	"viking": "res://assets/models/items/hat_viking.glb",
	"fez": "res://assets/models/items/hat_fez.glb",
	"top_hat": "res://assets/models/items/hat_top_hat.glb",
}

func _apply_cosmetics() -> void:
	# Placeholder capsule color (used if the GLB model isn't imported yet)
	if body_mesh and body_mesh.get_surface_override_material(0):
		var mat: StandardMaterial3D = body_mesh.get_surface_override_material(0).duplicate()
		mat.albedo_color = player_color
		body_mesh.set_surface_override_material(0, mat)
	# Detailed bean model, tinted with the player's color
	var swap := get_node_or_null("BeanModel") as ModelSwap
	if swap:
		swap.tint = player_color
		swap.apply_tint(player_color)
	if name_label:
		var face: String = CosmeticManager.FACE_EXPRESSIONS[clampi(player_face, 0, CosmeticManager.FACE_EXPRESSIONS.size() - 1)]
		name_label.text = "%s %s" % [CosmeticManager.FACE_ICONS.get(face, ""), player_name]
		name_label.modulate = player_color.lightened(0.3)
	# Body chunkiness (visual only; collision stays the same for fairness)
	var swap_node := get_node_or_null("BeanModel") as Node3D
	if swap_node:
		swap_node.scale = Vector3(player_size, 1.0 + (1.0 - player_size) * 0.4, player_size)
	_apply_hat()

func _set_layer_recursive(node: Node, layer_index: int) -> void:
	if node is VisualInstance3D and not (node is Label3D):
		(node as VisualInstance3D).layers = 1 << (layer_index - 1)
	for c in node.get_children():
		_set_layer_recursive(c, layer_index)

func _apply_hat() -> void:
	for c in hat_mount.get_children():
		c.queue_free()
	var path: String = HAT_MODELS.get(player_hat, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var hat := ModelSwap.new()
	hat.model_path = path
	hat.target_size = 0.45
	hat_mount.add_child(hat)
