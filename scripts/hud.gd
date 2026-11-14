extends Control
# everything on screen that isn't the 3d stage. all hand drawn.
# laid out on a 640x360 grid (V()) and scaled up, so it sits the same at any resolution

const DOTS := {
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
}

const YELLOW := Color("#f5e04a")
const PIP := Color("#3fb6ff")
const BOX := Color("#3a3d41")
const BOX_EDGE := Color("#5a5e63")
const CONE := Color("#9aa0a6")

var arena = null
var font: Font
var portraits := {}  # char_id -> Texture2D from assets/characters/<file>_portrait.png
var boombox_tex: Texture2D
var t := 0.0
var u := 2.0

var fx := []
var bursts := [{"n": 0, "t": 0.0}, {"n": 0, "t": 0.0}]

var say_text := ""
var say_col := Color.WHITE
var say_t := 0.0
var say_age := 0.0
var sub_text := ""
var hint_text := ""
var hint_alpha := 1.0


func _ready() -> void:
	font = Game.font
	mouse_filter = MOUSE_FILTER_IGNORE
	boombox_tex = Game.asset_tex("ui/boombox")
	for i in Game.characters.size():
		var tex: Texture2D = Game.asset_tex("characters/" + str(Game.characters[i]["file"]) + "_portrait")
		if tex:
			portraits[i] = tex


func say(text: String, col := Color.WHITE, dur := 1.0) -> void:
	say_text = text
	say_col = col
	say_t = dur
	say_age = 0.0


func ring(p: Vector2, col: Color, big: bool) -> void:
	fx.append({"kind": "ring", "p": p, "t": 0.0, "life": 0.45 if big else 0.3, "col": col, "r": 2.6 if big else 1.6})
	fx.append({"kind": "spark", "p": p, "t": 0.0, "life": 0.22, "seed": randf() * 100.0, "n": 9 if big else 5, "r": 2.2 if big else 1.4})


func show_burst(id: int, n: int) -> void:
	bursts[id] = {"n": n, "t": 0.9}


func _process(delta: float) -> void:
	t += delta
	say_t -= delta
	say_age += delta
	for b in bursts:
		b["t"] -= delta
	for i in range(fx.size() - 1, -1, -1):
		fx[i]["t"] += delta
		if fx[i]["t"] >= fx[i]["life"]:
			fx.remove_at(i)
	queue_redraw()


# ---------------- helpers ----------------

func V(x: float, y: float) -> Vector2:
	return Vector2(size.x * 0.5 + (x - 320.0) * u, y * u)


func _fs(n: float) -> int:
	return maxi(6, int(n * u))


