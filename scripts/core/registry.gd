extends Node
## Typed catalogue of all game content. Explicit id lists (exported builds remap .tres files).

const RIDER_IDS: Array[StringName] = [&"niko", &"mika", &"taro", &"luna", &"boro", &"yuki", &"zed", &"pippa", &"kaito"]
const BOARD_IDS: Array[StringName] = [&"starter", &"carver", &"float", &"rocket", &"grip", &"twin", &"powder", &"rail", &"alpine", &"aurora", &"comet", &"legend"]
const TRACK_IDS: Array[StringName] = [&"vale_pinheiros", &"lago_cristal", &"pico_vulcanico", &"festival_boreal", &"floresta_gigante", &"estacao_abandonada", &"tempestade_polar", &"cume_celestial"]
const EXTRA_TRACK_IDS: Array[StringName] = [&"parque_manobras"]
const ITEM_IDS: Array[StringName] = [&"snowball", &"icemine", &"penguin", &"fog", &"wave", &"gust", &"shield", &"spring", &"magnet", &"repair", &"comet", &"whirl"]
const CUPS := [
	{"id": "cup1", "name": "Copa Floco", "name_en": "Flake Cup", "tracks": [&"vale_pinheiros", &"lago_cristal"]},
	{"id": "cup2", "name": "Copa Brasa", "name_en": "Ember Cup", "tracks": [&"pico_vulcanico", &"festival_boreal"]},
	{"id": "cup3", "name": "Copa Raiz", "name_en": "Root Cup", "tracks": [&"floresta_gigante", &"estacao_abandonada"]},
	{"id": "cup4", "name": "Copa Lenda", "name_en": "Legend Cup", "tracks": [&"tempestade_polar", &"cume_celestial"]},
]

var riders: Dictionary = {}
var boards: Dictionary = {}
var tracks: Dictionary = {}
var items: Dictionary = {}
var _glb_cache: Dictionary = {}

func _ready() -> void:
	for id in RIDER_IDS:
		riders[id] = load("res://resources/riders/%s.tres" % id) as RiderDefinition
	for id in BOARD_IDS:
		boards[id] = load("res://resources/boards/%s.tres" % id) as BoardDefinition
	for id in TRACK_IDS + EXTRA_TRACK_IDS:
		tracks[id] = load("res://resources/tracks/%s.tres" % id) as TrackDefinition
	for id in ITEM_IDS:
		items[id] = load("res://resources/items/%s.tres" % id) as ItemDefinition

func rider(id: StringName) -> RiderDefinition:
	return riders.get(id)

func board(id: StringName) -> BoardDefinition:
	return boards.get(id)

func track(id: StringName) -> TrackDefinition:
	return tracks.get(id)

func item(id: StringName) -> ItemDefinition:
	return items.get(id)

func cup_of(track_id: StringName) -> int:
	for i in CUPS.size():
		if track_id in CUPS[i].tracks:
			return i
	return -1

func glb_scene(path: String) -> PackedScene:
	if not _glb_cache.has(path):
		_glb_cache[path] = load(path) as PackedScene
	return _glb_cache[path]

func prop_mesh(lib_path: String, node_name: String) -> Node3D:
	## Instantiates one named root from a props/items/boards GLB library.
	var root := glb_scene(lib_path).instantiate()
	var n := root.find_child(node_name, true, false) as Node3D
	if n == null:
		root.queue_free()
		push_error("AssetRegistry: missing node %s in %s" % [node_name, lib_path])
		return null
	n.get_parent().remove_child(n)
	n.owner = null
	root.queue_free()
	n.transform = Transform3D.IDENTITY
	return n

func mesh_of(lib_path: String, node_name: String) -> Mesh:
	var key := lib_path + "::" + node_name
	if _glb_cache.has(key):
		return _glb_cache[key]
	var n := prop_mesh(lib_path, node_name)
	var m: Mesh = null
	if n is MeshInstance3D:
		m = (n as MeshInstance3D).mesh
	elif n != null:
		for c in n.find_children("*", "MeshInstance3D", true, false):
			m = (c as MeshInstance3D).mesh
			break
	if n:
		n.free()
	_glb_cache[key] = m
	return m

func item_texture(id: StringName) -> Texture2D:
	var d := item(id)
	return load(d.icon_path) if d and ResourceLoader.exists(d.icon_path) else null
