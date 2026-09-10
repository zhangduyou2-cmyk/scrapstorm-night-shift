extends Node
## Bounded SFX voices and synchronized, original three-layer adaptive map scores.
## Web music begins only after a real keyboard/mouse gesture, never on menu load.

const MAX_VOICES := 8
const MUSIC_LAYERS: Array[String] = ["bed", "rhythm", "boss"]
const MAP_IDS: Array[String] = ["yard", "foundry", "reactor"]
const PHASE_GAINS: Dictionary = {
	"menu": [0.38, 0.0, 0.0], "combat": [0.62, 0.66, 0.0],
	"shop": [0.38, 0.12, 0.0], "boss": [0.58, 0.66, 0.54],
	"pause": [0.18, 0.0, 0.0], "result": [0.34, 0.0, 0.0],
}
const SOUNDS: Dictionary = {
	"ui": "res://assets/audio/ui.wav", "start": "res://assets/audio/start.wav",
	"collect": "res://assets/audio/collect.wav", "blast": "res://assets/audio/blast.wav",
	"hit": "res://assets/audio/hit.wav", "dash": "res://assets/audio/dash.wav",
	"enemy_down": "res://assets/audio/enemy_down.wav", "win": "res://assets/audio/win.wav",
	"lose": "res://assets/audio/lose.wav", "foam": "res://assets/audio/foam.wav",
	"arc": "res://assets/audio/arc.wav", "warning": "res://assets/audio/warning.wav",
	"boss_charge": "res://assets/audio/boss_charge.wav", "unlock": "res://assets/audio/unlock.wav",
	"skill_pulse": "res://assets/audio/skill_pulse.wav", "skill_singularity": "res://assets/audio/skill_singularity.wav",
	"skill_overdrive": "res://assets/audio/skill_overdrive.wav", "singularity_burst": "res://assets/audio/singularity_burst.wav",
	"skill_ready": "res://assets/audio/skill_ready.wav", "boss_break": "res://assets/audio/boss_break.wav",
	"evolve": "res://assets/audio/evolve.wav", "install": "res://assets/audio/install.wav",
}
const COOLDOWNS: Dictionary = {
	"ui": 0.06, "start": 0.4, "collect": 0.09, "blast": 0.15,
	"hit": 0.12, "dash": 0.15, "enemy_down": 0.08, "win": 1.0, "lose": 1.0,
	"foam": 0.30, "arc": 0.25, "warning": 0.35, "boss_charge": 0.60, "unlock": 0.6,
	"skill_pulse": 0.18, "skill_singularity": 0.35, "skill_overdrive": 0.35,
	"singularity_burst": 0.20, "skill_ready": 0.8, "boss_break": 0.25, "evolve": 0.6, "install": 0.12,
}
const GAINS_DB: Dictionary = {
	"ui": -10.0, "start": -8.0, "collect": -16.0, "blast": -3.0,
	"hit": -5.0, "dash": -7.0, "enemy_down": -13.0, "win": -8.0, "lose": -7.0,
	"foam": -17.0, "arc": -17.0, "warning": -5.0, "boss_charge": -8.0, "unlock": -9.0,
	"skill_pulse": -6.0, "skill_singularity": -8.0, "skill_overdrive": -9.0,
	"singularity_burst": -5.0, "skill_ready": -11.0, "boss_break": -5.0, "evolve": -9.0, "install": -10.0,
}
const IMPORTANT_EVENTS: Array[String] = ["ui", "start", "blast", "hit", "win", "lose", "warning", "boss_charge", "unlock", "skill_pulse", "skill_singularity", "skill_overdrive", "singularity_burst", "skill_ready", "boss_break", "evolve", "install"]
const VARIED_EVENTS: Array[String] = ["collect", "enemy_down", "foam", "arc", "blast"]
const PITCH_VARIANTS: Array[float] = [1.0, 0.965, 1.025, 0.99, 1.045]

