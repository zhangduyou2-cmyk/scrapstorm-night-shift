class_name ScrapMaps
extends RefCounted
## Immutable map descriptions. Runtime hazards belong to StandardDirector.

static func ids() -> Array[String]:
	return ["yard", "foundry", "reactor"]


static func get_map(id: String) -> Dictionary:
	var maps: Dictionary = {
		"yard": {
			"name_key": "MAP_YARD", "desc_key": "MAP_YARD_DESC", "boss_name_key": "BOSS_IRON_MAW",
			"color": Color("ddb962"), "floor": Color("17282c"), "mechanic_key": "MECHANIC_YARD",
			"obstacles": [Rect2(237, 236, 70, 56), Rect2(973, 236, 70, 56), Rect2(237, 500, 70, 56), Rect2(973, 500, 70, 56)],
			"boss_health": 4200.0, "music": "yard",
			"elite_name_key": "ELITE_MAGNET_HAULER", "counter_key": "COUNTER_YARD", "interaction_key": "INTERACT_YARD",
		},
		"foundry": {
			"name_key": "MAP_FOUNDRY", "desc_key": "MAP_FOUNDRY_DESC", "boss_name_key": "BOSS_FURNACE_WARDEN",
			"color": Color("ffa364"), "floor": Color("302421"), "mechanic_key": "MECHANIC_FOUNDRY",
			"obstacles": [Rect2(180, 240, 95, 70), Rect2(1005, 475, 95, 70), Rect2(580, 132, 120, 65), Rect2(580, 584, 120, 65)],
			"boss_health": 5600.0, "music": "foundry",
			"elite_name_key": "ELITE_SLAG_CRAWLER", "counter_key": "COUNTER_FOUNDRY", "interaction_key": "INTERACT_FOUNDRY",
		},
		"reactor": {
			"name_key": "MAP_REACTOR", "desc_key": "MAP_REACTOR_DESC", "boss_name_key": "BOSS_ARC_REGENT",
			"color": Color("96b7ff"), "floor": Color("19243b"), "mechanic_key": "MECHANIC_REACTOR",
			"obstacles": [Rect2(435, 275, 65, 68), Rect2(780, 275, 65, 68), Rect2(435, 457, 65, 68), Rect2(780, 457, 65, 68)],
			"boss_health": 2600.0, "music": "reactor",
			"elite_name_key": "ELITE_RELAY_SENTINEL", "counter_key": "COUNTER_REACTOR", "interaction_key": "INTERACT_REACTOR",
		},
	}
	var valid_id: String = id if maps.has(id) else "yard"
	var result: Dictionary = maps[valid_id].duplicate(true)
	result["id"] = valid_id
	return result


static func wave_key(wave: int) -> String:
	return ["STAGE_RECLAIM", "STAGE_PINCER", "STAGE_BREAKTHROUGH", "STAGE_SALVAGE", "STAGE_SIEGE", "STAGE_BOSS"][clampi(wave - 1, 0, 5)]


static func stage_duration(wave: int) -> float:
	return float([120, 165, 180, 195, 210][clampi(wave - 1, 0, 4)])
