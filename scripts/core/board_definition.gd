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
