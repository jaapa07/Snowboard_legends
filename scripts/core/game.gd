extends Node
## Session state and scene flow. Holds the race configuration chosen in menus.

enum Mode { GRAND_PRIX, QUICK_RACE, TIME_TRIAL, TRICK_ATTACK, SKILL_SLALOM, SKILL_LANDING, SKILL_COINS, MENU_BACKGROUND, SKILL_TARGETS }

var mode: int = Mode.QUICK_RACE
var track_id: StringName = &"vale_pinheiros"
var laps: int = 5
var difficulty: int = 1            ## 0 rookie (450 ms), 1 normal (250 ms), 2 expert (120 ms)
var items_enabled: bool = true
var seed_value: int = 1234
var cup_index: int = 0
var cup_race: int = 0
var cup_points: Dictionary = {}    ## participant index -> points
var cup_credits_earned: int = 0
## participant: {type: "human"/"ai", device, rider, board, name}
var participants: Array[Dictionary] = []
var last_results: Array = []
var pending_unlocks: Array[String] = []
var headless_autoplay: bool = false  ## tests: humans replaced by AI
var results_processed: bool = false
var last_summary: Dictionary = {}

## Progression rules (spec §11 / §21). Thresholds are configurable here.
const PLACE_POINTS := [10, 7, 4, 2]
const PLACE_CREDITS := [100, 70, 40, 25]
const TRICK_BONUS_CAP := 50
const TRICK_POINTS_PER_CREDIT := 40
const QUICK_RACE_CREDIT_FACTOR := 0.5
## medal thresholds [bronze, silver, gold]; slalom uses max missed gates (lower is better)
const SKILL_THRESHOLDS := {
	"trick": [1500, 3000, 5000],
	"landing": [5, 9, 14],
	"coins": [40, 70, 100],
	"slalom_missed": [4, 2, 0],
	"targets": [4, 7, 10],
}

func lang() -> String:
	return String(Save.settings().lang)

func t(key: String) -> String:
	return I18n.t(key, lang())

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Inputs.apply_remaps(Save.settings().remaps)
	Inputs.vibration_enabled = bool(Save.settings().vibration)
	apply_display()
	get_tree().root.focus_exited.connect(_on_focus_lost)
	_apply_mobile_profile()

func is_mobile() -> bool:
	## native mobile, or the web build opened on a phone/tablet browser (e.g. Safari on iPhone)
	return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")

func _apply_mobile_profile() -> void:
	## First launch on a phone/tablet: low quality preset (Mobile renderer, 0.75 render scale, no heavy effects).
	if (is_mobile() or OS.has_feature("web")) and not bool(Save.settings().get("mobile_profile_applied", false)):
		Save.settings().quality = 0
		Save.settings().mobile_profile_applied = true
		Save.write()

func _notification(what: int) -> void:
	# iOS/Android: app sent to background (home button, call, notification centre) -> pause and save
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var race := get_tree().get_first_node_in_group("race_manager") if get_tree() else null
		if race and race.has_method("request_pause") and human_count() <= 1:
			race.request_pause()
		if what == NOTIFICATION_APPLICATION_PAUSED:
			Save.write()

func apply_display() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	var fs := bool(Save.settings().fullscreen)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)

func quality() -> int:
	return int(Save.settings().quality)

func _on_focus_lost() -> void:
	## Pause the simulation when the window loses focus in single-human races.
	var race := get_tree().get_first_node_in_group("race_manager")
	if race and race.has_method("request_pause") and human_count() <= 1:
		race.request_pause()

func human_count() -> int:
	var n := 0
	for p in participants:
		if p.type == "human":
			n += 1
	return n

