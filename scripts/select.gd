extends Control
# character select, laid out like LLB's: big character art, a strip of portraits along the
# bottom, pick someone to see their bio, and once both sides are locked in the START GAME
# banner comes in.
#   2 player: p1 = A/D + F (pick) + G (back), p2 = arrows + K + L
#   vs cpu:   you pick yourself first, then the cpu's fighter, with your keys
#   mouse:    hover a portrait, click to pick, click START GAME / BACK

const FighterScript := preload("res://scripts/fighter.gd")
const UI := preload("res://scripts/ui_bg.gd")
const RANDOM := -1

const BG := Color("#3a3a3e")
const STRIPE := Color("#2c2c30")
const BAR := Color("#1e1e21")
const TILE := Color("#f7e93b")
const ORANGE := Color("#ff4b1f")

var t := 0.0
var cur := [0, 2]  # which tile each side's cursor is on (characters.size() = the random tile)
var locked := [false, false]
var lock_t := [0.0, 0.0]  # time since each side locked in (for the bio pop-in)
var picking := 0  # vs cpu only: 0 = picking your fighter, 1 = picking the cpu's
var banner_t := 0.0
var leaving := false

var portraits := {}
var svcs := []
var holders := []
var shown := [-2, -2]  # what each preview is currently showing
var swap_t := [1.0, 1.0]  # time since each preview changed (slide-in)
var tile_rects := []
var back_rect := Rect2()
var start_rect := Rect2()
var overlay: Control
var bg_tex: Texture2D  # assets/ui/select_bg.png, replaces the grey striped background


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Game.play_music("menu")
	bg_tex = Game.asset_tex("ui/select_bg")
	cur = [int(Game.p_chars[0]), int(Game.p_chars[1])]
	for i in Game.characters.size():
		var tex: Texture2D = Game.asset_tex("characters/" + str(Game.characters[i]["file"]) + "_portrait")
		if tex:
			portraits[i] = tex

	for i in 2:
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(svc)
		svcs.append(svc)
		holders.append(_make_stage(svc, i))

	# everything drawn on top of the 3d previews goes on this layer
	overlay = Control.new()
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.draw.connect(_draw_overlay)


func _n() -> int:
	return Game.characters.size()


func _all_locked() -> bool:
	return locked[0] and locked[1]


# ---------------- input ----------------

func _process(delta: float) -> void:
	t += delta
	banner_t += delta
	for i in 2:
		lock_t[i] += delta
		swap_t[i] += delta
	_layout()
	_update_previews()
	queue_redraw()
	overlay.queue_redraw()
	if leaving:
		return

	if Game.mode == "2p":
		for p in 2:
			_player_input(p, p)
	else:
		_player_input(0, picking)

	if Input.is_action_just_pressed("ui_accept"):
		_pick(0 if Game.mode == "2p" else picking)
	elif Input.is_action_just_pressed("ui_cancel"):
		_back(0 if Game.mode == "2p" else picking)


func _player_input(p: int, c: int) -> void:
	var pre := "p%d_" % p
	if not locked[c]:
		if Input.is_action_just_pressed(pre + "left"):
			_move(c, -1)
		elif Input.is_action_just_pressed(pre + "right"):
			_move(c, 1)
	if Input.is_action_just_pressed(pre + "swing"):
		_pick(c)
	elif Input.is_action_just_pressed(pre + "bunt"):
		_back(c)


