extends Node
# global stuff: characters, settings, saving, controls, scene changes,
# and the asset lookup (anything dropped into res://assets/ replaces its placeholder)

const VERSION := "v0.4"
const ASSET_DIR := "res://assets/"
const SAVE_PATH := "user://hyper_attack.cfg"

# "file" is the name used for that character's files in assets/characters/
# "turn" is how far the model gets spun round so it faces the right way (radians)
# the ability goes with the slot: 0 time stop, 1 double jump, 2 zero-g, 3 slow ball
var characters := [
	{"name": "NERDO", "file": "nerdo", "turn": -0.6, "ability": "TIME STOP", "desc": "freeze them. keep swinging.", "cost": 100.0},
	{"name": "MOUSE", "file": "mouse", "turn": PI / 2.0 - 0.6, "ability": "DOUBLE JUMP", "desc": "always gets a second jump. special = super hop.", "cost": 35.0},
	{"name": "PRIVATE", "file": "private", "turn": PI / 2.0 - 0.6, "ability": "ZERO-G", "desc": "ball floats and goes neutral. scramble for it.", "cost": 75.0},
	{"name": "MACDONALD", "file": "macdonald", "turn": PI / 2.0 - 0.6, "ability": "SLOW BALL", "desc": "ball crawls for 3.5s. breathe.", "cost": 60.0},
]

var colors := [Color("#ff3b5c"), Color("#2ec4ff")]
var INK := Color(0.04, 0.02, 0.07)

# settings (saved)
var stocks := 5
var match_time := 300.0  # seconds, 0 = no timer
var cpu_level := 1  # 0 easy, 1 normal, 2 hard
var sfx_vol := 0.8
var music_vol := 0.6
var fullscreen := false

# stats for the little profile card (saved)
var matches_played := 0
var p1_wins := 0

var mode := "cpu"  # "cpu" or "2p"
var p_chars := [0, 2]
var menu_start := "title"  # where the frontend opens: "title" or "main"

var key_names := [
	{"jump": "W", "swing": "F", "bunt": "G", "special": "H"},
	{"jump": "UP", "swing": "K", "bunt": "L", "special": ";"},
]

var font: FontVariation
var outline_mat: StandardMaterial3D
var tex_grid: ImageTexture
var tex_grid_dark: ImageTexture

var music: AudioStreamPlayer
var _music_name := ""
var _loader: CanvasLayer
var _load_label: Label
var _pending := ""
var _load_t := 0.0
var _hide_t := 0.0

const ACTIONS := ["left", "right", "up", "down", "jump", "swing", "bunt", "special"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_buses()
	load_settings()

	font = FontVariation.new()
	var custom = asset_any("fonts/main", ["ttf", "otf", "woff2", "woff"])
	if custom is Font:
		font.base_font = custom
	else:
		# placeholder look: the default font made bold + slanted
		font.base_font = ThemeDB.fallback_font
		font.variation_embolden = 1.3
		font.variation_transform = Transform2D(Vector2(1.0, 0.22), Vector2(0.0, 1.0), Vector2.ZERO)

	outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = INK
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mat.grow = true
	outline_mat.grow_amount = 0.035

	tex_grid = _tex(64, _paint_grid)
	tex_grid_dark = _tex(64, _paint_grid_dark)

	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	_build_loader()


# ---------------- assets ----------------

# returns the resource at assets/<path> or null if nobody's added it
func asset(path: String) -> Resource:
	var full := ASSET_DIR + path
	if ResourceLoader.exists(full):
		return load(full)
	return null


# same but tries a few file types, e.g. asset_any("sfx/hit", ["wav", "ogg"])
func asset_any(base: String, exts: Array) -> Resource:
	for e in exts:
		var r := asset(base + "." + str(e))
		if r != null:
			return r
	return null


func asset_tex(base: String) -> Texture2D:
	var r := asset_any(base, ["png", "jpg", "jpeg", "webp", "svg"])
	return r as Texture2D


func asset_scene(base: String) -> PackedScene:
	var r := asset_any(base, ["glb", "gltf", "tscn", "fbx", "blend"])
	return r as PackedScene


func play_music(name_: String) -> void:
	if name_ == _music_name and music.playing:
		return
	_music_name = name_
	var s = asset_any("music/" + name_, ["ogg", "mp3", "wav"])
	if s == null:
		music.stop()  # no music unless you add some
		return
	if "loop" in s:
		s.loop = true
	music.stream = s
	music.play()


# ---------------- settings / save ----------------

func _setup_buses() -> void:
	for b in ["SFX", "Music"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_vol, 0.001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_vol, 0.001)))
	if OS.get_name() != "Web":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		stocks = cf.get_value("settings", "stocks", stocks)
		match_time = cf.get_value("settings", "match_time", match_time)
		cpu_level = cf.get_value("settings", "cpu_level", cpu_level)
		sfx_vol = cf.get_value("settings", "sfx_vol", sfx_vol)
		music_vol = cf.get_value("settings", "music_vol", music_vol)
		fullscreen = cf.get_value("settings", "fullscreen", fullscreen)
		matches_played = cf.get_value("stats", "matches", 0)
		p1_wins = cf.get_value("stats", "p1_wins", 0)
	apply_settings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("settings", "stocks", stocks)
	cf.set_value("settings", "match_time", match_time)
	cf.set_value("settings", "cpu_level", cpu_level)
	cf.set_value("settings", "sfx_vol", sfx_vol)
	cf.set_value("settings", "music_vol", music_vol)
	cf.set_value("settings", "fullscreen", fullscreen)
	cf.set_value("stats", "matches", matches_played)
	cf.set_value("stats", "p1_wins", p1_wins)
	cf.save(SAVE_PATH)


