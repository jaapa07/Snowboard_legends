class_name RiderController
extends CharacterBody3D
## Arcade snowboard rider. Same physics for humans and AI; intent comes from an InputCommand provider.

signal trick_landed(rider: RiderController, label: String, points: int, coins: int, quality: String)
signal crashed(rider: RiderController)
signal jumped(rider: RiderController)
signal coins_changed(rider: RiderController, coins: int)
signal items_changed(rider: RiderController)
signal got_hit(rider: RiderController, kind: String, blocked: bool)
signal message(rider: RiderController, key: String)
signal respawned(rider: RiderController, reason: String)

enum State { GROUND, AIR, GRIND, FALLEN, LIFT, FINISHED, FROZEN }

const MAX_RACE_COINS := 200
const COINS_PER_100 := 5
const MAX_TRICK_COINS := 30
const DAMAGE_COOLDOWN := 2.0
const BASE_POINTS := {"ollie": 50, "grab": 100, "180": 100, "360": 200, "540": 350, "720": 500, "frontflip": 300, "backflip": 300, "grind": 150}

var index: int = 0
var def: RiderDefinition
var board: BoardDefinition
var tuning: RiderTuning = RiderTuning.new()
var provider: Object                 ## has command(rider, delta) -> InputCommand
var device: String = ""
var is_human: bool = false
var track: TrackRuntime
var visual: RiderVisual

var state: int = State.GROUND
var yaw: float = 0.0
var yaw_rate: float = 0.0
var ground_n: Vector3 = Vector3.UP
var speed: float = 0.0
var air_time: float = 0.0
var off_ground_t: float = 0.0
var jump_charge: float = 0.0
var _flip_lock: bool = false    ## tuck/brake held through take-off: no flip until released and pressed again
var _jump_was_held: bool = false
var _buffer_t: float = 0.0
var _vf: float = 0.0
var _vl: float = 0.0
var spin_angle: float = 0.0
var flip_angle: float = 0.0
var grab_time: float = 0.0
var grind_rail: int = -1
var grind_t: float = 0.0
var grind_dir: int = 1
var grind_len: float = 0.0
var did_grind: bool = false
var fallen_t: float = 0.0
var frozen_t: float = 0.0
var resume_speed: float = 0.0   ## speed given back when a reset freeze ends (pit respawns roll on)
var last_trick_key: String = ""
# signature trick (scripts/tricks/signature_tricks.gd)
var sig_active: bool = false
var sig_done: bool = false
var sig_t: float = 0.0
var _sig_step: int = 0
var _sig_seq_t: float = 0.0
var _sig_prev := [false, false, false]
var repeat_count: int = 0

# race state (owned by RaceManager)
var lap: int = 0
var s: float = 0.0
var lat: float = 0.0
var proj_idx: int = 0
var next_cp: int = 0
var last_safe_s: float = 0.0
var offtrack_t: float = 0.0
var finished: bool = false
var finish_time: float = 0.0
var place: int = 1
var progress: float = 0.0
var race_coins: int = 0
var trick_points_total: int = 0
var best_combo: int = 0

# items & effects
var offense_item: StringName = &""
var utility_item: StringName = &""
var shield_t: float = 0.0
var boost_t: float = 0.0
var slow_t: float = 0.0
var spinout_t: float = 0.0
var magnet_t: float = 0.0
var fog_t: float = 0.0
var damage_cd: float = 0.0
var invuln_t: float = 0.0
var wind: Vector3 = Vector3.ZERO
var surface: String = "snow"
var _cmd: InputCommand = InputCommand.new()
var last_cmd: InputCommand = InputCommand.new()

# stat multipliers
var m_speed := 1.0
var m_control := 1.0
var m_jump := 1.0
var m_accel := 1.0
var m_resist := 1.0
var m_spin := 1.0
var assist_mult := 1.0               ## AI catch-up multiplier on the speed cap (set by RaceManager, 1.0..1.05)
const ASSIST_MAX := 0.05

