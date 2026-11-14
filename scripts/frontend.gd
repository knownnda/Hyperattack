extends Control
# title screen + main menu + options + how to play, laid out like LLB's menus.
# W/S or arrows to move, F / K / enter to pick, G / L / esc to go back. mouse works too.

const UI := preload("res://scripts/ui_bg.gd")

var state := "title"
var sel := 0
var t := 0.0
var flash := 0.0
var slide := []  # how far each button is poked out (selected one slides right)
var back_rect := Rect2()
var lock_t := 0.0  # ignore input for a moment after switching screens

var logo: Texture2D
var title_bg: Texture2D
var menu_bg: Texture2D
var profile_pic: Texture2D

const TIMES := [0.0, 120.0, 180.0, 300.0, 420.0, 600.0]
const LEVELS := ["easy", "normal", "hard"]


func _ready() -> void:
	logo = Game.asset_tex("ui/logo")
	title_bg = Game.asset_tex("ui/title_bg")
	menu_bg = Game.asset_tex("ui/menu_bg")
	profile_pic = Game.asset_tex("ui/profile")
	state = Game.menu_start
	Game.play_music("menu")
	_reset_slide()


func _items() -> Array:
	match state:
		"main":
			var list := ["versus", "single", "how to play", "options", "credits"]
			if OS.get_name() != "Web":
				list.append("quit")
			return list
		"options":
			return [
				"lives   < %d >" % Game.stocks,
				"timer   < %s >" % ("off" if Game.match_time <= 0.0 else "%d:00" % int(Game.match_time / 60.0)),
				"cpu   < %s >" % LEVELS[Game.cpu_level],
				"sfx   < %d%% >" % int(round(Game.sfx_vol * 100.0)),
				"music   < %d%% >" % int(round(Game.music_vol * 100.0)),
				"fullscreen   < %s >" % ("on" if Game.fullscreen else "off"),
				"back",
			]
	return []


func _reset_slide() -> void:
	slide.clear()
	for i in 8:
		slide.append(0.0)


# ---------------- input ----------------

func _pressed(names: Array) -> bool:
	for n in names:
		if Input.is_action_just_pressed(n):
			return true
	return false


func _process(delta: float) -> void:
	t += delta
	flash = maxf(flash - delta * 4.0, 0.0)
	for i in slide.size():
		slide[i] = lerpf(slide[i], 22.0 if i == sel else 0.0, 1.0 - exp(-18.0 * delta))
	queue_redraw()

	if state == "title":
		return  # handled in _input, any button works
	if lock_t > 0.0:
		lock_t -= delta
		return

	var items := _items()
	if _pressed(["ui_up", "p0_up", "p1_up"]):
		_move(-1, items.size())
	elif _pressed(["ui_down", "p0_down", "p1_down"]):
		_move(1, items.size())
	if state == "options":
		if _pressed(["ui_left", "p0_left", "p1_left"]):
			_change_option(-1)
		elif _pressed(["ui_right", "p0_right", "p1_right"]):
			_change_option(1)
	if _pressed(["ui_accept", "p0_swing", "p1_swing"]):
		_confirm()
	elif _pressed(["ui_cancel", "p0_bunt", "p1_bunt"]):
		_back()

	# mouse hover
	var m := get_local_mouse_position()
	for i in items.size():
		if _button_rect(i).has_point(m) and sel != i:
			sel = i
			Sfx.play("tick", 1.4, -10.0)


