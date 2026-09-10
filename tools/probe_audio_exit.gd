extends SceneTree
## Native regression: play actual Ogg voices and retire them before process exit.
## Use --test-settings. --immediate reproduces the unsafe old fixture exit.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sound: Node = root.get_node("SoundBank")
	sound.set_context("yard", "combat")
	sound.unlock_audio()
	await create_timer(.75).timeout
	var active: int = sound.get_music_state().active_bank
	var playing: int = 0
	for player: AudioStreamPlayer in sound._banks[active]["players"]:
		if player.playing:
			playing += 1
	print("AUDIO_EXIT_PROBE ", JSON.stringify({"headless": DisplayServer.get_name() == "headless", "playing_layers": playing}))
	if OS.get_cmdline_user_args().has("--immediate"):
		sound.stop_all()
	else:
		await sound.shutdown()
	quit(0)