var _voices: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _streams: Dictionary = {}
var _event_counts: Dictionary = {}
var _music_streams: Dictionary = {}
var _banks: Array[Dictionary] = []
var _active_bank: int = 0
var _context_map: String = "yard"
var _context_phase: String = "menu"
var _context_revision: int = 0
var _unlocked: bool = false
var _music_volume: float = 0.55
var _sfx_volume: float = 0.85
var _headless: bool = false
var _bank_starts: int = 0
var _shutting_down: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	for event: String in SOUNDS:
		var stream := load(str(SOUNDS[event])) as AudioStream
		if stream != null:
			_streams[event] = stream
	for index: int in range(MAX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % index
		voice.bus = "Master"
		add_child(voice)
		_voices.append(voice)
	for map_id: String in MAP_IDS:
		var layers: Array[AudioStreamOggVorbis] = []
		for layer: String in MUSIC_LAYERS:
			var stream := load("res://assets/audio/music/%s_%s.ogg" % [map_id, layer]) as AudioStreamOggVorbis
			if stream != null:
				stream.loop = true
			layers.append(stream)
		_music_streams[map_id] = layers
	for bank_index: int in range(2):
		var players: Array[AudioStreamPlayer] = []
		for layer_index: int in range(3):
			var player := AudioStreamPlayer.new()
			player.name = "Music%d_%s" % [bank_index, MUSIC_LAYERS[layer_index]]
			player.volume_db = -80.0
			add_child(player)
			players.append(player)
		_banks.append({"players": players, "map": "", "fade": 0.0, "target": 0.0, "gains": [0.0, 0.0, 0.0]})
	Settings.preferences_changed.connect(_apply_volume)
	_apply_volume()
	_prepare_bank(0, "yard")
	if not OS.has_feature("web") and not _headless:
		unlock_audio()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		unlock_audio()


func unlock_audio() -> void:
	if _unlocked or _shutting_down:
		return
	_unlocked = true
	if not _banks.is_empty():
		_banks[_active_bank]["fade"] = 0.0
		_banks[_active_bank]["target"] = 1.0
		_start_bank(_active_bank)


func set_context(map_id: String, phase: String) -> void:
	if _shutting_down:
		return
	var next_map: String = map_id if map_id in MAP_IDS else "yard"
	var next_phase: String = phase if PHASE_GAINS.has(phase) else "menu"
	if next_map == _context_map and next_phase == _context_phase:
		return
	_context_revision += 1
	_context_phase = next_phase
	if next_map != _context_map:
		_context_map = next_map
		if _banks.is_empty():
			return
		_banks[_active_bank]["target"] = 0.0
		_active_bank = 1 - _active_bank
		_prepare_bank(_active_bank, next_map)
		if _unlocked:
			_start_bank(_active_bank)
	# Phase changes preserve every layer's clock; only its gain changes.


func _prepare_bank(index: int, map_id: String) -> void:
	var bank: Dictionary = _banks[index]
	bank["map"] = map_id
	bank["fade"] = 0.0
	bank["target"] = 1.0
	bank["gains"] = [0.0, 0.0, 0.0]
	var streams: Array = _music_streams.get(map_id, [])
	for layer: int in range(3):
		var player: AudioStreamPlayer = bank["players"][layer]
		player.stop()
		player.volume_db = -80.0
		player.stream = streams[layer] if layer < streams.size() else null


func _start_bank(index: int) -> void:
	_bank_starts += 1
	if _headless:
		return
	for player: AudioStreamPlayer in _banks[index]["players"]:
		if player.stream != null and not player.playing:
			player.play()


func _process(delta: float) -> void:
	var desired: Array = PHASE_GAINS[_context_phase]
	var smoothing: float = 1.0 - exp(-maxf(delta, 0.0) * 2.8)
	for bank: Dictionary in _banks:
		bank["fade"] = move_toward(float(bank["fade"]), float(bank["target"]), maxf(delta, 0.0) / 1.5)
		for layer: int in range(3):
			bank["gains"][layer] = lerpf(float(bank["gains"][layer]), float(desired[layer]), smoothing)
			var player: AudioStreamPlayer = bank["players"][layer]
			var gain: float = float(bank["fade"]) * float(bank["gains"][layer]) * _music_volume * 0.55
			player.volume_db = linear_to_db(maxf(gain, 0.0001))
			if float(bank["target"]) <= 0.0 and float(bank["fade"]) <= 0.0 and player.playing:
				player.stop()


func play(event: String) -> void:
	if _shutting_down or _headless or not _streams.has(event) or Settings.master_volume <= 0.0 or _sfx_volume <= 0.0:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(event, -100.0)) < float(COOLDOWNS[event]):
		return
	var active_events: Array[String] = []
	for voice: AudioStreamPlayer in _voices:
		active_events.append(str(voice.get_meta("event", "")) if voice.playing else "")
	var voice_index: int = _voice_index(event, active_events)
	if voice_index < 0:
		return
	var available_voice: AudioStreamPlayer = _voices[voice_index]
	available_voice.stop()
	available_voice.set_meta("event", event)
	_last_played[event] = now
	available_voice.stream = _streams[event]
	available_voice.set_meta("event_gain", float(GAINS_DB[event]))
	available_voice.volume_db = float(GAINS_DB[event]) + linear_to_db(maxf(_sfx_volume, .0001))
	var count: int = int(_event_counts.get(event, 0))
	available_voice.pitch_scale = PITCH_VARIANTS[count % PITCH_VARIANTS.size()] if event in VARIED_EVENTS else 1.0
	_event_counts[event] = count + 1
	available_voice.play()