func _input(event: InputEvent) -> void:
	if state == "title":
		var any: bool = (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo()
		if any:
			_go_state("main")
			Sfx.play("special", 1.3, -4.0)
			Sfx.play("menu_select")
			flash = 1.0
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if back_rect.has_point(event.position):
			_back()
			return
		for i in _items().size():
			if _button_rect(i).has_point(event.position):
				sel = i
				if state == "options":
					_change_option(1)
				else:
					_confirm()
				return


func _move(d: int, n: int) -> void:
	if n == 0:
		return
	sel = (sel + d + n) % n
	Sfx.play("tick", 1.3, -8.0)
	Sfx.play("menu_move")


func _go_state(s: String) -> void:
	state = s
	sel = 0
	lock_t = 0.15
	_reset_slide()


func _confirm() -> void:
	Sfx.play("hit", 1.5, -10.0)
	Sfx.play("menu_select")
	match state:
		"main":
			var item: String = _items()[sel]
			match item:
				"versus":
					Game.mode = "2p"
					Game.goto("res://scenes/select.tscn")
				"single":
					Game.mode = "cpu"
					Game.goto("res://scenes/select.tscn")
				"how to play":
					_go_state("howto")
				"options":
					_go_state("options")
				"credits":
					_go_state("credits")
				"quit":
					get_tree().quit()
		"options":
			if sel == 6:
				_back()
			else:
				_change_option(1)
		"howto", "credits":
			_back()


func _back() -> void:
	Sfx.play("tick", 0.8, -8.0)
	Sfx.play("menu_back")
	match state:
		"main":
			_go_state("title")
		"options":
			Game.save_settings()
			_go_state("main")
			sel = 3
		"howto":
			_go_state("main")
			sel = 2
		"credits":
			_go_state("main")
			sel = 4


func _change_option(d: int) -> void:
	match sel:
		0:
			Game.stocks = clampi(Game.stocks + d, 1, 9)
		1:
			var i := TIMES.find(Game.match_time)
			Game.match_time = TIMES[(maxi(i, 0) + d + TIMES.size()) % TIMES.size()]
		2:
			Game.cpu_level = (Game.cpu_level + d + 3) % 3
		3:
			Game.sfx_vol = clampf(snappedf(Game.sfx_vol + d * 0.1, 0.1), 0.0, 1.0)
		4:
			Game.music_vol = clampf(snappedf(Game.music_vol + d * 0.1, 0.1), 0.0, 1.0)
		5:
			Game.fullscreen = not Game.fullscreen
		_:
			return
	Game.apply_settings()
	Sfx.play("tick", 1.6, -8.0)


# ---------------- drawing ----------------

func _v(x: float, y: float) -> Vector2:
	return UI.V(size, x, y)


func _button_geom(i: int) -> Array:
	# staircase: each button sits a bit further left, like the reference
	var left := 140.0 - 11.0 * i
	var right: float = 305.0 - 5.0 * i + (slide[i] if i < slide.size() else 0.0)
	var top := 75.0 + 45.0 * i
	if state == "main" and _items().size() > 5:
		top = 58.0 + 41.0 * i
	if state == "options":
		top = 50.0 + 40.0 * i
		left = 150.0 - 9.0 * i
		right = 335.0 - 4.0 * i + (slide[i] if i < slide.size() else 0.0)
	return [left, right, top]


func _button_rect(i: int) -> Rect2:
	var g := _button_geom(i)
	var a := _v(g[0], g[2])
	var b := _v(g[1] + 9.0, g[2] + 37.0)
	return Rect2(a, b - a)


func _draw() -> void:
	var u := size.y / 360.0
	var f: Font = Game.font

	if state == "title":
		UI.draw_bg(self, size, t, title_bg, "title")
		_draw_logo(_v(320, 140), 120.0 * u)
		if fmod(t, 1.2) < 0.85:
			var p := _v(0, 330)
			p.x = 0.0
			draw_string_outline(f, p, "- Press Any Button -", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(15 * u), int(4 * u), UI.BLACK)
			draw_string(f, p, "- Press Any Button -", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(15 * u), Color.WHITE)
		_draw_flash()
		return

	UI.draw_bg(self, size, t, menu_bg, "menu")

	var header := {"main": "MAIN MENU", "options": "OPTIONS", "howto": "HOW TO PLAY", "credits": "CREDITS"}
	UI.draw_header(self, size, f, header.get(state, ""))

	if state == "howto":
		_draw_howto()
	elif state == "credits":
		_draw_credits()
	else:
		var items := _items()
		for i in items.size():
			var g := _button_geom(i)
			UI.draw_button(self, size, f, g[0], g[1], g[2], items[i], i == sel)

	_draw_profile()
	back_rect = UI.draw_back_arrow(self, size)
	_draw_flash()


func _draw_flash() -> void:
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash * 0.8))


