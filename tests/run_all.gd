extends Node
## Automated test suite (run as a SCENE so the autoloads exist):
##   godot --headless --path . --fixed-fps 60 res://tests/run_all.tscn -- [--suite unit,integration,e2e,ai] [--ai-races N] [--ai-laps L] [--tracks a,b]
## Exit code 0 = all checks passed, 1 = at least one failure. Writes user://test_report.json and prints TEST_SUMMARY.
## Uses its own save file (user://test_save.json); the player's save is never written.

const TEST_SAVE := "user://test_save.json"
const TEST_BACKUP := "user://test_save.bak.json"

var passed := 0
var failed := 0
var failures: Array[String] = []
var sections: Dictionary = {}     ## section -> {pass, fail}
var section := ""
var ai_report: Array = []
var t0 := 0

class Scripted extends RefCounted:
	## Deterministic test driver: optional line following along the course centre, tuck, lateral lane.
	var cmd := InputCommand.new()
	var follow := true
	var tuck := false
	var lane := 0.0
	var tr: TrackRuntime
	func command(r: RiderController, _delta: float) -> InputCommand:
		var keep_jump := cmd.jump_held
		var spin := cmd.spin_left
		cmd.steer = 0.0
		cmd.tuck = tuck
		cmd.jump_held = keep_jump
		cmd.spin_left = spin
		if follow and tr:
			var pr := tr.project(r.global_position, r.proj_idx)
			r.proj_idx = int(pr.idx)
			var s := float(pr.s)
			var tgt := tr.point_at(minf(s + 14.0, tr.length - 1.0), lane, 0.0)
			var d := tgt - r.global_position
			var want := atan2(-d.x, -d.z)
			var diff := wrapf(want - r.yaw, -PI, PI)
			cmd.steer = clampf(-diff * 2.5, -1.0, 1.0)
		return cmd

func _ready() -> void:
	_run.call_deferred()

func _args() -> PackedStringArray:
	return OS.get_cmdline_user_args()

func _arg(k: String, d: String) -> String:
	var a := _args()
	var i := a.find(k)
	return a[i + 1] if i >= 0 and a.size() > i + 1 else d

func _run() -> void:
	t0 = Time.get_ticks_msec()
	Engine.max_fps = 0
	Save.path = TEST_SAVE
	Save.backup_path = TEST_BACKUP
	_fresh_save()
	Game.set_meta("test_hold", true)
	var suites := _arg("--suite", "unit,integration,e2e,ai").split(",")
	if "unit" in suites:
		await _unit()
	if "integration" in suites:
		await _integration()
	if "e2e" in suites:
		await _e2e()
	if "ai" in suites:
		await _ai_races()
	_finish()

