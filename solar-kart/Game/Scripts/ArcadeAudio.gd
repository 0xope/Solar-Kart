class_name ArcadeAudio
extends Node

var _player_sfx: AudioStreamPlayer
var _player_boost: AudioStreamPlayer
var _player_engine: AudioStreamPlayer
var _player_skid: AudioStreamPlayer

var snd_countdown_beep: AudioStreamWAV
var snd_countdown_go: AudioStreamWAV
var snd_nitro_boost: AudioStreamWAV
var snd_coin: AudioStreamWAV
var snd_nitro_cell: AudioStreamWAV
var snd_impact_light: AudioStreamWAV
var snd_impact_heavy: AudioStreamWAV
var snd_engine_loop: AudioStreamWAV
var snd_skid_loop: AudioStreamWAV
var snd_oob_warning: AudioStreamWAV
var snd_teleport_whoosh: AudioStreamWAV
var snd_teleport_drop: AudioStreamWAV
var snd_ui_hover: AudioStreamWAV
var snd_ui_click: AudioStreamWAV

func _ready() -> void:
	_player_sfx = AudioStreamPlayer.new()
	_player_sfx.name = "SFXPlayer"
	_player_sfx.bus = "Master"
	add_child(_player_sfx)

	_player_boost = AudioStreamPlayer.new()
	_player_boost.name = "BoostPlayer"
	_player_boost.bus = "Master"
	add_child(_player_boost)

	_player_engine = AudioStreamPlayer.new()
	_player_engine.name = "EnginePlayer"
	_player_engine.bus = "Master"
	add_child(_player_engine)

	_player_skid = AudioStreamPlayer.new()
	_player_skid.name = "SkidPlayer"
	_player_skid.bus = "Master"
	add_child(_player_skid)

	_generate_all_sounds()

	# Start engine audio loop
	if snd_engine_loop:
		_player_engine.stream = snd_engine_loop
		_player_engine.volume_db = -10.0
		_player_engine.play()

	if snd_skid_loop:
		_player_skid.stream = snd_skid_loop
		_player_skid.volume_db = -80.0
		_player_skid.play()

func set_engine_state(speed_ratio: float, throttle: float) -> void:
	if _player_engine == null:
		return
	var target_pitch := lerpf(0.8, 2.3, clampf(speed_ratio, 0.0, 1.2))
	if throttle > 0.1:
		target_pitch += 0.15
	_player_engine.pitch_scale = lerpf(_player_engine.pitch_scale, target_pitch, 0.15)
	var target_vol := -14.0 + (throttle * 4.0) + (speed_ratio * 4.0)
	_player_engine.volume_db = lerpf(_player_engine.volume_db, target_vol, 0.2)

func set_tire_skid(intensity: float) -> void:
	if _player_skid == null:
		return
	var clamped := clampf(intensity, 0.0, 1.0)
	if clamped > 0.05:
		var vol := lerpf(-24.0, -8.0, clamped)
		_player_skid.volume_db = lerpf(_player_skid.volume_db, vol, 0.25)
		_player_skid.pitch_scale = lerpf(0.9, 1.25, clamped)
	else:
		_player_skid.volume_db = lerpf(_player_skid.volume_db, -80.0, 0.3)

func play_countdown_beep() -> void:
	_play_clip(snd_countdown_beep, -4.0)

func play_countdown_go() -> void:
	_play_clip(snd_countdown_go, -2.0)

func play_nitro() -> void:
	if snd_nitro_boost:
		_player_boost.stream = snd_nitro_boost
		_player_boost.volume_db = -2.0
		_player_boost.play()

func stop_nitro() -> void:
	_player_boost.stop()

func play_coin() -> void:
	_play_clip(snd_coin, -5.0)

func play_nitro_cell() -> void:
	_play_clip(snd_nitro_cell, -4.0)

func play_impact(heavy: bool = false) -> void:
	_play_clip(snd_impact_heavy if heavy else snd_impact_light, -3.0)

func play_oob_warning() -> void:
	_play_clip(snd_oob_warning, -4.0)

func play_teleport_whoosh() -> void:
	_play_clip(snd_teleport_whoosh, -3.0)

