extends Control
# end of match screen. winner big on the left with a 3d render, runner-up on the right,
# a few stats each, then rematch / change fighters / main menu.
# in versus it says "PLAYER 1 WINS" etc. against the cpu it's "YOU WIN!" or "CPU WINS".

const FighterScript := preload("res://scripts/fighter.gd")
const UI := preload("res://scripts/ui_bg.gd")

var arena = null
var shown := false
var t := 0.0
var appear := 0.0
var sel := 0
var prev_sel := 0
var pop_t := 0.0
var winner = null  # fighter node, or null for a draw
var loser = null
var svcs := []
var overlay: Control
var button_rects := []
var leaving := false

const BUTTONS := ["rematch", "change fighters", "main menu"]


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE


func show_results(win, lose) -> void:
	winner = win
	loser = lose
	shown = true
	visible = true
	appear = 0.0
	mouse_filter = MOUSE_FILTER_STOP
	Sfx.ui("results", "", "special", 0.9, -6.0)

	# order on screen: winner first (left, big), then the other one
	var order := [win, lose] if win else [arena.fighters[0], arena.fighters[1]]
	for i in 2:
		var f = order[i]
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(svc)
		svcs.append(svc)
		var holder := _make_stage(svc, f.color, i == 0 and win != null)
		var p = FighterScript.new()
		p.preview = true
		p.id = f.id
		p.char_id = f.char_id
		p.color = f.color
		p.facing = 1.0 if i == 0 else -1.0
		holder.add_child(p)

	overlay = Control.new()
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.draw.connect(_draw_overlay)


func _title() -> String:
	if winner == null:
		return "DRAW!"
	if Game.mode == "cpu":
		return "YOU WIN!" if winner.id == 0 else "CPU WINS"
	return "PLAYER %d WINS" % (winner.id + 1)


# ---------------- input ----------------

func _pressed(names: Array) -> bool:
	for n in names:
		if Input.is_action_just_pressed(n):
			return true
	return false


func _process(delta: float) -> void:
	if not shown:
		return
	t += delta
	appear += delta
	pop_t += delta
	if sel != prev_sel:
		prev_sel = sel
		pop_t = 0.0
	_layout()
	queue_redraw()
	overlay.queue_redraw()
	if leaving or appear < 0.6:
		return  # don't let a button mash from the match skip straight past it

	if _pressed(["ui_left", "p0_left", "p1_left"]):
		sel = (sel + 2) % 3
		Sfx.ui("menu_move", "", "tick", 1.3, -8.0)
	elif _pressed(["ui_right", "p0_right", "p1_right"]):
		sel = (sel + 1) % 3
		Sfx.ui("menu_move", "", "tick", 1.3, -8.0)
	if _pressed(["ui_accept", "p0_swing", "p1_swing"]):
		_pick()

	var m := get_local_mouse_position()
	for i in button_rects.size():
		if (button_rects[i] as Rect2).has_point(m) and sel != i:
			sel = i
			Sfx.ui("menu_hover", "", "tick", 1.4, -10.0)


func _gui_input(event: InputEvent) -> void:
	if not shown or leaving or appear < 0.6:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in button_rects.size():
			if (button_rects[i] as Rect2).has_point(event.position):
				sel = i
				_pick()
				return


func _pick() -> void:
	leaving = true
	Sfx.ui("menu_select", BUTTONS[sel].replace(" ", "_"), "hit", 1.5, -10.0)
	match sel:
		0:
			Game.goto("res://scenes/match.tscn")
		1:
			Game.goto("res://scenes/select.tscn")
		2:
			Game.menu_start = "main"
			Game.goto("res://scenes/frontend.tscn")


# ---------------- 3d renders ----------------

func _render_rect(i: int) -> Array:
	# [x, y, w, h] on the 640x360 grid. no boxes, the characters just stand there
	if i == 0:
		return [0.0, 62.0, 290.0, 290.0]
	return [300.0, 228.0, 100.0, 108.0]


func _layout() -> void:
	var u := size.y / 360.0
	for i in svcs.size():
		var r := _render_rect(i)
		var e := UI.ease_out_back(clampf((appear - 0.1 - i * 0.15) / 0.35, 0.0, 1.0))
		var svc: SubViewportContainer = svcs[i]
		var slide := (1.0 - e) * (-120.0 if i == 0 else 80.0) * u
		svc.position = UI.V(size, r[0], r[1]) + Vector2(slide, 0)
		svc.size = Vector2(r[2] * u, r[3] * u)
		var a := clampf((appear - 0.1 - i * 0.15) / 0.2, 0.0, 1.0)
		svc.modulate = Color(1, 1, 1, a) if (i == 0 or winner == null) else Color(0.55, 0.55, 0.6, a)


