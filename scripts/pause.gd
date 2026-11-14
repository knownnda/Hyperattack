extends Control
# esc in a match brings this up. same slanted buttons as the main menu.
#   resume / restart / controls / change characters / options / back to menu
# while it's open assets/music/music.ogg plays (or menu.ogg if there isn't one)
# options here change cpu level, timer and lives on the spot

const UI := preload("res://scripts/ui_bg.gd")
const TIMES := [0.0, 120.0, 180.0, 300.0, 420.0, 600.0]
const LEVELS := ["easy", "normal", "hard"]

var arena = null
var open := false
var state := "pause"
var sel := 0
var prev_sel := 0
var t := 0.0
var appear := 0.0
var pop_t := 0.0
var lock_t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


func toggle() -> void:
	open = not open
	visible = open
	state = "pause"
	sel = 0
	appear = 0.0
	lock_t = 0.12
	mouse_filter = MOUSE_FILTER_STOP if open else MOUSE_FILTER_IGNORE
	Sfx.ui("pause_open" if open else "pause_close", "", "tick", 1.0 if open else 0.8, -6.0)
	if open:
		Game.play_music("music", "menu")
	else:
		Game.play_music("match")
	if not open:
		Game.save_settings()
		if arena:
			arena.resume_lock = 0.2  # so the button you closed it with doesn't swing


# the "here are the controls, press enter when you're ready" screen before a match
func show_brief() -> void:
	open = true
	visible = true
	state = "brief"
	appear = 0.0
	mouse_filter = MOUSE_FILTER_STOP


func hide_brief() -> void:
	open = false
	visible = false
	state = "pause"
	mouse_filter = MOUSE_FILTER_IGNORE
	if arena:
		arena.resume_lock = 0.25


func _items() -> Array:
	if state == "options":
		return [
			"cpu   < %s >" % LEVELS[Game.cpu_level],
			"timer   < %s >" % ("off" if Game.match_time <= 0.0 else "%d:00" % int(Game.match_time / 60.0)),
			"lives   < %d >" % Game.stocks,
			"sfx   < %d%% >" % int(round(Game.sfx_vol * 100.0)),
			"music   < %d%% >" % int(round(Game.music_vol * 100.0)),
			"back",
		]
	if state == "controls" or state == "brief":
		return []
	return ["resume", "restart", "controls", "change characters", "options", "back to menu"]


func _pressed(names: Array) -> bool:
	for n in names:
		if Input.is_action_just_pressed(n):
			return true
	return false


func _process(delta: float) -> void:
	if not open:
		return
	t += delta
	appear += delta
	pop_t += delta
	if sel != prev_sel:
		prev_sel = sel
		pop_t = 0.0
	queue_redraw()
	if state == "brief":
		return  # the match itself listens for enter
	if lock_t > 0.0:
		lock_t -= delta
		return

	if state == "controls":
		if _pressed(["ui_accept", "p0_swing", "p1_swing", "p0_bunt", "p1_bunt"]):
			_back()
		return

	var items := _items()
	if _pressed(["ui_up", "p0_up", "p1_up"]):
		sel = (sel - 1 + items.size()) % items.size()
		Sfx.ui("menu_move", "", "tick", 1.3, -8.0)
	elif _pressed(["ui_down", "p0_down", "p1_down"]):
		sel = (sel + 1) % items.size()
		Sfx.ui("menu_move", "", "tick", 1.3, -8.0)
	if state == "options":
		if _pressed(["ui_left", "p0_left", "p1_left"]):
			_change(-1)
		elif _pressed(["ui_right", "p0_right", "p1_right"]):
			_change(1)
	if _pressed(["ui_accept", "p0_swing", "p1_swing"]):
		_confirm()
	elif _pressed(["p0_bunt", "p1_bunt"]):
		_back()

	var m := get_local_mouse_position()
	for i in items.size():
		if _rect(i).has_point(m) and sel != i:
			sel = i
			Sfx.ui("menu_hover", "", "tick", 1.4, -10.0)


func _gui_input(event: InputEvent) -> void:
	if not open:
		return
	if state == "controls" and event is InputEventMouseButton and event.pressed:
		_back()
		return
	if state == "brief" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		arena.start_from_brief()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _items().size():
			if _rect(i).has_point(event.position):
				sel = i
				if state == "options" and i < 5:
					_change(1)
				else:
					_confirm()
				return


# esc: back out of a sub page, or close the menu
func on_escape() -> void:
	if state != "pause":
		_back()
	else:
		toggle()


