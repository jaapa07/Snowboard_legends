extends Node
## Session state and scene flow. Holds the race configuration chosen in menus.

enum Mode { GRAND_PRIX, QUICK_RACE, TIME_TRIAL, TRICK_ATTACK, SKILL_SLALOM, SKILL_LANDING, SKILL_COINS, MENU_BACKGROUND }

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

func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
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
	participants.append({"type": "human", "device": "kb", "rider": player_rider, "board": player_board})
	for h in humans:
		participants.append(h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = []
	for r in Registry.RIDER_IDS:
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
	laps = 5
	track_id = Registry.CUPS[cup].tracks[0]
	goto_race()

func goto_race() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/race/race.tscn")

func goto_menu(screen: String = "main") -> void:
	get_tree().paused = false
	set_meta("menu_screen", screen)
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func goto_results() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/results.tscn")