func _draw_logo(c: Vector2, r: float) -> void:
	if logo:
		var ls := logo.get_size()
		var sc := (r * 2.0) / maxf(ls.x, ls.y)
		draw_texture_rect(logo, Rect2(c - ls * sc * 0.5, ls * sc), false)
		return
	# placeholder logo: spiky badge + the name
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0 - PI / 2.0
		var rr := r * (1.0 if i % 2 == 0 else 0.72) * (1.0 + 0.03 * sin(t * 3.0 + i))
		pts.append(c + Vector2(cos(a) * rr * 1.15, sin(a) * rr * 0.95))
	draw_colored_polygon(pts, Color("#0f4f6b"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), UI.CYAN, r * 0.05)
	draw_circle(c, r * 0.32, Color.WHITE)
	draw_arc(c, r * 0.32, 0.0, TAU, 32, UI.BLACK, r * 0.04)
	draw_circle(c, r * 0.1, Color("#ff3b5c"))
	var f: Font = Game.font
	var fs := int(r * 0.42)
	for row in [["HYPER", -0.32], ["ATTACK", 0.62]]:
		var p := c + Vector2(-r * 1.4, r * float(row[1]))
		draw_string_outline(f, p, row[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2.8, fs, int(r * 0.1), UI.BLACK)
		draw_string(f, p, row[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2.8, fs, UI.CYAN.lightened(0.4))


func _draw_profile() -> void:
	# little player card in the bottom left, like the reference
	var u := size.y / 360.0
	var f: Font = Game.font
	draw_colored_polygon(PackedVector2Array([Vector2(0, _v(0, 312).y), _v(240, 312), _v(228, 360), Vector2(0, size.y)]), UI.BLACK)
	var pr := Rect2(_v(95, 318), _v(119, 344) - _v(95, 318))
	if profile_pic:
		draw_texture_rect(profile_pic, pr, false)
	else:
		draw_rect(pr, Color("#55595e"))
		draw_rect(pr, Game.colors[0], false, 1.5 * u)
		draw_string(f, Vector2(pr.position.x, pr.end.y - 6.0 * u), "P1", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, int(11 * u), Color.WHITE)
	draw_line(_v(124, 329), _v(225, 329), Color(1, 1, 1, 0.4), 1.0)
	draw_string(f, _v(125, 327), "player 1", HORIZONTAL_ALIGNMENT_LEFT, -1, int(7 * u), Color.WHITE)
	draw_string(f, _v(125, 337), "matches: %d" % Game.matches_played, HORIZONTAL_ALIGNMENT_LEFT, -1, int(6 * u), Color(1, 1, 1, 0.75))
	draw_string(f, _v(125, 345), "wins: %d" % Game.p1_wins, HORIZONTAL_ALIGNMENT_LEFT, -1, int(6 * u), Color(1, 1, 1, 0.75))
	draw_string(f, _v(183, 355), Game.VERSION, HORIZONTAL_ALIGNMENT_LEFT, -1, int(6 * u), Color(1, 1, 1, 0.5))


func _draw_howto() -> void:
	var u := size.y / 360.0
	var f: Font = Game.font
	draw_colored_polygon(PackedVector2Array([_v(120, 45), _v(560, 45), _v(545, 300), _v(105, 300)]), Color(UI.BLACK, 0.92))
	draw_polyline(PackedVector2Array([_v(120, 45), _v(560, 45), _v(545, 300), _v(105, 300), _v(120, 45)]), Color.WHITE, 1.5 * u)
	var k0: Dictionary = Game.key_names[0]
	var k1: Dictionary = Game.key_names[1]
	var lines := [
		["the ball", UI.CYAN],
		["hit the ball and it turns your colour and speeds up.", Color.WHITE],
		["if the other player's ball touches you, you lose a life.", Color.WHITE],
		["hold up or down while you swing to aim. bunt pops it up soft.", Color.WHITE],
		["", Color.WHITE],
		["p1", Game.colors[0]],
		["A D move    W jump    S down    %s swing    %s bunt    %s special" % [k0["swing"], k0["bunt"], k0["special"]], Color.WHITE],
		["p2", Game.colors[1]],
		["arrows move    UP jump    %s swing    %s bunt    %s special" % [k1["swing"], k1["bunt"], k1["special"]], Color.WHITE],
		["", Color.WHITE],
		["gamepad:  A jump    X swing    B bunt    Y special", Color(1, 1, 1, 0.7)],
	]
	var y := 70.0
	for l in lines:
		var big: bool = l[1] != Color.WHITE and l[1] != Color(1, 1, 1, 0.7)
		draw_string(f, _v(135, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int((12 if big else 9) * u), l[1])
		y += 21.0 if big else 18.0


func _credit_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var file := FileAccess.open("res://assets/credits.txt", FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "" and not line.begins_with("#"):
			out.append(line)
	return out


func _draw_credits() -> void:
	var u := size.y / 360.0
	var f: Font = Game.font
	draw_colored_polygon(PackedVector2Array([_v(120, 45), _v(560, 45), _v(545, 300), _v(105, 300)]), Color(UI.BLACK, 0.92))
	draw_polyline(PackedVector2Array([_v(120, 45), _v(560, 45), _v(545, 300), _v(105, 300), _v(120, 45)]), Color.WHITE, 1.5 * u)
	var y := 70.0
	for line: String in _credit_lines():
		# all-caps lines are headings
		var heading: bool = line == line.to_upper()
		var parts: PackedStringArray = line.split(" - ")
		draw_string(f, _v(135, y), parts[0], HORIZONTAL_ALIGNMENT_LEFT, 400.0 * u, int((12 if heading else 9) * u), UI.CYAN if heading else Color.WHITE)
		y += 18.0 if heading else 13.0
		if parts.size() > 1:
			draw_string(f, _v(145, y), " - ".join(parts.slice(1)), HORIZONTAL_ALIGNMENT_LEFT, 390.0 * u, int(6 * u), Color(1, 1, 1, 0.6))
			y += 13.0
		y += 3.0