func default_participants(player_rider: String, player_board: String, humans: Array = []) -> void:
	participants.clear()
	participants.append({"type": "human", "device": "touch" if TouchControls.enabled() else "kb", "rider": player_rider, "board": player_board})
	for h in humans:
		participants.append(h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = []
	for r in Registry.RIDER_IDS:
		if r == &"kaito" and not Save.has_rider("kaito"):
			continue   # secret rider only races once unlocked
		var taken := false
		for p in participants:
			if p.rider == String(r):
				taken = true
		if not taken:
			pool.append(String(r))
	var boards := ["starter", "carver", "float", "rocket", "grip", "twin", "powder", "aurora"]
	while participants.size() < 4:
		var i := rng.randi_range(0, pool.size() - 1)
		participants.append({"type": "ai", "device": "", "rider": pool[i], "board": boards[rng.randi_range(0, boards.size() - 1)]})
		pool.remove_at(i)

func start_grand_prix(cup: int) -> void:
	mode = Mode.GRAND_PRIX
	cup_index = cup
	cup_race = 0
	cup_points.clear()
	cup_credits_earned = 0
	track_id = Registry.CUPS[cup].tracks[0]
	laps = Registry.track(track_id).default_laps
	goto_race()

func _test_intercept(scene: String) -> bool:
	## In-process test runner (tests/run_all) records scene requests instead of switching scenes.
	if has_meta("test_hold"):
		set_meta("requested_scene", scene)
		return true
	return false

func goto_race() -> void:
	results_processed = false
	last_summary = {}
	if _test_intercept("race"):
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/race/race.tscn")

func goto_menu(screen: String = "main") -> void:
	if _test_intercept("menu:" + screen):
		return
	get_tree().paused = false
	set_meta("menu_screen", screen)
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func goto_results() -> void:
	if _test_intercept("results"):
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/results.tscn")

func next_cup_race() -> void:
	cup_race += 1
	track_id = Registry.CUPS[cup_index].tracks[cup_race]
	laps = Registry.track(track_id).default_laps
	goto_race()

func is_cup_last_race() -> bool:
	return cup_race >= Registry.CUPS[cup_index].tracks.size() - 1

# ---------------------------------------------------------------- progression rules (pure, unit-tested)
static func place_points(place: int) -> int:
	return PLACE_POINTS[clampi(place - 1, 0, 3)] if place >= 1 and place <= 4 else 0

static func trick_bonus(trick_points: int) -> int:
	return clampi(trick_points / TRICK_POINTS_PER_CREDIT, 0, TRICK_BONUS_CAP)

static func race_credits(place: int, trick_points: int) -> int:
	var base: int = PLACE_CREDITS[clampi(place - 1, 0, 3)] if place >= 1 and place <= 4 else 0
	return base + trick_bonus(trick_points)

static func cup_medal_for_place(place: int) -> int:
	## 1st gold (3), 2nd silver (2), 3rd bronze (1), else none
	return 3 if place == 1 else (2 if place == 2 else (1 if place == 3 else 0))

static func skill_medal(kind: String, value: float) -> int:
	var th: Array = SKILL_THRESHOLDS[kind]
	var m := 0
	for i in 3:
		if kind == "slalom_missed":
			if value <= float(th[i]):
				m = i + 1
		elif value >= float(th[i]):
			m = i + 1
	return m

static func standings(points: Dictionary) -> Array:
	## [[participant_index, points], ...] best first; ties keep lower index first (stable, deterministic)
	var out: Array = []
	for k in points:
		out.append([int(k), int(points[k])])
	out.sort_custom(func(a, b): return a[1] > b[1] if a[1] != b[1] else a[0] < b[0])
	return out

func _best_human(rows: Array) -> Dictionary:
	for row in rows:
		if row.human:
			return row
	return rows[0] if rows.size() > 0 else {}

func process_results() -> Dictionary:
	## Applies points, credits, records, medals and unlocks exactly once per race; returns a summary for the UI.
	if results_processed:
		return last_summary
	results_processed = true
	var rows: Array = last_results
	var s := {"mode": mode, "track": String(track_id), "rows": rows, "credits": 0, "trick_bonus": 0, "unlocks": [],
		"medal": -1, "cup_done": false, "standings": [], "race_points": {}, "record": false, "skill_value": 0.0, "skill_kind": ""}
	var me := _best_human(rows)
	match mode:
		Mode.GRAND_PRIX:
			for row in rows:
				var pts := place_points(int(row.place))
				cup_points[int(row.index)] = int(cup_points.get(int(row.index), 0)) + pts
				s.race_points[int(row.index)] = pts
			if not me.is_empty():
				s.credits = race_credits(int(me.place), int(me.tricks))
				s.trick_bonus = trick_bonus(int(me.tricks))
			cup_credits_earned += int(s.credits)
			s.standings = standings(cup_points)
			if is_cup_last_race():
				s.cup_done = true
				var my_place := 4
				for i in s.standings.size():
					if not me.is_empty() and int(s.standings[i][0]) == int(me.index):
						my_place = i + 1
				s.medal = cup_medal_for_place(my_place)
				s.unlocks = Save.award_medal(String(Registry.CUPS[cup_index].id), s.medal)
		Mode.QUICK_RACE:
			if not me.is_empty():
				s.credits = int(race_credits(int(me.place), int(me.tricks)) * QUICK_RACE_CREDIT_FACTOR)
				s.trick_bonus = trick_bonus(int(me.tricks))
		Mode.TIME_TRIAL:
			if not me.is_empty() and float(me.time) > 0.0:
				s.record = is_equal_approx(Save.record(String(track_id), String(me.board)), float(me.time))
				s.skill_value = float(me.time)
		Mode.TRICK_ATTACK:
			s.skill_kind = "trick"; s.skill_value = float(me.tricks)
		Mode.SKILL_LANDING:
			s.skill_kind = "landing"; s.skill_value = float(me.landings)
		Mode.SKILL_COINS:
			s.skill_kind = "coins"; s.skill_value = float(me.coins)
		Mode.SKILL_SLALOM:
			s.skill_kind = "slalom_missed"; s.skill_value = float(me.missed)
		Mode.SKILL_TARGETS:
			s.skill_kind = "targets"; s.skill_value = float(me.get("targets", 0))
	if s.skill_kind != "":
		var finished_ok: bool = mode != Mode.SKILL_SLALOM or float(me.time) > 0.0
		s.medal = skill_medal(s.skill_kind, s.skill_value) if finished_ok else 0
		var key := "%s:%s" % [s.skill_kind, String(track_id)]
		var prof: Dictionary = Save.profile()
		if int(s.medal) > int(prof.skill_medals.get(key, 0)):
			prof.skill_medals[key] = int(s.medal)
		if s.skill_kind == "trick" and s.skill_value > float(prof.trick_best.get(String(track_id), 0)):
			prof.trick_best[String(track_id)] = int(s.skill_value)
			s.record = true
	Save.add_credits(int(s.credits))
	Save.write()
	pending_unlocks.assign(s.unlocks)
	last_summary = s
	return s
