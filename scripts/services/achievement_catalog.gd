class_name AchievementCatalog
extends RefCounted
## Original milestones and cosmetic rewards. No reward changes combat statistics.
const REWARDS: Dictionary = {
  "skin_cobalt": {
    "kind": "skin",
    "value": "cobalt",
    "color": "74e7ff",
    "name_key": "GARAGE_SKIN_COBALT"
  },
  "skin_aurora": {
    "kind": "skin",
    "value": "aurora",
    "color": "8af0bf",
    "name_key": "GARAGE_SKIN_AURORA"
  },
  "color_ember": {
    "kind": "skill_color",
    "value": "ember",
    "color": "ff8c4b",
    "name_key": "GARAGE_COLOR_EMBER"
  },
  "color_prism": {
    "kind": "skill_color",
    "value": "prism",
    "color": "f6a9ef",
    "name_key": "GARAGE_COLOR_PRISM"
  },
  "title_shiftbreaker": {
    "kind": "title",
    "value": "shiftbreaker",
    "color": "ffc04d",
    "name_key": "TITLE_SHIFTBREAKER"
  },
  "title_voidwalker": {
    "kind": "title",
    "value": "voidwalker",
    "color": "bda3e6",
    "name_key": "TITLE_VOIDWALKER"
  },
  "title_stormforged": {
    "kind": "title",
    "value": "stormforged",
    "color": "ffc04d",
    "name_key": "TITLE_STORMFORGED"
  },
  "title_nightlegend": {
    "kind": "title",
    "value": "nightlegend",
    "color": "ffd987",
    "name_key": "TITLE_NIGHTLEGEND"
  }
}
const DEFINITIONS: Dictionary = {
  "first_shift": {
    "name_key": "ACH_FIRST_SHIFT",
    "desc_key": "ACH_FIRST_SHIFT_DESC",
    "metric": "standard_clears",
    "target": 1,
    "coins": 20,
    "reward": "title_shiftbreaker",
    "color": "ffc04d"
  },
  "yard_operator": {
    "name_key": "ACH_YARD_OPERATOR",
    "desc_key": "ACH_YARD_OPERATOR_DESC",
    "metric": "yard_clear",
    "target": 1,
    "coins": 15,
    "reward": "",
    "color": "b6d18b"
  },
  "foundry_operator": {
    "name_key": "ACH_FOUNDRY_OPERATOR",
    "desc_key": "ACH_FOUNDRY_OPERATOR_DESC",
    "metric": "foundry_clear",
    "target": 1,
    "coins": 15,
    "reward": "",
    "color": "f07842"
  },
  "reactor_operator": {
    "name_key": "ACH_REACTOR_OPERATOR",
    "desc_key": "ACH_REACTOR_OPERATOR_DESC",
    "metric": "reactor_clear",
    "target": 1,
    "coins": 15,
    "reward": "",
    "color": "74e7ff"
  },
  "sector_sweep": {
    "name_key": "ACH_SECTOR_SWEEP",
    "desc_key": "ACH_SECTOR_SWEEP_DESC",
    "metric": "sectors",
    "target": 3,
    "coins": 40,
    "reward": "skin_cobalt",
    "color": "74e7ff"
  },
  "flawless_shift": {
    "name_key": "ACH_FLAWLESS_SHIFT",
    "desc_key": "ACH_FLAWLESS_SHIFT_DESC",
    "metric": "clean_standard",
    "target": 1,
    "coins": 60,
    "reward": "skin_aurora",
    "color": "8af0bf"
  },
  "boss_precision": {
    "name_key": "ACH_BOSS_PRECISION",
    "desc_key": "ACH_BOSS_PRECISION_DESC",
    "metric": "clean_bosses",
    "target": 1,
    "coins": 25,
    "reward": "color_ember",
    "color": "ff8c4b"
  },
  "overtime_3": {
    "name_key": "ACH_OVERTIME_3",
    "desc_key": "ACH_OVERTIME_3_DESC",
    "metric": "best_endless_rooms",
    "target": 3,
    "coins": 20,
    "reward": "",
    "color": "c89b72"
  },
  "overtime_6": {
    "name_key": "ACH_OVERTIME_6",
    "desc_key": "ACH_OVERTIME_6_DESC",
    "metric": "best_endless_rooms",
    "target": 6,
    "coins": 30,
    "reward": "title_voidwalker",
    "color": "bda3e6"
  },
  "overtime_12": {
    "name_key": "ACH_OVERTIME_12",
    "desc_key": "ACH_OVERTIME_12_DESC",
    "metric": "best_endless_rooms",
    "target": 12,
    "coins": 50,
    "reward": "color_prism",
    "color": "f6a9ef"
  },
  "overtime_24": {
    "name_key": "ACH_OVERTIME_24",
    "desc_key": "ACH_OVERTIME_24_DESC",
    "metric": "best_endless_rooms",
    "target": 24,
    "coins": 100,
    "reward": "title_nightlegend",
    "color": "ffd987"
  },
  "overtime_boss": {
    "name_key": "ACH_OVERTIME_BOSS",
    "desc_key": "ACH_OVERTIME_BOSS_DESC",
    "metric": "endless_bosses",
    "target": 1,
    "coins": 20,
    "reward": "",
    "color": "f07842"
  },
  "safe_extraction": {
    "name_key": "ACH_SAFE_EXTRACTION",
    "desc_key": "ACH_SAFE_EXTRACTION_DESC",
    "metric": "extractions",
    "target": 1,
    "coins": 20,
    "reward": "",
    "color": "8af0bf"
  },
  "stormforge": {
    "name_key": "ACH_STORMFORGE",
    "desc_key": "ACH_STORMFORGE_DESC",
    "metric": "evolutions",
    "target": 3,
    "coins": 60,
    "reward": "title_stormforged",
    "color": "ffc04d"
  },
  "scrap_collector": {
    "name_key": "ACH_SCRAP_COLLECTOR",
    "desc_key": "ACH_SCRAP_COLLECTOR_DESC",
    "metric": "total_scrap",
    "target": 10000,
    "coins": 40,
    "reward": "",
    "color": "a6dbad"
  },
  "veteran": {
    "name_key": "ACH_VETERAN",
    "desc_key": "ACH_VETERAN_DESC",
    "metric": "total_kills",
    "target": 2500,
    "coins": 50,
    "reward": "",
    "color": "e6b0a1"
  }
}
const EVOLUTIONS: Array[String] = ["steel_storm", "conduction_grid", "compression_blast"]