func setup(i: int, rider_def: RiderDefinition, board_def: BoardDefinition, trk: TrackRuntime, prov: Object, human: bool, dev: String, board_level: int = 0) -> void:
	index = i; def = rider_def; board = board_def; track = trk; provider = prov; is_human = human; device = dev
	name = "Rider%d_%s" % [i, def.id]
	var bm := board.mods(board_level)   # garage upgrades included, capped at ±12 %
	m_speed = def.stat_mod(def.speed) * (1.0 + float(bm.speed))
	m_control = def.stat_mod(def.control) * (1.0 + float(bm.control))
	m_jump = def.stat_mod(def.jump) * (1.0 + float(bm.jump))
	m_accel = def.stat_mod(def.accel) * (1.0 + float(bm.accel))
	m_resist = def.stat_mod(def.resist)
	m_spin = 1.0 + float(bm.spin) + (def.jump - 3) * 0.03
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(58.0)
	floor_snap_length = 0.7
	floor_stop_on_slope = false
	floor_block_on_wall = false
	wall_min_slide_angle = deg_to_rad(5)
	safe_margin = 0.02
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38; cap.height = 1.4
	cs.shape = cap
	cs.position = Vector3(0, 0.72, 0)
	add_child(cs)
	visual = RiderVisual.new()
	add_child(visual)
	visual.setup(self)

func place_at(p: Vector3, heading_fwd: Vector3) -> void:
	global_position = p
	yaw = atan2(-heading_fwd.x, -heading_fwd.z)
	velocity = Vector3.ZERO
	_vf = 0.0; _vl = 0.0
	yaw_rate = 0.0
	spin_angle = 0.0; flip_angle = 0.0
	reset_physics_interpolation()

func forward_dir() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func is_controllable() -> bool:
	return state == State.GROUND or state == State.AIR or state == State.GRIND

func vmax() -> float:
	var v := tuning.max_speed * m_speed
	if last_cmd.tuck and state == State.GROUND:
		v = tuning.tuck_speed * m_speed
	if boost_t > 0.0:
		v = tuning.boost_speed
	if slow_t > 0.0:
		v *= 0.55
	# optional AI catch-up assist (spec §10): at most +5 %, never above the physical ceiling (boost speed)
	return minf(v * assist_mult, maxf(v, tuning.boost_speed)) if assist_mult > 1.0 else v

# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	_tick_effects(delta)
	if state == State.LIFT:
		visual.tick(delta)
		return
	var cmd := _cmd
	if provider and (state == State.GROUND or state == State.AIR or state == State.GRIND):
		cmd = provider.command(self, delta)
	else:
		cmd.clear()
	last_cmd.copy_from(cmd)
	match state:
		State.GROUND:
			_step_ground(cmd, delta)
		State.AIR:
			_step_air(cmd, delta)
		State.GRIND:
			_step_grind(cmd, delta)
		State.FALLEN:
			_step_fallen(delta)
		State.FROZEN:
			frozen_t -= delta
			velocity = Vector3.ZERO
			if frozen_t <= 0.0:
				state = State.GROUND
				_vf = resume_speed; _vl = 0.0
				resume_speed = 0.0
		State.FINISHED:
			_step_finished(delta)
	if is_controllable():
		_use_items(cmd)
	speed = Vector3(velocity.x, 0, velocity.z).length()
	visual.tick(delta)

