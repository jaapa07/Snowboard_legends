class_name BoardDefinition
extends Resource
## Board stats: modifiers are capped to +-12% (spec section 8).

@export var id: StringName
@export var display_name: String = ""
@export_enum("balanced", "speed", "freestyle", "carving") var category: String = "balanced"
@export_range(-0.12, 0.12) var speed_mod: float = 0.0
@export_range(-0.12, 0.12) var control_mod: float = 0.0
@export_range(-0.12, 0.12) var jump_mod: float = 0.0
@export_range(-0.12, 0.12) var accel_mod: float = 0.0
@export_range(-0.12, 0.12) var spin_mod: float = 0.0
@export var price: int = 0
@export var unlock: String = "start"
@export var node_name: String = ""
@export_file("*.png") var thumbnail_path: String = ""
@export var description_pt: String = ""
@export var description_en: String = ""

const MAX_LEVEL := 3
const MOD_CAP := 0.12

static func upgrade_cost(level: int) -> int:
	## credits for going from `level` to `level + 1`
	return [150, 300, 450][clampi(level, 0, 2)]

func mods(level: int = 0) -> Dictionary:
	## Attribute modifiers including garage upgrades. Each level improves the board's own specialty
	## (+2 % on the category stat, +1 % on everything for balanced boards), always capped at ±12 % (spec §8).
	var m := {"speed": speed_mod, "control": control_mod, "jump": jump_mod, "accel": accel_mod, "spin": spin_mod}
	var lv := clampi(level, 0, MAX_LEVEL)
	var gains: Dictionary = {"speed": {"speed": 0.02, "accel": 0.01}, "carving": {"control": 0.02, "accel": 0.01}, "freestyle": {"jump": 0.015, "spin": 0.015},
		"balanced": {"speed": 0.01, "control": 0.01, "jump": 0.01, "accel": 0.01, "spin": 0.01}}[category]
	for k in gains:
		m[k] = minf(MOD_CAP, float(m[k]) + float(gains[k]) * lv)
	return m
