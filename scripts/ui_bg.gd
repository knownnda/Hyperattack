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


static func draw_bg(ci: CanvasItem, size: Vector2, t: float, tex: Texture2D, style: String) -> void:
	if tex:
		var ts := tex.get_size()
		var sc := maxf(size.x / ts.x, size.y / ts.y)
		var ds := ts * sc
		ci.draw_texture_rect(tex, Rect2((size - ds) * 0.5, ds), false)
		return

	var u := size.y / 360.0
	ci.draw_rect(Rect2(Vector2.ZERO, size), YELLOW)

	if style == "title":
		# straight black band up the middle
		ci.draw_rect(Rect2(V(size, 255, 0), Vector2(130.0 * u, size.y)), BLACK)
	else:
		# speaker grill pattern down the left
		var right_edge := V(size, 120, 0).x
		var row := 0
		while row * 45.0 * u < size.y:
			var y0 := row * 45.0 * u + 4.0 * u
			var x := 3.0 * u
			var i := 0
			while x < right_edge:
				var h := (28.0 + 9.0 * sin(i * 0.9 + row * 1.7 + t * 1.5)) * u
				ci.draw_rect(Rect2(Vector2(x, y0 + (37.0 * u - h) * 0.5), Vector2(3.0 * u, h)), Color(BLACK, 0.85))
				x += 7.0 * u
				i += 1
			row += 1
		# slanted black band
		ci.draw_colored_polygon(PackedVector2Array([V(size, 250, 0), V(size, 300, 0), V(size, 170, 360), V(size, 120, 360)]), BLACK)

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
	# heavy shadow block like the big beam in the reference
	ci.draw_colored_polygon(PackedVector2Array([V(size, 300, 0), V(size, 345, 0), V(size, 330, 360), V(size, 285, 360)]), BLACK)


# the black slanted menu button. sel = selected (white with a cyan stripe)
static func draw_button(ci: CanvasItem, size: Vector2, font: Font, left: float, right: float, top: float, label: String, sel: bool) -> void:
	var u := size.y / 360.0
	var h := 37.0
	var s := 9.0
	var body := PackedVector2Array([V(size, left + s, top), V(size, right + s, top), V(size, right, top + h), V(size, left, top + h)])
	ci.draw_colored_polygon(body, Color.WHITE if sel else BLACK)
	if not sel:
		ci.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), Color(1, 1, 1, 0.9), 1.5 * u)
	# end stripes
	if sel:
		ci.draw_colored_polygon(PackedVector2Array([V(size, right + s + 3, top), V(size, right + s + 11, top), V(size, right + 11, top + h), V(size, right + 3, top + h)]), CYAN)
		ci.draw_colored_polygon(PackedVector2Array([V(size, right + s + 14, top), V(size, right + s + 16, top), V(size, right + 16, top + h), V(size, right + 14, top + h)]), Color.WHITE)
	else:
		for off in [4.0, 9.0]:
			ci.draw_colored_polygon(PackedVector2Array([V(size, right + s + off, top), V(size, right + s + off + 2.5, top), V(size, right + off + 2.5, top + h), V(size, right + off, top + h)]), Color.WHITE)
	var fs := int(19.0 * u)
	var p := V(size, left + s * 0.5, top + h * 0.5 + 6.5)
	ci.draw_string(font, p, label, HORIZONTAL_ALIGNMENT_CENTER, (right - left) * u, fs, BLACK if sel else Color.WHITE)


static func draw_header(ci: CanvasItem, size: Vector2, font: Font, text: String) -> void:
	var u := size.y / 360.0
	ci.draw_colored_polygon(PackedVector2Array([V(size, 290, 0), Vector2(size.x, 0), Vector2(size.x, V(size, 0, 28).y), V(size, 282, 28)]), BLACK)
	ci.draw_string(font, V(size, 300, 20), text, HORIZONTAL_ALIGNMENT_CENTER, 150.0 * u, int(13.0 * u), Color.WHITE)


static func draw_back_arrow(ci: CanvasItem, size: Vector2) -> Rect2:
	var u := size.y / 360.0
	var c := V(size, 605, 345)
	ci.draw_arc(c + Vector2(0, -2.0 * u), 6.0 * u, -PI * 0.5, PI * 0.5, 12, Color.WHITE, 2.0 * u)
	ci.draw_line(c + Vector2(0, 4.0 * u), c + Vector2(-10.0 * u, 4.0 * u), Color.WHITE, 2.0 * u)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13.0 * u, 4.0 * u), c + Vector2(-8.0 * u, 0), c + Vector2(-8.0 * u, 8.0 * u)]), Color.WHITE)
	return Rect2(c - Vector2(16, 12) * u, Vector2(26, 22) * u)