func _voice_index(event: String, active_events: Array[String]) -> int:
	# Pure bounded allocation also permits pressure tests without starting the
	# headless dummy audio thread. Automatic tools only take idle voices; skill
	# and reward cues cannot replace a playing safety warning or charge cue.
	for index: int in range(active_events.size()):
		if active_events[index].is_empty():
			return index
	if event not in IMPORTANT_EVENTS:
		return -1
	var selected: int = -1
	var lowest: int = 4
	var incoming: int = _event_priority(event)
	for index: int in range(active_events.size()):
		var priority: int = _event_priority(active_events[index])
		if priority <= incoming and priority < lowest:
			selected = index
			lowest = priority
	return selected


func _event_priority(event: String) -> int:
	if event in ["warning", "boss_charge"]:
		return 3
	return 2 if event in IMPORTANT_EVENTS else 0


func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	for bank: Dictionary in _banks:
		for player: AudioStreamPlayer in bank["players"]:
			player.stop()
			player.stream = null
	_last_played.clear()


func shutdown() -> void:
	# AudioServer retires playback instances on its mix thread. Automated native
	# capture/export fixtures must await that retirement before SceneTree.quit().
	# _exit_tree cannot supply an awaited delay, so explicit shutdown is separate.
	_shutting_down = true
	stop_all()
	if not _headless and is_inside_tree():
		# Allow two device buffers to retire; 180 ms can be shorter than native output latency.
		var retire_seconds: float = maxf(0.35, AudioServer.get_output_latency() * 2.0 + 0.1)
		await get_tree().create_timer(retire_seconds, true, false, true).timeout
		await get_tree().process_frame


func get_music_state() -> Dictionary:
	return {"map_id": _context_map, "phase": _context_phase, "revision": _context_revision,
		"unlocked": _unlocked, "active_bank": _active_bank, "music_volume": _music_volume,
		"sfx_volume": _sfx_volume, "music_players": _banks.size() * 3,
		"bank_starts": _bank_starts, "phase_targets": PHASE_GAINS[_context_phase].duplicate()}


func _exit_tree() -> void:
	stop_all()
	_streams.clear()
	_music_streams.clear()


func _preference(name: String, fallback: float) -> float:
	for property: Dictionary in Settings.get_property_list():
		if property["name"] == name:
			var value: Variant = Settings.get(name)
			if (value is int or value is float) and is_finite(float(value)):
				return clampf(float(value), 0.0, 1.0)
	return fallback


func _apply_volume() -> void:
	_music_volume = _preference("music_volume", 0.55)
	_sfx_volume = _preference("sfx_volume", 0.85)
	var master_index: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_index, Settings.master_volume <= 0.0)
	AudioServer.set_bus_volume_db(master_index, linear_to_db(maxf(Settings.master_volume, 0.0001)))
	for voice: AudioStreamPlayer in _voices:
		voice.volume_db = float(voice.get_meta("event_gain", -10.0)) + linear_to_db(maxf(_sfx_volume, 0.0001))
	_process(0.0)
