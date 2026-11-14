extends Node3D
# one fighter. movement is done by hand (no physics bodies) since the arena is just a box.
# gameplay is on the x/y plane, z is only for looks.
# if there's a model at res://assets/characters/<file>.glb it uses that,
# otherwise it's a placeholder capsule guy

const WALK_SPEED := 11.0
const GROUND_ACCEL := 85.0
const AIR_ACCEL := 45.0
const JUMP_SPEED := 18.0
const GRAVITY := 42.0
const FAST_FALL := 85.0

const SWING_STARTUP := 0.05
const SWING_ACTIVE := 0.14
const SWING_END := 0.2
const SWING_RANGE := 1.8
const VIS := 1.5  # fighters are drawn 1.5x bigger, LLB guys are chunky

const MODEL_HEIGHT := 1.8

var preview := false  # true = just standing on the menu screen
var id := 0
var char_id := 0
var is_cpu := false
var color := Color.WHITE
var arena = null

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var facing := 1.0
var on_floor := true
var max_air_jumps := 0
var air_jumps := 0

var swing_t := -1.0  # -1 = not swinging
var aim := 0  # -1 down, 0 straight, 1 up
var swing_connected := false
var swing_kind := 0  # 0 = swing, 1 = bunt

var hitstop := 0.0
var stun := 0.0
var invuln := 0.0
var stocks := 3
var meter := 0.0
var alive := true

# input, from the keyboard/pad or the bot brain
var in_move := 0.0
var in_aim := 0
var jump_buf := 0.0
var swing_buf := 0.0
var special_buf := 0.0
var bunt_buf := 0.0
var bot_wait := 0.0

# visuals
var rig: Node3D
var bat_pivot: Node3D
var body_parts: Node3D
var moon: MeshInstance3D
var tag: Label3D
var anim_t := 0.0
var run_phase := 0.0

var model: Node3D = null
var anim: AnimationPlayer = null
var anim_map := {}
var cur_anim := ""
var restart_anim := false


func _ready() -> void:
	if char_id == 1:
		max_air_jumps = 1
	air_jumps = max_air_jumps

	if not preview:
		scale = Vector3.ONE * VIS
	rig = Node3D.new()
	add_child(rig)
	rig.scale.x = facing
	_build_bat()
	if not _load_model():
		_build_body()
	_build_extras()

	set_process(preview)
	update_visual()


func _process(delta: float) -> void:
	# only runs on the menu preview
	rotation.y = sin(anim_t * 0.7) * 0.5
	_animate(delta)
	update_visual()


func tick(delta: float) -> void:
	if not alive:
		return
	_read_input(delta)
	invuln = maxf(invuln - delta, 0.0)

	if hitstop > 0.0:
		hitstop -= delta
		_animate(delta)
		update_visual()
		return

	var move := in_move
	if stun > 0.0:
		stun -= delta
		move = 0.0
		jump_buf = 0.0
		swing_buf = 0.0
		bunt_buf = 0.0
		special_buf = 0.0

	var swinging := swing_t >= 0.0
	var target := move * WALK_SPEED
	if swinging and on_floor:
		target *= 0.25  # plant your feet a bit when swinging
	var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
	if stun > 0.0:
		accel = 8.0
	vel.x = move_toward(vel.x, target, accel * delta)
	if not swinging and absf(move) > 0.2:
		facing = signf(move)

	if jump_buf > 0.0:
		if on_floor:
			vel.y = JUMP_SPEED
			on_floor = false
			jump_buf = 0.0
			arena.dust(pos)
			Sfx.play("jump", randf_range(0.95, 1.05), -8.0)
		elif air_jumps > 0:
			air_jumps -= 1
			vel.y = JUMP_SPEED * 0.92
			jump_buf = 0.0
			Sfx.play("jump", 1.3, -8.0)

	var g := GRAVITY
	if not on_floor and in_aim < 0 and vel.y < 2.0:
		g = FAST_FALL
	vel.y -= g * delta
	pos += vel * delta

	var hw: float = arena.half_w - 0.45
	if pos.x < -hw:
		pos.x = -hw
		vel.x = maxf(vel.x, 0.0)
	elif pos.x > hw:
		pos.x = hw
		vel.x = minf(vel.x, 0.0)
	if pos.y <= 0.0:
		if not on_floor and vel.y < -12.0:
			arena.dust(pos)
		pos.y = 0.0
		vel.y = 0.0
		on_floor = true
		air_jumps = max_air_jumps
	else:
		on_floor = false
	var top: float = arena.height - 2.9
	if pos.y > top:
		pos.y = top
		vel.y = minf(vel.y, 0.0)

	if swinging:
		swing_t += delta
		if swing_t < SWING_STARTUP + SWING_ACTIVE:
			aim = in_aim  # you can still steer it until the bat connects
		if swing_t > SWING_STARTUP + SWING_ACTIVE + SWING_END:
			swing_t = -1.0
	elif swing_buf > 0.0 or bunt_buf > 0.0:
		swing_kind = 0 if swing_buf > 0.0 else 1
		swing_buf = 0.0
		bunt_buf = 0.0
		swing_t = 0.0
		aim = in_aim
		swing_connected = false
		restart_anim = true
		if swing_kind == 0:
			Sfx.play("swing", randf_range(0.9, 1.15), -10.0)
		else:
			Sfx.play("swing", 1.6, -16.0)

	if special_buf > 0.0:
		special_buf = 0.0
		arena.try_special(self)

	_animate(delta)
	update_visual()


