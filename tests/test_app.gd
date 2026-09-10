extends SceneTree
## Integration assertions for app transitions and localized persistent preferences.

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
	var settings: Node = root.get_node("Settings")
	var original_path: String = settings.get_preferences_path()
	var previous := {"locale": settings.locale, "volume": settings.master_volume, "effects": settings.effects_enabled}
	var fixture_path := "user://settings-app-test-%d.cfg" % Time.get_ticks_usec()
	settings.set("_config_path", fixture_path)
	settings.set_locale("en")
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	verify(scene.mode == "menu" and scene.menu.visible, "App starts in hangar")
	verify(settings.locale == "en" and TranslationServer.get_locale() == "en", "Default language is English")
	settings.set_locale("zh_CN")
	verify(scene.language_option.selected == 1, "Language control follows Chinese preference")
	verify(tr("START_SHIFT") != "START_SHIFT" and tr("START_SHIFT") != "START YOUR SHIFT", "Chinese translation resolves")
	var cfg := ConfigFile.new()
	verify(cfg.load(fixture_path) == OK and cfg.get_value("preferences", "locale") == "zh_CN", "Chinese preference persisted")
	settings.set_locale("xx_invalid")
	verify(settings.locale == "zh_CN", "Unsupported locale is rejected")
	settings.set_volume(-3.0)
	verify(settings.master_volume == 0.0, "Volume clamps lower bound")
	settings.set_volume(8.0)
	verify(settings.master_volume == 1.0, "Volume clamps upper bound")
	settings.set_volume(INF)
	verify(settings.master_volume == 1.0, "Nonfinite volume rejected")
	settings.set_effects(false)
	cfg.load(fixture_path)
	verify(cfg.get_value("preferences", "effects_enabled") == false, "Effect preference persisted")
	scene._start_run()
	verify(scene.mode == "playing" and scene.world.active, "Start enters active gameplay")
	scene._pause_run()
	var stopped_at: float = scene.world.elapsed
	scene.world._physics_process(1.0)
	verify(scene.mode == "pause" and scene.world.elapsed == stopped_at, "Pause freezes world time")
	scene._open_settings()
	verify(scene.mode == "settings" and scene.world.paused, "Pause settings keep combat frozen")
	scene._close_settings()
	verify(scene.mode == "pause", "Settings return to pause screen")
	scene._resume_run()
	verify(scene.mode == "playing" and not scene.world.paused, "Resume restores active play")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	verify(scene.mode == "pause" and scene.world.paused, "Focus loss pauses play")
	scene._resume_run()
	scene.world.debug_damage_player(1000.0)
	scene.world._physics_process(1.0 / 60.0)
	verify(scene.mode == "result" and scene.final_stats.get("won") == false, "Death enters loss screen")
	scene._update_hud(scene.world.get_stats())
	verify(scene.final_stats.has("won"), "Late HUD update preserves final result")
	settings.set_locale("en")
	verify(scene.result_title.text == "UNIT OFFLINE", "Result relocalizes after final stats update")
	scene._start_run()
	verify(scene.final_stats.is_empty() and scene.world.health == 100.0 and scene.world.currency == 0, "Restart clears result and resources")
	scene._return_to_menu()
	verify(scene.mode == "menu" and not scene.world.active, "Return to hangar stops run")
	scene._open_settings()
	scene._close_settings()
	verify(scene.mode == "menu", "Menu settings return to hangar")
	settings.set_locale(previous.locale)
	settings.set_volume(previous.volume)
	settings.set_effects(previous.effects)
	settings.set("_config_path", original_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	root.get_node("SoundBank").stop_all()
	scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("APP_TEST ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