func _fresh_save() -> void:
	for p in [TEST_SAVE, TEST_BACKUP, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Save.data = Save.default_data()
	Save.write()

# ---------------------------------------------------------------- assertions
func begin(name: String) -> void:
	section = name
	if not sections.has(name):
		sections[name] = {"pass": 0, "fail": 0}
	print("== ", name)

func check(cond: bool, what: String, detail: String = "") -> bool:
	if cond:
		passed += 1
		sections[section].pass += 1
	else:
		failed += 1
		sections[section].fail += 1
		var msg := "[%s] %s %s" % [section, what, detail]
		failures.append(msg)
		print("  FAIL ", msg)
	return cond

func near(a: float, b: float, eps: float) -> bool:
	return absf(a - b) <= eps

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _finish() -> void:
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var report := {"passed": passed, "failed": failed, "failures": failures, "sections": sections, "ai": ai_report,
		"seconds": snappedf(secs, 0.1), "engine": Engine.get_version_info().string, "args": Array(_args())}
	var rp := _arg("--report", "user://test_report.json")
	var f := FileAccess.open(rp, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("TEST_REPORT ", ProjectSettings.globalize_path(rp))
	for k in sections:
		print("  %-28s pass=%d fail=%d" % [k, sections[k].pass, sections[k].fail])
	print("TEST_SUMMARY passed=%d failed=%d seconds=%.1f" % [passed, failed, secs])
	Game.remove_meta("test_hold")
	get_tree().quit(1 if failed > 0 else 0)

# ---------------------------------------------------------------- sandboxes
func _sandbox(track_id: StringName = &"vale_pinheiros", rider_id: StringName = &"niko", board_id: StringName = &"starter") -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var tr := TrackRuntime.new()
	root.add_child(tr)
	tr.setup(Registry.track(track_id), 0, false)
	var prov := Scripted.new()
	prov.tr = tr
	var r := RiderController.new()
	root.add_child(r)
	r.setup(0, Registry.rider(rider_id), Registry.board(board_id), tr, prov, false, "")
	r.place_at(tr.point_at(40.0, 0.0, 0.3), tr.fwd[tr.idx_at(40.0)])
	r.proj_idx = tr.idx_at(40.0)
	return {"root": root, "tr": tr, "r": r, "prov": prov}

func _free(sb: Dictionary) -> void:
	(sb.root as Node).queue_free()
	await get_tree().process_frame

func _new_race(track_id: StringName, laps: int, mode: int, seed_: int, participants: Array = [], autoplay: bool = true) -> Node:
	Game.track_id = track_id
	Game.laps = laps
	Game.mode = mode
	Game.seed_value = seed_
	Game.difficulty = 1
	Game.items_enabled = true
	Game.headless_autoplay = autoplay
	if participants.is_empty():
		Game.default_participants("niko", "starter")
	else:
		Game.participants.clear()
		Game.participants.append_array(participants)
	var race := (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	add_child(race)
	return race

func _rm(race: Node) -> RaceManager:
	return race.get_node("RaceManager") as RaceManager

func _wait_racing(rm: RaceManager) -> void:
	while rm.phase != RaceManager.Phase.RACE:
		await get_tree().physics_frame

func _end_race(race: Node) -> void:
	get_tree().paused = false
	race.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

# ================================================================ UNIT (spec §15)
func _unit() -> void:
	await _u_physics()
	await _u_jump()
	await _u_landing_and_combos()
	await _u_coins_and_cooldown()
	_u_lift()
	_u_ranking_and_standings()
	_u_save()
	_u_rng()
	_u_progression()
	_u_content()

func _u_physics() -> void:
	begin("unit: physics integration")
	var sb := _sandbox()
	var r: RiderController = sb.r
	var prov: Scripted = sb.prov
	prov.follow = true
	await _frames(240)
	check(r.global_position.is_finite() and r.velocity.is_finite(), "state finite after 4 s")
	check(r.speed > 6.0, "accelerates downhill from rest", "speed=%.2f" % r.speed)
	var pr: Dictionary = sb.tr.project(r.global_position, r.proj_idx)
	check(absf(float(pr.lat)) < sb.tr.half_width(float(pr.s)) + 2.0, "stays on the course while line-following", "lat=%.1f" % float(pr.lat))
	check(float(pr.s) > 60.0, "made forward progress", "s=%.1f" % float(pr.s))
	await _free(sb)

	begin("unit: speed limits")
	for tuck in [false, true]:
		sb = _sandbox(&"cume_celestial")
		r = sb.r
		(sb.prov as Scripted).tuck = tuck
		var vmax_seen := 0.0
		for i in 60 * 24:
			await get_tree().physics_frame
			if r.state == RiderController.State.GROUND:
				vmax_seen = maxf(vmax_seen, r._vf)
		var cap := (r.tuning.tuck_speed if tuck else r.tuning.max_speed) * r.m_speed
		check(vmax_seen <= cap + 1.5, "ground speed respects %s cap" % ("tuck" if tuck else "base"), "max=%.2f cap=%.2f" % [vmax_seen, cap])
		check(vmax_seen > cap * 0.75, "reaches near the %s cap on a long descent" % ("tuck" if tuck else "base"), "max=%.2f cap=%.2f" % [vmax_seen, cap])
		await _free(sb)
	var ar := RiderController.new()
	ar.def = Registry.rider(&"niko"); ar.board = Registry.board(&"starter")
	ar.assist_mult = 1.0 + RiderController.ASSIST_MAX
	var capped := ar.vmax()
	ar.assist_mult = 1.0
	check(near(capped, ar.vmax() * 1.05, 0.01) and capped <= ar.tuning.boost_speed + 0.001, "AI assist at most +5 % and under the physical ceiling", "%.2f vs %.2f" % [capped, ar.vmax()])
	ar.free()
	check(near(RiderTuning.new().max_speed, 24.0, 0.01) and near(RiderTuning.new().tuck_speed, 29.0, 0.01) and near(RiderTuning.new().boost_speed, 35.0, 0.01), "spec speeds 24/29/35 m/s")

func _u_jump() -> void:
	begin("unit: jump")
	var sb := _sandbox()
	var r: RiderController = sb.r
	(sb.prov as Scripted).follow = false
	await _frames(20)
	r.set_physics_process(false)   # drive the jump math directly
	r.m_jump = 1.0
	var tn := r.tuning
	for c in [0.0, tn.jump_charge_max * 0.5, tn.jump_charge_max, 2.0]:
		r.state = RiderController.State.GROUND
		r.off_ground_t = 0.0
		r.velocity = Vector3.ZERO
		r.ground_n = Vector3.UP
		r._do_jump(c, false)
		var expect := lerpf(tn.jump_min, tn.jump_max, clampf(c / tn.jump_charge_max, 0, 1))
		check(near(r.velocity.y, expect, 0.01) and r.velocity.y >= 4.0 - 0.01 and r.velocity.y <= 8.0 + 0.01, "charged jump impulse %.2f s in 4..8 m/s" % c, "vy=%.2f" % r.velocity.y)
		check(r.state == RiderController.State.AIR, "jump enters AIR")
	# coyote time: allowed up to 100 ms after leaving the ground, refused after
	r.state = RiderController.State.AIR; r.off_ground_t = 0.08; r.velocity = Vector3.ZERO
	r._do_jump(0.0, false)
	check(r.velocity.y > 3.9, "coyote jump at 80 ms")
	r.state = RiderController.State.AIR; r.off_ground_t = 0.15; r.velocity = Vector3.ZERO
	r._do_jump(0.0, false)
	check(near(r.velocity.y, 0.0, 0.001), "no jump at 150 ms off the ground")
	check(near(tn.coyote_time, 0.10, 0.001) and near(tn.jump_buffer, 0.12, 0.001) and near(tn.jump_charge_max, 0.65, 0.001), "coyote 100 ms, buffer 120 ms, charge 0.65 s")
	# hold-and-release through the real input path: charge while held, fire on release
	r.set_physics_process(true)
	r.state = RiderController.State.GROUND
	r.velocity = Vector3.ZERO
	await _frames(20)
	var jumped := [0]
	r.jumped.connect(func(_r): jumped[0] += 1)
	(sb.prov as Scripted).cmd.jump_held = true
	await _frames(30)
	check(jumped[0] == 0 and r.jump_charge > 0.3, "holding Space charges without jumping", "charge=%.2f" % r.jump_charge)
	(sb.prov as Scripted).cmd.jump_held = false
	await _frames(2)
	check(jumped[0] == 1 and r.state == RiderController.State.AIR, "release fires the charged jump")
	await _free(sb)

func _u_landing_and_combos() -> void:
	begin("unit: tricks, combos, landing")
	var sb := _sandbox()
	var r: RiderController = sb.r
	(sb.prov as Scripted).follow = false
	await _frames(30)
	var got: Array = []
	r.trick_landed.connect(func(_r, label, pts, coins, q): got.append([label, pts, coins, q]))
	# 360 + grab: base 200+100, mult 1 + 0.5 (2 parts) + 0.5 (grab+spin) = 2.0 -> 600, coins min(30, 6*5)
	r.grab_time = 0.5; r.did_grind = false; r.air_time = 1.0; r.flip_angle = 0.0
	r._score_tricks(360.0, 0.0, "clean")
	check(got.size() == 1 and int(got[0][1]) == 600 and int(got[0][2]) == 30, "360+grab combo = 600 pts, 30 coins (cap)", str(got))
	r._score_tricks(360.0, 0.0, "clean")
	check(got.size() == 2 and int(got[1][1]) == 420, "repeated trick reduced 30%", str(got.back()))
	r.grab_time = 0.0
	r._score_tricks(0.0, 360.0, "clean")
	check(int(got[2][1]) == 300, "frontflip alone 300 (alternating resets repetition)", str(got.back()))
	r.grab_time = 0.5; r.did_grind = true; r.flip_angle = -TAU
	r._score_tricks(720.0, 360.0, "perfect")
	check(int(got[3][1]) == int(round((500 + 300 + 100 + 150) * 3.0)), "multiplier capped at 3x", str(got.back()))
	r.grab_time = 0.0; r.did_grind = false; r.air_time = 0.6; r.flip_angle = 0.0
	r._score_tricks(0.0, 0.0, "clean")
	check(int(got[4][1]) == 50, "ollie 50 for real air time", str(got.back()))
	# points are only validated on landing: a bad landing crashes and awards nothing
	var n_before := got.size()
	await _frames(10)
	r.set_physics_process(false)   # call the landing evaluation directly (rider is on the floor)
	r.state = RiderController.State.AIR
	r.spin_angle = deg_to_rad(90.0); r.flip_angle = 0.0; r.grab_time = 0.0; r.air_time = 1.0
	r.velocity = Vector3(0, -2, 0)
	r._land()
	check(r.state == RiderController.State.FALLEN and got.size() == n_before, "sideways landing (90°) crashes with no points")
	check(r.fallen_t >= r.tuning.fall_min - 0.01 and r.fallen_t <= r.tuning.fall_max + 0.01, "fall lasts 0.8–1.4 s", "%.2f" % r.fallen_t)
	r.set_physics_process(true)
	await _frames(int(r.fallen_t * 60.0) + 6)
	check(r.state == RiderController.State.GROUND and r.invuln_t > 0.0, "recovers after the fall with brief invulnerability")
	await _frames(10)
	r.set_physics_process(false)
	n_before = got.size()
	r.state = RiderController.State.AIR
	r.spin_angle = deg_to_rad(362.0); r.grab_time = 0.0; r.air_time = 1.0
	r.velocity = Vector3(0, -2, 0)
	r._land()
	check(r.state == RiderController.State.GROUND and got.size() == n_before + 1 and String(got.back()[3]) == "perfect", "clean 360 landing validated (perfect)", str(got.back()))
	# signature trick: Q, E, Shift in sequence starts it; landing before it ends crashes, after it scores
	var sgd := SignatureTricks.of("niko")
	r.state = RiderController.State.AIR
	r._enter_air(true)
	var seq := [[true, false, false], [false, false, false], [false, true, false], [false, false, false], [false, false, true]]
	for st in seq:
		var c := InputCommand.new()
		c.spin_left = st[0]; c.spin_right = st[1]; c.grab = st[2]
		r._signature_input(c, 1.0 / 60.0)
	check(r.sig_active, "Q, E, Shift in sequence starts the signature trick")
	r.velocity = Vector3(0, -2, 0)
	r._land()
	check(r.state == RiderController.State.FALLEN, "landing mid-signature is a crash")
	r.set_physics_process(true)
	await _frames(int(r.fallen_t * 60.0) + 10)
	r.set_physics_process(false)
	r.state = RiderController.State.AIR
	r._enter_air(true)
	r.start_signature()
	for i in int(float(sgd.dur) * 60.0) + 2:
		r._signature_step(1.0 / 60.0)
	check(r.sig_done and not r.sig_active, "signature completes after its duration")
	n_before = got.size()
	r.velocity = Vector3(0, -2, 0)
	r.air_time = 1.5
	r._land()
	check(r.state == RiderController.State.GROUND and got.size() == n_before + 1 and String(got.back()[0]) == SignatureTricks.label("niko", Game.lang()) and int(got.back()[1]) >= int(sgd.points),
		"completed signature scores its points", str(got.back()))
	var c2 := InputCommand.new()
	c2.spin_left = true
	r._enter_air(true)
	r._signature_input(c2, 1.0 / 60.0)
	r._signature_input(InputCommand.new(), 1.0)
	check(r._sig_step == 0, "sequence expires after 0.8 s")
	await _free(sb)

func _u_coins_and_cooldown() -> void:
	begin("unit: coin balance")
	var sb := _sandbox(&"vale_pinheiros", &"boro")
	var r: RiderController = sb.r
	(sb.prov as Scripted).follow = false
	await _frames(10)
	r.add_coins(150); r.add_coins(150)
	check(r.race_coins == 200, "race coins capped at 200", str(r.race_coins))
	r.add_coins(-500)
	check(r.race_coins == 0, "balance never negative")
	check(ItemSystem.PRICE == 20 and RiderController.COINS_PER_100 == 5 and RiderController.MAX_TRICK_COINS == 30, "station 20, 5 coins/100 pts, 30 per jump")
	begin("unit: damage cooldown and shield")
	r.state = RiderController.State.GROUND
	r.invuln_t = 0.0
	check(r.apply_hit("snowball"), "first hit lands")
	check(not r.apply_hit("snowball"), "second hit inside 2 s ignored (no stun-lock)")
	r._tick_effects(2.05)
	check(r.apply_hit("snowball"), "hit lands again after the 2 s cooldown")
	r._tick_effects(2.05)
	r.shield_t = 6.0
	check(not r.apply_hit("icemine") and r.shield_t == 0.0, "shield blocks one attack and breaks")
	r._tick_effects(1.0)
	r.state = RiderController.State.LIFT
	check(not r.can_be_hit(), "riders in the lift are untouchable")
	r.state = RiderController.State.GROUND
	await _free(sb)

func _u_lift() -> void:
	begin("unit: lift FIFO")
	var l := LiftSystem.new()
	for id in [2, 0, 3, 1]:
		l.enqueue(id)
	check(l.enqueue(0) == 1, "re-enqueue keeps the original slot")
	var arrived: Array = []
	var departs: Array = []
	var t := 0.0
	var prev_riding := 0
	while arrived.size() < 4 and t < 30.0:
		arrived.append_array(l.tick(1.0 / 60.0))
		t += 1.0 / 60.0
		if l.riding.size() > prev_riding or (l.riding.size() > 0 and departs.size() < 4 and not departs.has(l.riding.back().id)):
			if not departs.has(l.riding.back().id):
				departs.append(l.riding.back().id)
		prev_riding = l.riding.size()
	check(arrived == [2, 0, 3, 1], "arrival order equals queue order", str(arrived))
	check(near(t, 3 * LiftSystem.DEPART_INTERVAL + LiftSystem.RIDE_TIME, 0.1), "1 cabin / 1.2 s, 3 s ride", "t=%.2f" % t)
	var l2 := LiftSystem.new()
	l2.skip_animation = true
	l2.enqueue(5)
	check(l2.tick(0.016) == [5], "solo training may skip the ride")

func _u_ranking_and_standings() -> void:
	begin("unit: ranking / standings")
	var st := Game.standings({0: 17, 1: 17, 2: 20, 3: 4})
	check(st == [[2, 20], [0, 17], [1, 17], [3, 4]], "cup standings sorted, ties stable", str(st))
	check(Game.place_points(1) == 10 and Game.place_points(2) == 7 and Game.place_points(3) == 4 and Game.place_points(4) == 2, "points 10/7/4/2")

func _u_save() -> void:
	begin("unit: save / migration")
	var v1 := {"schema": 1, "profile": {"name": "Old", "money": 340, "riders": ["niko"]}}
	var m := Save.migrate(v1.duplicate(true))
	check(int(m.schema) == 2 and int(m.profile.credits) == 340 and not m.profile.has("money") and m.has("ghosts"), "schema 1 -> 2 migration (money -> credits)")
	check(not Save.validate({"schema": 2, "profile": {"credits": -5}}), "negative credits rejected")
	check(not Save.validate({"profile": {}}), "missing schema rejected")
	# round trip + atomic write + backup recovery
	_fresh_save()
	Save.data.profile.credits = 777
	check(Save.write(), "atomic write")
	Save.data.profile.credits = 1
	Save.load_or_create()
	check(Save.credits() == 777, "reload restores credits")
	Save.data.profile.credits = 778
	Save.write()   # backup now holds 777
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Save.load_or_create()
	check(Save.credits() == 777 and Save.last_error != "", "corrupt save -> backup restored", "credits=%d err=%s" % [Save.credits(), Save.last_error])
	check(Save.export_to("user://test_export.json"), "export")
	Save.data.profile.credits = 5
	check(Save.import_from("user://test_export.json") and Save.credits() == 777, "import validated file")
	var bad := FileAccess.open("user://test_bad.json", FileAccess.WRITE)
	bad.store_string(JSON.stringify({"schema": 2, "profile": {"credits": "lots"}}))
	bad.close()
	check(not Save.import_from("user://test_bad.json"), "import rejects invalid file")
	# purchases never charge twice
	_fresh_save()
	Save.data.profile.credits = 1000
	Save.data.profile.boards_unlocked.append("rocket")
	var r1 := Save.try_buy_board("rocket", 400)
	var r2 := Save.try_buy_board("rocket", 400)
	check(r1 == "ok" and r2 == "owned" and Save.credits() == 600, "buy once, second confirm does not charge", "%s %s %d" % [r1, r2, Save.credits()])
	check(Save.try_buy_board("legend", 1500) == "locked", "locked board cannot be bought")
	Save.data.profile.boards_unlocked.append("comet")
	check(Save.try_buy_board("comet", 900) == "credits" and Save.credits() == 600, "insufficient credits: no charge")
	Save.load_or_create()
	check(Save.has_board("rocket") and Save.credits() == 600, "purchase persisted")

func _u_rng() -> void:
	begin("unit: seeded RNG")
	var a := ItemSystem.new(); var b := ItemSystem.new(); var c := ItemSystem.new()
	a.setup(null, 42, true); b.setup(null, 42, true); c.setup(null, 43, true)
	var sa := []; var sb := []; var sc := []
	for i in 40:
		sa.append(a.roll("offense" if i % 2 == 0 else "utility", 1 + i % 4))
		sb.append(b.roll("offense" if i % 2 == 0 else "utility", 1 + i % 4))
		sc.append(c.roll("offense" if i % 2 == 0 else "utility", 1 + i % 4))
	check(sa == sb, "same seed -> same item rolls")
	check(sa != sc, "different seed -> different sequence")
	# position weighting: leader gets more defence (shield), last place more recovery (repair)
	var d := ItemSystem.new(); d.setup(null, 7, true)
	var lead := {}; var last := {}
	for i in 4000:
		var x := d.roll("utility", 1); lead[x] = int(lead.get(x, 0)) + 1
		var y := d.roll("utility", 4); last[y] = int(last.get(y, 0)) + 1
	check(int(lead.get(&"shield", 0)) > int(last.get(&"shield", 0)), "leader rolls more shields", "%s vs %s" % [lead.get(&"shield"), last.get(&"shield")])
	check(int(last.get(&"repair", 0)) > int(lead.get(&"repair", 0)), "last place rolls more repairs", "%s vs %s" % [last.get(&"repair"), lead.get(&"repair")])
	for n in [a, b, c, d]:
		n.free()

func _u_progression() -> void:
	begin("unit: credits / medals / unlocks")
	check(Game.race_credits(1, 0) == 100 and Game.race_credits(2, 0) == 70 and Game.race_credits(3, 0) == 40 and Game.race_credits(4, 0) == 25, "credits 100/70/40/25")
	check(Game.trick_bonus(100000) == 50 and Game.race_credits(1, 100000) == 150, "trick bonus capped at 50")
	check(Game.cup_medal_for_place(1) == 3 and Game.cup_medal_for_place(3) == 1 and Game.cup_medal_for_place(4) == 0, "cup medal by final standing")
	check(Game.skill_medal("trick", 3200) == 2 and Game.skill_medal("slalom_missed", 0) == 3 and Game.skill_medal("slalom_missed", 5) == 0 and Game.skill_medal("targets", 8) == 2, "skill medal thresholds")
	_fresh_save()
	var u1 := Save.award_medal("cup1", 1)
	check("cup:2" in u1 and "board:grip" in u1 and "board:rocket" in u1 and Save.medal("cup1") == 1, "bronze opens next cup + boards", str(u1))
	var u2 := Save.award_medal("cup1", 3)
	check("rider:boro" in u2 and "rider:yuki" in u2 and "board:twin" in u2, "gold unlocks silver+gold rewards", str(u2))
	check(Save.award_medal("cup1", 2).is_empty() and Save.medal("cup1") == 3, "lower medal never downgrades")
	var u4 := Save.award_medal("cup4", 3)
	check("rider:kaito" in u4 and "board:legend" in u4, "Legend Cup gold unlocks the secret rider", str(u4))
	check(Save.award_medal("cup4", 3).is_empty(), "unlocks applied only once")

func _u_content() -> void:
	begin("unit: content / i18n")
	check(Registry.TRACK_IDS.size() == 8 and Registry.RIDER_IDS.size() >= 8 and Registry.BOARD_IDS.size() == 12 and Registry.ITEM_IDS.size() == 12, "8 courses, 8+ riders, 12 boards, 12 items (10 + seeker comet + whirlwind)")
	for tid in Registry.TRACK_IDS + Registry.EXTRA_TRACK_IDS:
		var dl := Registry.track(tid).default_laps
		check(dl >= 3 and dl <= 9, "course %s has its own number of descents (%d)" % [tid, dl])
	for rid in Registry.RIDER_IDS:
		var sg := SignatureTricks.of(String(rid))
		check(SignatureTricks.DATA.has(String(rid)) and int(sg.points) >= 400 and fposmod(absf(float(sg.spin)), 180.0) < 0.1 and fposmod(absf(float(sg.flip)), 360.0) < 0.1,
			"rider %s signature lands aligned (%s)" % [rid, sg.pt])
	var names := SignatureTricks.DATA.values().map(func(x): return x.pt)
	check(names.size() == 9 and names.size() == Array(names).reduce(func(acc, n): return acc if acc.has(n) else acc + [n], []).size(), "signature names are unique")
	begin("unit: board upgrades")
	for bid in Registry.BOARD_IDS:
		var b := Registry.board(bid)
		var ok := true
		var better := false
		for lv in range(0, BoardDefinition.MAX_LEVEL + 1):
			var m := b.mods(lv)
			for k in m:
				if absf(float(m[k])) > 0.12 + 1e-6:
					ok = false
		var m0 := b.mods(0); var m3 := b.mods(3)
		for k in m0:
			if float(m3[k]) > float(m0[k]) + 1e-6:
				better = true
		check(ok, "board %s stays within ±12%% at every level" % bid)
		check(better or b.category == "speed" and float(m0.speed) >= 0.12 - 1e-6, "board %s improves with upgrades (or is already capped)" % bid)
	_fresh_save()
	Save.data.profile.credits = 1000
	check(Save.try_upgrade_board("rocket") == "not_owned", "cannot upgrade a board you do not own")
	var u1 := Save.try_upgrade_board("starter")
	var u2 := Save.try_upgrade_board("starter")
	var u3 := Save.try_upgrade_board("starter")
	var u4 := Save.try_upgrade_board("starter")
	check(u1 == "ok" and u2 == "ok" and u3 == "ok" and u4 == "max" and Save.board_level("starter") == 3 and Save.credits() == 1000 - 150 - 300 - 450, "levels 1-3 cost 150/300/450, max at 3", "%s %s %s %s %d" % [u1, u2, u3, u4, Save.credits()])
	Save.data.profile.credits = 100
	check(Save.try_upgrade_board("carver") == "credits" and Save.board_level("carver") == 0 and Save.credits() == 100, "insufficient credits: no charge, no level")
	Save.load_or_create()
	check(Save.board_level("starter") == 3, "upgrade level persisted")
	_fresh_save()
	begin("unit: content / i18n")
	var bad_keys := []
	for k in I18n.S:
		if (I18n.S[k] as Array).size() != 2 or String(I18n.S[k][0]) == "" or String(I18n.S[k][1]) == "":
			bad_keys.append(k)
	check(bad_keys.is_empty(), "every UI string has PT and EN", str(bad_keys))
	for bid in Registry.BOARD_IDS:
		var b := Registry.board(bid)
		var ok := absf(b.speed_mod) <= 0.12 and absf(b.control_mod) <= 0.12 and absf(b.jump_mod) <= 0.12 and absf(b.accel_mod) <= 0.12 and absf(b.spin_mod) <= 0.12
		check(ok, "board %s modifiers within ±12%%" % bid)
	for rid in Registry.RIDER_IDS:
		var d := Registry.rider(rid)
		check(ResourceLoader.exists(d.model_path) and ResourceLoader.exists(d.portrait_path), "rider %s model + portrait" % rid)
	for iid in Registry.ITEM_IDS:
		check(ResourceLoader.exists(Registry.item(iid).icon_path), "item %s icon" % iid)
	for tid in Registry.TRACK_IDS + Registry.EXTRA_TRACK_IDS:
		var td := Registry.track(tid)
		check(ResourceLoader.exists(td.scene_path) and FileAccess.file_exists(td.data_path) and ResourceLoader.exists(td.map_path) and ResourceLoader.exists(td.music_path), "course %s GLB/data/map/music" % tid)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(td.data_path))
		var cps: Array = data.checkpoints
		var gaps_ok := true
		for i in range(1, cps.size()):
			var g := float(cps[i]) - float(cps[i - 1])
			if g < 40.0 - 0.01 or g > 80.0 + 0.01:
				gaps_ok = false
		check(gaps_ok, "course %s checkpoints every 40–80 m" % tid)
		if td.campaign:
			check(near(float(data.length), td.length_m, 1.0), "course %s length %d m" % [tid, int(td.length_m)])

# ================================================================ INTEGRATION
func _integration() -> void:
	await _i_full_race()
	await _i_items_and_stations()
	await _i_recovery_and_reset()
	await _i_routes()
	await _i_progression_persist()
	await _i_modes()
	await _i_split_screen()

func _i_full_race() -> void:
	begin("integration: 5-run race, 4 riders, lift")
	var race := _new_race(&"vale_pinheiros", 5, Game.Mode.QUICK_RACE, 2024)
	var rm := _rm(race)
	var done := [{}]
	rm.race_done.connect(func(s): done[0] = s)
	var order_ok := true
	var lap_ok := true
	var seen_queue := false
	var last_laps := {}
	while done[0].is_empty():
		await get_tree().physics_frame
		if rm.lift.riding.size() > 0:
			seen_queue = true
		if Engine.get_physics_frames() % 6 == 0 and rm.phase == RaceManager.Phase.RACE:
			# ranking consistency: places follow the ranking key (0.5 m hysteresis)
			var rs := rm.riders.duplicate()
			rs.sort_custom(func(a, b): return a.place < b.place)
			for i in range(1, rs.size()):
				if not rs[i].finished and not rs[i - 1].finished and float(rs[i].get_meta("rank_key", 0.0)) > float(rs[i - 1].get_meta("rank_key", 0.0)) + 0.6:
					order_ok = false
		for r in rm.riders:
			if int(last_laps.get(r.index, 0)) > r.lap:
				lap_ok = false
			last_laps[r.index] = r.lap
	var s: Dictionary = done[0]
	var rows: Array = s.results
	check(rows.size() == 4, "4 participants")
	var all_fin := rows.all(func(x): return float(x.time) > 0.0 and int(x.laps_done) == 4)
	check(all_fin, "all 4 complete 5 descents", str(rows.map(func(x): return [x.rider, x.time, x.laps_done])))
	var places := rows.map(func(x): return int(x.place))
	places.sort()
	check(places == [1, 2, 3, 4], "places 1..4 unique")
	var times_sorted := rows.all(func(x): return true)
	for i in range(1, rows.size()):
		if float(rows[i].time) < float(rows[i - 1].time):
			times_sorted = false
	check(times_sorted, "finish order frozen by finishing time")
	check(int(s.cp_skips) == 0 and int(s.nan) == 0, "no skipped checkpoints, no NaN", "skips=%d nan=%d" % [s.cp_skips, s.nan])
	check(order_ok, "HUD ranking matches progress")
	check(lap_ok, "lap counter never decreases")
	check(seen_queue, "riders rode the lift between descents")
	check(float(s.time) > 120.0 and float(s.time) < 420.0, "race length plausible (3–6 min target)", "%.1f s" % float(s.time))
	await _end_race(race)

func _i_items_and_stations() -> void:
	begin("integration: stations + all 12 items")
	var race := _new_race(&"vale_pinheiros", 5, Game.Mode.QUICK_RACE, 77)
	var rm := _rm(race)
	await _wait_racing(rm)
	await _frames(120)
	var tr := rm.track
	var a: RiderController = rm.riders[0]
	var b: RiderController = rm.riders[1]
	# keep AIs from interfering: freeze everyone, we drive the effects directly
	for r in rm.riders:
		r.provider = Scripted.new()
		(r.provider as Scripted).follow = false
	# station purchase
	var st: Dictionary = tr.stations[0]
	a.offense_item = &""; a.utility_item = &""
	var msgs := []
	a.message.connect(func(_r, k): msgs.append(k))
	a.race_coins = 0
	st.cooldown = 0.0
	a.global_position = st.p + Vector3.UP * 0.3
	rm.items.try_station(a)
	check("no_coins" in msgs and a.race_coins == 0, "insufficient coins signalled, race continues")
	st.cooldown = 0.0
	a.race_coins = 25
	rm.items.try_station(a)
	var slot_item: StringName = a.offense_item if st.slot == "offense" else a.utility_item
	check(a.race_coins == 5 and slot_item != &"", "station sells an item for 20 coins", "coins=%d item=%s" % [a.race_coins, slot_item])
	check(Registry.item(slot_item).slot == st.slot, "item matches the station slot")
	rm.items.try_station(a)
	check(a.race_coins == 5, "full slot: no second charge")
	# helper to line up b ahead of a on the course
	var place := func(r: RiderController, s: float, lat: float) -> void:
		r.state = RiderController.State.GROUND
		r.place_at(tr.point_at(s, lat, 0.2), tr.fwd[tr.idx_at(s)])
		r.proj_idx = tr.idx_at(s)
		r.damage_cd = 0.0; r.invuln_t = 0.0; r.shield_t = 0.0; r.slow_t = 0.0; r.spinout_t = 0.0
	var hits := []
	b.got_hit.connect(func(_r, kind, blocked): hits.append([kind, blocked]))
	# snowball: projectile ahead
	place.call(a, 200.0, 0.0); place.call(b, 212.0, 0.0)
	a.progress = 200.0; b.progress = 212.0
	check(rm.items.use_item(a, &"snowball"), "snowball thrown")
	await _frames(60)
	check(hits.any(func(h): return h[0] == "snowball"), "snowball hits the rider ahead", str(hits))
	# penguin chaser
	hits.clear()
	place.call(a, 260.0, 0.0); place.call(b, 285.0, 2.0)
	a.s = 260.0; b.s = 285.0; a.progress = 260.0; b.progress = 285.0
	check(rm.items.use_item(a, &"penguin"), "penguin released")
	await _frames(150)
	check(hits.any(func(h): return h[0] == "penguin"), "penguin catches the target", str(hits))
	# ice mine: dropped behind, triggers on a grounded rider
	hits.clear()
	place.call(a, 330.0, 0.0)
	rm.items.use_item(a, &"icemine")
	await _frames(40)
	var mine: Dictionary = rm.items.mines.back()
	place.call(b, 0.0, 0.0)
	b.global_position = mine.p + Vector3.UP * 0.2
	await _frames(3)
	check(hits.any(func(h): return h[0] == "icemine") and b.spinout_t > 0.0, "ice mine spins the rider out", str(hits))
	# fog cloud
	place.call(a, 380.0, 0.0); place.call(b, 400.0, 0.0)
	a.progress = 380.0; b.progress = 400.0
	rm.items.use_item(a, &"fog")
	await _frames(5)
	check(b.fog_t > 0.0, "fog reduces visibility of the rider inside it")
	# wave pushes nearby riders
	hits.clear()
	place.call(a, 450.0, 0.0); place.call(b, 452.0, 3.0)
	await _frames(1)
	rm.items.use_item(a, &"wave")
	check(hits.any(func(h): return h[0] == "wave"), "snow wave hits riders within 12 m")
	# seeker comet: flies to the leader along the course
	hits.clear()
	place.call(a, 600.0, 0.0); place.call(b, 700.0, 0.0)
	a.s = 600.0; b.s = 700.0; a.progress = 600.0; b.progress = 700.0; a.lap = 0; b.lap = 0
	for r in rm.riders:
		r.place = 4
	b.place = 1; a.place = 2
	check(rm.items.use_item(a, &"comet"), "seeker comet launched at the leader")
	await _frames(200)
	check(hits.any(func(h): return h[0] == "comet") and b.slow_t > 0.0, "comet reaches and slows the leader", str(hits))
	b.place = 2; a.place = 1
	check(not rm.items.use_item(a, &"comet"), "the leader cannot use the seeker comet")
	# whirlwind: target loses its inventory
	hits.clear()
	place.call(a, 640.0, 0.0); place.call(b, 655.0, 0.0)
	b.offense_item = &"snowball"; b.utility_item = &"shield"
	await _frames(1)
	check(rm.items.use_item(a, &"whirl"), "whirlwind thrown")
	await _frames(60)
	check(hits.any(func(h): return h[0] == "whirl") and b.offense_item == &"" and b.utility_item == &"", "whirlwind strips both item slots", "%s %s %s" % [str(hits), b.offense_item, b.utility_item])
	# gust / shield / magnet / spring / repair
	place.call(a, 500.0, 0.0)
	rm.items.use_item(a, &"gust")
	check(near(a.boost_t, 2.0, 0.05), "gust boosts for 2 s")
	rm.items.use_item(a, &"shield")
	check(near(a.shield_t, 6.0, 0.05), "shield lasts 6 s")
	rm.items.use_item(a, &"magnet")
	check(near(a.magnet_t, 5.0, 0.05), "magnet lasts 5 s")
	await _frames(2)
	place.call(a, 520.0, 0.0)
	await _frames(10)
	var vy0 := a.velocity.y
	check(rm.items.use_item(a, &"spring") and a.state == RiderController.State.AIR and a.velocity.y > vy0 + 8.0, "spring launches from the ground")
	check(not rm.items.use_item(a, &"spring"), "spring refused in the air")
	await _frames(90)
	check(not rm.items.use_item(a, &"repair"), "repair refused when not fallen")
	a.state = RiderController.State.GROUND
	a._crash()
	check(rm.items.use_item(a, &"repair"), "repair used while fallen")
	await _frames(12)
	check(a.state == RiderController.State.GROUND, "repair gets the rider up quickly")
	# projectiles expire, never pass walls (4 s life)
	place.call(a, 560.0, 0.0)
	rm.items.use_item(a, &"snowball")
	await _frames(int(ItemSystem.PROJECTILE_LIFE * 60) + 10)
	check(rm.items.projectiles.filter(func(p): return p.kind == "snowball").is_empty(), "snowball expires within 4 s")
	await _end_race(race)

func _i_recovery_and_reset() -> void:
	begin("integration: off-track reset")
	var race := _new_race(&"pico_vulcanico", 5, Game.Mode.QUICK_RACE, 5)
	var rm := _rm(race)
	await _wait_racing(rm)
	await _frames(240)
	var r: RiderController = rm.riders[1]
	var safe := r.last_safe_s
	var resets0 := int(rm.qa.resets)
	r.global_position += rm.track.right[rm.track.idx_at(r.s)] * 70.0 + Vector3.UP * 5.0
	await _frames(int((r.tuning.offtrack_reset_time + 0.6) * 60))
	check(int(rm.qa.resets) > resets0, "rider far off the course is reset after 2 s")
	check(r.state == RiderController.State.FROZEN or r.state == RiderController.State.GROUND, "reset to the last safe checkpoint with penalty")
	var pr := rm.track.project(r.global_position, r.proj_idx)
	check(absf(float(pr.lat)) < 3.0 and float(pr.s) >= safe - 1.0, "placed back on the course", "s=%.0f safe=%.0f lat=%.1f" % [float(pr.s), safe, float(pr.lat)])
	await _end_race(race)

func _i_routes() -> void:
	begin("integration: split routes / shortcuts")
	for tid in Registry.TRACK_IDS:
		var td := Registry.track(tid)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(td.data_path))
		var splits := (data.features as Array).filter(func(f): return f.type == "split")
		if splits.is_empty():
			check(false, "%s has split routes" % tid)
			continue
		var sp: Dictionary = splits[0]
		for side in [-1.0, 1.0]:
			var sb := _sandbox(tid, &"taro", &"grip")
			var r: RiderController = sb.r
			var tr: TrackRuntime = sb.tr
			var s0 := maxf(10.0, float(sp.s0) - 60.0)
			var lane: float = side * (float(sp.div) * 0.5 + tr.half_width(float(sp.s0)) * 0.5) * 0.5 + float(sp.get("lat", 0.0))
			r.place_at(tr.point_at(s0, 0.0, 0.3), tr.fwd[tr.idx_at(s0)])
			r.proj_idx = tr.idx_at(s0)
			var prov: Scripted = sb.prov
			prov.lane = lane
			var max_s := s0
			var off_max := 0.0
			for i in 60 * 14:
				await get_tree().physics_frame
				var pr := tr.project(r.global_position, r.proj_idx)
				max_s = maxf(max_s, float(pr.s))
				if float(pr.s) > float(sp.s0) and float(pr.s) < float(sp.s1):
					off_max = maxf(off_max, absf(float(pr.lat)) - tr.half_width(float(pr.s)))
				if max_s > float(sp.s1) + 20.0:
					break
			check(max_s > float(sp.s1) + 10.0, "%s %s route at s=%d is passable" % [tid, "left" if side < 0 else "right", int(sp.s0)], "reached s=%.0f (split ends %d)" % [max_s, int(sp.s1)])
			check(off_max < 8.0, "%s %s route counts for checkpoints (inside gate width)" % [tid, "left" if side < 0 else "right"], "beyond edge %.1f m" % off_max)
			await _free(sb)

func _i_progression_persist() -> void:
	begin("integration: cup finish, unlock, save reload")
	_fresh_save()
	Game.mode = Game.Mode.GRAND_PRIX
	Game.cup_index = 0
	Game.cup_race = 1
	Game.track_id = &"lago_cristal"
	Game.participants = [{"type": "human", "device": "kb", "rider": "niko", "board": "starter"}, {"type": "ai", "rider": "mika", "board": "carver", "device": ""},
		{"type": "ai", "rider": "taro", "board": "float", "device": ""}, {"type": "ai", "rider": "luna", "board": "grip", "device": ""}]
	Game.cup_points = {0: 10, 1: 7, 2: 4, 3: 2}
	Game.cup_credits_earned = 100
	Game.last_results = [{"index": 0, "rider": "niko", "board": "starter", "human": true, "place": 1, "time": 60.0, "tricks": 900, "coins": 40, "laps_done": 4, "gates": 0, "missed": 0, "landings": 0},
		{"index": 1, "rider": "mika", "board": "carver", "human": false, "place": 2, "time": 61.0, "tricks": 0, "coins": 0, "laps_done": 4, "gates": 0, "missed": 0, "landings": 0},
		{"index": 2, "rider": "taro", "board": "float", "human": false, "place": 3, "time": 62.0, "tricks": 0, "coins": 0, "laps_done": 4, "gates": 0, "missed": 0, "landings": 0},
		{"index": 3, "rider": "luna", "board": "grip", "human": false, "place": 4, "time": 63.0, "tricks": 0, "coins": 0, "laps_done": 4, "gates": 0, "missed": 0, "landings": 0}]
	Game.results_processed = false
	var s := Game.process_results()
	check(int(Game.cup_points[0]) == 20 and int(Game.cup_points[3]) == 4, "cup points accumulate over the 2 races")
	check(int(s.credits) == 100 + 22, "1st place credits + trick bonus", str(s.credits))
	check(s.cup_done and int(s.medal) == 3, "cup closes with gold")
	check("cup:2" in s.unlocks and "rider:yuki" in s.unlocks, "unlocks granted", str(s.unlocks))
	var again := Game.process_results()
	check(again == s and Save.credits() == 122, "results applied exactly once", str(Save.credits()))
	Save.data = {}
	Save.load_or_create()
	check(Save.credits() == 122 and Save.has_rider("yuki") and int(Save.profile().cups_unlocked) == 2 and Save.medal("cup1") == 3, "progress survives reload")
	_fresh_save()

func _i_modes() -> void:
	begin("integration: time trial ghost")
	var race := _new_race(&"vale_pinheiros", 1, Game.Mode.TIME_TRIAL, 9, [{"type": "human", "device": "kb", "rider": "yuki", "board": "carver"}])
	var rm := _rm(race)
	var done := [{}]
	rm.race_done.connect(func(s): done[0] = s)
	while done[0].is_empty():
		await get_tree().physics_frame
	var g: Dictionary = Save.data.ghosts.get("vale_pinheiros", {})
	check(rm.riders.size() == 1 and not rm.items.enabled, "solo run, items off")
	check(not g.is_empty() and (g.frames as Array).size() > 100, "ghost recorded as transform samples", str((g.get("frames", []) as Array).size()))
	check(Save.record("vale_pinheiros", "carver") > 0.0, "record stored per course and board")
	await _end_race(race)

	begin("integration: trick attack (2 min)")
	race = _new_race(&"parque_manobras", 99, Game.Mode.TRICK_ATTACK, 4, [{"type": "human", "device": "kb", "rider": "luna", "board": "twin"}])
	rm = _rm(race)
	done = [{}]
	rm.race_done.connect(func(s): done[0] = s)
	while done[0].is_empty():
		await get_tree().physics_frame
	check(near(float(done[0].time), 120.0, 0.5), "ends at 2:00", str(done[0].time))
	check(int(done[0].results[0].tricks) > 0, "tricks scored", str(done[0].results[0].tricks))
	await _end_race(race)

	begin("integration: target shooting")
	Game.laps = 0
	race = _new_race(&"vale_pinheiros", 1, Game.Mode.SKILL_TARGETS, 12, [{"type": "human", "device": "kb", "rider": "taro", "board": "rocket"}])
	rm = _rm(race)
	done = [{}]
	rm.race_done.connect(func(s): done[0] = s)
	while done[0].is_empty():
		await get_tree().physics_frame
	var trow: Dictionary = done[0].results[0]
	check(rm.targets.size() >= 9, "targets placed along the course", str(rm.targets.size()))
	check(int(trow.targets) > 0 and int(trow.targets) <= rm.targets.size(), "snowballs knock targets down", "%d/%d" % [trow.targets, rm.targets.size()])
	Game.last_results = done[0].results
	Game.results_processed = false
	var tsum := Game.process_results()
	check(String(tsum.skill_kind) == "targets" and int(tsum.medal) == Game.skill_medal("targets", float(trow.targets)), "graded with target thresholds", "%d -> %d" % [trow.targets, tsum.medal])
	await _end_race(race)

	begin("integration: skill games")
	for m in [Game.Mode.SKILL_SLALOM, Game.Mode.SKILL_COINS, Game.Mode.SKILL_LANDING]:
		race = _new_race(&"vale_pinheiros", 1, m, 6, [{"type": "human", "device": "kb", "rider": "mika", "board": "grip"}])
		rm = _rm(race)
		done = [{}]
		rm.race_done.connect(func(s): done[0] = s)
		while done[0].is_empty():
			await get_tree().physics_frame
		var row: Dictionary = done[0].results[0]
		match m:
			Game.Mode.SKILL_SLALOM:
				check(rm.slalom_gates.size() > 5 and int(row.gates) + int(row.missed) == rm.slalom_gates.size(), "slalom gates all judged", "%d+%d/%d" % [row.gates, row.missed, rm.slalom_gates.size()])
			Game.Mode.SKILL_COINS:
				check(int(row.coins) > 0 and float(row.time) > 0.0, "coin rush collects coins", str(row.coins))
			Game.Mode.SKILL_LANDING:
				check(near(float(done[0].time), 120.0, 0.5), "landing challenge lasts 2 min")
		Game.last_results = done[0].results
		Game.results_processed = false
		var sm := Game.process_results()
		check(int(sm.medal) >= 0 and String(sm.skill_kind) != "", "skill result graded with configurable thresholds", "%s=%s medal=%d" % [sm.skill_kind, sm.skill_value, sm.medal])
		await _end_race(race)
	_fresh_save()

func _i_split_screen() -> void:
	begin("integration: local multiplayer split screen")
	for n in [2, 3, 4]:
		var ps: Array = []
		for i in n:
			ps.append({"type": "human", "device": ["kb_left", "kb_right", "joy0", "joy1"][i], "rider": ["niko", "mika", "taro", "luna"][i], "board": "starter"})
		for i in range(n, 4):
			ps.append({"type": "ai", "device": "", "rider": ["boro", "yuki", "zed", "pippa"][i], "board": "carver"})
		var race := _new_race(&"festival_boreal", 1, Game.Mode.QUICK_RACE, 3, ps, false)
		var rm := _rm(race)
		await _frames(5)
		var cs := rm.screens.get_children()
		check(cs.size() == n and rm.cameras.size() == n and rm.huds.size() == n, "%d players: %d viewports, cameras, HUDs" % [n, n])
		var vs := get_viewport().get_visible_rect().size
		var c0 := cs[0] as Control
		if n == 2:
			check(near(c0.size.x, vs.x, 1) and near(c0.size.y, vs.y / 2.0, 1), "2 players split horizontally")
		else:
			check(near(c0.size.x, vs.x / 2.0, 1) and near(c0.size.y, vs.y / 2.0, 1), "%d players in a 2x2 grid" % n)
		var provs := rm.riders.filter(func(r): return r.is_human).map(func(r): return (r.provider as HumanProvider).device if r.provider is HumanProvider else "")
		check(provs.size() == n and provs.all(func(d): return d != ""), "each human reads its own device", str(provs))
		var w := (cs[0] as SubViewportContainer).get_child(0) as SubViewport
		check(w.find_world_3d() == get_viewport().find_world_3d(), "viewports share one World3D / simulation")
		await _end_race(race)

# ================================================================ E2E (menus, keyboard + gamepad)
func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var u := InputEventAction.new()
	u.action = action
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame

func _joy(button: JoyButton) -> void:
	## Gamepad button as the OS would deliver it (no physical pad in CI): pushed into the viewport input path.
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	e.pressure = 1.0
	e.device = 0
	get_viewport().push_input(e)
	await get_tree().process_frame
	var u := e.duplicate() as InputEventJoypadButton
	u.pressed = false
	u.pressure = 0.0
	get_viewport().push_input(u)
	await get_tree().process_frame
	await get_tree().process_frame

func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()

func _e2e() -> void:
	begin("e2e: menu flow (keyboard + gamepad)")
	_fresh_save()
	if Game.has_meta("requested_scene"):
		Game.remove_meta("requested_scene")
	var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)
	await _frames(10)
	check(menu.screen == "title", "opens on the title")
	await _press("ui_accept")
	check(menu.screen == "main", "Enter opens the main menu", menu.screen)
	check(_focus() != null, "a control has visible focus")
	# every main entry reachable with ui_down, focus never lost
	var labels := []
	for i in 10:
		labels.append((_focus() as Button).text if _focus() is Button else "?")
		await _press("ui_down")
	check(labels.size() == 10 and not "?" in labels and Game.t("local_mp") in labels, "all 10 main entries focusable (incl. local multiplayer)", str(labels))
	var jd := InputEventJoypadButton.new(); jd.button_index = JOY_BUTTON_DPAD_DOWN; jd.pressed = true
	var ja := InputEventJoypadButton.new(); ja.button_index = JOY_BUTTON_A; ja.pressed = true
	var jb := InputEventJoypadButton.new(); jb.button_index = JOY_BUTTON_B; jb.pressed = true
	check(jd.is_action("ui_down") and ja.is_action("ui_accept") and jb.is_action("ui_cancel"), "gamepad d-pad/A/B map to ui navigation")
	var ax := InputEventJoypadMotion.new(); ax.axis = JOY_AXIS_LEFT_Y; ax.axis_value = 1.0
	check(ax.is_action("ui_down"), "left stick navigates menus")
	# options via gamepad: d-pad to "Opções" and A
	menu.go("main", false)
	await _frames(2)
	for i in 8:
		await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_A)
	check(menu.screen == "options", "gamepad d-pad + A open Options", menu.screen)
	var lang_before := String(Save.settings().lang)
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	check(String(Save.settings().lang) != lang_before, "language switches with d-pad right (PT/EN)")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	check(String(Save.settings().lang) == lang_before, "and back")
	await _joy(JOY_BUTTON_B)
	check(menu.screen == "main", "B goes back", menu.screen)
	# remap a key
	menu.go("controls")
	await _frames(2)
	await _press("ui_accept")   # first row: steer_left
	var k := InputEventKey.new()
	k.physical_keycode = KEY_J
	k.keycode = KEY_J
	k.pressed = true
	get_viewport().push_input(k)
	await _frames(3)
	check(Inputs.key_name("steer_left") == "J" and int(Save.settings().remaps.get("steer_left", 0)) == KEY_J, "steer_left remapped to J and saved", Inputs.key_name("steer_left"))
	Inputs.reset_keyboard_defaults()
	Save.settings().remaps = {}
	# local multiplayer entry: two humans seated, a third joins with START on a free pad
	menu.history.clear()
	menu.go("main", false)
	await _frames(2)
	await _press("ui_down")
	await _press("ui_down")
	await _press("ui_accept")
	check(menu.screen == "participants" and menu.slots.filter(func(x): return x.type == "human").size() == 2, "Local multiplayer seats 2 players", str(menu.slots))
	var st := InputEventJoypadButton.new(); st.button_index = JOY_BUTTON_START; st.pressed = true; st.device = 2
	get_viewport().push_input(st)
	await _frames(3)
	check(menu.slots.filter(func(x): return x.type == "human").size() == 3 and menu.slots.any(func(x): return x.device == "joy2"), "START on a free pad joins as P3", str(menu.slots))
	get_viewport().push_input(st)
	await _frames(3)
	check(menu.slots.filter(func(x): return x.type == "human").size() == 3, "same pad cannot join twice")
	menu._participants_done()
	await _frames(2)
	check(menu.screen == "rider" and menu.picks.size() == 3, "each human picks a rider in turn", str(menu.picks.size()))
	# quick race: participants -> rider (confirm anim) -> board -> track -> launch request
	menu.history.clear()
	menu.go("main", false)
	await _frames(2)
	await _press("ui_down")
	await _press("ui_accept")
	check(menu.screen == "participants", "Quick race opens participant slots", menu.screen)
	await _press("ui_down")          # slot 2 type
	await _press("ui_right")         # CPU -> Empty
	check(menu.slots[1].type == "empty", "slot type changed with right", str(menu.slots[1]))
	await _press("ui_left")
	for i in 4:
		await _press("ui_down")
	if not (_focus() is Button and (_focus() as Button).text == Game.t("continue_btn")):
		menu._participants_done()
	else:
		await _press("ui_accept")
	await _frames(3)
	check(menu.screen == "rider", "rider select", menu.screen)
	await _press("ui_accept")
	await get_tree().create_timer(1.4).timeout
	check(menu.screen == "board", "confirm animation then board select", menu.screen)
	await _press("ui_accept")
	await get_tree().create_timer(1.1).timeout
	check(menu.screen == "track", "track select", menu.screen)
	check(_focus() is Button and (_focus() as Button).text.contains(Registry.track(&"vale_pinheiros").display_name), "first unlocked course focused", str(_focus()))
	await _press("ui_accept")
	for i in 3000:
		await get_tree().process_frame
		if Game.has_meta("requested_scene"):
			break
	check(String(Game.get_meta("requested_scene", "")) == "race", "Start loads assets and requests the race", str(Game.get_meta("requested_scene", "")))
	check(Game.participants.size() == 4 and Game.participants[0].type == "human", "participants built from the slots", str(Game.participants.size()))
	menu.queue_free()
	await _frames(2)
	await _e2e_garage()
	await _e2e_grand_prix()
	await _e2e_touch()
	# pause -> restart / menu in a live race (human slot)
	begin("e2e: race pause / restart / quit")
	Game.remove_meta("requested_scene")
	var race := _new_race(&"vale_pinheiros", 1, Game.Mode.QUICK_RACE, 8, [{"type": "human", "device": "kb", "rider": "niko", "board": "starter"},
		{"type": "ai", "device": "", "rider": "mika", "board": "carver"}], false)
	var rm := _rm(race)
	await _wait_racing(rm)
	var kd := InputEventKey.new(); kd.physical_keycode = KEY_W; kd.keycode = KEY_W; kd.pressed = true
	Input.parse_input_event(kd)
	await _frames(90)
	check(rm.riders[0].last_cmd.tuck, "keyboard input reaches the rider (W = tuck)")
	var ku := kd.duplicate() as InputEventKey; ku.pressed = false
	Input.parse_input_event(ku)
	await _press("pause")
	check(get_tree().paused and rm.paused and rm.pause_menu != null, "Esc pauses")
	var t_paused := rm.race_time
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(near(rm.race_time, t_paused, 0.001), "simulation frozen while paused")
	await _press("ui_cancel")
	check(not get_tree().paused, "Esc/B resumes")
	await _press("pause")
	await _press("ui_down")
	await _press("ui_accept")
	check(String(Game.get_meta("requested_scene", "")) == "race", "Restart requested from pause")
	Game.remove_meta("requested_scene")
	get_tree().paused = false
	await _end_race(race)

