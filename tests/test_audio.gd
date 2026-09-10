extends SceneTree
## Audio resource/mixer regression, deliberately distinct from subjective listening.

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)


func _run() -> void:
	var bank: Node = root.get_node("SoundBank")
	var settings: Node = root.get_node("Settings")
	bank.set_process(false)
	verify(bank._voices.size() == 8 and bank.get_music_state().music_players == 6, "Voice pools are bounded at 8 SFX and 6 crossfade music players")
	verify(bank._streams.size() == 22, "All 22 sound effects load")
	verify(bank._music_streams.size() == 3, "All three map scores load")
	var durations: Dictionary = {}
	var resource_ids: Array[int] = []
	for map_id: String in ["yard", "foundry", "reactor"]:
		var layers: Array = bank._music_streams[map_id]
		verify(layers.size() == 3 and layers.all(func(item: Variant) -> bool: return item is AudioStreamOggVorbis), "%s has three Ogg music layers" % map_id)
		var reference: float = layers[0].get_length()
		verify(reference >= 59.9 and reference <= 100.0, "%s score is a complete 60-100 second loop" % map_id)
		verify(layers.all(func(item: AudioStreamOggVorbis) -> bool: return item.loop and absf(item.get_length() - reference) < 0.001), "%s layers loop and share an exact duration" % map_id)
		durations[map_id] = reference
		for layer: AudioStreamOggVorbis in layers:
			resource_ids.append(layer.get_instance_id())
	verify(resource_ids.size() == _unique_count(resource_ids), "Every map/layer uses its own stream resource")
	verify(not bank.get_music_state().unlocked, "Headless startup does not claim an audio gesture")
	var move := InputEventMouseMotion.new()
	bank._input(move)
	verify(not bank.get_music_state().unlocked, "Mouse motion cannot unlock browser audio")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	bank._input(click)
	verify(bank.get_music_state().unlocked and bank.get_music_state().bank_starts == 1, "Pressed input unlocks a single synchronized music bank")
	bank.unlock_audio()
	verify(bank.get_music_state().bank_starts == 1, "Repeated unlock does not restart music")
	bank.set_context("yard", "combat")
	var before: Dictionary = bank.get_music_state()
	for count: int in range(40):
		bank.set_context("yard", "combat")
	verify(bank.get_music_state() == before, "Repeated context is idempotent")
	bank._process(5.0)
	var active: int = bank.get_music_state().active_bank
	var combat_gain: float = bank._banks[active]["gains"][1]
	bank.set_context("yard", "shop")
	bank._process(5.0)
	verify(bank._banks[active]["gains"][1] < combat_gain * 0.25, "Shop reduces percussion while keeping a harmonic bed")
	verify(bank.get_music_state().bank_starts == 1, "Phase changes preserve the same playback start")
	bank.set_context("yard", "boss")
	bank._process(5.0)
	verify(bank._banks[active]["gains"][2] > 0.5, "Boss introduces the extra synchronized ostinato/percussion layer")
	bank.set_context("yard", "pause")
	bank._process(5.0)
	verify(bank._banks[active]["gains"][1] < .001 and bank._banks[active]["gains"][2] < .001, "Pause ducks percussion and boss layer")
	verify(bank._banks[active]["gains"][0] > .17 and bank._banks[active]["gains"][0] < .19, "Pause keeps only a quiet musical bed")
	bank.set_context("foundry", "combat")
	var next_active: int = bank.get_music_state().active_bank
	verify(next_active != active and bank._banks[active]["target"] == 0.0, "Changing map crossfades into the other fixed bank")
	verify(bank._banks[next_active]["fade"] == 0.0, "New map starts at zero gain")
	bank._process(0.3)
	verify(bank._banks[next_active]["fade"] > 0.0 and bank._banks[next_active]["fade"] < 1.0, "Music fade uses a gradual gain ramp")
	bank._process(3.0)
	verify(bank._banks[active]["fade"] == 0.0 and bank._banks[next_active]["fade"] == 1.0, "Crossfade settles and retires the previous bank")
	bank.set_context("missing-map", "missing-phase")
	verify(bank.get_music_state().map_id == "yard" and bank.get_music_state().phase == "menu", "Invalid contexts fall back to the quiet yard menu")
	var original_master: float = settings.master_volume
	var original_music: float = settings.music_volume
	var original_sfx: float = settings.sfx_volume
	settings.music_volume = 0.0
	settings.sfx_volume = .8
	settings.preferences_changed.emit()
	bank._process(4.0)
	var music_player: AudioStreamPlayer = bank._banks[bank.get_music_state().active_bank]["players"][0]
	verify(music_player.volume_db <= -79.0 and bank.get_music_state().sfx_volume == .8, "Music can mute independently of SFX")
	settings.music_volume = .7
	settings.sfx_volume = 0.0
	settings.preferences_changed.emit()
	verify(bank.get_music_state().music_volume == .7 and bank.get_music_state().sfx_volume == 0.0, "SFX can mute independently of music")
	settings.master_volume = 0.0
	settings.preferences_changed.emit()
	verify(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Master mute applies to music and effects")
	settings.music_volume = NAN
	settings.sfx_volume = 9.0
	settings.preferences_changed.emit()
	verify(is_finite(bank.get_music_state().music_volume) and bank.get_music_state().sfx_volume == 1.0, "Invalid mix values remain finite and clamped")
	settings.master_volume = original_master
	settings.music_volume = original_music
	settings.sfx_volume = original_sfx
	settings.preferences_changed.emit()
	verify(bank.VARIED_EVENTS.has("collect") and not bank.VARIED_EVENTS.has("warning"), "Repetitive effects vary subtly while safety warnings keep fixed pitch")
	verify(bank.IMPORTANT_EVENTS.has("warning") and bank.IMPORTANT_EVENTS.has("boss_charge"), "Critical warnings have priority over automatic tool sounds")
	var new_events: Array[String] = ["skill_pulse", "skill_singularity", "skill_overdrive", "singularity_burst", "skill_ready", "boss_break", "evolve", "install"]
	var effect_resources: Array[int] = []
	for event: String in new_events:
		var effect: AudioStream = bank._streams.get(event)
		verify(effect is AudioStreamWAV and effect.get_length() >= 0.25 and effect.get_length() < 1.0, "%s is a complete short WAV resource" % event)
		verify(bank.COOLDOWNS.has(event) and float(bank.COOLDOWNS[event]) > 0.0 and bank.GAINS_DB.has(event) and float(bank.GAINS_DB[event]) <= -5.0, "%s has bounded playback rate and mix headroom" % event)
		verify(bank.IMPORTANT_EVENTS.has(event) and not bank.VARIED_EVENTS.has(event), "%s keeps recognizable fixed pitch and deliberate-action priority" % event)
		if effect != null:
			effect_resources.append(effect.get_instance_id())
	verify(effect_resources.size() == 8 and _unique_count(effect_resources) == 8, "Each new feedback event uses a distinct resource")
	var full: Array[String] = ["warning", "skill_pulse", "foam", "arc", "collect", "enemy_down", "hit", "install"]
	verify(bank._voice_index("foam", full) == -1 and bank._voice_index("arc", full) == -1, "Automatic tools never steal a playing voice under saturation")
	var warning_slot: int = bank._voice_index("warning", full)
	verify(warning_slot >= 0 and full[warning_slot] in ["foam", "arc", "collect", "enemy_down"], "Warning displaces a low-priority effect instead of another warning")
	var cast_slot: int = bank._voice_index("skill_overdrive", full)
	verify(cast_slot >= 0 and full[cast_slot] != "warning", "Skill feedback leaves an active safety warning intact")
	var safety_full: Array[String] = ["warning", "boss_charge", "warning", "boss_charge", "warning", "boss_charge", "warning", "boss_charge"]
	verify(bank._voice_index("evolve", safety_full) == -1 and bank._voice_index("install", safety_full) == -1, "Reward and install cues cannot preempt a fully occupied warning pool")
	full[5] = ""
	verify(bank._voice_index("arc", full) == 5 and bank._voice_index("skill_ready", full) == 5, "All event types prefer an idle voice before replacing feedback")
	verify(bank._voice_index("boss_charge", safety_full) >= 0, "A new critical charge cue is still eligible when the pool is all critical")
	bank.stop_all()
	verify(bank._voices.all(func(item: AudioStreamPlayer) -> bool: return item.stream == null), "Stopping releases effect playback resources")
	verify(bank._banks.all(func(item: Dictionary) -> bool: return item["players"].all(func(player: AudioStreamPlayer) -> bool: return player.stream == null)), "Stopping releases every music playback resource")
	var before_shutdown: Dictionary = bank.get_music_state()
	await bank.shutdown()
	bank.set_context("reactor", "boss")
	bank.unlock_audio()
	bank.play("warning")
	verify(bank.get_music_state() == before_shutdown, "Late gameplay contexts cannot restart music during shutdown")
	verify(bank._voices.all(func(item: AudioStreamPlayer) -> bool: return item.stream == null), "Late sound events cannot create playback during shutdown")
	print("AUDIO_TEST ", JSON.stringify({"checks": checks, "failures": failures, "durations": durations, "note": "Resource and state tests do not replace listening."}))
	quit(0 if failures.is_empty() else 1)


func _unique_count(values: Array[int]) -> int:
	var found: Dictionary = {}
	for value: int in values:
		found[value] = true
	return found.size()
