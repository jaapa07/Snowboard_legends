extends Node
## Local persistence: user://save.json, schema-versioned, atomic write (tmp + rename), backup recovery,
## validated export/import. No online services.

signal saved
const SCHEMA := 2
const PATH := "user://save.json"
const BACKUP := "user://save.bak.json"

var data: Dictionary = {}
var last_error: String = ""
var path: String = PATH       ## overridable so automated tests never touch the player's save
var backup_path: String = BACKUP

func _ready() -> void:
	load_or_create()

func default_data() -> Dictionary:
	return {
		"schema": SCHEMA,
		"profile": {"name": "Rider", "credits": 0, "riders": ["niko", "mika", "taro", "luna"], "boards_unlocked": ["starter", "carver", "float"],
			"boards_owned": ["starter", "carver", "float"], "equipped": {"rider": "niko", "board": "starter"},
			"medals": {}, "cups_unlocked": 1, "trick_best": {}, "skill_medals": {}, "board_levels": {}},
		"records": {},   ## track_id -> {board_id: best_time_seconds}
		"ghosts": {},    ## track_id -> {"time": t, "rider": id, "board": id, "frames": [[x,y,z,yaw], ...]}
		"settings": {"lang": "pt", "music": 0.8, "sfx": 0.9, "voice": 0.8, "quality": 1, "shake": true, "motion": true,
			"vibration": true, "assist": true, "fullscreen": false, "remaps": {}, "touch_controls": "auto", "tilt_steering": false,
			"mobile_profile_applied": false},
	}

func load_or_create() -> void:
	last_error = ""
	var d := _read(path)
	if d.is_empty():
		d = _read(backup_path)
		if not d.is_empty():
			last_error = "save principal inválido; backup restaurado"
	if d.is_empty():
		d = default_data()
	data = migrate(d)
	_fill_defaults(data, default_data())

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY or not validate(parsed):
		return {}
	return parsed

func validate(d: Dictionary) -> bool:
	if not d.has("schema") or not d.has("profile"):
		return false
	var p: Variant = d.profile
	if typeof(p) != TYPE_DICTIONARY:
		return false
	if p.has("credits") and (typeof(p.credits) != TYPE_FLOAT and typeof(p.credits) != TYPE_INT):
		return false
	if p.has("credits") and float(p.credits) < 0:
		return false
	return true

func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("schema", 1))
	if v < 2:
		# schema 1 stored "money" instead of "credits" and had no ghosts
		var p: Dictionary = d.profile
		if p.has("money"):
			p["credits"] = int(p.money)
			p.erase("money")
		if not d.has("ghosts"):
			d["ghosts"] = {}
		d["schema"] = 2
	return d

func _fill_defaults(d: Dictionary, def: Dictionary) -> void:
	for k in def:
		if not d.has(k):
			d[k] = def[k]
		elif typeof(def[k]) == TYPE_DICTIONARY and typeof(d[k]) == TYPE_DICTIONARY:
			_fill_defaults(d[k], def[k])

func write() -> bool:
	var txt := JSON.stringify(data, "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "não foi possível escrever o save"
		return false
	f.store_string(txt)
	f.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(path):
		dir.copy(path, backup_path)
	var err := dir.rename(tmp.get_file(), path.get_file())
	if err != OK:
		last_error = "falha ao renomear save (%d)" % err
		return false
	saved.emit()
	return true

func export_to(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true

func import_from(path: String) -> bool:
	var d := _read(path)
	if d.is_empty():
		last_error = "arquivo inválido"
		return false
	data = migrate(d)
	_fill_defaults(data, default_data())
	return write()

# ---------------- profile helpers
func profile() -> Dictionary:
	return data.profile

func settings() -> Dictionary:
	return data.settings

func credits() -> int:
	return int(data.profile.credits)

func add_credits(n: int) -> void:
	data.profile.credits = maxi(0, credits() + n)

func has_rider(id: String) -> bool:
	return id in data.profile.riders

func has_board(id: String) -> bool:
	return id in data.profile.boards_owned

func board_unlocked(id: String) -> bool:
	return id in data.profile.boards_unlocked

func try_buy_board(id: String, price: int) -> String:
	## Returns "ok", "owned", "locked" or "credits". Never charges twice.
	if has_board(id):
		return "owned"
	if not board_unlocked(id):
		return "locked"
	if credits() < price:
		return "credits"
	data.profile.credits = credits() - price
	data.profile.boards_owned.append(id)
	write()
	return "ok"

func board_level(id: String) -> int:
	return int(data.profile.get("board_levels", {}).get(id, 0))

func try_upgrade_board(id: String) -> String:
	## Returns "ok", "not_owned", "max" or "credits". The level is checked before charging, so a repeated
	## confirmation can never charge twice for the same level.
	if not has_board(id):
		return "not_owned"
	var lv := board_level(id)
	if lv >= BoardDefinition.MAX_LEVEL:
		return "max"
	var cost := BoardDefinition.upgrade_cost(lv)
	if credits() < cost:
		return "credits"
	data.profile.credits = credits() - cost
	if not data.profile.has("board_levels"):
		data.profile["board_levels"] = {}
	data.profile.board_levels[id] = lv + 1
	write()
	return "ok"

func medal(cup_id: String) -> int:
	return int(data.profile.medals.get(cup_id, 0))  ## 0 none, 1 bronze, 2 silver, 3 gold

func award_medal(cup_id: String, m: int) -> Array[String]:
	## Stores best medal and applies unlocks. Returns list of unlock messages.
	var out: Array[String] = []
	if m <= medal(cup_id):
		return out
	data.profile.medals[cup_id] = m
	var cup_idx := int(cup_id.substr(3)) - 1
	if m >= 1 and int(data.profile.cups_unlocked) < cup_idx + 2 and cup_idx + 2 <= 4:
		data.profile.cups_unlocked = cup_idx + 2
		out.append("cup:%d" % (cup_idx + 2))
	var tags: Array[String] = []
	for lvl in range(1, m + 1):
		tags.append("%s:%s" % [cup_id, ["", "bronze", "silver", "gold"][lvl]])
	for rid in Registry.RIDER_IDS:
		var r := Registry.rider(rid)
		if r.unlock in tags and not has_rider(String(rid)):
			data.profile.riders.append(String(rid))
			out.append("rider:" + String(rid))
	for bid in Registry.BOARD_IDS:
		var b := Registry.board(bid)
		if b.unlock in tags and not board_unlocked(String(bid)):
			data.profile.boards_unlocked.append(String(bid))
			out.append("board:" + String(bid))
	return out

func record(track_id: String, board_id: String) -> float:
	return float(data.records.get(track_id, {}).get(board_id, 0.0))

func submit_record(track_id: String, board_id: String, t: float) -> bool:
	var cur := record(track_id, board_id)
	if cur <= 0.0 or t < cur:
		if not data.records.has(track_id):
			data.records[track_id] = {}
		data.records[track_id][board_id] = t
		return true
	return false