func _e2e_touch() -> void:
	begin("e2e: touch controls (handler level)")
	var tc := TouchControls.new()
	add_child(tc)
	tc.size = get_viewport().get_visible_rect().size
	tc.setup(null)
	await _frames(2)
	var vs := get_viewport().get_visible_rect().size
	# The headless display server never dispatches screen-touch events (neither Input.parse_input_event nor
	# Viewport.push_input), so the events are fed to the control's own handler. OS delivery needs a real device.
	var touch := func(idx: int, pos: Vector2, on: bool) -> void:
		var e := InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = on
		tc._input(e)
	var drag := func(idx: int, pos: Vector2) -> void:
		var e := InputEventScreenDrag.new(); e.index = idx; e.position = pos
		tc._input(e)
	# thumb-stick on the left half: drag right = steer right, up = tuck
	var o := Vector2(vs.x * 0.2, vs.y * 0.7)
	touch.call(0, o, true)
	drag.call(0, o + Vector2(100, 0))
	await _frames(1)
	check(float(TouchControls.state.steer) > 0.7, "stick dragged right steers right", str(TouchControls.state.steer))
	drag.call(0, o + Vector2(0, -90))
	await _frames(1)
	check(bool(TouchControls.state.tuck) and absf(float(TouchControls.state.steer)) < 0.2, "stick pushed up = tuck")
	# second finger on JUMP while steering (multi-touch)
	var jb: Dictionary = tc._buttons.filter(func(b): return b.id == "jump")[0]
	touch.call(1, jb.c, true)
	await _frames(1)
	check(bool(TouchControls.state.jump) and bool(TouchControls.state.tuck), "multi-touch: jump held while steering")
	var cmd := InputCommand.new()
	Inputs.read("touch", cmd)
	check(cmd.jump_held and cmd.tuck, "InputRouter reads the 'touch' device")
	touch.call(1, jb.c, false)
	touch.call(0, o, false)
	await _frames(1)
	check(not bool(TouchControls.state.jump) and float(TouchControls.state.steer) == 0.0, "releasing fingers resets the controls")
	# item button edge-triggers use_offense once
	var ob: Dictionary = tc._buttons.filter(func(b): return b.id == "off")[0]
	touch.call(2, ob.c, true)
	Inputs.read("touch", cmd)
	var first := cmd.use_offense
	Inputs.read("touch", cmd)
	check(first and not cmd.use_offense, "item button fires once per tap")
	touch.call(2, ob.c, false)
	var paused := [false]
	tc.pause_pressed.connect(func(): paused[0] = true)
	var pb: Dictionary = tc._buttons.filter(func(b): return b.id == "pause")[0]
	touch.call(3, pb.c, true)
	touch.call(3, pb.c, false)
	check(paused[0], "on-screen pause button")
	for b in tc._buttons:
		check(Rect2(Vector2.ZERO, vs).has_point(b.c), "button %s inside the screen" % b.id)
	tc.queue_free()
	await _frames(1)
	TouchControls.reset_state()
	# forced touch mode: menus show an on-screen back button and default the player to the touch device
	Save.settings().touch_controls = "on"
	var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)
	await _frames(3)
	menu.go("main")
	await _frames(2)
	check(menu._back_btn != null, "touch: on-screen Back button in menus")
	menu._back_btn.pressed.emit()
	await _frames(2)
	check(menu.screen == "title", "Back button goes back")
	menu._begin(Game.Mode.QUICK_RACE)
	check(String(menu.slots[0].device) == "touch", "player 1 defaults to the touch device")
	menu.queue_free()
	await _frames(2)
	Save.settings().touch_controls = "auto"

