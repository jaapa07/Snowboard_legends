class_name RaceManager
extends Node
## Owns a race: loads the course, spawns riders, runs countdown, checkpoints, ranking (10 Hz), lift flow,
## off-track recovery, item stations, finish and results. Physics is never coupled to UI: HUD listens to signals.

signal phase_changed(phase: int)
signal ranking_changed()
signal rider_finished(rider: RiderController)
signal lap_changed(rider: RiderController)
signal countdown(value: int)

enum Phase { LOADING, COUNTDOWN, RACE, DONE }
const RIDER_REPEL_DIST := 1.1
const TIME_LIMIT_AFTER_FIRST := 35.0

var phase: int = Phase.LOADING
var track: TrackRuntime
var riders: Array[RiderController] = []
var ais: Array = []
var items: ItemSystem
var lift := LiftSystem.new()
var laps: int = 5
var race_time: float = 0.0
var mode: int = 0
var huds: Array = []
var cameras: Array[ChaseCamera] = []
var world: Node3D
var screens: Control
var rng := RandomNumberGenerator.new()
var _rank_t: float = 0.0
var _count_t: float = 0.0
var _last_count: int = 4
var _first_finish_t: float = -1.0
var _finish_order: int = 0
var _riding_cabins: Dictionary = {}
var _cabin_pool: Array[Node3D] = []
var ghost_frames: Array = []
var ghost_node: Node3D
var _ghost_play: Array = []
var _ghost_t: float = 0.0
var trick_time_left: float = 120.0
var slalom_gates: Array[Dictionary] = []
var gates_passed: int = 0
var gates_missed: int = 0
var landings_clean: int = 0
var paused: bool = false
var pause_menu: Control
var test_log: Array[String] = []
var max_race_time: float = 600.0

func _ready() -> void:
	add_to_group("race_manager")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mode = Game.mode
	rng.seed = Game.seed_value
	laps = Game.laps
	if mode == Game.Mode.TIME_TRIAL or mode == Game.Mode.SKILL_SLALOM or mode == Game.Mode.SKILL_COINS:
		laps = 1
	if mode == Game.Mode.TRICK_ATTACK or mode == Game.Mode.SKILL_LANDING:
		laps = 99
		lift.skip_animation = true
	world = get_parent().get_node("World")
	screens = get_parent().get_node("UI/Screens")
	_load()

func _load() -> void:
	var def := Registry.track(Game.track_id)
	track = TrackRuntime.new()
	world.add_child(track)
	track.setup(def, Game.quality(), DisplayServer.get_name() != "headless")
	items = ItemSystem.new()
	world.add_child(items)
	items.setup(self, Game.seed_value, Game.items_enabled and mode in [Game.Mode.GRAND_PRIX, Game.Mode.QUICK_RACE])
	_spawn()
	_build_screens()
	if mode == Game.Mode.SKILL_SLALOM:
		_build_slalom()
	if mode == Game.Mode.TIME_TRIAL:
		_load_ghost()
	if Game.headless_autoplay or DisplayServer.get_name() == "headless":
		Engine.max_fps = 0
	var music := def.music_path
	Audio.play_music(music)
	phase = Phase.COUNTDOWN
	_count_t = 3.6
	phase_changed.emit(phase)

func _spawn() -> void:
	var ps: Array = Game.participants
	if mode in [Game.Mode.TIME_TRIAL, Game.Mode.TRICK_ATTACK, Game.Mode.SKILL_SLALOM, Game.Mode.SKILL_LANDING, Game.Mode.SKILL_COINS]:
		ps = [Game.participants[0]]
	for i in ps.size():
		var p: Dictionary = ps[i]
		var r := RiderController.new()
		var human := p.type == "human" and not Game.headless_autoplay
		var prov: Object
		if human:
			prov = HumanProvider.new(String(p.device))
		else:
			var ai := AIDriver.new(Game.difficulty if p.type == "ai" else 2, Game.seed_value + i * 977, self)
			ais.append(ai)
			prov = ai
		world.add_child(r)
		r.setup(i, Registry.rider(StringName(p.rider)), Registry.board(StringName(p.board)), track, prov, human, String(p.get("device", "")))
		r.is_human = p.type == "human"
		var sp: Vector3 = track.spawn_points[i % track.spawn_points.size()]
		r.place_at(sp, track.fwd[track.idx_at(20.0)])
		r.state = RiderController.State.FROZEN
		r.frozen_t = 999.0
		if not r.is_human and Save.settings().assist:
			pass
		r.trick_landed.connect(_on_trick)
		r.crashed.connect(func(_r): pass)
		riders.append(r)