func _input(event: InputEvent) -> void:
	if leaving:
		return
	var mc: int = 0 if Game.mode == "2p" else picking  # the cursor the mouse drives
	if event is InputEventMouseMotion and not locked[mc]:
		for j in tile_rects.size():
			if (tile_rects[j] as Rect2).has_point(event.position) and cur[mc] != j:
				cur[mc] = j
				Sfx.ui("select_change", _file_of(j), "tick", 1.3, -8.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if back_rect.has_point(event.position):
			_back(mc)
			return
		if _all_locked() and start_rect.has_point(event.position):
			_start()
			return
		for j in tile_rects.size():
			if (tile_rects[j] as Rect2).has_point(event.position):
				if not locked[mc]:
					cur[mc] = j
				_pick(mc)
				return


func _move(c: int, d: int) -> void:
	var n := _n() + 1
	cur[c] = (int(cur[c]) + d + n) % n
	Sfx.ui("select_change", _file_of(cur[c]), "tick", 1.3, -8.0)


func _file_of(j: int) -> String:
	return "random" if j >= _n() else str(Game.characters[j]["file"])


func _pick(c: int) -> void:
	if _all_locked():
		_start()
		return
	if locked[c]:
		return
	var j: int = cur[c]
	if j >= _n():
		j = randi() % _n()  # the ? tile
		cur[c] = j
	Game.p_chars[c] = j
	locked[c] = true
	lock_t[c] = 0.0
	Sfx.ui("select_ready", _file_of(j), "hit", 1.3, -6.0)
	if Game.mode == "cpu" and c == 0:
		picking = 1
	if _all_locked():
		banner_t = 0.0
		Sfx.ui("select_all_ready", "", "special", 1.0, -6.0)


func _back(c: int) -> void:
	if Game.mode == "cpu":
		# undo in reverse order: cpu's pick, then back to picking the cpu, then yours, then leave
		if locked[1]:
			locked[1] = false
		elif picking == 1:
			picking = 0
			locked[0] = false
		else:
			_leave()
			return
	else:
		if locked[c]:
			locked[c] = false
		elif not locked[0] and not locked[1]:
			_leave()
			return
		else:
			return
	Sfx.ui("select_unready", "", "tick", 1.0, -6.0)


func _leave() -> void:
	leaving = true
	Sfx.ui("menu_back", "select", "tick", 0.8, -8.0)
	Game.menu_start = "main"
	Game.goto("res://scenes/frontend.tscn")


func _start() -> void:
	if leaving:
		return
	leaving = true
	Sfx.ui("select_go", "", "special", 1.2, -2.0)
	Game.goto("res://scenes/match.tscn")


# ---------------- 3d previews ----------------

func _layout() -> void:
	var u := size.y / 360.0
	for i in 2:
		var svc: SubViewportContainer = svcs[i]
		var x0 := -20.0 if i == 0 else 350.0
		var e := UI.ease_out_back(clampf(float(swap_t[i]) / 0.3, 0.0, 1.0))
		var slide := (1.0 - e) * 50.0 * (-1.0 if i == 0 else 1.0)
		svc.position = UI.V(size, x0 + slide, 18)
		svc.size = Vector2(310.0 * u, 262.0 * u)
		svc.modulate.a = clampf(float(swap_t[i]) / 0.15, 0.0, 1.0)


func _update_previews() -> void:
	for i in 2:
		var want: int = int(Game.p_chars[i]) if locked[i] else int(cur[i])
		if want >= _n():
			want = RANDOM
		if want != shown[i]:
			shown[i] = want
			swap_t[i] = 0.0
			_set_preview(i, want)


func _make_stage(svc: SubViewportContainer, i: int) -> Node3D:
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)

	# close camera so the character is big, like the art in LLB's select screen
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 3.4)
	cam.rotation.x = -0.04
	cam.rotation.z = 0.05 if i == 0 else -0.05
	cam.fov = 38.0
	sv.add_child(cam)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9a9aa6")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30 if i == 0 else -30, 0)
	sv.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 2.0, -2.0)
	rim.light_color = Game.colors[i]
	rim.light_energy = 2.5
	rim.omni_range = 5.0
	sv.add_child(rim)

	var holder := Node3D.new()
	sv.add_child(holder)
	return holder


func _set_preview(i: int, c: int) -> void:
	var holder: Node3D = holders[i]
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	if c == RANDOM:
		return
	var f = FighterScript.new()
	f.preview = true
	f.id = i
	f.char_id = c
	f.color = Game.colors[i]
	f.facing = 1.0 if i == 0 else -1.0
	holder.add_child(f)


# ---------------- drawing: background (under the previews) ----------------

func _draw() -> void:
	var u := size.y / 360.0
	if bg_tex:
		UI.draw_bg(self, size, t, bg_tex, 0.0)
		return
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# dark stripes running up to the right
	var spacing := 46.0 * u
	var off := fmod(t * 6.0 * u, spacing)
	var k := -8
	while k < 30:
		var y := k * spacing + off
		var rise := size.x * 0.2
		draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(size.x, y - rise), Vector2(size.x, y - rise + 16.0 * u), Vector2(0, y + 16.0 * u)]), STRIPE)
		k += 1
	# faint little faces tiled behind everything
	var step := 62.0 * u
	var drift := fmod(t * 4.0 * u, step)
	for row in int(size.y / step) + 2:
		for colm in int(size.x / step) + 2:
			var c := Vector2(colm * step - drift + (step * 0.5 if row % 2 == 1 else 0.0), row * step - step * 0.5)
			var a := Color(1, 1, 1, 0.05)
			draw_circle(c, 17.0 * u, a)
			draw_circle(c + Vector2(-6, -3) * u, 3.5 * u, Color(BG, 0.9))
			draw_circle(c + Vector2(6, -3) * u, 3.5 * u, Color(BG, 0.9))
			draw_rect(Rect2(c + Vector2(-7, 6) * u, Vector2(14, 3) * u), Color(BG, 0.9))
	# dark strip across the top
	draw_rect(Rect2(0, 0, size.x, 26.0 * u), Color(BAR, 0.85))