const ALL_EVOLUTIONS: Array[String] = ["steel_storm", "conduction_grid", "compression_blast", "prism_relay", "hunter_swarm", "ordnance_chain"]

static func progress(id: String, profile: Dictionary) -> int:
	if not DEFINITIONS.has(id):
		return 0
	var metric: String = DEFINITIONS[id].metric
	var records: Dictionary = profile.get("records", {})
	var career: Dictionary = profile.get("career", {})
	if metric == "standard_clears" or metric == "sectors":
		var total: int = 0
		for sector: String in ["yard", "foundry", "reactor"]:
			var clears: int = int(records.get(sector, {}).get("clears", 0))
			total += mini(clears, 1) if metric == "sectors" else clears
		return total
	if metric.ends_with("_clear"):
		return int(records.get(metric.trim_suffix("_clear"), {}).get("clears", 0))
	if metric == "evolutions":
		var found: int = 0
		for evolution: String in EVOLUTIONS:
			if evolution in career.get("evolutions", []):
				found += 1
		return found
	return int(career.get(metric, 0))

static func status(id: String, profile: Dictionary) -> Dictionary:
	var result: Dictionary = DEFINITIONS[id].duplicate(true)
	result["id"] = id
	result["progress"] = mini(progress(id, profile), int(result.target))
	result["claimed"] = profile.get("achievements", {}).has(id)
	result["unlocked_at"] = int(profile.get("achievements", {}).get(id, {}).get("unlocked_at", 0))
	return result
