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
var band_k := 0.0  # 0 = title layout, 1 = menu layout, animates between
var appear := 0.0  # time since this screen opened (for fly-ins)
var pop_t := 1.0  # time since the selection last changed
var prev_sel := -1
var logo_shift := Vector2.ZERO  # how far the title stuff has slid left

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
	band_k = 0.0 if state == "title" else 1.0
	appear = 1.0
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
	appear += delta
	pop_t += delta
	if sel != prev_sel:
		prev_sel = sel
		pop_t = 0.0
	band_k = move_toward(band_k, 0.0 if state == "title" else 1.0, delta / 0.45)
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
			Sfx.ui("menu_hover", "", "tick", 1.4, -10.0)


func _input(event: InputEvent) -> void:
	if state == "title":
		var any: bool = (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo()
		if any:
			_go_state("main")
			if not Sfx.sounds.has("menu_start"):
				Sfx.play("swing", 0.8, -2.0)
			Sfx.ui("menu_start", "", "special", 1.3, -8.0)
			flash = 0.25
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if back_rect.has_point(event.position):
			_back()
			return
		for i in _items().size():
			if _button_rect(i).has_point(event.position):
				sel = i
				# clicking a setting changes it, clicking "back" goes back
				if state == "options" and i < _items().size() - 1:
					_change_option(1)
				else:
					_confirm()
				return


func _move(d: int, n: int) -> void:
	if n == 0:
		return
	sel = (sel + d + n) % n
	Sfx.ui("menu_move", "", "tick", 1.3, -8.0)


func _go_state(s: String) -> void:
	state = s
	sel = 0
	appear = 0.0
	pop_t = 0.0
	prev_sel = 0
	lock_t = 0.25 if s == "main" and band_k < 1.0 else 0.15
	_reset_slide()


func _confirm() -> void:
	var items_now := _items()
	var picked: String = str(items_now[sel]).get_slice("<", 0).strip_edges() if sel < items_now.size() else state
	Sfx.ui("menu_select", picked, "hit", 1.5, -10.0)
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
	Sfx.ui("menu_back", state, "tick", 0.8, -8.0)
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
	Sfx.ui("menu_change", "", "tick", 1.6, -8.0)


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
		top = 44.0 + 37.0 * i
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
	var k := smoothstep(0.0, 1.0, band_k)

	UI.draw_bg(self, size, t, title_bg if k < 0.5 else menu_bg, k)

	# title bits slide off to the left as the band moves
	if k < 1.0:
		var a := clampf(1.0 - k * 1.6, 0.0, 1.0)
		logo_shift = Vector2(-260.0 * u * k, 0)
		draw_set_transform(logo_shift, 0.0, Vector2.ONE)
		modulate_draw_logo(a)
		if state == "title" and fmod(t, 1.2) < 0.85:
			var p := _v(0, 330)
			p.x = 0.0
			draw_string_outline(f, p, "- Press Any Button -", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(15 * u), int(4 * u), Color(UI.BLACK, a))
			draw_string(f, p, "- Press Any Button -", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(15 * u), Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if state == "title":
		_draw_flash()
		return

	# menu bits come in once the band is mostly across
	var drop := clampf((appear - 0.2) / 0.25, 0.0, 1.0)
	var header := {"main": "MAIN MENU", "options": "OPTIONS", "howto": "HOW TO PLAY", "credits": "CREDITS"}
	UI.draw_header(self, size, f, header.get(state, ""), UI.ease_out_back(drop))

	if state == "howto":
		_slide_panel(drop)
		_draw_howto()
	elif state == "credits":
		_slide_panel(drop)
		_draw_credits()
	else:
		var items := _items()
		for i in items.size():
			var g := _button_geom(i)
			var ki := clampf((appear - 0.12 - i * 0.045) / 0.28, 0.0, 1.0)
			var xoff := -320.0 * (1.0 - UI.ease_out_back(ki))
			UI.draw_button(self, size, f, g[0], g[1], g[2], items[i], i == sel, t, pop_t / 0.22, xoff)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_set_transform(Vector2(0, 60.0 * u * (1.0 - UI.ease_out_back(drop))), 0.0, Vector2.ONE)
	_draw_profile()
	back_rect = UI.draw_back_arrow(self, size)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_flash()


func _slide_panel(drop: float) -> void:
	var u := size.y / 360.0
	draw_set_transform(Vector2(420.0 * u * (1.0 - UI.ease_out_back(drop)), 0), 0.0, Vector2.ONE)


func modulate_draw_logo(a: float) -> void:
	if a <= 0.0:
		return
	var u := size.y / 360.0
	_draw_logo(_v(320, 140), 120.0 * u, a)


func _draw_flash() -> void:
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash * 0.8))