# ---------------- drawing: everything on top ----------------

func _draw_overlay() -> void:
	var ci := overlay
	var u := size.y / 360.0
	var f: Font = Game.font

	_draw_name_bars(ci, u, f)
	for i in 2:
		if shown[i] == RANDOM:
			_draw_random_art(ci, u, f, i)
	for i in 2:
		if locked[i]:
			_draw_bio(ci, u, f, i)
	_draw_roster(ci, u, f)
	if _all_locked():
		_draw_banner(ci, u, f)
	_draw_hint(ci, u, f)


func _who(i: int) -> String:
	return Game.who(i)


func _draw_name_bars(ci: Control, u: float, f: Font) -> void:
	for i in 2:
		var right := i == 1
		var nm := "RANDOM"
		if shown[i] >= 0:
			nm = str(Game.characters[shown[i]]["name"])
		var col: Color = ORANGE if i == 0 else Color("#1f8bff")
		var x0 := 60.0 if not right else 460.0
		var pts := PackedVector2Array([UI.V(size, x0, 8), UI.V(size, x0 + 120, 8), UI.V(size, x0 + 116, 21), UI.V(size, x0 - 4, 21)])
		ci.draw_colored_polygon(pts, col)
		var align := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		ci.draw_string(f, UI.V(size, x0 + 6, 18.5), nm, align, 106.0 * u, int(10 * u), Color.WHITE)
		# P1 / P2 / CPU tag on the outside end of the bar
		var tag_x := x0 - 30.0 if not right else x0 + 124.0
		ci.draw_string(f, UI.V(size, tag_x, 18.5), _who(i), HORIZONTAL_ALIGNMENT_CENTER, 26.0 * u, int(9 * u), col.lightened(0.3))


func _draw_random_art(ci: Control, u: float, f: Font, i: int) -> void:
	var c := UI.V(size, 140.0 if i == 0 else 500.0, 150)
	var fs := int(170 * u)
	ci.draw_string_outline(f, c + Vector2(-60 * u, 55 * u), "?", HORIZONTAL_ALIGNMENT_CENTER, 120 * u, fs, int(14 * u), Color("#1fb5c7"))
	ci.draw_string(f, c + Vector2(-60 * u, 55 * u), "?", HORIZONTAL_ALIGNMENT_CENTER, 120 * u, fs, TILE)


