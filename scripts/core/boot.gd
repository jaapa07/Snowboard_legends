extends Node
## Entry point. Command line (after "--"): --race <track> [--laps N] [--autoplay] [--seed N] [--mode quick|tt|trick]
## --screenshot <path> [--at seconds] [--count N --every s] captures real frames then quits (evidence captures).
## --menu <screen> opens the front end on a given screen; --show-results goes to the results scene after an autoplay race;
## --humans N adds local human slots (split screen) driven by AI when --autoplay is set.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--screenshot" in args:
		(func(): get_tree().current_scene = null).call_deferred()
	var i := args.find("--race")
	if i >= 0:
		Game.track_id = StringName(args[i + 1]) if args.size() > i + 1 else &"vale_pinheiros"
		Game.laps = _int(args, "--laps", 5)
		Game.seed_value = _int(args, "--seed", 1234)
		Game.difficulty = _int(args, "--difficulty", 1)
		Game.headless_autoplay = "--autoplay" in args
		var m := _str(args, "--mode", "quick")
		Game.mode = {"quick": Game.Mode.QUICK_RACE, "tt": Game.Mode.TIME_TRIAL, "trick": Game.Mode.TRICK_ATTACK, "slalom": Game.Mode.SKILL_SLALOM, "gp": Game.Mode.GRAND_PRIX}.get(m, Game.Mode.QUICK_RACE)
		var humans: Array = []
		for k in range(1, _int(args, "--humans", 1)):
			humans.append({"type": "human", "device": ["kb_right", "joy0", "joy1"][k - 1], "rider": ["mika", "taro", "luna"][k - 1], "board": "carver"})
		Game.default_participants(_str(args, "--rider", "niko"), _str(args, "--board", "starter"), humans)
		if "--show-results" in args:
			Game.set_meta("show_results", true)
		if m == "gp":
			Game.cup_index = _int(args, "--cup", 0)
			Game.cup_race = _int(args, "--cup-race", 0)
		Game.goto_race.call_deferred()
		var si := args.find("--screenshot")
		if si >= 0:
			_capture(args[si + 1], float(_str(args, "--at", "8")), _int(args, "--count", 1), float(_str(args, "--every", "3")))
	else:
		Game.goto_menu.call_deferred(_str(args, "--menu", "title"))
		var si2 := args.find("--screenshot")
		if si2 >= 0:
			_capture(args[si2 + 1], float(_str(args, "--at", "3")), _int(args, "--count", 1), float(_str(args, "--every", "3")))

func _capture(path: String, at: float, count: int, every: float) -> void:
	## Real frame grabs from the running game (evidence screenshots). Boot detaches itself from
	## current_scene (deferred, queued in _ready before the scene change) so the change does not free it.
	## --warp <s>: simulate without drawing until race time s; --warp-results: until the results scene is up.
	## (Software rendering is slow; warping only skips drawing, the simulation is the normal game loop.)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var warp := float(_str(args, "--warp", "-1"))
	var warp_results := "--warp-results" in args
	if warp > 0.0 or warp_results:
		RenderingServer.render_loop_enabled = false
		while true:
			await get_tree().process_frame
			var cs := get_tree().current_scene
			if warp_results and cs and cs.name == "Results":
				break
			var rm := get_tree().get_first_node_in_group("race_manager")
			if not warp_results and rm and rm.race_time >= warp:
				break
		RenderingServer.render_loop_enabled = true
	await get_tree().create_timer(at, true, false, true).timeout
	for k in count:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var p := path if count == 1 else path.replace(".png", "_%02d.png" % k)
		img.save_png(p)
		print("SCREENSHOT ", p)
		if k < count - 1:
			await get_tree().create_timer(every, true, false, true).timeout
	get_tree().quit()

func _int(a: PackedStringArray, k: String, d: int) -> int:
	var i := a.find(k)
	return int(a[i + 1]) if i >= 0 and a.size() > i + 1 else d

func _str(a: PackedStringArray, k: String, d: String) -> String:
	var i := a.find(k)
	return a[i + 1] if i >= 0 and a.size() > i + 1 else d
