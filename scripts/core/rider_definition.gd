class_name RiderDefinition
extends Resource
## Static description of a playable rider (stats 1..5, model, portrait, personality).

@export var id: StringName
@export var display_name: String = ""
@export_range(1, 5) var speed: int = 3
@export_range(1, 5) var control: int = 3
@export_range(1, 5) var jump: int = 3
@export_range(1, 5) var accel: int = 3
@export_range(1, 5) var resist: int = 3
@export_file("*.glb") var model_path: String = ""
@export_file("*.png") var portrait_path: String = ""
@export var color: Color = Color.WHITE
@export var tagline_pt: String = ""
@export var tagline_en: String = ""
@export var unlock: String = "start"  ## "start" or "<cup>:<medal>" e.g. "cup1:silver"

func stat_mod(value: int) -> float:
	## Maps a 1..5 stat to a multiplier around 1.0 (+-8%).
	return 1.0 + (float(value) - 3.0) * 0.04