func play_teleport_drop() -> void:
	_play_clip(snd_teleport_drop, -2.5)

func play_ui_hover() -> void:
	_play_clip(snd_ui_hover, -10.0)

func play_ui_click() -> void:
	_play_clip(snd_ui_click, -4.0)

func _play_clip(clip: AudioStreamWAV, vol_db: float = 0.0) -> void:
	if clip == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = clip
	p.volume_db = vol_db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

func _generate_all_sounds() -> void:
	snd_countdown_beep = _make_tone(440.0, 0.18, 0.01, 0.12)
	snd_countdown_go = _make_chord([523.25, 659.25, 783.99, 1046.5], 0.45)
	snd_coin = _make_arpeggio([987.77, 1318.51, 1760.0], 0.22)
	snd_nitro_cell = _make_chord([440.0, 554.37, 659.25, 880.0], 0.35)
	snd_nitro_boost = _make_noise_rumble(1.3)
	snd_impact_light = _make_impact(120.0, 0.15)
	snd_impact_heavy = _make_impact(75.0, 0.3)
	snd_engine_loop = _make_engine_loop(0.8)
	snd_skid_loop = _make_skid_loop(0.5)
	snd_oob_warning = _make_tone(880.0, 0.12, 0.01, 0.08)
	snd_teleport_whoosh = _make_sweep(240.0, 1100.0, 0.35)
	snd_teleport_drop = _make_chord([110.0, 440.0, 880.0], 0.28)
	snd_ui_hover = _make_tone(1046.5, 0.04, 0.005, 0.035)
	snd_ui_click = _make_chord([659.25, 987.77], 0.14)

func _make_sweep(start_freq: float, end_freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var freq := lerpf(start_freq, end_freq, progress)
		phase += TAU * freq / float(sample_rate)
		var env := sin(progress * PI)
		var s := sin(phase) * env * 0.75
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _make_tone(freq: float, duration: float, attack: float, decay: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var env := 1.0
		if t < attack:
			env = t / attack
		else:
			env = clampf(1.0 - (t - attack) / maxf(0.001, (duration - attack)), 0.0, 1.0)
		var s := sin(TAU * freq * t) * env * 0.7
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _make_chord(freqs: Array, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 5.0)
		var s := 0.0
		for f in freqs:
			s += sin(TAU * float(f) * t)
		s = (s / float(freqs.size())) * env * 0.8
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _make_arpeggio(freqs: Array, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var note_dur := duration / float(freqs.size())

	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var note_idx := mini(int(t / note_dur), freqs.size() - 1)
		var note_t := fmod(t, note_dur)
		var env := exp(-note_t * 12.0)
		var s := sin(TAU * float(freqs[note_idx]) * t) * env * 0.75
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _make_noise_rumble(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	var last := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var env := 1.0
		if t < 0.1:
			env = t / 0.1
		elif t > duration - 0.2:
			env = (duration - t) / 0.2
		var white := randf_range(-1.0, 1.0)
		last = lerpf(last, white, 0.15)
		var tone := sin(TAU * (90.0 + sin(t * 15.0) * 20.0) * t) * 0.4
		var s := (last * 0.6 + tone) * env * 0.7
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _make_impact(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 20.0)
		var f := freq * (1.0 - t / duration * 0.5)
		var noise := randf_range(-0.3, 0.3)
		var s := (sin(TAU * f * t) + noise) * env * 0.9
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _make_engine_loop(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	var base_freq := 48.0
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		# Fundamental + harmonics for a throaty rumble
		var s := sin(TAU * base_freq * t) * 0.45
		s += sin(TAU * base_freq * 2.0 * t) * 0.30
		s += sin(TAU * base_freq * 3.0 * t) * 0.15
		s += sin(TAU * base_freq * 4.0 * t) * 0.10
		# Subtle buzz
		s += randf_range(-0.06, 0.06)
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func _make_skid_loop(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	var filtered := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var white := randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, white, 0.35)
		var whistle := sin(TAU * 950.0 * t) * 0.15
		var s := (filtered * 0.6 + whistle) * 0.7
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream
