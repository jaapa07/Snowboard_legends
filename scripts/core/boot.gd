extends Node
## Entry point. Command line (after "--"): --race <track> [--laps N] [--autoplay] [--seed N] [--mode quick|tt|trick]
## --screenshot <path> [--at seconds] captures a real frame then quits (used for evidence captures).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--race")
	if i >= 0:
		Game.track_id = StringName(args[i + 1]) if args.size() > i + 1 else &"vale_pinheiros"
		Game.laps = _int(args, "--laps", 5)
		Game.seed_value = _int(args, "--seed", 1234)
		Game.difficulty = _int(args, "--difficulty", 1)
		Game.headless_autoplay = "--autoplay" in args
		var m := _str(args, "--mode", "quick")
		Game.mode = {"quick": Game.Mode.QUICK_RACE, "tt": Game.Mode.TIME_TRIAL, "trick": Game.Mode.TRICK_ATTACK, "slalom": Game.Mode.SKILL_SLALOM, "gp": Game.Mode.GRAND_PRIX}.get(m, Game.Mode.QUICK_RACE)
		Game.default_participants(_str(args, "--rider", "niko"), _str(args, "--board", "starter"))
		Game.goto_race.call_deferred()
	else:
		Game.goto_menu.call_deferred()

func _int(a: PackedStringArray, k: String, d: int) -> int:
	var i := a.find(k)
	return int(a[i + 1]) if i >= 0 and a.size() > i + 1 else d

func _str(a: PackedStringArray, k: String, d: String) -> String:
	var i := a.find(k)
	return a[i + 1] if i >= 0 and a.size() > i + 1 else d
