extends Node3D
# the match: builds the stage, runs the loop, sorts out hits / KOs / specials and all the juice

const FighterScript := preload("res://scripts/fighter.gd")
const BallScript := preload("res://scripts/ball.gd")
const HudScript := preload("res://scripts/hud.gd")
const HitShader := preload("res://scripts/hitframe.gdshader")
const PauseScript := preload("res://scripts/pause.gd")
const ResultsScript := preload("res://scripts/results.gd")
const RESULTS_DELAY := 3.8  # roughly how long the final KO sound runs before the results come up

var half_w := 12.0
var height := 11.5

var fighters := []
var ball = null
var cam: Camera3D
var cam_home := Vector3(0.0, 5.4, 24.5)
var cam_fov := 46.0
var shake := 0.0
var punch := 0.0  # camera zoom-in on big hits
var punch_at := Vector2.ZERO

var time_stop_t := 0.0
var time_stopper = null

var state := "brief"  # brief (controls screen) -> intro -> play -> over
var state_t := 0.0
var debris := []

var hud
var pause
var results
var elapsed := 0.0  # match time, for the results screen
var stats := {}  # per player: kos, hits, bunts, peak speed, charged hits
var final_winner = null
var final_loser = null
var resume_lock := 0.0
var fx_mat: ShaderMaterial
var fx_rect: ColorRect
var hit_fx_t := 0.0
var time_left := 300.0
var rally := 0
var robots := []


func _ready() -> void:
	time_left = Game.match_time
	for i in 2:
		stats[i] = {"kos": 0, "hits": 0, "bunts": 0, "peak": 0.0, "charged": 0}
	Game._music_pos.erase("match")  # a new match starts its song from the top
	Game.play_music("match")
	_build_world()
	_spawn_fighters()
	ball = BallScript.new()
	ball.arena = self
	add_child(ball)
	ball.serve()
	_build_hud()
	pause.show_brief()


func _physics_process(delta: float) -> void:
	state_t += delta
	if time_stop_t <= 0.0:
		_update_debris(delta)
		for r in robots:
			r.position.y = r.get_meta("y0") + absf(sin(state_t * 2.0 + r.get_meta("ph"))) * 0.12
	_update_camera(delta)
	_update_fx(delta)

	if state == "brief":
		if Input.is_action_just_pressed("ui_accept"):
			start_from_brief()
		elif Input.is_action_just_pressed("quit"):
			Game.goto("res://scenes/select.tscn")
			set_physics_process(false)
		return

	if Input.is_action_just_pressed("quit"):
		if state == "over":
			Game.menu_start = "main"
			Game.goto("res://scenes/frontend.tscn")
			set_physics_process(false)
		elif pause.open:
			pause.on_escape()
		else:
			pause.toggle()
		return
	if pause.open:
		return
	if resume_lock > 0.0:
		resume_lock -= delta
		return

	match state:
		"intro":
			if state_t > 1.3:
				state = "play"
				state_t = 0.0
				hud.say("GO!", Color("#ffd447"), 0.6)
				Sfx.play("special", 1.4, -4.0)
			return
		"over":
			# final KO: everything frozen while the sound plays, then the results screen
			if state_t > RESULTS_DELAY and not results.shown:
				hud.say_t = 0.0
				results.show_results(final_winner, final_loser)
			return

	hud.hint_alpha = clampf(1.0 - (state_t - 5.0) * 0.5, 0.0, 1.0)
	elapsed += delta
	if Game.match_time > 0.0:
		time_left -= delta
	if Game.match_time > 0.0 and time_left <= 0.0:
		_time_up()
		return

	if time_stop_t > 0.0:
		# only whoever stopped time gets to move
		time_stop_t -= delta
		time_stopper.tick(delta)
		_check_swing(time_stopper)
		if time_stop_t <= 0.0:
			_end_time_stop()
		return

	for f in fighters:
		f.tick(delta)
	ball.tick(delta)


# enter (or a click) on the controls screen
func start_from_brief() -> void:
	if state != "brief":
		return
	pause.hide_brief()
	state = "intro"
	state_t = 0.0
	hud.say("READY?", Color.WHITE, 1.3)
	Sfx.ui("match_start", "", "special", 1.1, -6.0)


func _anyone_pressed() -> bool:
	if Input.is_action_just_pressed("ui_accept"):
		return true
	for i in 2:
		if Input.is_action_just_pressed("p%d_swing" % i):
			return true
	return false


# ---------------- hits ----------------