func _e2e_garage() -> void:
	begin("e2e: garage purchase + equip")
	_fresh_save()
	Save.data.profile.credits = 1000
	Save.data.profile.boards_unlocked.append("rocket")
	Save.write()
	var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)
	await _frames(5)
	menu.go("garage")
	await _frames(3)
	var target: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Rocket"):
			target = b
	check(target != null, "Rocket listed in the shop")
	target.grab_focus()
	await _press("ui_accept")
	await _frames(2)
	var yes: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == Game.t("yes"):
			yes = b
	check(yes != null, "purchase asks for confirmation")
	check(Save.credits() == 1000, "nothing charged before confirming")
	yes.pressed.emit()
	yes.pressed.emit()   # double confirm must not charge twice
	await _frames(3)
	check(Save.credits() == 600 and Save.has_board("rocket"), "charged once (1000 -> 600), board owned", str(Save.credits()))
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Rocket"):
			target = b
	target.grab_focus()
	await _press("ui_accept")
	check(String(Save.profile().equipped.board) == "rocket" and Save.credits() == 600, "owned board equips without charge")
	Save.load_or_create()
	check(Save.has_board("rocket") and Save.credits() == 600, "purchase persisted on disk")
	menu.queue_free()
	await _frames(2)
	_fresh_save()

