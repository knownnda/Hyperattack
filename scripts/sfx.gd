extends Node
# placeholder sounds get made with maths when the game boots.
# drop a file in assets/sfx/ with the same name (hit.wav, ko.ogg ...) and it gets used instead

const RATE := 22050

var sounds := {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var _lp := 0.0  # little lowpass for the noisy sounds


func _ready() -> void:
	sounds["hit"] = _synth(0.18, _hit)
	sounds["bounce"] = _synth(0.08, _bounce)
	sounds["jump"] = _synth(0.12, _jump)
	sounds["swing"] = _synth(0.13, _swing)
	sounds["ko"] = _synth(0.55, _ko)
	sounds["special"] = _synth(0.35, _special)
	sounds["timestop"] = _synth(1.0, _timestop)
	sounds["slow"] = _synth(0.4, _slow)
	sounds["float"] = _synth(0.5, _float)
	sounds["tick"] = _synth(0.05, _tick)

	# your own sounds win over the generated ones
	for key in sounds.keys():
		var custom = Game.asset_any("sfx/" + str(key), ["wav", "ogg", "mp3"])
		if custom is AudioStream:
			sounds[key] = custom
	# extra slots that are silent unless you add a file for them
	for extra in ["menu_move", "menu_select", "menu_back", "ready", "go", "win"]:
		var custom = Game.asset_any("sfx/" + extra, ["wav", "ogg", "mp3"])
		if custom is AudioStream:
			sounds[extra] = custom

	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		voices.append(p)


func play(sound: String, pitch := 1.0, db := 0.0) -> void:
	if not sounds.has(sound):
		return
	var p := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	p.stream = sounds[sound]
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


func _synth(length: float, wave: Callable) -> AudioStreamWAV:
	_lp = 0.0
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = clampf(wave.call(float(i) / RATE), -1.0, 1.0)
		var fade := minf(1.0, float(n - i) / 200.0)  # stops clicks at the end
		data.encode_s16(i * 2, int(v * fade * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _soft_noise(amount: float) -> float:
	_lp += (_noise() - _lp) * amount
	return _lp


# --- the actual sounds ---

func _hit(t: float) -> float:
	return _noise() * exp(-t * 45.0) * 0.8 + sin(TAU * 140.0 * t) * exp(-t * 16.0) * 0.8


func _bounce(t: float) -> float:
	return sin(TAU * 620.0 * t) * exp(-t * 55.0) * 0.5 + _noise() * exp(-t * 120.0) * 0.25


func _jump(t: float) -> float:
	return sin(TAU * (280.0 * t + 1900.0 * t * t)) * exp(-t * 18.0) * 0.35


func _swing(t: float) -> float:
	return _soft_noise(0.18) * sin(PI * t / 0.13) * 0.9


func _ko(t: float) -> float:
	var boom := _soft_noise(0.3) * exp(-t * 6.0) * 0.9
	var drop := sin(TAU * (190.0 * t - 150.0 * t * t)) * exp(-t * 4.0) * 0.6
	return boom + drop


func _special(t: float) -> float:
	var env := 1.0 - t / 0.35
	return (sin(TAU * (220.0 * t + 900.0 * t * t)) + 0.5 * sin(TAU * (440.0 * t + 1800.0 * t * t))) * env * 0.3


func _timestop(t: float) -> float:
	return sin(TAU * 88.0 * t) * exp(-t * 3.0) * 0.6 + sin(TAU * 177.0 * t) * exp(-t * 4.5) * 0.3 + sin(TAU * 523.0 * t) * exp(-t * 9.0) * 0.15


func _slow(t: float) -> float:
	return sin(TAU * (500.0 * t - 500.0 * t * t)) * (1.0 - t / 0.4) * 0.4


func _float(t: float) -> float:
	return sin(TAU * 380.0 * t + 3.0 * sin(TAU * 9.0 * t)) * sin(PI * t / 0.5) * 0.35


func _tick(t: float) -> float:
	return sin(TAU * 900.0 * t) * exp(-t * 80.0) * 0.4