func _build_screens() -> void:
	var humans: Array[RiderController] = []
	for r in riders:
		if r.is_human:
			humans.append(r)
	if humans.is_empty():
		humans.append(riders[0])  # spectator view (automated tests / attract)
	var n := humans.size()
	for i in n:
		var c := SubViewportContainer.new()
		c.stretch = true
		var vp := SubViewport.new()
		vp.msaa_3d = Viewport.MSAA_2X if Game.quality() >= 1 else Viewport.MSAA_DISABLED
		vp.scaling_3d_scale = [0.75, 0.9, 1.0][clampi(Game.quality(), 0, 2)] if n == 1 else [0.7, 0.8, 0.9][clampi(Game.quality(), 0, 2)]
		vp.audio_listener_enable_3d = i == 0
		c.add_child(vp)
		screens.add_child(c)
		_layout(c, i, n)
		var cam := ChaseCamera.new()
		cam.target = humans[i]
		cam.shake_enabled = bool(Save.settings().shake)
		cam.motion_enabled = bool(Save.settings().motion)
		cam.far = 1400.0
		vp.add_child(cam)
		cam.current = true
		cam.snap()
		cameras.append(cam)
		var hud := RaceHUD.new()
		hud.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.add_child(hud)
		hud.setup(self, humans[i], n)
		huds.append(hud)
	get_viewport().size_changed.connect(_relayout)

func _layout(c: Control, i: int, n: int) -> void:
	var sz := get_viewport().get_visible_rect().size
	var rect := Rect2(Vector2.ZERO, sz)
	if n == 2:
		rect = Rect2(0, i * sz.y / 2.0, sz.x, sz.y / 2.0)
	elif n >= 3:
		rect = Rect2((i % 2) * sz.x / 2.0, (i / 2) * sz.y / 2.0, sz.x / 2.0, sz.y / 2.0)
	c.position = rect.position
	c.size = rect.size

func _relayout() -> void:
	var cs := screens.get_children()
	for i in cs.size():
		_layout(cs[i], i, cs.size())

# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	match phase:
		Phase.COUNTDOWN:
			_count_t -= delta
			var v := int(ceil(_count_t - 0.6))
			if v != _last_count and v >= 0:
				_last_count = v
				countdown.emit(v)
				Audio.play("count_go" if v == 0 else "count")
			if _count_t <= 0.6:
				phase = Phase.RACE
				phase_changed.emit(phase)
				for r in riders:
					r.state = RiderController.State.GROUND
					r.frozen_t = 0.0
		Phase.RACE:
			race_time += delta
			_race_tick(delta)
		Phase.DONE:
			pass

func _race_tick(delta: float) -> void:
	for r in riders:
		_track_rider(r, delta)
	_repel()
	_lift_tick(delta)
	_rank_t += delta
	if _rank_t >= 0.1:
		_rank_t = 0.0
		_rank()
	if mode == Game.Mode.TIME_TRIAL:
		_ghost_tick(delta)
	if mode == Game.Mode.TRICK_ATTACK or mode == Game.Mode.SKILL_LANDING:
		trick_time_left -= delta
		if trick_time_left <= 0.0:
			trick_time_left = 0.0
			for r in riders:
				if not r.finished:
					_finish(r)
	if mode == Game.Mode.SKILL_SLALOM:
		_slalom_tick()
	# end conditions
	var all_done := true
	var humans_done := true
	for r in riders:
		if not r.finished:
			all_done = false
			if r.is_human:
				humans_done = false
	if _first_finish_t >= 0.0 and race_time - _first_finish_t > TIME_LIMIT_AFTER_FIRST and humans_done:
		all_done = true
	if race_time > max_race_time:
		all_done = true
	if all_done:
		_end_race()