# the ball calls this every little step it moves
func ball_step_check() -> bool:
	for f in fighters:
		if _check_swing(f):
			return true
	for f in fighters:
		if not f.alive or f.invuln > 0.0:
			continue
		if ball.is_dangerous_to(f.id) and f.body_dist(ball.pos) < 0.6 + ball.radius:
			_ko(f)
			return true
	return false


func _check_swing(f) -> bool:
	if not f.alive or ball.hitstop > 0.0 or ball.gone_t > 0.0:
		return false
	if not f.can_reach(ball.pos, ball.radius):
		return false

	f.swing_connected = true
	if f.swing_kind == 1:
		f.hitstop = ball.bunted(f.hit_center(), f.facing)
		hud.ring(ball.pos, Color.WHITE, false)
		f.meter = minf(f.meter + 5.0, 100.0)
		stats[f.id]["bunts"] += 1
		Sfx.play("bounce", 0.6, -2.0)
		return true

	var dir := Vector2(f.facing, 0.0)
	if f.aim == 0:
		# aim assist: a plain swing bends toward the other player if they're in front of you
		var foe = _fighter_by_id(1 - f.id)
		if foe and foe.alive:
			var to: Vector2 = foe.pos + Vector2(0.0, 1.3) - ball.pos
			if signf(to.x) == f.facing:
				var ang := clampf(atan2(to.y, absf(to.x)), -0.5, 0.5)
				dir = Vector2(f.facing * cos(ang), sin(ang))
	# up / down aim. holding forward too gives a flatter angle, just up / down is steep
	if f.aim != 0:
		var steep := 0.52 if f.hit_fwd else 0.95
		if f.aim == -1 and f.on_floor:
			steep = 0.52  # on the ground a steep spike just dies in the floor
		dir = Vector2(f.facing * cos(steep), sin(steep) * f.aim)

	var charge: float = f.charge_level
	f.charge_level = 0.0
	var stop: float = ball.struck(f.id, f.hit_center() + dir * 0.3, dir, charge)
	rally += 1
	if rally >= 2:
		hud.show_burst(f.id, rally)
	f.hitstop = stop
	f.meter = minf(f.meter + 18.0, 100.0)
	stats[f.id]["hits"] += 1
	stats[f.id]["peak"] = maxf(stats[f.id]["peak"], ball.speed)
	if charge > 0.6:
		stats[f.id]["charged"] += 1
	var sp: float = ball.speed
	add_shake(0.05 + sp * 0.004)
	_burst(ball.pos, f.color, 4 + int(sp / 15.0))
	hud.ring(ball.pos, Color.WHITE if sp < 30.0 else f.color.lightened(0.4), sp >= 30.0)
	Sfx.play("hit", clampf(0.8 + sp / 120.0, 0.8, 1.6), 0.0)
	if sp >= 30.0 or charge > 0.6:
		_flash(f.color, stop)
		_punch_in(clampf(sp / 95.0, 0.25, 1.0))
	if charge > 0.6:
		hud.ring(ball.pos, Color.WHITE, true)
		add_shake(0.3 * charge)
		Sfx.ui("charged_hit", "", "ko", 1.6, -6.0)
	return true


func _ko(f) -> void:
	var dir: Vector2 = ball.vel.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	f.get_hit(dir)
	var attacker = _fighter_by_id(ball.owner_id)
	if attacker:
		attacker.meter = minf(attacker.meter + 25.0, 100.0)
		stats[attacker.id]["kos"] += 1

	_burst(ball.pos, f.color, 26)
	_burst(ball.pos, Color.WHITE, 10)
	hud.ring(ball.pos, f.color, true)
	hud.ring(ball.pos, Color.WHITE, true)
	rally = 0
	_flash(f.color, 0.45)
	_punch_in(1.0)
	ball.vanish()
	shake = 0.8
	if f.stocks > 0:
		Sfx.play("ko", 1.0, 0.0)  # the last one gets the big final KO sound instead

	if f.stocks <= 0:
		f.alive = false
		f.visible = false
		_check_winner()


func _check_winner() -> void:
	var left := fighters.filter(func(f): return f.alive)
	if left.size() > 1:
		return
	state = "over"
	state_t = 0.0
	Game.matches_played += 1
	if left.size() == 1 and left[0].id == 0:
		Game.p1_wins += 1
	Game.save_settings()
	ball.vanish()
	if left.size() == 1:
		final_winner = left[0]
		final_loser = fighters[1 - left[0].id]
	# big GAME! + the final KO sound, then the results screen a few seconds later
	hud.sub_text = ""
	hud.say("GAME!", Color("#f5e04a"), RESULTS_DELAY)
	_flash(Color.WHITE, 0.4)
	_punch_in(1.0)
	shake = 1.0
	Sfx.ui("final_ko", "", "ko", 0.7, 0.0)