func _read_input(delta: float) -> void:
	jump_buf = maxf(jump_buf - delta, 0.0)
	swing_buf = maxf(swing_buf - delta, 0.0)
	special_buf = maxf(special_buf - delta, 0.0)
	bunt_buf = maxf(bunt_buf - delta, 0.0)

	if is_cpu:
		_bot(delta)
		return

	var p := "p%d_" % id
	in_move = Input.get_axis(p + "left", p + "right")
	in_aim = 0
	if Input.is_action_pressed(p + "up"):
		in_aim = 1
	elif Input.is_action_pressed(p + "down"):
		in_aim = -1
	if Input.is_action_just_pressed(p + "jump"):
		jump_buf = 0.1
	if Input.is_action_just_pressed(p + "swing"):
		swing_buf = 0.12
	if Input.is_action_just_pressed(p + "bunt"):
		bunt_buf = 0.12
	if Input.is_action_just_pressed(p + "special"):
		special_buf = 0.05


func hit_center() -> Vector2:
	return pos + Vector2(facing * 1.2, 1.4)


func can_reach(p: Vector2, r: float) -> bool:
	if swing_connected or swing_t < SWING_STARTUP or swing_t > SWING_STARTUP + SWING_ACTIVE:
		return false
	return p.distance_to(hit_center()) <= SWING_RANGE + r


func body_dist(p: Vector2) -> float:
	var y := clampf(p.y, pos.y + 0.5, pos.y + 2.3)
	return p.distance_to(Vector2(pos.x, y))


func get_hit(dir: Vector2) -> void:
	stocks -= 1
	invuln = 2.2
	stun = 0.45
	hitstop = 0.3
	swing_t = -1.0
	var kx := 1.0 if dir.x >= 0.0 else -1.0
	vel = Vector2(kx * 12.0, 10.0)
	on_floor = false


func super_hop() -> void:
	vel.y = JUMP_SPEED * 1.35
	on_floor = false
	air_jumps = max_air_jumps


# ---------------- bot ----------------

func _bot(delta: float) -> void:
	var lvl: int = Game.cpu_level
	bot_wait -= delta
	if bot_wait > 0.0:
		return
	# easy bots think slower and miss more
	var think: Vector2 = [Vector2(0.14, 0.25), Vector2(0.05, 0.12), Vector2(0.02, 0.05)][lvl]
	bot_wait = randf_range(think.x, think.y)

	var ball = arena.ball
	if ball.gone_t > 0.0:
		in_move = clampf(-pos.x * 0.15, -1.0, 1.0) if absf(pos.x) > 5.0 else 0.0
		in_aim = 0
		return

	var bvel: Vector2 = ball.current_velocity()
	var lead_t: float = [0.05, 0.1, 0.12][lvl]
	var lead: Vector2 = ball.pos + bvel * lead_t
	var dx := lead.x - pos.x
	var dy := lead.y - (pos.y + 1.0)
	var threat: bool = ball.is_dangerous_to(id)

	# stand just beside the ball on our side of it
	var side := -1.0 if dx > 0.0 else 1.0
	var target_x := lead.x + side * 0.9
	if ball.owner_id == id:
		target_x = pos.x + side * 1.5  # just hit it, give it space
	in_move = clampf((target_x - pos.x) * 0.5, -1.0, 1.0)
	if absf(in_move) < 0.12:
		in_move = 0.0
	if absf(dx) < 2.5 and signf(dx) != facing and swing_t < 0.0:
		in_move = signf(dx) * 0.25

	if dy > 1.6 and absf(dx) < 3.0 and randf() < 0.5:
		if on_floor or (air_jumps > 0 and vel.y < 0.0):
			jump_buf = 0.1

	var reach := lead.distance_to(hit_center())
	if reach < SWING_RANGE + 0.6 and swing_t < 0.0 and ball.hitstop <= 0.0:
		var chance: float = ([0.5, 0.85, 0.97][lvl] if threat else 0.55)
		if randf() < chance:
			if not threat and ball.owner_id < 0 and ball.float_t <= 0.0 and randf() < 0.2:
				bunt_buf = 0.1
			else:
				swing_buf = 0.1
			in_aim = _bot_aim()
	elif swing_t < 0.0:
		in_aim = 0

	var cost: float = Game.characters[char_id]["cost"]
	if meter >= cost:
		var want := false
		match char_id:
			0, 2, 3:
				want = threat and bvel.length() > 25.0
			1:
				want = not on_floor and dy > 2.0
		if want and randf() < 0.3:
			special_buf = 0.05