func _track_rider(r: RiderController, delta: float) -> void:
	if r.finished or r.state == RiderController.State.LIFT:
		return
	var pr := track.project(r.global_position, r.proj_idx)
	r.proj_idx = int(pr.idx)
	r.lat = float(pr.lat)
	var s := float(pr.s)
	# checkpoints must be passed in order; progress is capped beyond the next gate (anti-exploit)
	var cps := track.checkpoints
	while r.next_cp < cps.size() and s >= cps[r.next_cp] - 1.0 and absf(r.lat) < track.half_width(s) + 8.0:
		r.last_safe_s = cps[r.next_cp]
		r.next_cp += 1
	var cap := track.length if r.next_cp >= cps.size() else cps[r.next_cp] + 20.0
	r.s = minf(s, cap)
	r.progress = r.lap * track.length + r.s
	# off-track / fell below the course
	var hw := track.half_width(s)
	var out := absf(r.lat) > hw + track.data.berm_w + 4.0 or float(pr.height) < -9.0 or float(pr.dist) > hw + 30.0
	if not r.global_position.is_finite() or not r.velocity.is_finite():
		out = true
		r.offtrack_t = 99.0
	if out and r.state != RiderController.State.FROZEN:
		r.offtrack_t += delta
		if r.offtrack_t > r.tuning.offtrack_reset_time:
			_reset_rider(r)
	else:
		r.offtrack_t = 0.0
	# fissures: touching the floor inside a pit sends you back to the last safe point
	if r.state == RiderController.State.GROUND:
		var z := track.zone_at(r.s, r.lat)
		if not z.is_empty() and String(z.kind) == "pit":
			_reset_rider(r)
			return
	items.try_station(r)
	# end of a descent
	var final_run := r.lap >= laps - 1
	if final_run and r.s >= track.finish_s:
		_finish(r)
	elif not final_run and r.s >= track.lift_s and r.next_cp >= cps.size() - 1:
		_enter_lift(r)

func _reset_rider(r: RiderController) -> void:
	var s := r.last_safe_s
	var p := track.point_at(s, 0.0, 0.5)
	r.reset_to(p, track.fwd[track.idx_at(s)], r.tuning.reset_penalty)
	r.proj_idx = track.idx_at(s)
	r.offtrack_t = 0.0
	test_log.append("reset rider %d at %.0f" % [r.index, s])

func _repel() -> void:
	for i in riders.size():
		for j in range(i + 1, riders.size()):
			var a := riders[i]; var b := riders[j]
			if a.state == RiderController.State.LIFT or b.state == RiderController.State.LIFT or a.finished or b.finished:
				continue
			var d := b.global_position - a.global_position
			d.y = 0.0
			var l := d.length()
			if l < RIDER_REPEL_DIST and l > 0.001:
				var push := d / l * (RIDER_REPEL_DIST - l) * 6.0
				a.push(-push); b.push(push)

# ---------------------------------------------------------------- lift
func _queue_spot(i: int) -> Vector3:
	return track.point_at(track.length - 6.0 - i * 1.6, 0.0, 0.0)

func _enter_lift(r: RiderController) -> void:
	r.enter_lift()
	lift.enqueue(r.index)
	r.global_position = _queue_spot(lift.position_in_queue(r.index))

func _cabin() -> Node3D:
	if _cabin_pool.size() > 0:
		var c: Node3D = _cabin_pool.pop_back()
		c.visible = true
		return c
	var n := Registry.prop_mesh(TrackRuntime.PROPS_GLB, "lift_cabin_%d" % (_riding_cabins.size() % 4))
	if n == null:
		n = Node3D.new()
	world.add_child(n)
	return n