func _fighter_by_id(fid: int):
	for f in fighters:
		if f.id == fid:
			return f
	return null


func dust(p: Vector2) -> void:
	_burst(p + Vector2(0.0, 0.15), Color.WHITE, 5, 0.45)


func _time_up() -> void:
	# most lives left wins, otherwise it's a draw
	var a = fighters[0]
	var b = fighters[1]
	if a.stocks != b.stocks:
		var loser = a if a.stocks < b.stocks else b
		loser.alive = false
		loser.visible = false
	else:
		for f in fighters:
			f.alive = false
	_check_winner()


func on_serve() -> void:
	rally = 0
	Sfx.play("tick", 0.7, -6.0)
	_burst(ball.pos, Color.WHITE, 6)


# ---------------- specials ----------------

func try_special(f) -> void:
	if state != "play":
		return
	var ch: Dictionary = Game.characters[f.char_id]
	var cost: float = ch["cost"]
	if f.meter < cost:
		Sfx.play("tick", 0.5, -14.0)
		return

	match f.char_id:
		0:
			if time_stop_t > 0.0:
				return
			time_stop_t = 2.0
			time_stopper = f
			Sfx.play("timestop", 1.0, 0.0)
		1:
			f.super_hop()
			Sfx.play("jump", 0.7, 0.0)
		2:
			if ball.gone_t > 0.0:
				return
			ball.start_float(4.0)
			Sfx.play("float", 1.0, -2.0)
		3:
			if ball.gone_t > 0.0:
				return
			ball.slow_t = 3.5
			Sfx.play("slow", 1.0, -2.0)

	f.meter -= cost
	hud.say(ch["ability"], f.color, 0.7)
	_burst(f.pos + Vector2(0.0, 1.0), f.color, 12)
	_punch_in(0.35, f.pos + Vector2(0.0, 1.0))


func _end_time_stop() -> void:
	time_stop_t = 0.0
	time_stopper = null
	Sfx.play("timestop", 1.6, -6.0)


# ---------------- juice ----------------

func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func _flash(col: Color, dur: float) -> void:
	hit_fx_t = dur
	fx_mat.set_shader_parameter("tint", col)
	fx_mat.set_shader_parameter("seed", randf() * 100.0)


func _punch_in(amount: float, at = null) -> void:
	punch = maxf(punch, amount)
	punch_at = ball.pos if at == null else at


func _update_fx(delta: float) -> void:
	hit_fx_t -= delta
	var hit := 1.0 if hit_fx_t > 0.0 else 0.0
	var gray := 1.0 if time_stop_t > 0.0 else 0.0
	fx_rect.visible = hit > 0.0 or gray > 0.0
	if not fx_rect.visible:
		return
	fx_mat.set_shader_parameter("hit", hit)
	fx_mat.set_shader_parameter("gray", gray)
	var vs := get_viewport().get_visible_rect().size
	var sp := cam.unproject_position(Vector3(ball.pos.x, ball.pos.y, 0.0))
	fx_mat.set_shader_parameter("center", sp / vs)
	fx_mat.set_shader_parameter("aspect", vs.x / vs.y)


func _update_camera(delta: float) -> void:
	shake = move_toward(shake, 0.0, delta * 1.8)
	# hold the punch while the game is frozen on a hit, then ease out
	if hit_fx_t <= 0.0:
		punch = move_toward(punch, 0.0, delta * 2.5)
	var e := punch * punch
	var off := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.6
	var follow := Vector3(punch_at.x * 0.35, (punch_at.y - 5.0) * 0.25, 0.0) * e
	cam.position = cam_home + off + follow
	if ball and ball.gone_t <= 0.0:
		cam.position.x += ball.pos.x * 0.06
	cam.fov = cam_fov - 12.0 * e
	cam.rotation.z = (randf_range(-1.0, 1.0) * shake * 0.02)


func _burst(p: Vector2, col: Color, n: int, power := 1.0) -> void:
	for i in n:
		var m := MeshInstance3D.new()
		var b := PrismMesh.new()
		b.size = Vector3(0.12, 0.3, 0.05) * randf_range(0.7, 1.4)
		m.mesh = b
		m.material_override = Game.flat(col)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(p.x, p.y, 0.3)
		add_child(m)
		var v := Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 1.0), randf_range(-0.3, 0.6)).normalized() * randf_range(6.0, 15.0) * power
		debris.append({"node": m, "vel": v, "life": randf_range(0.3, 0.7)})


