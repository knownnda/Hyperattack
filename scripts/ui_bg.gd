extends RefCounted
# shared menu drawing in the LLB style: yellow, black band, girder tower, slanted buttons.
# everything is laid out on a 640x360 grid and scaled, same as the hud.
# if you add assets/ui/title_bg.png / menu_bg.png they get drawn instead of the placeholder

const YELLOW := Color("#f7ec3b")
const BLACK := Color("#0a0a0a")
const CYAN := Color("#2ee6ff")


static func V(size: Vector2, x: float, y: float) -> Vector2:
	var u := size.y / 360.0
	return Vector2(size.x * 0.5 + (x - 320.0) * u, y * u)


# k = 0 is the title look (straight band in the middle), k = 1 is the menu look
# (band slid over to the left and tilted, speaker grill showing). anything in between
# is the slide from one to the other
static func draw_bg(ci: CanvasItem, size: Vector2, t: float, tex: Texture2D, k: float) -> void:
	if tex:
		var ts := tex.get_size()
		var sc := maxf(size.x / ts.x, size.y / ts.y)
		var ds := ts * sc
		ci.draw_texture_rect(tex, Rect2((size - ds) * 0.5, ds), false)
		return

	var u := size.y / 360.0
	ci.draw_rect(Rect2(Vector2.ZERO, size), YELLOW)

	# speaker grill down the left, fades in as the band moves out of the way
	if k > 0.01:
		var right_edge := V(size, 120, 0).x
		var row := 0
		while row * 45.0 * u < size.y:
			var y0 := row * 45.0 * u + 4.0 * u
			var x := 3.0 * u
			var i := 0
			while x < right_edge:
				var h := (28.0 + 9.0 * sin(i * 0.9 + row * 1.7 + t * 1.5)) * u * clampf(k * 1.4 - 0.4, 0.0, 1.0)
				ci.draw_rect(Rect2(Vector2(x, y0 + (37.0 * u - h) * 0.5), Vector2(3.0 * u, h)), Color(BLACK, 0.85))
				x += 7.0 * u
				i += 1
			row += 1

	# girder tower on the right
	var cols := [395.0, 465.0, 540.0, 615.0]
	var th := 7.0 * u
	for cx in cols:
		ci.draw_line(V(size, cx, 0), V(size, cx - 6.0, 360), BLACK, th)
	var yy := 18.0
	while yy < 360.0:
		ci.draw_line(V(size, cols[0], yy), V(size, cols[3] + 40.0, yy), BLACK, th * 0.6)
		yy += 46.0
	for c in cols.size() - 1:
		var bay := 18.0
		while bay < 340.0:
			var a: float = cols[c]
			var b: float = cols[c + 1]
			ci.draw_line(V(size, a, bay), V(size, b, bay + 46.0), BLACK, th * 0.4)
			ci.draw_line(V(size, b, bay), V(size, a, bay + 46.0), BLACK, th * 0.4)
			bay += 46.0
	ci.draw_colored_polygon(PackedVector2Array([V(size, 300, 0), V(size, 345, 0), V(size, 330, 360), V(size, 285, 360)]), BLACK)

	# the big black band: straight in the middle on the title, slanted on the left in the menu
	var from := [Vector2(255, 0), Vector2(385, 0), Vector2(385, 360), Vector2(255, 360)]
	var to := [Vector2(250, 0), Vector2(300, 0), Vector2(170, 360), Vector2(120, 360)]
	var band := PackedVector2Array()
	for i in 4:
		var p: Vector2 = (from[i] as Vector2).lerp(to[i], k)
		band.append(V(size, p.x, p.y))
	ci.draw_colored_polygon(band, BLACK)


static func ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


