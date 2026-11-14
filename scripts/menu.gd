extends Control
# character select. pick a mode, pick your guy, press swing to ready up

const FighterScript := preload("res://scripts/fighter.gd")

var cards := []
var is_ready_p := [false, false]
var start_timer := -1.0
var t := 0.0

var btn_cpu: Button
var btn_2p: Button
var diff_row: HBoxContainer
var diff_btns := []
var prompt: Label


func _ready() -> void:
	theme = _make_theme()
	resized.connect(queue_redraw)

	var col := VBoxContainer.new()
	add_child(col)
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.offset_left = 36
	col.offset_right = -36
	col.offset_top = 14
	col.offset_bottom = -14
	col.add_theme_constant_override("separation", 8)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	var title := _label("HYPER ATTACK", 60, Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color("#f2c230"))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color("#0d3b3a"))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(title)

	var modes := VBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	top.add_child(modes)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	modes.add_child(mode_row)
	btn_cpu = _button("VS CPU", func(): _set_mode("cpu"), 22)
	btn_2p = _button("2 PLAYER", func(): _set_mode("2p"), 22)
	btn_cpu.custom_minimum_size = Vector2(170, 44)
	btn_2p.custom_minimum_size = Vector2(170, 44)
	mode_row.add_child(btn_cpu)
	mode_row.add_child(btn_2p)
	diff_row = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 6)
	diff_row.alignment = BoxContainer.ALIGNMENT_END
	modes.add_child(diff_row)
	var levels := ["EASY", "NORMAL", "HARD"]
	for n in 3:
		var b := _button(levels[n], func(): _set_level(n), 15)
		b.custom_minimum_size = Vector2(90, 30)
		diff_row.add_child(b)
		diff_btns.append(b)

	var row := HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 30)
	col.add_child(row)
	row.add_child(_make_side(0))
	row.add_child(_make_side(1))

	prompt = _label("", 22, Color.WHITE)
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.add_theme_color_override("font_outline_color", Game.INK)
	col.add_child(prompt)

	_set_mode(Game.mode)
	_set_level(Game.cpu_level)
	for i in 2:
		_set_preview(i)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b2423"))
	var c0: Color = Game.colors[0]
	var c1: Color = Game.colors[1]
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.56, 0), Vector2(w * 0.44, h), Vector2(0, h)]), c0.darkened(0.62).lerp(Color("#0b2423"), 0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.56, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.44, h)]), c1.darkened(0.62).lerp(Color("#0b2423"), 0.35))
	# panel seams like the stage walls
	for i in 12:
		var x := i * 120.0
		draw_line(Vector2(x, 0), Vector2(x, h), Color(0, 0, 0, 0.18), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.55, 0), Vector2(w * 0.57, 0), Vector2(w * 0.45, h), Vector2(w * 0.43, h)]), Color("#06100f"))
	# hazard tape top and bottom
	for band_y in [0.0, h - 14.0]:
		draw_rect(Rect2(0, band_y, w, 14), Color("#f2c230"))
		var x := -20.0 + fmod(t * 30.0, 28.0)
		while x < w:
			draw_colored_polygon(PackedVector2Array([Vector2(x, band_y), Vector2(x + 14, band_y), Vector2(x + 28, band_y + 14), Vector2(x + 14, band_y + 14)]), Color("#1c1a14"))
			x += 28.0
	var f: Font = Game.font
	draw_string_outline(f, Vector2(w * 0.5 - 70, h * 0.56), "VS", HORIZONTAL_ALIGNMENT_CENTER, 140, 96, 18, Color("#0d3b3a"))
	draw_string(f, Vector2(w * 0.5 - 70, h * 0.56), "VS", HORIZONTAL_ALIGNMENT_CENTER, 140, 96, Color("#f2c230"))


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	prompt.modulate.a = 0.55 + 0.45 * sin(t * 5.0)

	if start_timer >= 0.0:
		start_timer -= delta
		if start_timer < 0.0:
			get_tree().change_scene_to_file("res://scenes/match.tscn")
		return

	for i in 2:
		if not Game.is_human(i):
			continue
		var p := "p%d_" % i
		if not is_ready_p[i]:
			if Input.is_action_just_pressed(p + "left"):
				_cycle_char(i, -1)
			elif Input.is_action_just_pressed(p + "right"):
				_cycle_char(i, 1)
		if Input.is_action_just_pressed(p + "swing"):
			is_ready_p[i] = not is_ready_p[i]
			Sfx.play("hit" if is_ready_p[i] else "tick", 1.3, -6.0)
			_refresh()
	if Input.is_action_just_pressed("ui_accept"):
		_go()

	var all_ready := true
	for i in 2:
		if Game.is_human(i) and not is_ready_p[i]:
			all_ready = false
	if all_ready:
		_go()


func _go() -> void:
	if start_timer >= 0.0:
		return
	start_timer = 0.6
	Sfx.play("special", 1.2, -2.0)
	prompt.text = "LET'S GO"


# ---------------- one side of the screen ----------------