func _e2e_grand_prix() -> void:
	begin("e2e: grand prix results flow")
	_fresh_save()
	Game.mode = Game.Mode.GRAND_PRIX
	Game.cup_index = 0
	Game.cup_race = 0
	Game.cup_points.clear()
	Game.cup_credits_earned = 0
	Game.track_id = &"vale_pinheiros"
	Game.participants = [{"type": "human", "device": "kb", "rider": "niko", "board": "starter"}, {"type": "ai", "rider": "mika", "board": "carver", "device": ""},
		{"type": "ai", "rider": "taro", "board": "float", "device": ""}, {"type": "ai", "rider": "luna", "board": "grip", "device": ""}]
	var rows := func(order: Array) -> Array:
		var out: Array = []
		for k in order.size():
			var i: int = order[k]
			out.append({"index": i, "rider": Game.participants[i].rider, "board": Game.participants[i].board, "human": i == 0, "place": k + 1,
				"time": 60.0 + k, "tricks": 400 if i == 0 else 0, "coins": 10, "laps_done": 4, "gates": 0, "missed": 0, "landings": 0})
		return out
	Game.last_results = rows.call([1, 0, 2, 3])
	Game.results_processed = false
	if Game.has_meta("requested_scene"):
		Game.remove_meta("requested_scene")
	var res := (load("res://scenes/menus/results.tscn") as PackedScene).instantiate()
	add_child(res)
	await _frames(5)
	check(_focus() is Button and (_focus() as Button).text == Game.t("next_race"), "race 1 of 2: 'Next race' focused")
	check(int(Game.cup_points[0]) == 7 and int(Game.cup_points[1]) == 10, "points 10/7/4/2 awarded")
	check(Save.credits() == 70 + 10, "2nd place credits 70 + trick bonus 10", str(Save.credits()))
	await _press("ui_accept")
	check(String(Game.get_meta("requested_scene", "")) == "race" and Game.cup_race == 1 and Game.track_id == &"lago_cristal", "next cup race requested (Lago Cristal)")
	res.queue_free()
	await _frames(2)
	Game.remove_meta("requested_scene")
	Game.last_results = rows.call([0, 1, 3, 2])
	Game.results_processed = false
	res = (load("res://scenes/menus/results.tscn") as PackedScene).instantiate()
	add_child(res)
	await _frames(5)
	var s: Dictionary = Game.last_summary
	check(s.cup_done and Game.standings(Game.cup_points)[0][0] == 0, "cup closes, player leads on 17 points", str(Game.cup_points))
	check(int(s.medal) == 3 and Save.medal("cup1") == 3, "gold medal stored")
	check("rider:yuki" in s.unlocks and "cup:2" in s.unlocks, "unlocks listed on the results screen", str(s.unlocks))
	var labels := res.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	check(labels.any(func(t): return t.contains("Yuki")), "unlock text visible")
	await _press("ui_accept")
	check(String(Game.get_meta("requested_scene", "")) == "menu:main", "last race returns to the main menu")
	res.queue_free()
	await _frames(2)
	Game.remove_meta("requested_scene")
	_fresh_save()