func _lift_tick(delta: float) -> void:
	var arrived := lift.tick(delta)
	# queued riders shuffle forward; riding riders follow their cabin along the cable
	for r in riders:
		if r.state != RiderController.State.LIFT:
			continue
		var q := lift.position_in_queue(r.index)
		if q >= 0:
			r.global_position = r.global_position.lerp(_queue_spot(q), clampf(delta * 4.0, 0, 1))
		var t := lift.ride_progress(r.index)
		if t >= 0.0:
			if not _riding_cabins.has(r.index):
				_riding_cabins[r.index] = _cabin()
			var cab: Node3D = _riding_cabins[r.index]
			var e := t * t * (3.0 - 2.0 * t)
			var p := track.cable_point(e, true)
			cab.global_position = p
			r.global_position = p + Vector3(0, -3.1, 0)
			r.yaw = atan2(-(track.lift_top - track.lift_bottom).x, -(track.lift_top - track.lift_bottom).z)
	for id in arrived:
		var r := riders[id]
		if _riding_cabins.has(id):
			var cab: Node3D = _riding_cabins[id]
			cab.visible = false
			_cabin_pool.append(cab)
			_riding_cabins.erase(id)
		r.lap += 1
		r.next_cp = 0
		r.last_safe_s = 0.0
		r.proj_idx = track.idx_at(10.0)
		var lane := (r.index % 2) * 2 - 1
		var p := track.point_at(10.0 + (r.index / 2) * 3.0, lane * 3.0, 0.4)
		r.exit_lift(p, track.fwd[track.idx_at(10.0)])
		lap_changed.emit(r)
		if r.is_human:
			Audio.play("lap")

# ---------------------------------------------------------------- ranking / finish
func _rank() -> void:
	var order := riders.duplicate()
	for r in order:
		var key: float = r.progress
		if r.state == RiderController.State.LIFT:
			var q := lift.position_in_queue(r.index)
			var ride := lift.ride_progress(r.index)
			key = r.lap * track.length + track.length + (ride * 10.0 if ride >= 0.0 else -q * 0.5)
		if r.finished:
			key = 1.0e7 - r.place * 10.0
		r.set_meta("rank_key", key)
	order.sort_custom(func(a, b):
		var ka: float = a.get_meta("rank_key"); var kb: float = b.get_meta("rank_key")
		if absf(ka - kb) < 0.5:
			return a.place < b.place   # hysteresis: keep previous order on near-ties
		return ka > kb)
	var changed := false
	for i in order.size():
		var r: RiderController = order[i]
		if r.finished:
			continue
		if r.place != i + 1:
			changed = true
		r.place = i + 1
	if changed:
		ranking_changed.emit()

func _finish(r: RiderController) -> void:
	if r.finished:
		return
	_finish_order += 1
	r.place = _finish_order
	r.finish_race(race_time)
	if _first_finish_t < 0.0:
		_first_finish_t = race_time
	rider_finished.emit(r)
	if r.is_human:
		Audio.play("finish")
	if mode == Game.Mode.TIME_TRIAL:
		_save_ghost(r)

func _end_race() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	# unfinished riders are ordered by progress (frozen order for finishers)
	var rest: Array = []
	for r in riders:
		if not r.finished:
			rest.append(r)
	rest.sort_custom(func(a, b): return a.progress > b.progress)
	for r in rest:
		_finish_order += 1
		r.place = _finish_order
		r.finished = true
		r.finish_time = -1.0
	phase_changed.emit(phase)
	Game.last_results = build_results()
	if not Game.headless_autoplay:
		get_tree().create_timer(3.5).timeout.connect(Game.goto_results)

func build_results() -> Array:
	var out: Array = []
	for r in riders:
		out.append({"index": r.index, "rider": String(r.def.id), "board": String(r.board.id), "human": r.is_human, "place": r.place,
			"time": r.finish_time, "tricks": r.trick_points_total, "coins": r.race_coins, "laps_done": r.lap,
			"gates": gates_passed, "missed": gates_missed, "landings": landings_clean})
	out.sort_custom(func(a, b): return a.place < b.place)
	return out

