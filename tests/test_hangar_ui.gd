extends SceneTree
## Isolated UI fixtures. No earned-currency, gameplay difficulty or human UX claims.
const Mission = preload("res://scripts/ui/mission_panel.gd")
const Garage = preload("res://scripts/ui/garage_panel.gd")
const Shop = preload("res://scripts/ui/shop_panel.gd")
const Profile = preload("res://scripts/services/player_profile.gd")
const Loadout = preload("res://scripts/game/run_loadout.gd")
const Ability = preload("res://scripts/game/player_ability.gd")
var checks: int = 0
var failures: Array[String] = []
var capture: bool = false
var shell: Control
var profile: RefCounted
var test_path: String

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	if "--test-settings" not in OS.get_cmdline_user_args():
		push_error("This fixture requires --test-settings")
		quit(1)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	test_path = "user://hangar-ui-fixture-%d.json" % OS.get_process_id()
	profile = Profile.new(test_path)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	shell = Control.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	theme.default_font_size = 16
	shell.theme = theme
	root.add_child(shell)
	var mission: Control = Mission.new()
	shell.add_child(mission)
	mission.present(profile)
	var deployed: Array[String] = []
	mission.deploy_requested.connect(func(id: String) -> void: deployed.append(id))
	verify(mission.step == 0 and mission.cards.size() == 3, "Dispatch opens sector selection")
	for index: int in range(3):
		mission.cards[index].button.pressed.emit()
		verify(mission.sector_preview.map_id == mission.selected, "Sector selection changes the actual large environment preview")
		await snap("mission-" + mission.selected + "-en")
	mission.deploy.pressed.emit()
	verify(mission.step == 1 and deployed.is_empty(), "First dispatch action opens preparation without starting combat")
	verify(profile.owns("skill_pulse") and profile.owns("skill_overdrive"), "Fresh profile offers two free active choices")
	mission._select_skill("overdrive")
	verify(profile.data.selected.skill == "overdrive" and mission.rig_preview.setup.skill == "overdrive", "Owned skill choice equips and previews the same next-run skill")
	var restored: RefCounted = Profile.new(test_path)
	if restored.data.selected.skill != "overdrive":
		print("HANGAR_PROFILE_RESTORE_FAILURE ", JSON.stringify({"saved": profile.data, "restored": restored.data, "error": restored.last_error, "path": test_path}))
	verify(restored.data.selected.skill == "overdrive", "Dispatch equipment selection persists transactionally")
	mission._select_skill("singularity")
	verify(profile.data.selected.skill == "overdrive" and mission.rig_preview.setup.skill == "singularity", "Locked skill can be previewed without equipping or unlocking it")
	verify(mission.preview_label.text == tr("HANGAR_PREVIEW_ONLY"), "Locked preview explicitly identifies its preview-only status")
	verify(mission.cosmetic_buttons.skin_arctic.disabled and mission.cosmetic_buttons.color_violet.disabled, "Unowned cosmetics cannot be equipped from dispatch")
	mission._select_skill("overdrive")
	await snap("loadout-en")
	mission.deploy.pressed.emit()
	verify(deployed == ["reactor"], "Second dispatch action emits exactly the selected sector")
	mission._back()
	verify(mission.step == 0, "Preparation back button returns to map selection")
	root.get_node("Settings").set_locale("zh_CN")
	mission.refresh()
	root.size = Vector2i(960, 540)
	await snap("mission-reactor-zh-960")
	mission._advance()
	await snap("loadout-zh-960")
	mission.queue_free()
	await process_frame
	root.size = Vector2i(1280, 720)
	root.get_node("Settings").set_locale("en")
	var garage: Control = Garage.new()
	shell.add_child(garage)
	garage.present(profile)
	verify(garage.category == "skill", "Workshop opens its blueprint category")
	garage.selected_id = "skill_singularity"
	garage._preview()
	garage.refresh()
	verify(garage.purchase_button.disabled and not profile.owns("skill_singularity"), "Unaffordable unlock remains disabled while its demonstration is available")
	garage.selected_id = "skin_arctic"
	garage._track()
	verify(profile.data.target_unlock == "skin_arctic", "Explicit track action changes the actual saved unlock target")
	garage.selected_id = "skill_singularity"
	garage._track()
	profile.data.coins = 180 # Isolated visual/purchase fixture, never a gameplay reward.
	verify(profile.save(), "Fixture profile can be written to its isolated path")
	garage.refresh()
	verify(garage.target_progress.size.y <= 6, "Unlock progress remains a thin meter without covering footer controls")
	await snap("garage-locked-en")
	garage._purchase_selected()
	verify(profile.data.coins == 20 and profile.data.selected.skill == "singularity", "Unlock deducts the precise catalogue price and equips it")
	verify(garage.purchase_button.disabled and garage.purchase_button.text == tr("GARAGE_ACTIVE"), "Equipped state is distinct from locked state")
	verify(profile.data.target_unlock.is_empty(), "Purchased tracked target clears from the progress display")
	garage.preview_layer.time = 2.1
	await snap("garage-unlocked-en")
	root.get_node("Settings").set_locale("zh_CN")
	garage.refresh()
	root.size = Vector2i(960, 540)
	await snap("garage-zh-960")
	garage.queue_free()
	await process_frame
	root.size = Vector2i(1280, 720)
	root.get_node("Settings").set_locale("en")
	var loadout: RefCounted = Loadout.new()
	loadout.reset(923)
	loadout.weapons.arc = 2
	loadout.mods.torque = 1
	var offers: Array = loadout.generate_offers(2)
	var ability: RefCounted = Ability.new()
	ability.configure({"skill": "overdrive"})
	var stats: Dictionary = {"wave": 2, "currency": 250, "loadout": {"weapons": loadout.weapons, "mods": loadout.mods}, "ability_id": "overdrive", "ability_branches": ability.get_branch_options(2), "evolutions": loadout.get_evolutions(), "sell_options": loadout.get_sell_options(), "can_reroll": true, "reroll_cost": 18}
	var shop: Control = Shop.new()
	shell.add_child(shop)
	shop.present(offers, stats, {"wave": 2, "earned_scrap": 116, "bonus": 35, "repaired": 10})
	verify(shop.cards.size() == 3 and shop.slot_ids == ["brush", "arc"], "Supply bench shows three offers and the actual installed tools")
	verify(shop.sell_buttons[1].visible and not shop.sell_buttons[1].disabled and not shop.sell_buttons[0].visible, "Only the permitted non-brush tool exposes the sell action")
	var sale_requests: Array[String] = []
	shop.sell_requested.connect(func(id: String) -> void: sale_requests.append(id))
	shop._sell(1)
	verify(sale_requests == ["arc"], "Selling sends one explicit world-owned request")
	var branch_requests: Array[String] = []
	shop.branch_requested.connect(func(id: String) -> void: branch_requests.append(id))
	shop._branch(0)
	verify(branch_requests == ["overdrive_turbine"], "Branch selection sends the exact offered branch ID")
	await snap("shop-branches-en")
	ability.choose_branch("overdrive_turbine", 2)
	stats.ability_branches = ability.get_branch_options(2)
	stats.ability_branch_rank = 1
	shop.branch_result({"ok": true, "reason": "ABILITY_BRANCH_SELECTED"}, offers, stats)
	verify(shop.branch_cards[0].button.disabled and shop.branch_cards[1].button.disabled, "Chosen branch and mutually exclusive alternative both disable after this shop decision")
	verify(shop.branch_cards[0].description.text == tr("BRANCH_OVERDRIVE_TURBINE_DESC"), "Installed rank-one branch describes current power rather than a future rank-two upgrade")
	var before: Dictionary = profile.data.duplicate(true)
	shop.install_index = 1
	shop.purchase_result({"ok": true}, offers, stats)
	verify(shop.install_fx > 0 and profile.data == before, "Installation animation has no profile side effects")
	await snap("shop-installed-en")
	root.get_node("Settings").set_locale("zh_CN")
	shop.refresh()
	root.size = Vector2i(960, 540)
	await snap("shop-zh-960")
	shop.queue_free()
	shell.queue_free()
	await root.get_node("SoundBank").shutdown()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(test_path + suffix)
	print("HANGAR_UI_TEST ", JSON.stringify({"checks": checks, "failures": failures, "captured": capture}))
	quit(0 if failures.is_empty() else 1)

func snap(id: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures/v04")
	var error: Error = root.get_texture().get_image().save_png("res://captures/v04/" + id + ".png")
	verify(error == OK, "Save visual fixture " + id)