func _make_stage(svc: SubViewportContainer, col: Color, is_winner: bool) -> Node3D:
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.3 if is_winner else 3.6)
	cam.fov = 36.0
	sv.add_child(cam)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9a9aa6")
	env.ambient_light_energy = 0.7 if is_winner else 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	sun.light_energy = 1.1 if is_winner else 0.6
	sv.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 2.0, -2.0)
	rim.light_color = col
	rim.light_energy = 2.5
	rim.omni_range = 5.0
	sv.add_child(rim)
	var holder := Node3D.new()
	sv.add_child(holder)
	return holder


# ---------------- drawing ----------------

func _draw() -> void:
	if not shown:
		return
	UI.draw_bg(self, size, t, null, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.15))


func _fighter_for(i: int):
	if winner:
		return winner if i == 0 else loser
	return arena.fighters[i]


func _who(fi) -> String:
	if not Game.is_human(fi.id):
		return "cpu"
	if Game.mode == "cpu":
		return "you"
	return "player %d" % (fi.id + 1)


# outlined text, same look as the menus
func _say(ci: Control, p: Vector2, text: String, fs: float, col: Color, a := 1.0, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	var u := size.y / 360.0
	ci.draw_string_outline(Game.font, p, text, align, w, int(fs * u), int(maxf(3.0, fs * 0.28) * u), Color(UI.BLACK, a))
	ci.draw_string(Game.font, p, text, align, w, int(fs * u), Color(col, a))


func _draw_overlay() -> void:
	var ci := overlay
	var u := size.y / 360.0
	var f: Font = Game.font

	# big title, slammed in and tilted like the menu stuff
	var title := _title()
	var tcol: Color = UI.YELLOW
	if winner:
		tcol = winner.color.lightened(0.1)
	var pop := 1.0 + maxf(0.0, 0.2 - appear) * 3.0
	ci.draw_set_transform(UI.V(size, 34, 56), -0.05, Vector2(pop, pop))
	ci.draw_string_outline(f, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * u), int(11 * u), UI.BLACK)
	ci.draw_string(f, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * u), tcol)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var a := clampf((appear - 0.35) / 0.25, 0.0, 1.0)
	var secs := int(arena.elapsed)

	# winner: name under the title, stats down the side of them as big numbers
	var w = _fighter_for(0)
	var wch: Dictionary = Game.characters[w.char_id]
	_say(ci, UI.V(size, 44, 80), str(wch["name"]) + "  -  " + _who(w), 13, Color.WHITE, a)
	var st: Dictionary = arena.stats[w.id]
	var rows := [
		[str(st["kos"]), "K.O.s"],
		[str(maxi(w.stocks, 0)), "lives left"],
		[str(st["hits"]), "hits"],
		[str(int(st["peak"])), "fastest hit"],
	]
	if st["charged"] > 0:
		rows.append([str(st["charged"]), "charged hits"])
	var y := 120.0
	for i in rows.size():
		var ra := clampf((appear - 0.45 - i * 0.07) / 0.2, 0.0, 1.0)
		var x := 236.0 - i * 4.0  # slight staircase, like the menu buttons
		_say(ci, UI.V(size, x, y), rows[i][0], 22, UI.YELLOW, ra, HORIZONTAL_ALIGNMENT_RIGHT, 40.0 * u)
		_say(ci, UI.V(size, x + 46, y), rows[i][1], 11, Color.WHITE, ra)
		y += 22.0
	_say(ci, UI.V(size, 214, y + 2), "match time %d:%02d" % [secs / 60, secs % 60], 8, Color(1, 1, 1, 0.8), a)

	# runner-up: small, greyed, one line of stats
	if winner:
		var l = _fighter_for(1)
		var lch: Dictionary = Game.characters[l.char_id]
		var lst: Dictionary = arena.stats[l.id]
		var la := clampf((appear - 0.6) / 0.25, 0.0, 1.0)
		_say(ci, UI.V(size, 306, 236), "runner-up", 9, Color(1, 1, 1, 0.7), la)
		_say(ci, UI.V(size, 300, 344), str(lch["name"]) + "  -  " + _who(l), 9, Color(1, 1, 1, 0.8), la)
		_say(ci, UI.V(size, 298, 355), "%d K.O.s   %d hits" % [lst["kos"], lst["hits"]], 7, Color(1, 1, 1, 0.6), la)

	# buttons: same staircase as the main menu, over on the right
	button_rects.clear()
	for i in 3:
		var left := 440.0 - i * 11.0
		var right := 605.0 - i * 5.0
		var top := 182.0 + i * 45.0
		var ki := clampf((appear - 0.55 - i * 0.06) / 0.28, 0.0, 1.0)
		var xoff := 300.0 * (1.0 - UI.ease_out_back(ki))
		UI.draw_button(ci, size, f, left, right, top, BUTTONS[i], i == sel, t, pop_t / 0.22, xoff)
		var a2 := UI.V(size, left, top)
		var b2 := UI.V(size, right + 9.0, top + 37.0)
		button_rects.append(Rect2(a2, b2 - a2))