func _bot_aim() -> int:
	var foe = null
	for f in arena.fighters:
		if f != self and f.alive:
			foe = f
	if foe == null:
		return 0
	var r := randf()
	if foe.pos.y > pos.y + 2.5:
		return 1
	if not on_floor and r < 0.45:
		return -1
	if r < 0.3:
		return 1
	return 0


# ---------------- animation ----------------

func _anim_state() -> String:
	if stun > 0.0:
		return "hurt"
	if swing_t >= 0.0:
		return "swing"
	if not on_floor:
		return "jump"
	if absf(vel.x) > 1.0:
		return "run"
	return "idle"


func _animate(delta: float) -> void:
	anim_t += delta
	if hitstop > 0.0:
		return  # everything freezes on impact, that's the point

	var running := on_floor and absf(vel.x) > 1.0
	if running:
		run_phase += delta * (5.0 + absf(vel.x) * 1.1)

	if anim:
		var state := _anim_state()
		_play(state)
		var rate := 1.0
		if state == "swing":
			rate = 2.2
		elif state == "run":
			rate = clampf(absf(vel.x) / 6.0, 0.8, 1.8)
		anim.advance(delta * rate)
		return

	if body_parts == null:
		return
	var sq := Vector3.ONE
	if not on_floor:
		var k := clampf(absf(vel.y) / 18.0, 0.0, 1.0) * 0.18
		sq = Vector3(1.0 - k, 1.0 + k, 1.0 - k)
	elif running:
		sq.y = 1.0 + sin(run_phase * 2.0) * 0.04
	else:
		sq.y = 1.0 + sin(anim_t * 2.5) * 0.015
	body_parts.scale = body_parts.scale.lerp(sq, 0.35)
	if model:
		# no animations in the file, so fake some life: hop when running, lean into swings
		body_parts.position.y = absf(sin(run_phase)) * 0.12 if running else 0.0
		var lean := 0.0
		if swing_t >= 0.0:
			lean = -0.35 if swing_t < SWING_STARTUP + SWING_ACTIVE else -0.15
		elif stun > 0.0:
			lean = 0.5
		body_parts.rotation.z = lerpf(body_parts.rotation.z, lean, 0.3)


func _play(state: String) -> void:
	var n: String = anim_map.get(state, "")
	if n == "":
		n = anim_map.get("idle", "")
	if n == "":
		return
	if n == cur_anim and not restart_anim:
		return
	cur_anim = n
	anim.play(n, 0.08)
	if restart_anim:
		anim.seek(0.0, true)
	restart_anim = false


# ---------------- looks ----------------

func update_visual() -> void:
	position = Vector3(pos.x, pos.y, 0.0)

	# paper-flip turn around
	rig.scale.x = move_toward(rig.scale.x, facing, 0.3)
	if absf(rig.scale.x) < 0.02:
		rig.scale.x = 0.02 * facing
	rotation.z = -vel.x * (0.012 if on_floor else 0.008)

	var rest := 0.5
	var a := rest
	if swing_t >= 0.0 and swing_kind == 1:
		# bunt: bat comes out flat in front and pokes it
		var k := clampf(swing_t / SWING_STARTUP, 0.0, 1.0)
		if swing_t > SWING_STARTUP + SWING_ACTIVE:
			k = 1.0 - clampf((swing_t - SWING_STARTUP - SWING_ACTIVE) / SWING_END, 0.0, 1.0)
		a = lerpf(rest, -1.45, k)
	elif swing_t >= 0.0:
		var end_a: float = [-2.4, -1.5, -0.4][aim + 1]
		if swing_t < SWING_STARTUP:
			a = lerpf(rest, 2.3, swing_t / SWING_STARTUP)
		elif swing_t < SWING_STARTUP + SWING_ACTIVE:
			a = lerpf(2.3, end_a, ease((swing_t - SWING_STARTUP) / SWING_ACTIVE, 0.4))
		else:
			a = lerpf(end_a, rest, clampf((swing_t - SWING_STARTUP - SWING_ACTIVE) / SWING_END, 0.0, 1.0))
	bat_pivot.rotation.z = a

	rig.position.x = randf_range(-0.07, 0.07) if hitstop > 0.0 else 0.0
	visible = alive and (invuln <= 0.0 or int(invuln * 14.0) % 2 == 0)

	if moon:
		moon.position = Vector3(cos(anim_t * 3.0) * 0.65, 1.55 + sin(anim_t * 6.0) * 0.1, sin(anim_t * 3.0) * 0.65)


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	return Game.toon(c, true, glow)