# ---------------- scene changes with the black "Loading." screen ----------------

func goto(scene: String) -> void:
	if _pending != "":
		return
	_pending = scene
	_load_t = 0.35
	_loader.visible = true


func _build_loader() -> void:
	_loader = CanvasLayer.new()
	_loader.layer = 100
	_loader.visible = false
	add_child(_loader)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loader.add_child(bg)
	_load_label = Label.new()
	_load_label.add_theme_font_override("font", font)
	_load_label.add_theme_font_size_override("font_size", 34)
	_load_label.add_theme_color_override("font_color", Color.WHITE)
	_load_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_load_label.offset_left = -260.0
	_load_label.offset_top = -90.0
	_load_label.offset_right = -40.0
	_load_label.offset_bottom = -40.0
	_loader.add_child(_load_label)


func _process(delta: float) -> void:
	if _pending != "":
		_load_t -= delta
		_load_label.text = "Loading" + ".".repeat(1 + int(Time.get_ticks_msec() / 300) % 3)
		if _load_t <= 0.0:
			get_tree().change_scene_to_file(_pending)
			_pending = ""
			_hide_t = 0.15
	elif _hide_t > 0.0:
		_hide_t -= delta
		if _hide_t <= 0.0:
			_loader.visible = false


# ---------------- look ----------------

# placeholder "prototype" grid texture for the greybox stage
func _paint_grid(x: int, y: int) -> Color:
	if x % 32 == 0 or y % 32 == 0:
		return Color("#6d7377")
	if x % 8 == 0 or y % 8 == 0:
		return Color("#9aa0a4")
	return Color("#a9afb3")


func _paint_grid_dark(x: int, y: int) -> Color:
	if x % 32 == 0 or y % 32 == 0:
		return Color("#2c3034")
	if x % 8 == 0 or y % 8 == 0:
		return Color("#41464b")
	return Color("#4a4f54")


func _tex(sz: int, paint: Callable) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			img.set_pixel(x, y, paint.call(x, y))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func grid_mat(dark := false, tile := 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex_grid_dark if dark else tex_grid
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * tile
	m.roughness = 0.9
	return m


func toon(c: Color, outlined := true, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.2
	m.metallic_specular = 0.3
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if outlined:
		m.next_pass = outline_mat
	return m


func flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func is_human(i: int) -> bool:
	return i == 0 or mode == "2p"


func who(i: int) -> String:
	return "CPU" if not is_human(i) else "P%d" % (i + 1)


func _setup_input() -> void:
	# W / up is jump AND "aim up" when you hold it during a swing
	var keys := [
		{"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S], "jump": [KEY_W, KEY_SPACE], "swing": [KEY_F], "bunt": [KEY_G], "special": [KEY_H]},
		{"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN], "jump": [KEY_UP], "swing": [KEY_K, KEY_KP_1], "bunt": [KEY_L, KEY_KP_2], "special": [KEY_SEMICOLON, KEY_KP_3]},
	]

	for i in 2:
		var p := "p%d_" % i
		for a in ACTIONS:
			if InputMap.has_action(p + a):
				InputMap.erase_action(p + a)
			InputMap.add_action(p + a, 0.4)

		var k: Dictionary = keys[i]
		for a in k:
			for code in k[a]:
				_key(p + a, code)

		_axis(p + "left", i, JOY_AXIS_LEFT_X, -1.0)
		_axis(p + "right", i, JOY_AXIS_LEFT_X, 1.0)
		_axis(p + "up", i, JOY_AXIS_LEFT_Y, -1.0)
		_axis(p + "down", i, JOY_AXIS_LEFT_Y, 1.0)
		_btn(p + "left", i, JOY_BUTTON_DPAD_LEFT)
		_btn(p + "right", i, JOY_BUTTON_DPAD_RIGHT)
		_btn(p + "up", i, JOY_BUTTON_DPAD_UP)
		_btn(p + "down", i, JOY_BUTTON_DPAD_DOWN)
		_btn(p + "jump", i, JOY_BUTTON_A)
		_btn(p + "swing", i, JOY_BUTTON_X)
		_btn(p + "swing", i, JOY_BUTTON_RIGHT_SHOULDER)
		_btn(p + "bunt", i, JOY_BUTTON_B)
		_btn(p + "special", i, JOY_BUTTON_Y)

	if not InputMap.has_action("quit"):
		InputMap.add_action("quit")
		_key("quit", KEY_ESCAPE)
		_btn("quit", -1, JOY_BUTTON_BACK)


func _key(action: String, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.device = -1
	InputMap.action_add_event(action, ev)


func _btn(action: String, device: int, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: String, device: int, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
