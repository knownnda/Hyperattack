extends Node3D
# the ball. when nobody owns it it falls and bounces like a normal ball,
# once someone swings at it it flies in straight lines and bounces off everything at full speed

const BASE_SPEED := 12.0
const MAX_SPEED := 120.0
const CHARGED_MAX := 150.0  # a full charge can push past the normal cap
const SERVE_GRAVITY := 22.0
const SLOW_FACTOR := 0.35

var arena = null
var radius := 0.45

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var speed := 0.0  # stored speed, sticks around through bunts and zero-g
var owner_id := -1
var hitstop := 0.0
var launch_vel := Vector2.ZERO
var float_t := 0.0
var slow_t := 0.0
var gone_t := 0.0
var t := 0.0

var mesh: MeshInstance3D
var mat: StandardMaterial3D
var core_mat: StandardMaterial3D
var streak: MeshInstance3D
var streak_mat: StandardMaterial3D
var last_pos := Vector2.ZERO


func _ready() -> void:
	mat = Game.toon(Color.WHITE)
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mesh.mesh = sm
	mesh.material_override = mat
	add_child(mesh)

	# your own ball: assets/ball/ball.glb, gets scaled to the right size automatically
	var custom: PackedScene = Game.asset_scene("ball/ball")
	if custom:
		var m := custom.instantiate() as Node3D
		mesh.add_child(m)
		mesh.mesh = null
		var box := AABB()
		var first := true
		for node in m.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var bb: AABB = mi.transform * mi.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		if not first:
			m.scale = Vector3.ONE * (radius * 2.0) / maxf(box.size.y, 0.001)

	# coloured ring floating round it (faces the camera) so you can see who owns it
	var band := TorusMesh.new()
	band.inner_radius = radius * 1.45
	band.outer_radius = radius * 1.7
	band.rings = 24
	core_mat = Game.flat(Color.WHITE)
	var b := MeshInstance3D.new()
	b.mesh = band
	b.material_override = core_mat
	b.rotation.x = PI / 2.0
	mesh.add_child(b)

	streak = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.95
	cm.bottom_radius = 0.0
	cm.height = 1.0
	cm.radial_segments = 12
	cm.rings = 1
	streak.mesh = cm
	streak_mat = StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material_override = streak_mat
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streak.top_level = true
	add_child(streak)


func serve() -> void:
	pos = Vector2(randf_range(-2.0, 2.0), arena.height - 3.0)
	vel = Vector2(randf_range(-2.0, 2.0), 0.0)
	owner_id = -1
	speed = 0.0
	float_t = 0.0
	slow_t = 0.0
	hitstop = 0.0
	gone_t = 0.0
	last_pos = pos
	visible = true
	_update_visual()


func vanish() -> void:
	visible = false
	gone_t = 1.4
	owner_id = -1
	speed = 0.0
	float_t = 0.0
	slow_t = 0.0
	hitstop = 0.0


func is_live() -> bool:
	return owner_id >= 0 and float_t <= 0.0 and gone_t <= 0.0


func is_dangerous_to(pid: int) -> bool:
	return is_live() and owner_id != pid


func time_scale() -> float:
	return SLOW_FACTOR if slow_t > 0.0 else 1.0


func current_velocity() -> Vector2:
	if hitstop > 0.0 or gone_t > 0.0:
		return Vector2.ZERO
	return vel * time_scale()


func start_float(dur: float) -> void:
	float_t = dur
	owner_id = -1


func _snap(from: Vector2) -> void:
	var hw: float = arena.half_w - radius
	pos = Vector2(clampf(from.x, -hw, hw), clampf(from.y, radius, arena.height - radius))
	vel = Vector2.ZERO
	float_t = 0.0