func _draw_bio(ci: Control, u: float, f: Font, i: int) -> void:
	# compact card: name, special, one-line summary, then a short bio
	var ch: Dictionary = Game.characters[Game.p_chars[i]]
	var e := UI.ease_out_back(clampf(float(lock_t[i]) / 0.3, 0.0, 1.0))
	var a := clampf(float(lock_t[i]) / 0.15, 0.0, 1.0)
	var w := 136.0
	var h := 142.0
	var x0 := 178.0 if i == 0 else 326.0
	x0 += (1.0 - e) * (30.0 if i == 0 else -30.0)
	var y0 := 34.0
	var col: Color = Game.colors[i]

	var box := PackedVector2Array([UI.V(size, x0 + 6, y0), UI.V(size, x0 + w + 6, y0), UI.V(size, x0 + w, y0 + h), UI.V(size, x0, y0 + h)])
	ci.draw_colored_polygon(box, Color(0, 0, 0, 0.72 * a))
	ci.draw_line(box[0], box[1], Color(col, a), 2.5 * u)

	# READY tag in the corner
	var tag := Rect2(UI.V(size, x0 + w - 36, y0 - 8), Vector2(40, 11) * u)
	ci.draw_rect(tag, Color(col, a))
	ci.draw_string(f, tag.position + Vector2(0, 8.5 * u), "READY", HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, int(8 * u), Color(1, 1, 1, a))

	var p := UI.V(size, x0 + 9, y0 + 24)
	ci.draw_string_outline(f, p, str(ch["name"]), HORIZONTAL_ALIGNMENT_LEFT, (w - 12) * u, int(19 * u), int(5 * u), Color(0, 0, 0, a))
	ci.draw_string(f, p, str(ch["name"]), HORIZONTAL_ALIGNMENT_LEFT, (w - 12) * u, int(19 * u), Color(TILE, a))

	ci.draw_string(f, UI.V(size, x0 + 9, y0 + 40), "SPECIAL", HORIZONTAL_ALIGNMENT_LEFT, -1, int(7 * u), Color(TILE, a))
	ci.draw_string(f, UI.V(size, x0 + 45, y0 + 40), str(ch["ability"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color(col.lightened(0.25), a))
	ci.draw_multiline_string(f, UI.V(size, x0 + 9, y0 + 54), str(ch["desc"]), HORIZONTAL_ALIGNMENT_LEFT, (w - 16) * u, int(8 * u), 2, Color(1, 1, 1, a))
	ci.draw_line(UI.V(size, x0 + 8, y0 + 72), UI.V(size, x0 + w - 8, y0 + 72), Color(1, 1, 1, 0.2 * a), 1.0)
	ci.draw_multiline_string(f, UI.V(size, x0 + 9, y0 + 84), str(ch.get("bio", "")), HORIZONTAL_ALIGNMENT_LEFT, (w - 16) * u, int(6.5 * u), 6, Color(1, 1, 1, 0.7 * a))


func _draw_roster(ci: Control, u: float, f: Font) -> void:
	# bar along the bottom with the portraits in it
	var top := UI.V(size, 0, 272).y
	var low := UI.V(size, 0, 332).y
	ci.draw_rect(Rect2(0, top, size.x, low - top), BAR)
	ci.draw_line(Vector2(0, top), Vector2(size.x, top), Color("#4c4c52"), 2.0 * u)
	ci.draw_rect(Rect2(0, low, size.x, size.y - low), Color("#0d0d0f"))

	var n := _n() + 1
	var tw := 32.0
	var th := 52.0
	var sl := 8.0
	var gap := 3.0
	var total := n * (tw + gap) - gap + sl
	var x := 320.0 - total * 0.5
	var y := 276.0
	tile_rects.clear()
	for j in n:
		var pts := PackedVector2Array([UI.V(size, x + sl, y), UI.V(size, x + sl + tw, y), UI.V(size, x + tw, y + th), UI.V(size, x, y + th)])
		var bb := Rect2(UI.V(size, x, y), UI.V(size, x + sl + tw, y + th) - UI.V(size, x, y))
		tile_rects.append(bb)
		if j < _n():
			ci.draw_colored_polygon(pts, TILE)
			if portraits.has(j):
				# crop the square portrait into the tall slanted tile
				var span := bb.size.x / bb.size.y
				var uvs := PackedVector2Array()
				for pt in pts:
					uvs.append(Vector2(0.5 - span * 0.5 + (pt.x - bb.position.x) / bb.size.x * span, (pt.y - bb.position.y) / bb.size.y))
				ci.draw_colored_polygon(pts, Color.WHITE, uvs, portraits[j])
			else:
				ci.draw_string(f, Vector2(bb.position.x, bb.end.y - 14 * u), str(Game.characters[j]["name"]).substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, bb.size.x, int(26 * u), Color.BLACK)
		else:
			ci.draw_colored_polygon(pts, Color("#151517"))
			ci.draw_string(f, Vector2(bb.position.x, bb.end.y - 13 * u), "?", HORIZONTAL_ALIGNMENT_CENTER, bb.size.x, int(30 * u), TILE)
		ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.9), 1.5 * u)
		x += tw + gap

	# cursors: thick outline in the player's colour plus a tag above the tile
	for i in 2:
		var j: int = int(Game.p_chars[i]) if locked[i] else int(cur[i])
		if j >= tile_rects.size():
			continue
		var bb: Rect2 = tile_rects[j]
		var pulse := 0.5 + 0.5 * sin(t * 8.0)
		var col: Color = Game.colors[i]
		var outline_w := (3.0 if locked[i] else 2.0 + pulse * 1.5) * u
		var o := PackedVector2Array([
			Vector2(bb.position.x + sl * u, bb.position.y), Vector2(bb.end.x, bb.position.y),
			Vector2(bb.end.x - sl * u, bb.end.y), Vector2(bb.position.x, bb.end.y), Vector2(bb.position.x + sl * u, bb.position.y)])
		ci.draw_polyline(o, col, outline_w)
		var both_here := (int(Game.p_chars[1 - i]) if locked[1 - i] else int(cur[1 - i])) == j
		var tag_x := bb.position.x + bb.size.x * (0.0 if (i == 0 or not both_here) else 0.5)
		if both_here and i == 0:
			tag_x = bb.position.x - bb.size.x * 0.2
		var tag_w := bb.size.x * (0.7 if both_here else 1.0)
		var ty := bb.position.y - 4.0 * u - pulse * 2.0 * u * (0.0 if locked[i] else 1.0)
		ci.draw_rect(Rect2(tag_x, ty - 11.0 * u, tag_w, 11.0 * u), col)
		ci.draw_string(f, Vector2(tag_x, ty - 2.5 * u), _who(i), HORIZONTAL_ALIGNMENT_CENTER, tag_w, int(8 * u), Color.WHITE)

	# right hand side: stripes, mode label, BACK
	for s in 4:
		var sx := 548.0 + s * 4.0
		ci.draw_line(UI.V(size, sx + 4, 276), UI.V(size, sx, 330), Color("#8a8a90"), 1.2 * u)
	ci.draw_string(f, UI.V(size, 570, 305), "versus" if Game.mode == "2p" else "vs cpu", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color("#d8d8de"))
	var bp := UI.V(size, 575, 352)
	ci.draw_string(f, bp, "BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), Color.WHITE)
	back_rect = Rect2(bp + Vector2(0, -14 * u), Vector2(50 * u, 18 * u))


func _draw_banner(ci: Control, u: float, f: Font) -> void:
	var e := UI.ease_out_back(clampf(banner_t / 0.35, 0.0, 1.0))
	var slide := (1.0 - e) * size.x
	var yc := UI.V(size, 0, 238).y
	var h := 24.0 * u
	ci.draw_set_transform(Vector2(slide, 0), 0.0, Vector2.ONE)

	# hazard stripes top and bottom, black band with scrolling text between
	for edge in [yc - h * 0.5 - 5.0 * u, yc + h * 0.5]:
		ci.draw_rect(Rect2(-size.x, edge, size.x * 3.0, 5.0 * u), Color("#e01818"))
		var sx := -size.x + fmod(t * 60.0 * u, 16.0 * u)
		while sx < size.x * 2.0:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, edge), Vector2(sx + 8 * u, edge), Vector2(sx + 13 * u, edge + 5 * u), Vector2(sx + 5 * u, edge + 5 * u)]), Color.BLACK)
			sx += 16.0 * u
	ci.draw_rect(Rect2(-size.x, yc - h * 0.5, size.x * 3.0, h), Color(0, 0, 0, 0.92))
	var tx := -fmod(t * 50.0 * u, 120.0 * u)
	while tx < size.x:
		ci.draw_string(f, Vector2(tx, yc + 4.0 * u), "READY TO START", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), TILE)
		tx += 120.0 * u

	# the button itself, a hexagon in the middle
	var pulse := 1.0 + sin(t * 6.0) * 0.03
	var c := Vector2(size.x * 0.5, yc)
	var hw := 82.0 * u * pulse
	var hh := 17.0 * u * pulse
	var hex := PackedVector2Array([c + Vector2(-hw + 14 * u, -hh), c + Vector2(hw - 14 * u, -hh), c + Vector2(hw, 0), c + Vector2(hw - 14 * u, hh), c + Vector2(-hw + 14 * u, hh), c + Vector2(-hw, 0)])
	ci.draw_colored_polygon(hex, Color.BLACK)
	ci.draw_polyline(hex + PackedVector2Array([hex[0]]), TILE, 3.0 * u)
	ci.draw_string(f, c + Vector2(-hw, 7 * u), "START GAME", HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(19 * u), Color.WHITE)
	start_rect = Rect2(c - Vector2(hw, hh), Vector2(hw, hh) * 2.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hint(ci: Control, u: float, f: Font) -> void:
	var k0: Dictionary = Game.key_names[0]
	var k1: Dictionary = Game.key_names[1]
	var txt := ""
	if _all_locked():
		txt = "press %s / click START GAME to fight     %s to go back" % [k0["swing"], k0["bunt"]]
	elif Game.mode == "cpu":
		txt = ("pick your fighter" if picking == 0 else "now pick the CPU's fighter") + "     A / D move   %s pick   %s back" % [k0["swing"], k0["bunt"]]
	else:
		txt = "P1:  A / D   %s pick   %s back          P2:  numpad 4 / 6   %s pick   %s back" % [k0["swing"], k0["bunt"], k1["swing"], k1["bunt"]]
	var p := Vector2(14.0 * u, UI.V(size, 0, 350).y)
	ci.draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * u), int(3 * u), Color.BLACK)
	ci.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * u), Color.WHITE)