func _draw_logo(c: Vector2, r: float, a := 1.0) -> void:
	if logo:
		var ls := logo.get_size()
		var sc := (r * 2.0) / maxf(ls.x, ls.y)
		draw_texture_rect(logo, Rect2(c - ls * sc * 0.5, ls * sc), false, Color(1, 1, 1, a))
		return
	# placeholder logo: spiky badge + the name
	var pts := PackedVector2Array()
	for i in 24:
		var ang := i * TAU / 24.0 - PI / 2.0
		var rr := r * (1.0 if i % 2 == 0 else 0.72) * (1.0 + 0.03 * sin(t * 3.0 + i))
		pts.append(c + Vector2(cos(ang) * rr * 1.15, sin(ang) * rr * 0.95))
	draw_colored_polygon(pts, Color(Color("#0f4f6b"), a))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(UI.CYAN, a), r * 0.05)
	var f: Font = Game.font
	var fs := int(r * 0.42)
	# words tilted a little to the right, drawn around the logo centre
	draw_set_transform(c + logo_shift, 0.1, Vector2.ONE)
	for row in [["HYPER", -0.06], ["ATTACK", 0.38]]:
		var p := Vector2(-r * 1.4, r * float(row[1]))
		draw_string_outline(f, p, row[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2.8, fs, int(r * 0.1), Color(UI.BLACK, a))
		draw_string(f, p, row[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2.8, fs, Color(UI.CYAN.lightened(0.4), a))
	draw_set_transform(logo_shift, 0.0, Vector2.ONE)


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
	# plain outlined text in the menu font, no boxes. steps first, then everyone's keys
	var u := size.y / 360.0
	var f: Font = Game.font
	var steps := [
		["1", "smack it", "tap swing to hit. hold swing to charge, let go for a way faster hit"],
		["2", "aim it", "hold W to send it up, S to send it down. add forward for a flatter angle"],
		["3", "don't get hit", "if THEIR ball hits YOU, you lose a life. last one standing wins"],
	]
	var y := 66.0
	for i in steps.size():
		var x := 132.0 - i * 9.0  # staircase, same as the menu buttons
		_say(_v(x, y + 6), steps[i][0], 32, UI.YELLOW)
		_say(_v(x + 26, y - 6), steps[i][1], 16, Color.WHITE)
		_say(_v(x + 27, y + 8), steps[i][2], 8.5, Color.WHITE)
		y += 38.0

	var k0: Dictionary = Game.key_names[0]
	var cols := [
		["p1", Game.colors[0], 132.0, [["A D", "move"], ["W", "jump"], ["S", "fall"], [k0["swing"], "swing"], [k0["bunt"], "bunt"], [k0["special"], "special"]], "left side of the keyboard"],
		["p2", Game.colors[1], 372.0, [["4 6", "move"], ["8", "jump"], ["5", "fall"], ["1", "swing"], ["2", "bunt"], ["3", "special"]], "numpad. arrows + K L ; work too"],
	]
	for c in cols:
		var x: float = c[2]
		var cy := 196.0
		_say(_v(x, cy), c[0], 24, c[1])
		var hw: float = f.get_string_size(str(c[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u)).x / u
		_say(_v(x + hw + 8, cy - 1), c[4], 7.5, Color.WHITE)
		cy += 18.0
		var keys: Array = c[3]
		for r in keys.size():
			var rx: float = x - r * 3.0
			_say(_v(rx, cy), str(keys[r][0]), 11, UI.YELLOW, HORIZONTAL_ALIGNMENT_RIGHT, 30.0 * u)
			_say(_v(rx + 36, cy), str(keys[r][1]), 9.5, Color.WHITE)
			cy += 15.0


# outlined text, same look as the menu buttons
func _say(p: Vector2, text: String, fs: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	var u := size.y / 360.0
	draw_string_outline(Game.font, p, text, align, w, int(fs * u), int(maxf(3.0, fs * 0.3) * u), UI.BLACK)
	draw_string(Game.font, p, text, align, w, int(fs * u), col)


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