# a proper swing. returns the hitstop so the hitter freezes for the same time
# charge = 0..1 from holding swing. a charged hit adds a big chunk of speed on top,
# and whoever hits it next carries on from that speed
func struck(by_id: int, from: Vector2, dir: Vector2, charge := 0.0) -> float:
	if speed < BASE_SPEED:
		speed = BASE_SPEED
	else:
		speed = minf(speed + 2.5 + speed * 0.05, MAX_SPEED)
	if charge > 0.0:
		speed = minf(speed + (8.0 + speed * 0.3) * charge, CHARGED_MAX)
	owner_id = by_id
	_snap(from)
	launch_vel = dir * speed
	hitstop = 0.05 + speed * 0.0045 + charge * 0.12
	return hitstop


# a bunt: pops it up soft and makes it neutral, but the speed is kept for the next swing
func bunted(from: Vector2, facing: float) -> float:
	owner_id = -1
	_snap(from)
	launch_vel = Vector2(facing * 2.5, 13.0)
	hitstop = 0.06
	return hitstop


func tick(delta: float) -> void:
	t += delta
	if gone_t > 0.0:
		gone_t -= delta
		if gone_t <= 0.0:
			serve()
			arena.on_serve()
		return

	if slow_t > 0.0:
		slow_t -= delta

	if hitstop > 0.0:
		hitstop -= delta
		if hitstop <= 0.0:
			vel = launch_vel
		_update_visual()
		return

	last_pos = pos
	var dt := delta * time_scale()
	if float_t > 0.0:
		float_t -= delta
		vel = vel.lerp(Vector2(0.0, sin(t * 2.5) * 1.2), 1.0 - exp(-4.0 * delta))
	elif owner_id < 0:
		vel.y -= SERVE_GRAVITY * dt

	# small steps so a fast ball can't skip through someone
	var n := maxi(1, ceili((vel * dt).length() / 0.2))
	for i in n:
		pos += vel * (dt / n)
		_bounce()
		if arena.ball_step_check():
			break

	_update_visual()


func _bounce() -> void:
	var hw: float = arena.half_w - radius
	var top: float = arena.height - radius
	var hit_wall := false
	if pos.x < -hw:
		pos.x = -hw
		vel.x = absf(vel.x)
		hit_wall = true
	elif pos.x > hw:
		pos.x = hw
		vel.x = -absf(vel.x)
		hit_wall = true
	if pos.y < radius:
		pos.y = radius
		if owner_id < 0 and float_t <= 0.0:
			vel.y = maxf(absf(vel.y) * 0.8, 11.0)  # keep a loose ball bouncing high enough to hit
		else:
			vel.y = absf(vel.y)
		hit_wall = true
	elif pos.y > top:
		pos.y = top
		vel.y = -absf(vel.y)
		hit_wall = true

	if hit_wall and is_live():
		Sfx.play("bounce", clampf(0.8 + speed / 100.0, 0.8, 1.8), -10.0)
		arena.add_shake(minf(speed / 400.0, 0.12))


func _update_visual() -> void:
	position = Vector3(pos.x, pos.y, 0.0)

	var c := Color.WHITE
	if owner_id >= 0:
		c = Game.colors[owner_id]
	if float_t > 0.0:
		c = Color("#b48cff")
	core_mat.albedo_color = c
	mat.albedo_color = Color.WHITE.lerp(c, 0.35)

	var s := 1.0
	if float_t > 0.0:
		s = 1.0 + sin(t * 10.0) * 0.12
	if slow_t > 0.0:
		s = 1.25
	mesh.scale = Vector3.ONE * s

	if hitstop > 0.0:
		mesh.position = Vector3(randf_range(-0.07, 0.07), randf_range(-0.07, 0.07), 0.0)
	else:
		mesh.position = Vector3.ZERO

	# streak behind it, longer the faster it goes
	var v := current_velocity()
	var slen := clampf(v.length() * 0.06, 0.0, 5.0)
	streak.visible = visible and is_live() and slen > 0.6
	if streak.visible:
		var d := v.normalized()
		streak.global_position = Vector3(pos.x - d.x * slen * 0.5, pos.y - d.y * slen * 0.5, -0.02)
		streak.global_rotation = Vector3(0.0, 0.0, atan2(d.y, d.x) - PI / 2.0)
		streak.scale = Vector3(1.0, slen, 1.0)
		streak_mat.albedo_color = Color(c.r, c.g, c.b, 0.65)
