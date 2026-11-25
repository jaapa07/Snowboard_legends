class_name TrackDefinition
extends Resource
## Course reference: authored GLB + runtime data JSON + presentation.

@export var id: StringName
@export var display_name: String = ""
@export var display_name_en: String = ""
@export_file("*.glb") var scene_path: String = ""
@export_file("*.json") var data_path: String = ""
@export_file("*.ogg") var music_path: String = ""
@export_file("*.png") var map_path: String = ""
@export var cup: int = 1
@export var length_m: float = 0.0
@export var description_pt: String = ""
@export var description_en: String = ""
@export var campaign: bool = true
@export_range(1, 9) var default_laps: int = 5   ## descents per race on this course (tuned for ~3-4 min races)