func _on_trick(r: RiderController, _label: String, _pts: int, _coins: int, quality: String) -> void:
	if quality != "sloppy":
		landings_clean += 1 if r.is_human or riders.size() == 1 else 0

# ---------------------------------------------------------------- time trial ghost
func _ghost_tick(delta: float) -> void:
	_ghost_t += delta
	var r := riders[0]
	if int(_ghost_t * 10.0) > ghost_frames.size() - 1 and not r.finished:
		ghost_frames.append([snappedf(r.global_position.x, 0.01), snappedf(r.global_position.y, 0.01), snappedf(r.global_position.z, 0.01), snappedf(r.yaw, 0.001)])
	if ghost_node and _ghost_play.size() > 1:
		var f := _ghost_t * 10.0
		var i := clampi(int(f), 0, _ghost_play.size() - 2)
		var a: Array = _ghost_play[i]; var b: Array = _ghost_play[i + 1]
		var t := clampf(f - i, 0, 1)
		ghost_node.global_position = Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), t)
		ghost_node.rotation.y = lerp_angle(float(a[3]), float(b[3]), t) + PI

func _load_ghost() -> void:
	var g: Dictionary = Save.data.ghosts.get(String(Game.track_id), {})
	if g.is_empty() or DisplayServer.get_name() == "headless":
		return
	_ghost_play = g.frames
	ghost_node = (load(Registry.rider(StringName(g.rider)).model_path) as PackedScene).instantiate()
	world.add_child(ghost_node)
	for mi in ghost_node.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.6, 0.9, 1.0, 0.35)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ap := ghost_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("glide"):
		ap.get_animation("glide").loop_mode = Animation.LOOP_LINEAR
		ap.play("glide")

func _save_ghost(r: RiderController) -> void:
	var tid := String(Game.track_id)
	var improved := Save.submit_record(tid, String(r.board.id), r.finish_time)
	var g: Dictionary = Save.data.ghosts.get(tid, {})
	if g.is_empty() or r.finish_time < float(g.get("time", 1e9)):
		Save.data.ghosts[tid] = {"time": r.finish_time, "rider": String(r.def.id), "board": String(r.board.id), "frames": ghost_frames}
	if improved or g.is_empty():
		Save.write()

# ---------------------------------------------------------------- skill: slalom
func _build_slalom() -> void:
	var s := 60.0
	var side := 1.0
	while s < track.finish_s - 20.0:
		var lat := side * track.half_width(s) * 0.4
		slalom_gates.append({"s": s, "lat": lat, "done": false})
		if DisplayServer.get_name() != "headless":
			for dl in [-2.5, 2.5]:
				var f := Registry.prop_mesh(TrackRuntime.PROPS_GLB, "flag_1" if side > 0 else "flag_0")
				world.add_child(f)
				f.global_position = track.point_at(s, lat + dl, 0.0)
		s += 42.0
		side = -side

func _slalom_tick() -> void:
	var r := riders[0]
	for g in slalom_gates:
		if g.done or r.s < float(g.s):
			continue
		g.done = true
		if absf(r.lat - float(g.lat)) < 2.6:
			gates_passed += 1
			Audio.play("gate")
		else:
			gates_missed += 1
			Audio.play("buy_fail")
			r.finish_time += 0.0

func slalom_time() -> float:
	var r := riders[0]
	return (r.finish_time if r.finish_time > 0 else race_time) + gates_missed * 2.0

# ---------------------------------------------------------------- pause
func request_pause() -> void:
	if phase == Phase.DONE or paused or Game.human_count() == 0:
		return
	paused = true
	get_tree().paused = true
	pause_menu = PauseMenu.new()
	get_parent().get_node("UI").add_child(pause_menu)
	pause_menu.closed.connect(func(): paused = false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		request_pause()
		get_viewport().set_input_as_handled()