func _confirm() -> void:
	var items := _items()
	var picked := str(items[sel]).get_slice("<", 0).strip_edges()
	Sfx.ui("menu_select", picked, "hit", 1.5, -10.0)
	if state == "options":
		if sel == items.size() - 1:
			_back()
		else:
			_change(1)
		return
	match sel:
		0:
			toggle()
		1:
			Game.goto("res://scenes/match.tscn")
		2:
			state = "controls"
			appear = 0.0
		3:
			Game.goto("res://scenes/select.tscn")
		4:
			state = "options"
			sel = 0
			appear = 0.0
		5:
			Game.menu_start = "main"
			Game.goto("res://scenes/frontend.tscn")


func _back() -> void:
	Sfx.ui("menu_back", state, "tick", 0.8, -8.0)
	if state == "options":
		Game.save_settings()
		state = "pause"
		sel = 4
		appear = 0.0
	elif state == "controls":
		state = "pause"
		sel = 2
		appear = 0.0
	else:
		toggle()


func _change(d: int) -> void:
	match sel:
		0:
			Game.cpu_level = (Game.cpu_level + d + 3) % 3  # the bot reads this live
		1:
			var i := TIMES.find(Game.match_time)
			Game.match_time = TIMES[(maxi(i, 0) + d + TIMES.size()) % TIMES.size()]
			arena.time_left = Game.match_time  # timer restarts at the new length
		2:
			var before: int = Game.stocks
			Game.stocks = clampi(Game.stocks + d, 1, 9)
			# give / take the difference to everyone still in, so it's fair mid-match
			for f in arena.fighters:
				if f.alive:
					f.stocks = clampi(f.stocks + (Game.stocks - before), 1, Game.stocks)
		3:
			Game.sfx_vol = clampf(snappedf(Game.sfx_vol + d * 0.1, 0.1), 0.0, 1.0)
		4:
			Game.music_vol = clampf(snappedf(Game.music_vol + d * 0.1, 0.1), 0.0, 1.0)
		_:
			return
	Game.apply_settings()
	Sfx.ui("menu_change", "", "tick", 1.6, -8.0)


func _geom(i: int) -> Array:
	var left := 150.0 - 10.0 * i
	var right := 340.0 - 5.0 * i
	var top := 64.0 + 42.0 * i
	if state == "options":
		top = 56.0 + 38.0 * i
		right = 355.0 - 5.0 * i
	return [left, right, top]


func _rect(i: int) -> Rect2:
	var g := _geom(i)
	var a := UI.V(size, g[0], g[2])
	var b := UI.V(size, g[1] + 9.0, g[2] + 37.0)
	return Rect2(a, b - a)


func _draw() -> void:
	if not open:
		return
	var u := size.y / 360.0
	var f: Font = Game.font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	# the black band from the menus, sliding in behind the buttons
	var k := UI.ease_out_back(clampf(appear / 0.25, 0.0, 1.0))
	var sx := -200.0 * (1.0 - k)
	draw_colored_polygon(PackedVector2Array([UI.V(size, 230 + sx, 0), UI.V(size, 330 + sx, 0), UI.V(size, 200 + sx, 360), UI.V(size, 100 + sx, 360)]), UI.BLACK)
	var heads := {"pause": "PAUSED", "options": "OPTIONS", "controls": "CONTROLS", "brief": "GET READY"}
	UI.draw_header(self, size, f, heads[state], k)
	if state == "controls" or state == "brief":
		_draw_controls_page(u, f)
		return

	var items := _items()
	for i in items.size():
		var g := _geom(i)
		var ki := clampf((appear - 0.04 - i * 0.04) / 0.22, 0.0, 1.0)
		var xoff := -320.0 * (1.0 - UI.ease_out_back(ki))
		UI.draw_button(self, size, f, g[0], g[1], g[2], items[i], i == sel, t, pop_t / 0.22, xoff)

	var tip := "W / S or arrows to move    %s / NUM 1 / enter to pick    esc to go back" % Game.key_names[0]["swing"]
	if state == "options":
		tip = "left / right to change.  changes kick in straight away"
	draw_string_outline(f, UI.V(size, 0, 345) * Vector2(0, 1), tip, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(8 * u), int(3 * u), UI.BLACK)
	draw_string(f, UI.V(size, 0, 345) * Vector2(0, 1), tip, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(8 * u), Color.WHITE)


# ---------------- controls page ----------------

