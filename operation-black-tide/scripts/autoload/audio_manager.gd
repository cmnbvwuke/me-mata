extends Node
## AudioManager (autoload)
## Sintetiza TODOS os efeitos sonoros proceduralmente na inicialização
## (sem arquivos de áudio externos) e oferece funções simples para tocá-los.
##
## Para substituir por samples reais, basta registrar um AudioStream com o
## mesmo nome: `AudioManager.register("rifle_shot", load("res://audio/m4.ogg"))`.

const MIX_RATE := 22050

var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7741
	_generate_library()
	_rng.randomize()


func register(sound_name: String, stream: AudioStream) -> void:
	_streams[sound_name] = stream


func get_stream(sound_name: String) -> AudioStream:
	return _streams.get(sound_name) as AudioStream


## Som "na cabeça" do jogador (armas do jogador, UI, rádio).
func play_2d(sound_name: String, volume_db: float = 0.0, pitch_variation: float = 0.05) -> AudioStreamPlayer:
	var stream := get_stream(sound_name)
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_variation, pitch_variation)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Som posicional no mundo (tiros inimigos, impactos, explosões).
func play_3d(sound_name: String, position: Vector3, volume_db: float = 0.0,
		max_distance: float = 80.0, unit_size: float = 6.0, pitch_variation: float = 0.06) -> AudioStreamPlayer3D:
	var stream := get_stream(sound_name)
	var scene := get_tree().current_scene
	if stream == null or scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = unit_size
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_variation, pitch_variation)
	scene.add_child(p)
	p.global_position = position
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Cria um player 3D em loop (rotor de helicóptero, sirene). O chamador é dono do nó.
func make_loop_player(sound_name: String, parent: Node, volume_db: float = 0.0,
		unit_size: float = 10.0, max_distance: float = 200.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = get_stream(sound_name)
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = max_distance
	parent.add_child(p)
	return p


# =========================================================================
# Biblioteca procedural
# =========================================================================

func _generate_library() -> void:
	# Armas
	_streams["rifle_shot"] = _wav(_echo(_gunshot(0.42, 16.0, 0.55, 70.0, 0.9, 0.9), 0.085, 0.28))
	_streams["pistol_suppressed"] = _wav(_gunshot(0.16, 38.0, 0.12, 120.0, 0.35, 0.15))
	_streams["pistol"] = _wav(_echo(_gunshot(0.26, 26.0, 0.42, 95.0, 0.75, 0.6), 0.07, 0.22))
	_streams["enemy_rifle"] = _wav(_echo(_gunshot(0.45, 14.0, 0.42, 60.0, 1.0, 0.7), 0.11, 0.3))
	_streams["dry_fire"] = _wav(_click(0.035, 2600.0, 0.6))
	_streams["mag_out"] = _wav(_click(0.09, 900.0, 0.9))
	_streams["mag_in"] = _wav(_concat(_click(0.05, 1400.0, 0.8), _click(0.08, 700.0, 1.0)))
	_streams["bolt"] = _wav(_concat(_click(0.06, 1800.0, 1.0), _silence(0.07), _click(0.07, 1100.0, 1.0)))
	_streams["equip"] = _wav(_click(0.12, 500.0, 0.5))
	_streams["fire_mode"] = _wav(_click(0.03, 3000.0, 0.5))
	_streams["casing"] = _wav(_tinkle())
	# Impactos e corpo
	_streams["impact"] = _wav(_noise_hit(0.09, 55.0, 0.6))
	_streams["flesh_hit"] = _wav(_noise_hit(0.12, 30.0, 0.12))
	_streams["death_thud"] = _wav(_thump(0.35, 55.0))
	_streams["footstep"] = _wav(_noise_hit(0.13, 38.0, 0.08))
	_streams["hitmarker"] = _wav(_tone(0.045, 1900.0, 70.0))
	_streams["whiz"] = _wav(_whiz())
	_streams["explosion"] = _wav(_echo(_explosion(), 0.18, 0.35))
	# Ambiente e UI
	_streams["heli_loop"] = _wav(_heli_loop(), true)
	_streams["alarm_loop"] = _wav(_alarm_loop(), true)
	_streams["heartbeat"] = _wav(_heartbeat(), true)
	_streams["radio_beep"] = _wav(_radio_beep())
	_streams["ui_click"] = _wav(_tone(0.04, 1200.0, 60.0))
	_streams["zip_tie"] = _wav(_zip())
	_streams["objective"] = _wav(_concat(_tone(0.09, 880.0, 14.0), _tone(0.16, 1320.0, 10.0)))


# --- Conversão --------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.95 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _buffer(duration: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(duration * MIX_RATE))
	return b


func _concat(a: PackedFloat32Array, b: PackedFloat32Array, c: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	var out := a.duplicate()
	out.append_array(b)
	out.append_array(c)
	return out


func _silence(duration: float) -> PackedFloat32Array:
	return _buffer(duration)


## Eco simples (reflexão em paredes/vegetação) para dar "peso" aos disparos.
func _echo(src: PackedFloat32Array, delay: float, feedback: float) -> PackedFloat32Array:
	var d := int(delay * MIX_RATE)
	var out := src.duplicate()
	out.resize(src.size() + d * 3)
	for i in range(src.size(), out.size()):
		out[i] = 0.0
	for i in range(d, out.size()):
		out[i] += out[i - d] * feedback
	return out


# --- Sintetizadores -----------------------------------------------------------

## Disparo: ruído filtrado com decaimento + "estalo" supersônico + grave (thump).
func _gunshot(duration: float, decay: float, lowpass: float, thump_freq: float,
		thump_gain: float, crack_gain: float) -> PackedFloat32Array:
	var out := _buffer(duration)
	var y1 := 0.0
	var y2 := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		y1 += lowpass * (white - y1)
		y2 += lowpass * 0.6 * (y1 - y2)
		var body := y2 * 2.5 * exp(-t * decay)
		var crack := white * exp(-t * 220.0) * crack_gain
		var thump := sin(TAU * thump_freq * t * (1.0 - t)) * exp(-t * 20.0) * thump_gain
		out[i] = body + crack + thump
	return out


func _click(duration: float, freq: float, noise_amt: float) -> PackedFloat32Array:
	var out := _buffer(duration)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var env := exp(-t * 60.0)
		out[i] = (sin(TAU * freq * t) * (1.0 - noise_amt) + _rng.randf_range(-1.0, 1.0) * noise_amt) * env
	return out


func _noise_hit(duration: float, decay: float, lowpass: float) -> PackedFloat32Array:
	var out := _buffer(duration)
	var y := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		y += lowpass * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * exp(-t * decay)
	return out


func _thump(duration: float, freq: float) -> PackedFloat32Array:
	var out := _buffer(duration)
	var y := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		y += 0.05 * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = (sin(TAU * freq * t) * 0.8 + y * 2.0) * exp(-t * 14.0)
	return out


func _tone(duration: float, freq: float, decay: float) -> PackedFloat32Array:
	var out := _buffer(duration)
	for i in out.size():
		var t := float(i) / MIX_RATE
		out[i] = sin(TAU * freq * t) * exp(-t * decay)
	return out


func _tinkle() -> PackedFloat32Array:
	var out := _buffer(0.25)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var bounce := exp(-t * 30.0) + exp(-maxf(t - 0.09, 0.0) * 40.0) * (0.5 if t > 0.09 else 0.0)
		out[i] = (sin(TAU * 4200.0 * t) + sin(TAU * 6100.0 * t) * 0.5) * bounce
	return out


## Bala passando perto ("zip"): ruído com varredura de frequência.
func _whiz() -> PackedFloat32Array:
	var out := _buffer(0.18)
	var y := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		var lp := lerpf(0.6, 0.08, t / 0.18)
		y += lp * (_rng.randf_range(-1.0, 1.0) - y)
		var env := sin(PI * t / 0.18)
		out[i] = y * env
	return out


func _explosion() -> PackedFloat32Array:
	var out := _buffer(2.2)
	var y1 := 0.0
	var y2 := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		y1 += 0.12 * (white - y1)
		y2 += 0.04 * (y1 - y2)
		var rumble := sin(TAU * 38.0 * t) * exp(-t * 3.0) * 0.8
		out[i] = (y2 * 6.0 + white * exp(-t * 40.0) * 0.6) * exp(-t * 2.2) + rumble
	return out


## Rotor: ruído grave modulado em "whop-whop" (6 Hz). Loop de 1 s.
func _heli_loop() -> PackedFloat32Array:
	var out := _buffer(1.0)
	var y1 := 0.0
	var y2 := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		y1 += 0.09 * (white - y1)
		y2 += 0.05 * (y1 - y2)
		var whop := pow(0.5 + 0.5 * cos(TAU * 6.0 * t), 4.0)
		out[i] = y2 * (0.35 + whop * 1.6) * 3.0 + sin(TAU * 24.0 * t) * 0.15 + white * 0.03
	# Crossfade das pontas para evitar estalos no loop
	var fade := int(0.03 * MIX_RATE)
	for i in fade:
		var k := float(i) / fade
		out[i] = out[i] * k + out[out.size() - fade + i] * (1.0 - k)
	return out


## Sirene de alarme oscilante. Loop de 2 s.
func _alarm_loop() -> PackedFloat32Array:
	var out := _buffer(2.0)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		var freq := 620.0 + 260.0 * (0.5 - 0.5 * cos(TAU * 0.5 * t))
		phase += TAU * freq / MIX_RATE
		out[i] = tanh(sin(phase) * 2.5) * 0.6
	return out


func _heartbeat() -> PackedFloat32Array:
	var out := _buffer(0.9)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var b1 := sin(TAU * 48.0 * t) * exp(-t * 18.0)
		var t2 := maxf(t - 0.22, 0.0)
		var b2 := sin(TAU * 42.0 * t2) * exp(-t2 * 20.0) * 0.7 if t > 0.22 else 0.0
		out[i] = b1 + b2
	return out


func _radio_beep() -> PackedFloat32Array:
	var out := _buffer(0.22)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var tone := sin(TAU * 1250.0 * t) * (1.0 if t < 0.09 else 0.0)
		var squelch := _rng.randf_range(-1.0, 1.0) * 0.5 * (1.0 if t > 0.1 else 0.0) * exp(-(t - 0.1) * 30.0)
		out[i] = tone * 0.6 + squelch
	return out


func _zip() -> PackedFloat32Array:
	var out := _buffer(0.35)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var teeth := 0.5 + 0.5 * signf(sin(TAU * (90.0 + t * 200.0) * t))
		out[i] = _rng.randf_range(-1.0, 1.0) * teeth * (1.0 - t / 0.35)
	return out