# ================================================================ AI RACES
func _ai_races() -> void:
	begin("ai: automated races")
	var n := int(_arg("--ai-races", "2"))
	var laps := int(_arg("--ai-laps", "0"))   # 0 = each course's own number of descents
	var tracks: Array = []
	var ta := _arg("--tracks", "")
	if ta != "":
		for t in ta.split(","):
			tracks.append(StringName(t))
	else:
		tracks = Registry.TRACK_IDS + Registry.EXTRA_TRACK_IDS
	for tid in tracks:
		var stats := {"track": String(tid), "races": 0, "completed": 0, "riders_finished": 0, "riders_total": 0, "cp_skips": 0, "nan": 0,
			"resets": 0, "max_stall": 0.0, "times": [], "fails": [], "wins": {}, "laps": laps if laps > 0 else Registry.track(tid).default_laps}
		for k in n:
			var seed_ := 1000 + k * 37
			Game.seed_value = seed_
			Game.default_participants(String(Registry.RIDER_IDS[k % 8]), ["starter", "carver", "float", "rocket"][k % 4])
			var race := _new_race(tid, laps if laps > 0 else Registry.track(tid).default_laps, Game.Mode.QUICK_RACE, seed_, Game.participants.duplicate(true))
			var rm := _rm(race)
			var done := [{}]
			rm.race_done.connect(func(s): done[0] = s)
			while done[0].is_empty():
				await get_tree().physics_frame
			var s: Dictionary = done[0]
			stats.races += 1
			var fin: int = s.results.filter(func(x): return float(x.time) > 0.0).size()
			stats.riders_finished += fin
			stats.riders_total += s.results.size()
			if fin == s.results.size():
				stats.completed += 1
			else:
				stats.fails.append({"seed": seed_, "unfinished": s.results.filter(func(x): return float(x.time) <= 0.0).map(func(x): return [x.rider, x.laps_done])})
			stats.cp_skips += int(s.cp_skips)
			stats.nan += int(s.nan)
			stats.resets += int(s.resets)
			for v in (s.max_stall as Dictionary).values():
				stats.max_stall = maxf(float(stats.max_stall), float(v))
			stats.times.append(float(s.results[0].time))
			var w := String(s.results[0].rider)
			stats.wins[w] = int(stats.wins.get(w, 0)) + 1
			await _end_race(race)
		var times: Array = stats.times
		times.sort()
		stats["best"] = times[0] if times.size() > 0 else -1.0
		stats["median"] = times[times.size() / 2] if times.size() > 0 else -1.0
		stats.erase("times")
		ai_report.append(stats)
		print("  AI %s races=%d complete=%d finishers=%d/%d skips=%d nan=%d resets=%d stall=%.1fs winner best=%.1f median=%.1f" % [tid, stats.races,
			stats.completed, stats.riders_finished, stats.riders_total, stats.cp_skips, stats.nan, stats.resets, stats.max_stall, stats.best, stats.median])
		check(stats.completed == stats.races, "%s: every AI finishes (%d races x %d runs)" % [tid, n, laps], str(stats.fails))
		check(stats.cp_skips == 0, "%s: no skipped checkpoints" % tid, str(stats.cp_skips))
		check(stats.nan == 0, "%s: no NaN" % tid)
		check(float(stats.max_stall) < 20.0, "%s: no AI stuck (longest stall < 20 s)" % tid, "%.1f" % stats.max_stall)
