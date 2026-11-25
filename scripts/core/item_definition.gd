class_name ItemDefinition
extends Resource
## Power-up description. Slot "offense" (F / Y) or "utility" (R / B).

@export var id: StringName
@export var display_name: String = ""
@export var display_name_en: String = ""
@export_enum("offense", "utility") var slot: String = "offense"
@export_file("*.png") var icon_path: String = ""
@export var model_node: String = ""
@export var duration: float = 0.0
## Weight per race position (1st..4th) for the roll at an item station.
@export var weights: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1])
@export var description_pt: String = ""
@export var counterplay_pt: String = ""