func _tick_effects(delta: float) -> void:
	shield_t = maxf(0.0, shield_t - delta)
	boost_t = maxf(0.0, boost_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	spinout_t = maxf(0.0, spinout_t - delta)
	magnet_t = maxf(0.0, magnet_t - delta)
	fog_t = maxf(0.0, fog_t - delta)
	damage_cd = maxf(0.0, damage_cd - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	_buffer_t = maxf(0.0, _buffer_t - delta)

func _surface_info() -> Dictionary:
	surface = "snow"
	var grip := tuning.lateral_grip * m_control
	var extra_drag := 0.0
	wind = Vector3.ZERO
	var sheltered := false
	if track:
		for z in track.zones_at(s, lat):
			match String(z.kind):
				"ice":
					surface = "ice"; grip = tuning.ice_grip * m_control
				"slush":
					surface = "slush"; extra_drag += 6.0
				"steam":
					extra_drag += 1.5
				"boost":
					if boost_t < 0.3:
						boost_t = 0.6
				"shelter":
					sheltered = true
		if not sheltered:
			for z in track.zones_at(s, lat):
				if String(z.kind) == "wind":
					wind = track.right[track.idx_at(s)] * float(z.force)
	if spinout_t > 0.0:
		grip = tuning.spinout_grip
	return {"grip": grip, "drag": extra_drag}

func _step_ground(cmd: InputCommand, delta: float) -> void:
	var n := get_floor_normal() if is_on_floor() else ground_n
	ground_n = ground_n.lerp(n, clampf(delta * 12.0, 0.0, 1.0)).normalized()
	var d := forward_dir()
	var f := (d - ground_n * d.dot(ground_n)).normalized()
	var r := f.cross(ground_n).normalized()
	var si := _surface_info()
	# speed is integrated internally; the slide result only removes what walls actually blocked
	var vf := _vf
	var vl := _vl
	# gravity along the tangent plane
	var g := Vector3(0, -tuning.gravity, 0)
	vf += g.dot(f) * delta * tuning.slope_accel_factor * m_accel
	if vf < tuning.push_until and not cmd.brake:
		vf += tuning.push_accel * m_accel * delta
	if device == "touch" and not cmd.brake and not cmd.jump_held and absf(cmd.steer) < 0.25:
		cmd.tuck = true   # phones: tuck by itself on straights (holding the stick up all race is tiring)
	var dk := tuning.drag_k * (tuning.tuck_drag_mult if cmd.tuck else 1.0)
	vf -= (dk * vf * absf(vf) + tuning.rolling * signf(vf) + float(si.drag) * 0.1 * vf) * delta
	if cmd.brake:
		vf = move_toward(vf, 0.0, tuning.brake_decel * delta)
	if boost_t > 0.0:
		vf += 18.0 * delta
	var cap := vmax()
	if vf > cap:
		vf = move_toward(vf, cap, tuning.overspeed_decel * delta)
	# steering: rate falls with speed; braking (lean back) sharpens, tuck and jump-charge dull it
	var k := clampf(absf(vf) / 30.0, 0.0, 1.0)
	var turn := lerpf(tuning.turn_rate_low, tuning.turn_rate_high, k) * m_control
	if cmd.brake:
		turn *= tuning.brake_turn_mult
	if cmd.tuck:
		turn *= tuning.tuck_turn_mult
	if cmd.jump_held:
		turn *= 0.6 if device == "touch" else 0.35
	if spinout_t > 0.0:
		yaw_rate = 7.0
	else:
		yaw_rate = move_toward(yaw_rate, -cmd.steer * turn, tuning.turn_response * delta)
	yaw += yaw_rate * delta
	vf -= absf(yaw_rate) * absf(vf) * tuning.carve_speed_cost * delta
	vl = move_toward(vl, 0.0, float(si.grip) * delta)
	velocity = f * vf + r * vl - ground_n * tuning.ground_stick + wind * delta * 10.0
	floor_snap_length = 0.7
	move_and_slide()
	for ci in get_slide_collision_count():
		var cn := get_slide_collision(ci).get_normal()
		if cn.y < 0.55:  # wall / obstacle: lose the blocked part of the motion
			var into := minf(0.0, (f * vf + r * vl).dot(cn))
			var blocked := cn * into
			vf -= blocked.dot(f)
			vl -= blocked.dot(r)
			if into < -6.0:
				slow_t = maxf(slow_t, 0.25)
	_vf = vf
	_vl = vl
	_rider_coins()
	# jump input: charge while held, fire on release
	if cmd.jump_held:
		jump_charge = minf(jump_charge + delta, tuning.jump_charge_max)
	elif _jump_was_held:
		_do_jump(jump_charge, cmd.tuck)
		jump_charge = 0.0
	elif _buffer_t > 0.0:
		_buffer_t = 0.0
		_do_jump(0.0, false)
	_jump_was_held = cmd.jump_held
	if is_on_floor():
		off_ground_t = 0.0
	else:
		off_ground_t += delta
		if off_ground_t > tuning.coyote_time:
			_enter_air(false)

func _seed_speed() -> void:
	var d := forward_dir()
	var f := (d - ground_n * d.dot(ground_n)).normalized()
	var r := f.cross(ground_n).normalized()
	_vf = velocity.dot(f)
	_vl = velocity.dot(r)

func _do_jump(charge: float, accel_hop: bool) -> void:
	if state != State.GROUND and off_ground_t > tuning.coyote_time:
		return
	var t := clampf(charge / tuning.jump_charge_max, 0.0, 1.0)
	var imp := lerpf(tuning.jump_min, tuning.jump_max, t) * m_jump
	if accel_hop and t < 0.15:
		# quick tap while tucked: low "accelerating" hop with a forward push
		imp = tuning.jump_min * 0.8
		velocity += forward_dir() * 2.5
	velocity += ground_n * imp
	_enter_air(true)
	jumped.emit(self)

func _enter_air(from_jump: bool) -> void:
	state = State.AIR
	air_time = 0.0
	spin_angle = 0.0; flip_angle = 0.0; grab_time = 0.0
	did_grind = false
	sig_active = false; sig_done = false; sig_t = 0.0; _sig_step = 0
	_flip_lock = last_cmd != null and (last_cmd.tuck or last_cmd.brake) or device == "touch"
	floor_snap_length = 0.0
	if not from_jump:
		pass
	visual.on_takeoff()

func _step_air(cmd: InputCommand, delta: float) -> void:
	air_time += delta
	velocity.y -= tuning.gravity * delta
	velocity += wind * delta
	yaw += -cmd.steer * tuning.air_steer * delta
	# rotate horizontal velocity slightly toward the new heading (air control)
	var hv := Vector3(velocity.x, 0, velocity.z)
	var hs := hv.length()
	if hs > 0.5:
		var nd := hv.normalized().slerp(forward_dir(), clampf(delta * 1.2, 0, 1)).normalized()
		velocity.x = nd.x * hs; velocity.z = nd.z * hs
	_signature_input(cmd, delta)
	var sr := deg_to_rad(tuning.spin_rate_deg) * m_spin
	if sig_active:
		_signature_step(delta)
	elif cmd.spin_left:
		spin_angle += sr * delta
	elif cmd.spin_right:
		spin_angle -= sr * delta
	var fr := deg_to_rad(tuning.flip_rate_deg) * m_spin
	if _flip_lock and not cmd.flip_front and not cmd.flip_back:
		_flip_lock = false
	if sig_active or sig_done or _flip_lock:
		pass
	elif cmd.flip_front:
		flip_angle += fr * delta
	elif cmd.flip_back:
		flip_angle -= fr * delta
	if cmd.grab and not sig_active and not sig_done:
		grab_time += delta
	_landing_assist(cmd, delta)
	# release buffer: a jump pressed just before touching down fires on landing
	if cmd.jump_held and not _jump_was_held:
		_buffer_t = tuning.jump_buffer
	_jump_was_held = cmd.jump_held
	move_and_slide()
	_rider_coins()
	if velocity.y <= 0.5 and _try_grind():
		return
	if is_on_floor() and air_time > 0.06:
		_land()

func _landing_assist(cmd: InputCommand, delta: float) -> void:
	## Humans: while falling with no rotation input, the board eases to the nearest clean angle (half spins,
	## whole flips), so a trick released a little early still lands. Stronger on touch screens.
	if not is_human or sig_active or velocity.y > 0.0:
		return
	var rate := deg_to_rad(300.0 if device == "touch" else 150.0) * delta
	if not cmd.spin_left and not cmd.spin_right:
		spin_angle = move_toward(spin_angle, snappedf(spin_angle, PI), rate)
	if (not cmd.flip_front and not cmd.flip_back) or _flip_lock:
		flip_angle = move_toward(flip_angle, snappedf(flip_angle, TAU), rate)

func _land() -> void:
	var spin_deg := rad_to_deg(absf(spin_angle))
	var flip_deg := rad_to_deg(absf(flip_angle))
	var r1 := fposmod(spin_deg, 180.0); var dev1 := minf(r1, 180.0 - r1)
	var r2 := fposmod(flip_deg, 360.0); var dev2 := minf(r2, 360.0 - r2)
	var dev := maxf(dev1, dev2)
	if last_cmd.grab and grab_time > 0.0 and not sig_done:
		dev += 15.0 if device == "touch" else 35.0
	if sig_active:
		dev = 999.0   # touched down before the signature trick finished
	# landing slope check: steep impact with high vertical speed is harder
	var impact := -velocity.y
	if impact > 16.0:
		dev += (impact - 16.0) * 3.0
	ground_n = get_floor_normal()
	state = State.GROUND
	_seed_speed()
	off_ground_t = 0.0
	floor_snap_length = 0.7
	var quality := "clean"
	if dev > tuning.land_sloppy_deg:
		_crash()
		return
	elif dev > tuning.land_clean_deg:
		quality = "sloppy"
		_scale_speed(tuning.sloppy_speed_mult)
	elif dev < tuning.land_perfect_deg and (spin_deg > 150.0 or flip_deg > 300.0 or grab_time > 0.3):
		quality = "perfect"
		_vf += 2.0
	_score_tricks(spin_deg, flip_deg, quality)
	visual.on_land(quality)
	spin_angle = 0.0; flip_angle = 0.0
	if _buffer_t > 0.0:
		_buffer_t = 0.0
		_do_jump(0.0, false)

func start_signature() -> bool:
	## Starts this rider's signature trick (also used by the AI). Only once per jump, only in the air.
	if state != State.AIR or sig_active or sig_done:
		return false
	sig_active = true
	sig_t = 0.0
	spin_angle = 0.0; flip_angle = 0.0; grab_time = 0.0
	return true

func _signature_input(cmd: InputCommand, delta: float) -> void:
	var now := [cmd.spin_left, cmd.spin_right, cmd.grab]
	if _sig_step > 0:
		_sig_seq_t += delta
		if _sig_seq_t > SignatureTricks.INPUT_WINDOW:
			_sig_step = 0
	# edges in order: spin-left, spin-right, grab
	if now[_sig_step] and not _sig_prev[_sig_step]:
		if _sig_step == 0:
			_sig_seq_t = 0.0
		_sig_step += 1
		if _sig_step >= 3:
			_sig_step = 0
			start_signature()
	_sig_prev = now

func _signature_step(delta: float) -> void:
	var d := SignatureTricks.of(String(def.id))
	sig_t += delta
	var p := clampf(sig_t / float(d.dur), 0.0, 1.0)
	var e := p * p * (3.0 - 2.0 * p)
	spin_angle = deg_to_rad(float(d.spin)) * e
	flip_angle = deg_to_rad(float(d.flip)) * e
	if d.grab:
		grab_time = 0.0   # the grab is part of the signature, not scored separately
	if p >= 1.0:
		sig_active = false
		sig_done = true

func _score_tricks(spin_deg: float, flip_deg: float, quality: String) -> void:
	var parts: Array[String] = []
	var pts := 0
	if sig_done:
		var d := SignatureTricks.of(String(def.id))
		parts.append(SignatureTricks.label(String(def.id), Game.lang()))
		pts = int(d.points)
		spin_deg = 0.0; flip_deg = 0.0
	var spins := int(round(spin_deg / 180.0))
	if spins >= 1:
		var key: String = ["180", "360", "540", "720"][mini(spins, 4) - 1]
		parts.append(key); pts += BASE_POINTS[key]
	var flips := int(round(flip_deg / 360.0))
	if flips >= 1:
		var fk := "frontflip" if flip_angle > 0.0 else "backflip"
		parts.append(fk if flips == 1 else "%dx %s" % [flips, fk]); pts += BASE_POINTS[fk] * flips
	if grab_time > 0.3:
		parts.append("grab"); pts += BASE_POINTS.grab
	if did_grind:
		parts.append("grind"); pts += BASE_POINTS.grind
	if parts.is_empty():
		if air_time > 0.45:
			parts.append("ollie"); pts += BASE_POINTS.ollie
		else:
			return
	var mult := 1.0 + 0.5 * (parts.size() - 1)
	if grab_time > 0.3 and spins >= 1:
		mult += 0.5  # grab+spin combo
	if quality == "perfect":
		mult += 0.25
	mult = minf(mult, 3.0)
	var key_main := parts[0]
	if key_main == last_trick_key:
		repeat_count += 1
	else:
		repeat_count = 0
		last_trick_key = key_main
	var rep := pow(0.7, repeat_count)
	var total := int(round(pts * mult * rep))
	var gained := mini(MAX_TRICK_COINS, int(total / 100) * COINS_PER_100)
	add_coins(gained)
	trick_points_total += total
	best_combo = maxi(best_combo, parts.size())
	var shown: Array[String] = []
	for part in parts:
		shown.append(_trick_label(part))
	trick_landed.emit(self, " + ".join(shown), total, gained, quality)

const TRICK_PT := {"frontflip": "mortal p/ frente", "backflip": "mortal p/ trás", "grab": "agarrada", "grind": "corrimão", "ollie": "pulo"}

func _trick_label(part: String) -> String:
	if Game.lang() == "en":
		return part
	for k in TRICK_PT:
		if part.ends_with(k):
			return part.replace(k, String(TRICK_PT[k]))
	return part

func _crash() -> void:
	state = State.FALLEN
	fallen_t = lerpf(tuning.fall_max, tuning.fall_min, clampf((def.resist - 1) / 4.0, 0, 1))
	spin_angle = 0.0; flip_angle = 0.0
	visual.on_fall()
	crashed.emit(self)

func _step_fallen(delta: float) -> void:
	fallen_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	velocity.y -= tuning.gravity * delta
	move_and_slide()
	if fallen_t <= 0.0:
		state = State.GROUND
		_seed_speed()
		invuln_t = 1.0
		visual.on_recover()

func _step_finished(delta: float) -> void:
	# past the finish there may be no terrain under a fast rider: keep finishers on the run-out
	if track and global_position.y < track.point_at(minf(s, track.length - 1.0), 0.0).y - 12.0:
		global_position = track.point_at(minf(s, track.length - 1.0), clampf(lat, -3.0, 3.0), 0.3)
		velocity = Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(Vector3.ZERO, 8.0 * delta)
	velocity = Vector3(hv.x, velocity.y - tuning.gravity * delta, hv.z)
	move_and_slide()
	if is_on_floor():
		velocity.y = 0.0

# ------------------------------------------------------------------ rails
func _try_grind() -> bool:
	if track == null:
		return false
	for ri in track.rails.size():
		var rail: Dictionary = track.rails[ri]
		var a: Vector3 = rail.a; var b: Vector3 = rail.b
		var ab := b - a
		var t := clampf((global_position - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if t <= 0.02 or t >= 0.98:
			continue
		var cp := a + ab * t
		var dh := Vector2(global_position.x - cp.x, global_position.z - cp.z).length()
		var dy := global_position.y - cp.y
		if dh < 0.8 and dy > -0.35 and dy < 0.7:
			state = State.GRIND
			grind_rail = ri; grind_t = t; grind_len = ab.length()
			grind_dir = 1 if velocity.dot(ab) >= 0.0 else -1
			speed = maxf(Vector3(velocity.x, 0, velocity.z).length(), tuning.grind_min_speed)
			did_grind = true
			visual.on_grind(true)
			return true
	return false

func _step_grind(cmd: InputCommand, delta: float) -> void:
	var rail: Dictionary = track.rails[grind_rail]
	var a: Vector3 = rail.a; var b: Vector3 = rail.b
	var dir := (b - a).normalized() * grind_dir
	grind_t += grind_dir * speed * delta / grind_len
	var cp := a.lerp(b, clampf(grind_t, 0.0, 1.0))
	velocity = dir * speed
	global_position = cp + Vector3.UP * 0.05
	yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), delta * 10.0)
	air_time += delta
	if cmd.jump_held and not _jump_was_held or grind_t <= 0.0 or grind_t >= 1.0:
		state = State.AIR
		velocity += Vector3.UP * 4.0
		visual.on_grind(false)
	_jump_was_held = cmd.jump_held

# ------------------------------------------------------------------ coins & items
func add_coins(n: int) -> void:
	if n == 0:
		return
	race_coins = clampi(race_coins + n, 0, MAX_RACE_COINS)
	coins_changed.emit(self, race_coins)

func _rider_coins() -> void:
	if track == null:
		return
	var radius := 9.0 if magnet_t > 0.0 else 1.6
	var got := track.take_coins_near(global_position + Vector3.UP * 0.8, radius)
	if got > 0:
		add_coins(got * 5)
		visual.on_coin()

func _use_items(cmd: InputCommand) -> void:
	var race := get_tree().get_first_node_in_group("race_manager")
	if race == null:
		return
	if cmd.use_offense and offense_item != &"":
		if race.items.use_item(self, offense_item):
			offense_item = &""
			items_changed.emit(self)
	if cmd.use_utility and utility_item != &"":
		if race.items.use_item(self, utility_item):
			utility_item = &""
			items_changed.emit(self)

func can_be_hit() -> bool:
	return state != State.LIFT and state != State.FINISHED and invuln_t <= 0.0 and damage_cd <= 0.0

func apply_hit(kind: String) -> bool:
	## Returns true when the hit landed (false when blocked/ignored). Global damage cooldown prevents stun-lock.
	if not can_be_hit():
		return false
	if shield_t > 0.0:
		shield_t = 0.0
		damage_cd = 0.6
		visual.on_shield_break()
		got_hit.emit(self, kind, true)
		return false
	damage_cd = DAMAGE_COOLDOWN
	var res := 1.0 - (m_resist - 1.0) * 1.5
	match kind:
		"snowball":
			slow_t = 1.0 * res
			_scale_speed(0.55)
			visual.on_hit()
		"icemine":
			spinout_t = 1.2 * res
			_scale_speed(0.7)
			visual.on_hit()
		"penguin":
			if state == State.GROUND or state == State.AIR:
				_scale_speed(0.4)
				_crash()
				fallen_t = minf(fallen_t, 1.0)
		"wave":
			slow_t = 0.6 * res
			visual.on_hit()
		"comet":
			slow_t = 1.5 * res
			_scale_speed(0.5)
			visual.on_hit()
		"whirl":
			spinout_t = 0.6 * res
			_scale_speed(0.75)
			visual.on_hit()
		"collision":
			slow_t = 0.4
	got_hit.emit(self, kind, false)
	return true

func push(impulse: Vector3) -> void:
	if state == State.GROUND or state == State.AIR:
		velocity += impulse
		var f := forward_dir()
		_vf += impulse.dot(f)
		_vl += impulse.dot(f.cross(Vector3.UP))

func _scale_speed(k: float) -> void:
	velocity *= k
	_vf *= k
	_vl *= k

# ------------------------------------------------------------------ lift / reset
func enter_lift() -> void:
	state = State.LIFT
	velocity = Vector3.ZERO
	collision_mask = 0
	invuln_t = 999.0
	shield_t = 0.0; boost_t = 0.0; slow_t = 0.0; spinout_t = 0.0
	visual.on_lift(true)

func exit_lift(p: Vector3, fwd_dir: Vector3) -> void:
	place_at(p, fwd_dir)
	collision_mask = 1
	state = State.GROUND
	invuln_t = 1.0
	velocity = fwd_dir * 6.0
	_vf = 6.0
	visual.on_lift(false)

func reset_to(p: Vector3, fwd_dir: Vector3, penalty: float, roll_speed: float = 0.0, reason: String = "reset") -> void:
	place_at(p, fwd_dir)
	state = State.FROZEN
	frozen_t = penalty
	resume_speed = roll_speed
	invuln_t = penalty + 1.0
	visual.on_recover()
	respawned.emit(self, reason)

func finish_race(t: float) -> void:
	finished = true
	finish_time = t
	state = State.FINISHED
	invuln_t = 999.0
	visual.on_finish()