func _make_side(i: int) -> Control:
	var c: Color = Game.colors[i]
	var right := i == 1
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)

	var who := _label("", 34, c)
	who.add_theme_constant_override("outline_size", 10)
	who.add_theme_color_override("font_outline_color", Game.INK)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(who)

	# 3d preview with a READY stamp over the top
	var stack := MarginContainer.new()
	stack.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(stack)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(260, 220)
	stack.add_child(svc)
	var holder := _make_stage(svc, c)
	var stamp := _label("READY", 80, Color("#7dff8a"))
	stamp.add_theme_constant_override("outline_size", 18)
	stamp.add_theme_color_override("font_outline_color", Game.INK)
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(stamp)

	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", 10)
	v.add_child(pick)
	var prev_b := _button("<", func(): _cycle_char(i, -1), 26)
	prev_b.custom_minimum_size = Vector2(50, 50)
	var name_l := _label("", 54, Color.WHITE)
	name_l.add_theme_constant_override("outline_size", 12)
	name_l.add_theme_color_override("font_outline_color", Game.INK)
	name_l.size_flags_horizontal = SIZE_EXPAND_FILL
	var next_b := _button(">", func(): _cycle_char(i, 1), 26)
	next_b.custom_minimum_size = Vector2(50, 50)
	pick.add_child(prev_b)
	pick.add_child(name_l)
	pick.add_child(next_b)

	var ability := _label("", 24, c)
	ability.add_theme_constant_override("outline_size", 8)
	ability.add_theme_color_override("font_outline_color", Game.INK)
	v.add_child(ability)
	var desc := _label("", 17, Color(1, 1, 1, 0.85))
	v.add_child(desc)

	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 6)
	keys.custom_minimum_size.y = 36
	v.add_child(keys)

	cards.append({"who": who, "stamp": stamp, "holder": holder, "name": name_l, "ability": ability, "desc": desc, "keys": keys})
	return v


func _keycap(parent: Control, key: String, what: String) -> void:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(5)
	sb.border_color = Color(0.7, 0.7, 0.75)
	sb.border_width_bottom = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 3
	cap.add_theme_stylebox_override("panel", sb)
	var kl := _label(key, 16, Game.INK)
	cap.add_child(kl)
	cap.size_flags_vertical = SIZE_SHRINK_CENTER
	parent.add_child(cap)
	var wl := _label(what, 14, Color(1, 1, 1, 0.75))
	parent.add_child(wl)
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	parent.add_child(gap)


func _make_stage(svc: SubViewportContainer, c: Color) -> Node3D:
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 4.0)
	cam.rotation.x = -0.06
	cam.fov = 38.0
	sv.add_child(cam)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7a5cc4")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_color = Color("#fff1d6")
	sv.add_child(sun)

	# spotlight disc on the floor
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.02
	var d := MeshInstance3D.new()
	d.mesh = disc
	d.material_override = Game.flat(c.darkened(0.3))
	sv.add_child(d)

	var holder := Node3D.new()
	sv.add_child(holder)
	return holder


func _set_preview(i: int) -> void:
	var holder: Node3D = cards[i]["holder"]
	for child in holder.get_children():
		child.queue_free()
	var f = FighterScript.new()
	f.preview = true
	f.id = i
	f.char_id = Game.p_chars[i]
	f.color = Game.colors[i]
	f.facing = 1.0 if i == 0 else -1.0
	holder.add_child(f)


# ---------------- state ----------------

func _refresh() -> void:
	for i in 2:
		var card: Dictionary = cards[i]
		var ch: Dictionary = Game.characters[Game.p_chars[i]]
		var human: bool = Game.is_human(i)
		card["who"].text = Game.who(i)
		card["name"].text = ch["name"]
		card["ability"].text = ch["ability"]
		card["desc"].text = ch["desc"]
		card["stamp"].visible = is_ready_p[i] and human

		var keys: HBoxContainer = card["keys"]
		for k in keys.get_children():
			keys.remove_child(k)
			k.queue_free()
		if human:
			var kn: Dictionary = Game.key_names[i]
			_keycap(keys, "A D" if i == 0 else "< >", "move")
			_keycap(keys, kn["jump"], "jump")
			_keycap(keys, kn["swing"], "swing")
			_keycap(keys, kn["bunt"], "bunt")
			_keycap(keys, kn["special"], "special")
		else:
			keys.add_child(_label("CPU - click < > to pick its fighter", 15, Color(1, 1, 1, 0.6)))

	_style_button(btn_cpu, Game.mode == "cpu")
	_style_button(btn_2p, Game.mode == "2p")
	diff_row.modulate.a = 1.0 if Game.mode == "cpu" else 0.0
	for n in 3:
		_style_button(diff_btns[n], Game.cpu_level == n)

	if Game.mode == "cpu":
		prompt.text = "PRESS  F  WHEN YOU'RE READY"
	else:
		prompt.text = "PRESS SWING TO READY UP   ( F  /  K )"


func _set_mode(m: String) -> void:
	Game.mode = m
	is_ready_p = [false, false]
	Sfx.play("tick", 1.0, -6.0)
	_refresh()


func _set_level(n: int) -> void:
	Game.cpu_level = n
	Sfx.play("tick", 1.2, -6.0)
	_refresh()


func _cycle_char(i: int, d: int) -> void:
	if is_ready_p[i] or start_timer >= 0.0:
		return
	var n: int = Game.characters.size()
	Game.p_chars[i] = (int(Game.p_chars[i]) + d + n) % n
	Sfx.play("tick", 1.3, -6.0)
	_set_preview(i)
	_refresh()


# ---------------- ui helpers ----------------

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = Game.font
	th.default_font_size = 18
	return th


func _label(text: String, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, cb: Callable, fsize := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = FOCUS_NONE
	b.add_theme_font_size_override("font_size", fsize)
	b.pressed.connect(cb)
	_style_button(b, false)
	return b


func _style_button(b: Button, on: bool) -> void:
	var yellow := Color("#ffd447")
	var normal := StyleBoxFlat.new()
	normal.skew = Vector2(0.25, 0.0)  # slanted buttons
	normal.set_content_margin_all(8)
	normal.border_color = yellow if on else Color(1, 1, 1, 0.25)
	normal.set_border_width_all(3)
	normal.bg_color = yellow if on else Color(Game.INK, 0.85)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = yellow
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = yellow.darkened(0.2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	var fc := Game.INK if on else Color.WHITE
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", Game.INK)