func _part(mesh: Mesh, m: Material, at: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	if parent == null:
		parent = rig
	parent.add_child(mi)
	return mi


func _build_bat() -> void:
	bat_pivot = Node3D.new()
	bat_pivot.position = Vector3(0.1, 0.85, 0.45)
	rig.add_child(bat_pivot)
	var bat := CylinderMesh.new()
	bat.top_radius = 0.09
	bat.bottom_radius = 0.045
	bat.height = 1.15
	_part(bat, _mat(Color("#e8dcc4")), Vector3(0, 0.6, 0), bat_pivot)
	var grip := CylinderMesh.new()
	grip.top_radius = 0.055
	grip.bottom_radius = 0.055
	grip.height = 0.28
	_part(grip, _mat(color.darkened(0.5)), Vector3(0, 0.08, 0), bat_pivot)


func _load_model() -> bool:
	var file: String = Game.characters[char_id]["file"]
	var scene: PackedScene = Game.asset_scene("characters/" + file)
	if scene == null:
		return false

	# body_parts wraps the model so static models still get squash + bounce
	body_parts = Node3D.new()
	rig.add_child(body_parts)
	model = scene.instantiate()
	body_parts.add_child(model)
	model.rotation.y = float(Game.characters[char_id].get("turn", PI / 2.0))
	_fit_model()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = Game.outline_mat

	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim = players[0] as AnimationPlayer
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_map_anims()
	return true


func _fit_model() -> void:
	# scale whatever model it is to about 1.8 tall, feet on the floor, centred on us.
	# flat stuff (a ground plane baked into the file) gets hidden and ignored
	var box := AABB()
	var first := true
	var inv := rig.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if b.size.y < maxf(b.size.x, b.size.z) * 0.02:
			mi.visible = false
			continue
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	if first:
		return
	var s := MODEL_HEIGHT / maxf(box.size.y, 0.0001)
	model.scale = Vector3.ONE * s
	var c := box.get_center()
	model.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)


func _map_anims() -> void:
	var names := anim.get_animation_list()
	anim_map["idle"] = _pick(names, ["idle"])
	anim_map["run"] = _pick(names, ["sprint", "run", "walk"])
	anim_map["jump"] = _pick(names, ["jump", "fall"])
	anim_map["swing"] = _pick(names, ["attack", "melee", "swing", "punch", "slash", "kick"])
	anim_map["hurt"] = _pick(names, ["hurt", "damage", "hit-react", "hitreact", "die"])
	for key in ["idle", "run"]:
		var n: String = anim_map[key]
		if n != "":
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR


func _pick(names: PackedStringArray, keys: Array) -> String:
	for key in keys:
		for n in names:
			var low: String = n.to_lower()
			if "wheelchair" in low or "sit" in low:
				continue
			if key in low:
				return n
	return ""


func _build_body() -> void:
	# placeholder: capsule + head + a visor so you can see which way it faces
	body_parts = Node3D.new()
	rig.add_child(body_parts)
	var body := CapsuleMesh.new()
	body.radius = 0.38
	body.height = 1.5
	_part(body, _mat(color), Vector3(0, 0.75, 0), body_parts)
	var head := SphereMesh.new()
	head.radius = 0.3
	head.height = 0.6
	_part(head, _mat(color.lightened(0.35)), Vector3(0, 1.72, 0), body_parts)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.12, 0.14, 0.42)
	_part(visor, Game.toon(Game.INK, false), Vector3(0.25, 1.76, 0), body_parts)

	# big letter on the chest so you know who's who before real art goes in
	var letter := Label3D.new()
	letter.text = str(Game.characters[char_id]["name"]).substr(0, 1)
	letter.font = Game.font
	letter.font_size = 64
	letter.outline_size = 12
	letter.position = Vector3(0, 0.95, 0.4)
	letter.modulate = Color.WHITE
	letter.outline_modulate = Game.INK
	body_parts.add_child(letter)


func _build_extras() -> void:
	# glowing ring under your feet so you can always find yourself
	var ring := TorusMesh.new()
	ring.inner_radius = 0.45
	ring.outer_radius = 0.56
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = color
	var r := MeshInstance3D.new()
	r.mesh = ring
	r.material_override = rm
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.position.y = 0.03
	r.scale.y = 0.3
	add_child(r)