func _draw_controls_page(u: float, f: Font) -> void:
	# just text, the same outlined slanted font as the menus. key in yellow, what it does in white
	var e := UI.ease_out_back(clampf(appear / 0.3, 0.0, 1.0))
	var a := clampf(appear / 0.2, 0.0, 1.0)
	for i in 2:
		var fi = arena.fighters[i]
		var ch: Dictionary = Game.characters[fi.char_id]
		var x := 118.0 if i == 0 else 362.0
		var y := 112.0 + (1.0 - e) * 30.0
		var head := "p%d" % (i + 1)
		if not Game.is_human(i):
			head = "cpu"
		_say(UI.V(size, x, y), head, 30, fi.color, a)
		var hw := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * u)).x / u
		_say(UI.V(size, x + hw + 10, y), "as " + str(ch["name"]), 12, UI.YELLOW, a)
		y += 24.0
		var rows := []
		if not Game.is_human(i):
			rows = [["", "playing on " + LEVELS[Game.cpu_level]], ["", "special: " + str(ch["ability"]).to_lower()], ["", "(change it in options)"]]
		elif i == 0:
			var k: Dictionary = Game.key_names[0]
			rows = [["A D", "move"], ["W", "jump"], ["S", "fall"], [k["swing"], "swing  (hold to charge)"], [k["bunt"], "bunt"], [k["special"], "special: " + str(ch["ability"]).to_lower()]]
		else:
			rows = [["4 6", "move"], ["8", "jump"], ["5", "fall"], ["1", "swing  (hold to charge)"], ["2", "bunt"], ["3", "special: " + str(ch["ability"]).to_lower()]]
		for r in rows.size():
			var rx := x - r * 3.0  # slight staircase like the menu buttons
			if str(rows[r][0]) != "":
				_say(UI.V(size, rx, y), str(rows[r][0]), 13, UI.YELLOW, a, HORIZONTAL_ALIGNMENT_RIGHT, 34.0 * u)
			_say(UI.V(size, rx + 42, y), str(rows[r][1]), 10, Color.WHITE, a)
			y += 17.0
		if i == 1 and Game.is_human(1):
			_say(UI.V(size, x, y + 2), "numpad. arrows + K L ; work too", 7, Color(1, 1, 1, 0.6), a)
		if i == 0 and Game.mode == "cpu":
			_say(UI.V(size, x, y + 2), "arrows or the mouse work too", 7, Color(1, 1, 1, 0.6), a)

	if state == "brief":
		_draw_brief_extras(u, f, e)
		return
	var hint := "esc / %s / click to go back" % Game.key_names[0]["bunt"]
	_say(Vector2(0, UI.V(size, 0, 345).y), hint, 8, Color.WHITE, 1.0, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_brief_extras(u: float, f: Font, e: float) -> void:
	var tp := Vector2(0, UI.V(size, 0, 80).y - (1.0 - e) * 30.0 * u)
	_say(tp, "VERSUS" if Game.mode == "2p" else "VS CPU", 32, UI.YELLOW, 1.0, HORIZONTAL_ALIGNMENT_CENTER, size.x)

	# "press ENTER to start", just text, ENTER bigger and yellow, pulsing a bit
	var pulse := 1.0 + sin(t * 5.0) * 0.04
	var fs := 18.0
	var parts := [["press ", Color.WHITE, fs], ["ENTER", UI.YELLOW, fs * 1.35], [" to start", Color.WHITE, fs]]
	var total := 0.0
	for p in parts:
		total += f.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(p[2] * u)).x
	draw_set_transform(UI.V(size, 320, 296), -0.03, Vector2(pulse, pulse))
	var x := -total * 0.5
	for p in parts:
		_say(Vector2(x, 0), p[0], p[2], p[1], 1.0)
		x += f.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(p[2] * u)).x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_say(Vector2(0, UI.V(size, 0, 345).y), "(or click)      esc goes back to character select", 8, Color(1, 1, 1, 0.75), 1.0, HORIZONTAL_ALIGNMENT_CENTER, size.x)


# outlined text, same look as the menus
func _say(p: Vector2, text: String, fs: float, col: Color, a := 1.0, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	var u := size.y / 360.0
	draw_string_outline(Game.font, p, text, align, w, int(fs * u), int(maxf(3.0, fs * 0.28) * u), Color(UI.BLACK, a))
	draw_string(Game.font, p, text, align, w, int(fs * u), Color(col, a))