func _text(p: Vector2, text: String, fsize: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	if outline > 0:
		draw_string_outline(font, p, text, align, width, fsize, outline, Color(Game.INK, col.a))
	draw_string(font, p, text, align, width, fsize, col)


func _box(a: Vector2, b: Vector2, col: Color) -> void:
	draw_rect(Rect2(a, b - a), col)


func _frame(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_rect(Rect2(a, b - a), col, false, w)


func _scr(p: Vector2) -> Vector2:
	return arena.cam.unproject_position(Vector3(p.x, p.y, 0.0))


func _ppu(p: Vector2) -> float:
	return (_scr(p + Vector2(1.0, 0.0)) - _scr(p)).x


# ---------------- draw ----------------

func _draw() -> void:
	if arena == null:
		return
	u = size.y / 360.0
	_draw_world_fx()
	for f in arena.fighters:
		_draw_player(f)
	_draw_boombox()
	_draw_bursts()
	_draw_say()
	if hint_text != "" and hint_alpha > 0.01:
		_text(V(0, 290), hint_text, _fs(7), Color(1, 1, 1, 0.85 * hint_alpha), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(3 * u))


func _draw_world_fx() -> void:
	# swing swooshes
	for f in arena.fighters:
		if not f.alive or f.swing_t < 0.0 or f.swing_kind != 0:
			continue
		var k: float = (f.swing_t - 0.05) / 0.14  # startup / active times from fighter.gd
		if k < 0.0 or k > 1.6:
			continue
		var a_now: float = f.bat_pivot.rotation.z
		var a_start := 2.3
		var center := _scr(f.pos + Vector2(f.facing * 0.15, 1.3))
		var r_out := _ppu(f.pos) * 2.0
		var r_in := r_out * 0.55
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var fade := clampf(1.6 - k, 0.0, 1.0)
		var steps := 14
		for i in steps + 1:
			var a := lerpf(a_start, a_now, float(i) / steps)
			var d := Vector2(-sin(a) * f.facing, -cos(a))  # screen y is down
			pts.append(center + d * r_out)
			cols.append(Color(f.color, fade * float(i) / steps))
		for i in range(steps, -1, -1):
			var a := lerpf(a_start, a_now, float(i) / steps)
			var d := Vector2(-sin(a) * f.facing, -cos(a))
			pts.append(center + d * r_in)
			cols.append(Color(1, 1, 1, fade * 0.8 * float(i) / steps))
		if absf(a_now - a_start) > 0.2:
			draw_polygon(pts, cols)

	# white reticle round the ball while it's frozen on a hit
	var ball = arena.ball
	if ball.gone_t <= 0.0 and ball.hitstop > 0.0 and ball.owner_id >= 0:
		var c := _scr(ball.pos)
		var r := _ppu(ball.pos) * 1.3
		draw_arc(c, r, 0.0, TAU, 40, Color.WHITE, 2.5 * u * 0.5, true)
		draw_arc(c, r * 0.55, 0.0, TAU, 30, Color(1, 1, 1, 0.7), 1.5, true)
		for i in 4:
			var d := Vector2.RIGHT.rotated(i * PI / 2.0 + t * 2.0)
			draw_line(c + d * r * 0.8, c + d * r * 1.35, Color.WHITE, 2.0 * u * 0.5)

	# hit rings + sparks
	for e in fx:
		var k: float = e["t"] / e["life"]
		var c := _scr(e["p"])
		var ppu := _ppu(e["p"])
		if e["kind"] == "ring":
			var rr: float = ppu * e["r"] * (1.0 - pow(1.0 - k, 3.0))
			draw_arc(c, rr, 0.0, TAU, 48, Color(e["col"], 1.0 - k), maxf(1.0, (1.0 - k) * 6.0 * u * 0.5), true)
		else:
			var n: int = e["n"]
			for i in n:
				var ang: float = (float(i) / n) * TAU + sin(e["seed"] + i * 7.1) * 0.5
				var d := Vector2.RIGHT.rotated(ang)
				var r0: float = ppu * e["r"] * (0.3 + k * 0.7)
				var r1: float = r0 + ppu * e["r"] * 0.6 * (1.0 - k)
				draw_line(c + d * r0, c + d * r1, Color(1, 1, 1, 1.0 - k), 2.5 * u * 0.5)


func _draw_player(f) -> void:
	var dx := 0.0 if f.id == 0 else 320.0
	var ch: Dictionary = Game.characters[f.char_id]
	var dim := 1.0 if f.alive else 0.45

	# portrait: your picture if there is one, otherwise a coloured box with a letter
	var c := V(105 + dx, 24)
	var pr := Rect2(V(85 + dx, 4), V(125 + dx, 44) - V(85 + dx, 4))
	if portraits.has(f.char_id):
		draw_texture_rect(portraits[f.char_id], pr, false, Color(1, 1, 1, dim))
	else:
		draw_rect(pr, Color(Color("#55595e"), dim))
		draw_rect(pr, Color(f.color, dim), false, 2.0 * u)
		_text(Vector2(pr.position.x, c.y + 7.0 * u), str(ch["name"]).substr(0, 1), _fs(20), Color(1, 1, 1, dim), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, int(3 * u))

	# name
	_text(V(127 + dx, 16), str(ch["name"]).to_lower(), _fs(9), Color(1, 1, 1, dim), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(3 * u))

	# yellow special bar, crosshatched where it's empty
	var a := V(125 + dx, 20)
	var b := V(218 + dx, 29)
	_box(a, b, Color(0.05, 0.03, 0.08, 0.9))
	var fill: float = clampf(f.meter / 100.0, 0.0, 1.0)
	var fx_end := lerpf(a.x, b.x, fill)
	var is_full: bool = f.meter >= ch["cost"]
	var bar_col := YELLOW
	if is_full and fmod(t, 0.25) < 0.12:
		bar_col = Color.WHITE
	_box(a, Vector2(fx_end, b.y), Color(bar_col, dim))
	var h := b.y - a.y
	var sx := fx_end - h
	while sx < b.x:
		var p0 := Vector2(sx, b.y)
		var p1 := Vector2(sx + h, a.y)
		if p0.x < fx_end:
			p0 = Vector2(fx_end, b.y - (fx_end - sx))
		if p1.x > b.x:
			p1 = Vector2(b.x, b.y - (b.x - sx))
		if p1.x > p0.x:
			draw_line(p0, p1, Color(0.4, 0.3, 0.55, 0.8), 1.0)
		sx += 2.5 * u
	var cost_x := lerpf(a.x, b.x, float(ch["cost"]) / 100.0)
	if ch["cost"] < 100.0:
		draw_line(Vector2(cost_x, a.y), Vector2(cost_x, b.y), Color(1, 1, 1, 0.8), 1.5)
	_frame(a, b, Color(1, 1, 1, dim), 1.5)

	# dotted bar: lights up with your current burst
	var a2 := V(125 + dx, 32)
	var b2 := V(218 + dx, 39)
	_box(a2, b2, Color(0.05, 0.03, 0.08, 0.9))
	_frame(a2, b2, Color(1, 1, 1, dim), 1.5)
	var lit: int = bursts[f.id]["n"] if bursts[f.id]["t"] > -2.0 else 0
	for i in 16:
		var p := Vector2(lerpf(a2.x + 4.0 * u, b2.x - 4.0 * u, i / 15.0), (a2.y + b2.y) * 0.5)
		draw_circle(p, 1.2 * u, Color(YELLOW, dim) if i < lit else Color(1, 1, 1, 0.35 * dim))

	# life pips
	for i in Game.stocks:
		var px := 131.0 + dx + i * 9.0
		var on: bool = i < f.stocks
		var pip := PackedVector2Array([V(px + 3, 43), V(px + 9, 43), V(px + 6, 51), V(px, 51)])
		draw_colored_polygon(pip, Color(PIP, dim) if on else Color(0.1, 0.12, 0.2, 0.8))
		draw_polyline(PackedVector2Array([pip[0], pip[1], pip[2], pip[3], pip[0]]), Color(1, 1, 1, dim if on else 0.3), 1.2)

	if is_full:
		var key := ""
		if Game.is_human(f.id):
			key = " [" + Game.key_names[f.id]["special"] + "]"
		_text(V(180 + dx, 51), "special" + key, _fs(6), Color(YELLOW, dim), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(2 * u))


func _draw_boombox() -> void:
	var ball = arena.ball
	var sp := 0.0
	if ball.gone_t <= 0.0:
		sp = ball.speed

	if boombox_tex:
		draw_texture_rect(boombox_tex, Rect2(V(146, 290), V(494, 362) - V(146, 290)), false)
	else:
		_boombox_body()
	_boombox_screens(ball, sp)


func _boombox_body() -> void:
	# side wings with the little outer speakers
	draw_colored_polygon(PackedVector2Array([V(150, 330), V(178, 318), V(178, 362), V(146, 362)]), BOX.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([V(490, 330), V(462, 318), V(462, 362), V(494, 362)]), BOX.darkened(0.3))
	_speaker(V(162, 348), 13.0 * u)
	_speaker(V(478, 348), 13.0 * u)

	# body
	_box(V(178, 294), V(462, 362), BOX)
	_box(V(178, 294), V(462, 297), BOX_EDGE)
	_frame(V(178, 294), V(462, 362), Color("#06110f"), 2.0)

	# big speakers + tweeters
	_speaker(V(214, 352), 30.0 * u)
	_speaker(V(426, 352), 30.0 * u)
	_speaker(V(209, 316), 11.0 * u)
	_speaker(V(431, 316), 11.0 * u)


func _boombox_screens(ball, sp: float) -> void:
	var label_col := Color(1, 1, 1, 0.8)
	_text(V(231, 302), "NOW PLAYING:", _fs(5), label_col)
	_box(V(231, 304), V(351, 312), Color("#050807"))
	var song: String = "HYPER ATTACK - " + (Game._music_name.to_upper() if Game.music.playing else "NO MUSIC") + "      "
	var scroll := int(t * 4.0) % song.length()
	var shown := (song.substr(scroll) + song).substr(0, 26)
	_text(V(233, 311), shown, _fs(6), Color("#e8f6ff"))

	_text(V(340, 302), "TIME:", _fs(5), label_col)
	_box(V(355, 301), V(400, 313), Color("#050807"))
	var secs := maxi(0, int(ceil(arena.time_left)))
	var tcol := Color.WHITE if secs > 10 or fmod(t, 0.5) < 0.25 else Color("#ff5a5a")
	var ttxt := "%d:%02d" % [secs / 60, secs % 60]
	if Game.match_time <= 0.0:
		ttxt = "--:--"
		tcol = Color.WHITE
	_text(V(355, 312), ttxt, _fs(10), tcol, HORIZONTAL_ALIGNMENT_CENTER, 45.0 * u)

	_text(V(260, 317), "SPEED:", _fs(5), label_col)
	_text(V(363, 317), "RELEASE", _fs(5), label_col)

	# the big dot matrix speed readout
	_box(V(283, 314), V(353, 338), Color("#050807"))
	_frame(V(283, 314), V(353, 338), Color("#2a3a38"), 1.5)
	var txt := str(int(sp)) if sp > 0.0 else "---"
	while txt.length() < 3:
		txt = " " + txt
	var on_col := Color.WHITE
	if sp > 0.0 and ball.owner_id >= 0:
		on_col = Color.WHITE.lerp(Game.colors[ball.owner_id], 0.25)
	var dot := 2.8 * u
	var total_w := txt.length() * 6.0 * dot - dot
	var ox := (V(283, 0).x + V(353, 0).x) * 0.5 - total_w * 0.5
	var oy := V(0, 316.5).y
	var jitter := Vector2.ZERO
	if sp > 80.0 and ball.hitstop > 0.0:
		jitter = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * u
	for ci in txt.length():
		var ch := txt[ci]
		var rows = DOTS.get(ch, null)
		for ry in 7:
			for rx in 5:
				var lit: bool = rows != null and rows[ry][rx] == "1"
				var p := Vector2(ox + ci * 6.0 * dot + rx * dot, oy + ry * dot) + jitter
				draw_rect(Rect2(p, Vector2(dot * 0.8, dot * 0.8)), on_col if lit else Color(1, 1, 1, 0.06))

	# vu meters bounce with the speed
	var level := clampf(sp / 160.0, 0.0, 1.0)
	_vu(V(226, 325), V(276, 331), level + sin(t * 23.0) * 0.04 * level, false)
	_vu(V(363, 325), V(413, 331), level + sin(t * 19.0 + 1.0) * 0.04 * level, true)

	# two little scope screens
	for s in 2:
		var x0 := 283.0 + s * 38.0
		_box(V(x0, 341), V(x0 + 32, 360), Color("#050807"))
		var pts := PackedVector2Array()
		for i in 17:
			var xx := x0 + 2.0 + i * 1.75
			var yy := 350.5 + sin(t * (5.0 + s * 3.0) + i * 0.6) * (2.0 + level * 5.0)
			pts.append(V(xx, yy))
		draw_polyline(pts, Color("#ff5a5a") if s == 0 else Color("#6bff8a"), 1.5)


func _speaker(c: Vector2, r: float) -> void:
	draw_circle(c, r * 1.12, Color("#06110f"))
	draw_circle(c, r, Color("#1b2b2a"))
	draw_arc(c, r * 0.86, 0.0, TAU, 40, CONE, r * 0.14, true)
	draw_circle(c, r * 0.62, CONE.darkened(0.25))
	draw_circle(c, r * 0.3, Color("#0e1a19"))
	draw_circle(c, r * 0.12, CONE)


func _vu(a: Vector2, b: Vector2, level: float, flip: bool) -> void:
	var n := 12
	var w := (b.x - a.x) / n
	for i in n:
		var k := float(i) / (n - 1)
		var on := k <= level
		var col := Color("#ff7a2e").lerp(YELLOW, k)
		var idx := (n - 1 - i) if flip else i
		draw_rect(Rect2(Vector2(a.x + idx * w, a.y), Vector2(w * 0.75, b.y - a.y)), col if on else Color(col, 0.15))


func _draw_bursts() -> void:
	for i in 2:
		var b: Dictionary = bursts[i]
		if b["t"] <= 0.0 or b["n"] < 2:
			continue
		var age: float = 0.9 - b["t"]
		var pop := 1.0 + maxf(0.0, 0.12 - age) * 4.0
		var a := clampf(b["t"] * 4.0, 0.0, 1.0)
		var x := 175.0 if i == 0 else 465.0
		var fsz := _fs(26.0 * pop)
		var p := V(x - 55, 112)
		draw_string_outline(font, p, "Burst", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsz, int(6 * u), Color(Color("#0d3b3a"), a))
		draw_string(font, p, "Burst", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsz, Color(1, 1, 1, a))
		var w := font.get_string_size("Burst", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsz).x
		var num := str(b["n"])
		draw_string_outline(font, p + Vector2(w + 4.0 * u, 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsz, int(6 * u), Color(Color("#0d3b3a"), a))
		draw_string(font, p + Vector2(w + 4.0 * u, 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsz, Color(Color("#f5e04a"), a))


func _draw_say() -> void:
	if say_t <= 0.0 or say_text == "":
		return
	var a := clampf(say_t * 4.0, 0.0, 1.0)
	var pop := 1.0 + maxf(0.0, 0.12 - say_age) * 5.0
	var fsz := _fs(44.0 * pop)
	var p := V(0, 180)
	p.x = 0.0
	draw_string_outline(font, p + Vector2(0, fsz * 0.35), say_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fsz, int(9 * u), Color(Color("#0d3b3a"), a))
	draw_string(font, p + Vector2(0, fsz * 0.35), say_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fsz, Color(say_col, a))
	if sub_text != "":
		_text(Vector2(0, V(0, 215).y), sub_text, _fs(10), Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(3 * u))