func _update_debris(delta: float) -> void:
	for i in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[i]
		var v: Vector3 = d["vel"]
		v.y -= 30.0 * delta
		v *= 0.97
		d["vel"] = v
		var m: MeshInstance3D = d["node"]
		m.position += v * delta
		m.rotation.z += 12.0 * delta
		d["life"] -= delta
		m.scale = Vector3.ONE * clampf(d["life"] * 2.5, 0.01, 1.0)
		if d["life"] <= 0.0:
			m.queue_free()
			debris.remove_at(i)


# ---------------- setup ----------------

func _spawn_fighters() -> void:
	for i in 2:
		var f = FighterScript.new()
		f.id = i
		f.char_id = Game.p_chars[i]
		f.is_cpu = not Game.is_human(i)
		f.color = Game.colors[i]
		f.stocks = Game.stocks
		f.arena = self
		f.pos = Vector2(-6.0 if i == 0 else 6.0, 0.0)
		f.facing = 1.0 if i == 0 else -1.0
		add_child(f)
		fighters.append(f)


func _build_hud() -> void:
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 1
	add_child(fx_layer)
	fx_rect = ColorRect.new()
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = HitShader
	fx_rect.material = fx_mat
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_rect.visible = false
	fx_layer.add_child(fx_rect)
	fx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud = HudScript.new()
	hud.arena = self
	hud_layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 5
	add_child(pause_layer)
	pause = PauseScript.new()
	pause.arena = self
	pause_layer.add_child(pause)
	pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var results_layer := CanvasLayer.new()
	results_layer.layer = 6
	add_child(results_layer)
	results = ResultsScript.new()
	results.arena = self
	results_layer.add_child(results)
	results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var k0: Dictionary = Game.key_names[0]
	var t := "P1   A/D move   W jump   S down   %s swing   %s bunt   %s special" % [k0["swing"], k0["bunt"], k0["special"]]
	if Game.mode == "cpu":
		t += "      (arrow keys + K / L / ; and the mouse work too)"
	if Game.mode == "2p":
		var k1: Dictionary = Game.key_names[1]
		t += "        P2   arrows   %s swing   %s bunt   %s special" % [k1["swing"], k1["bunt"], k1["special"]]
	hud.hint_text = t + "      hold up / down while swinging to aim"


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a2d30")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a8f94")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 7, -8)
	warm.light_color = Color("#ffffff")
	warm.omni_range = 22.0
	warm.light_energy = 0.6
	add_child(warm)
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = cam_fov
	cam.position = cam_home
	add_child(cam)
	cam.look_at(Vector3(0.0, 4.9, 0.0))
	cam.current = true

	_build_stage()


func _build_stage() -> void:
	# your own stage: assets/stage/stage.glb (or .tscn). put the floor top at y=0,
	# the play area runs x -12..12 and y 0..11.5 on the z=0 plane
	var custom: PackedScene = Game.asset_scene("stage/stage")
	if custom:
		add_child(custom.instantiate())
	else:
		_greybox()

	# optional flat background picture far behind everything
	var bg_tex: Texture2D = Game.asset_tex("stage/background")
	if bg_tex:
		var q := QuadMesh.new()
		var aspect := float(bg_tex.get_width()) / float(bg_tex.get_height())
		q.size = Vector2(60.0 * aspect, 60.0) if aspect < 1.6 else Vector2(96.0, 96.0 / aspect)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = bg_tex
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(0, 6.0, -30.0)
		add_child(mi)


func _greybox() -> void:
	# placeholder stage: plain prototype-grid boxes in the same layout as the real thing will be
	var light: StandardMaterial3D = Game.grid_mat(false)
	var dark: StandardMaterial3D = Game.grid_mat(true)
	_box(Vector3(40, 1.0, 8.0), Vector3(0, -0.5, -1.0), light, true)
	_box(Vector3(40, 6.0, 1.0), Vector3(0, -3.5, 3.5), dark)
	_box(Vector3(40, 0.05, 0.2), Vector3(0, 0.03, 2.6), Game.flat(Color("#e8e8e8")))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(1.0, height + 0.5, 1.2), Vector3(side * (half_w + 0.5), height / 2.0, 0.0), dark)
		_box(Vector3(14, 24, 2.0), Vector3(side * (half_w + 8.0), 6.0, 1.6), dark)
	_box(Vector3(36, 2.6, 3.6), Vector3(0, height + 1.3, 0.0), dark)
	_box(Vector3(46, 24, 0.6), Vector3(0, 8.0, -8.0), light)


func _box(sz: Vector3, at: Vector3, m: Material, shadows := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