# slanted menu button.
# sel = selected: white, wobbling, with a colour-shifting shadow behind it.
# pop = 0..1 how far into the "just got selected" pop it is, xoff slides it sideways (for fly-ins)
static func draw_button(ci: CanvasItem, size: Vector2, font: Font, left: float, right: float, top: float, label: String, sel: bool, t := 0.0, pop := 1.0, xoff := 0.0) -> void:
	var u := size.y / 360.0
	var h := 37.0
	var s := 9.0
	left += xoff
	right += xoff
	var center := V(size, (left + right) * 0.5 + s * 0.5, top + h * 0.5)

	# draw around the centre so the selected one can tilt and scale
	var ang := 0.0
	var sc := 1.0
	if sel:
		var e := ease_out_back(clampf(pop, 0.0, 1.0))
		sc = lerpf(0.82, 1.06, e) + sin(t * 3.1) * 0.012
		ang = lerpf(-0.12, -0.035, e) + sin(t * 2.3) * 0.018
	ci.draw_set_transform(center, ang, Vector2(sc, sc))

	var hw := (right - left) * 0.5 * u
	var hh := h * 0.5 * u
	var ss := s * u
	var body := PackedVector2Array([Vector2(-hw + ss * 0.5, -hh), Vector2(hw + ss * 0.5, -hh), Vector2(hw - ss * 0.5, hh), Vector2(-hw - ss * 0.5, hh)])

	if sel:
		# shadow shape behind, a bit bigger, drifting and shifting cyan <-> pink
		var under := PackedVector2Array()
		var drift := Vector2(4.0 + sin(t * 2.7) * 2.0, 4.0 + cos(t * 2.1) * 1.5) * u
		for i in 4:
			var wob := Vector2(sin(t * 5.0 + i * 1.9), cos(t * 4.3 + i * 2.6)) * 1.6 * u
			under.append(body[i] * 1.06 + drift + wob)
		var shade := CYAN.lerp(Color("#ff2e9a"), 0.5 + 0.5 * sin(t * 1.8))
		ci.draw_colored_polygon(under, shade)
		# main white plate, corners wobble a little so it feels alive
		var plate := PackedVector2Array()
		for i in 4:
			plate.append(body[i] + Vector2(sin(t * 6.1 + i * 1.3), cos(t * 5.2 + i * 2.1)) * 1.1 * u)
		ci.draw_colored_polygon(plate, Color.WHITE)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(hw + ss * 0.5 + 3 * u, -hh), Vector2(hw + ss * 0.5 + 10 * u, -hh), Vector2(hw - ss * 0.5 + 10 * u, hh), Vector2(hw - ss * 0.5 + 3 * u, hh)]), CYAN)
	else:
		ci.draw_colored_polygon(body, BLACK)
		ci.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), Color(1, 1, 1, 0.9), 1.5 * u)
		for off in [4.0, 9.0]:
			var o: float = off * u
			ci.draw_colored_polygon(PackedVector2Array([Vector2(hw + ss * 0.5 + o, -hh), Vector2(hw + ss * 0.5 + o + 2.5 * u, -hh), Vector2(hw - ss * 0.5 + o + 2.5 * u, hh), Vector2(hw - ss * 0.5 + o, hh)]), Color.WHITE)

	var fs := int(19.0 * u)
	var tp := Vector2(-hw, 6.5 * u)
	if sel:
		ci.draw_string_outline(font, tp, label, HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, fs, int(3 * u), Color(BLACK, 0.15))
	ci.draw_string(font, tp, label, HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, fs, BLACK if sel else Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_header(ci: CanvasItem, size: Vector2, font: Font, text: String, drop := 1.0) -> void:
	var u := size.y / 360.0
	ci.draw_set_transform(Vector2(0, -32.0 * u * (1.0 - drop)), 0.0, Vector2.ONE)
	ci.draw_colored_polygon(PackedVector2Array([V(size, 290, 0), Vector2(size.x, 0), Vector2(size.x, V(size, 0, 28).y), V(size, 282, 28)]), BLACK)
	ci.draw_string(font, V(size, 300, 20), text, HORIZONTAL_ALIGNMENT_CENTER, 150.0 * u, int(13.0 * u), Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_back_arrow(ci: CanvasItem, size: Vector2) -> Rect2:
	var u := size.y / 360.0
	var c := V(size, 605, 345)
	ci.draw_arc(c + Vector2(0, -2.0 * u), 6.0 * u, -PI * 0.5, PI * 0.5, 12, Color.WHITE, 2.0 * u)
	ci.draw_line(c + Vector2(0, 4.0 * u), c + Vector2(-10.0 * u, 4.0 * u), Color.WHITE, 2.0 * u)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13.0 * u, 4.0 * u), c + Vector2(-8.0 * u, 0), c + Vector2(-8.0 * u, 8.0 * u)]), Color.WHITE)
	return Rect2(c - Vector2(16, 12) * u, Vector2(26, 22) * u)
