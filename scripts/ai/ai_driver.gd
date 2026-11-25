class_name AIDriver
extends RefCounted
## Computer rider. Uses the same InputCommand path and physics as humans. No teleports, no free coins.
## FSM: Race, Overtake, Avoid, Jump, Trick, Recover, LiftQueue, Finish. Reaction delay per difficulty.

enum S { RACE, OVERTAKE, AVOID, JUMP, TRICK, RECOVER, LIFT_QUEUE, FINISH }
const REACTION_MS := [450, 250, 120]
const LANE_SKILL := [0.25, 0.55, 0.85]
const TRICK_AMBITION := [0.3, 0.6, 0.9]

var difficulty: int = 1
var rng := RandomNumberGenerator.new()
var fsm: int = S.RACE
var race: Node
var _buffer: Array[InputCommand] = []
var _delay_frames: int = 15
var _lane_choice: Dictionary = {}      ## split s0 -> lateral
var _target_lat: float = 0.0
var _lat_smooth: float = 0.0
var _stuck_t: float = 0.0
var _trick_goal: float = 0.0
var _trick_dir: int = 1
var _flip_goal: float = 0.0
var _grab_goal: float = 0.0
var _item_t: float = 0.0
var _noise: float = 0.0
var _was_jump: bool = false
var stats := {"jumps": 0, "tricks": 0, "items": 0, "recoveries": 0}

func _init(diff: int, seed_: int, race_node: Node) -> void:
	difficulty = clampi(diff, 0, 2)
	rng.seed = seed_
	race = race_node
	_delay_frames = int(round(REACTION_MS[difficulty] / (1000.0 / 60.0)))

func command(r: RiderController, delta: float) -> InputCommand:
	var ideal := _think(r, delta)
	_buffer.append(ideal)
	if _buffer.size() > _delay_frames:
		var out: InputCommand = _buffer.pop_front()
		# steering + air controls react with delay; item edges keep their single frame
		return out
	return InputCommand.new()

func _think(r: RiderController, delta: float) -> InputCommand:
	var c := InputCommand.new()
	var tr: TrackRuntime = r.track
	if r.finished:
		fsm = S.FINISH
		return c
	if r.state == RiderController.State.LIFT:
		fsm = S.LIFT_QUEUE
		return c
	if r.state == RiderController.State.FALLEN:
		if r.utility_item == &"repair":
			c.use_utility = true
		return c
	if r.state == RiderController.State.AIR or r.state == RiderController.State.GRIND:
		return _air(r, c)
	# ---- ground
	fsm = S.RACE
	var s := r.s
	var hw := tr.half_width(s)
	var lat_goal := _racing_line(r, tr, s, hw)
	if race.mode == Game.Mode.SKILL_FLAKES and race.specials:
		for pk in race.specials.pickups:
			if pk.kind == "flake" and not pk.taken:
				var pr := tr.project(pk.p, r.proj_idx)
				if float(pr.s) > s + 3.0 and float(pr.s) - s < 60.0:
					lat_goal = clampf(float(pr.lat), -hw + 1.5, hw - 1.5)   # steer for the next flake
					break
	if race.mode == Game.Mode.SKILL_TARGETS or race.mode == Game.Mode.SKILL_SNOWMEN:
		var tg: Dictionary = race.next_target(s)
		if not tg.is_empty() and float(tg.s) - s < 60.0:
			lat_goal = float(tg.lat)   # line up with the next target
	# overtaking first, hazard avoidance last: avoidance must have the final word (an overtake used to pull
	# riders back across a gap edge)
	lat_goal = _overtake(r, s, lat_goal, hw)
	var before_avoid := lat_goal
	lat_goal = _avoid(r, tr, s, lat_goal, hw)
	var avoiding := absf(lat_goal - before_avoid) > 0.01
	_lat_smooth = lerpf(_lat_smooth, lat_goal, clampf(delta * (7.0 if avoiding else 3.0), 0, 1))
	var look := clampf(10.0 + r.speed * 0.9, 10.0, 35.0)
	if r.fog_t > 0.0:
		look *= 0.6
	var tgt := tr.point_at(minf(s + look, tr.length - 1.0), _lat_smooth)
	var to := tgt - r.global_position
	var desired := atan2(-to.x, -to.z)
	# steer against the heading the rider will have when this (delayed) command lands: the reaction delay
	# otherwise turns the steering loop into a limit cycle (±50° weave that bleeds all speed), worst for
	# high-control riders whose boards turn fastest
	var delay_s := float(_delay_frames) / 60.0
	var err := wrapf(desired - (r.yaw + r.yaw_rate * delay_s), -PI, PI)
	var gain := (2.4 + difficulty * 0.4) / maxf(0.8, r.m_control)
	if r.fog_t > 0.0:
		_noise = lerpf(_noise, rng.randf_range(-0.5, 0.5), 0.1)
		err += _noise * 0.3
	var steer := -err * gain
	if absf(steer) < 0.04:
		steer = 0.0   # hysteresis dead band avoids oscillation
	c.steer = clampf(steer, -1.0, 1.0)
	# speed: limit by upcoming curvature
	var kmax := 0.0
	var ss := s
	while ss < minf(s + 30.0 + r.speed * 0.5, tr.length - 1.0):
		kmax = maxf(kmax, absf(tr.curv[tr.idx_at(ss)]))
		ss += 4.0
	var krad := deg_to_rad(kmax)
	var vcap := 99.0 if krad < 0.0005 else sqrt((26.0 + difficulty * 3.0) * r.m_control / krad)
	if r.speed > vcap + 1.5 or (absf(err) > 0.8 and r.speed > 9.0):
		c.brake = true
	elif kmax < 0.25 and absf(err) < 0.25:
		c.tuck = true
	var z := tr.zone_at(s, r.lat)
	if not z.is_empty() and String(z.kind) == "ice":
		c.tuck = false
	# ramps: charge the jump and release at the lip
	for rp in tr.ramps:
		var lip: float = float(rp.s) + float(rp.l) * 0.5
		var dlat := absf(r.lat - float(rp.lat))
		# a ramp in front of a gap needs a fully charged jump (0.65 s): start charging earlier
		var pre := 6.0
		for z2 in tr.zones:
			if String(z2.kind) == "pit" and float(z2.s0) > lip and float(z2.s0) - lip < 15.0:
				pre = maxf(6.0, r.speed * r.tuning.jump_charge_max)
		# release early enough that the delayed command still reaches the rider before the lip
		var lead := 0.6 + r.speed * float(_delay_frames) / 60.0
		if dlat < float(rp.w) * 0.5 and s > float(rp.s) - float(rp.l) * 0.5 - pre - lead and s < lip - lead:
			c.jump_held = true
			fsm = S.JUMP
	# stuck recovery
	if r.speed < 2.0 and race.phase == 2:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	if _stuck_t > 2.5:
		fsm = S.RECOVER
		var back := tr.point_at(minf(s + 8.0, tr.length - 1.0), 0.0) - r.global_position
		c.steer = clampf(-wrapf(atan2(-back.x, -back.z) - r.yaw, -PI, PI) * 3.0, -1, 1)
		c.brake = false; c.tuck = false
		if _stuck_t > 3.5:
			c.jump_held = int(_stuck_t * 4.0) % 2 == 0
		if _stuck_t > 6.0:
			_stuck_t = 0.0
			stats.recoveries += 1
	_items(r, c, tr, kmax, delta)
	if c.jump_held and not _was_jump:
		_plan_trick(r)
		stats.jumps += 1
	_was_jump = c.jump_held
	return c

func _racing_line(r: RiderController, tr: TrackRuntime, s: float, hw: float) -> float:
	# inside line through the next curve, centre on straights
	var k := tr.curv[tr.idx_at(minf(s + 25.0, tr.length - 1.0))]
	var lat := clampf(k * 6.0, -hw * 0.45, hw * 0.45)
	for sp in tr.splits:
		if s > float(sp.s0) - 45.0 and s < float(sp.s1):
			var key := float(sp.s0)
			if not _lane_choice.has(key):
				var shw := tr.half_width(float(sp.s0) + 10.0)
				var lane_w := shw - float(sp.div) * 0.5
				var left := -(float(sp.div) * 0.5 + lane_w * 0.5)
				var right := -left
				var fancy := _lane_has_feature(tr, sp, right)
				var bad_r := _lane_bad(tr, sp, right)
				var bad_l := _lane_bad(tr, sp, left)
				var take_fancy: bool = rng.randf() < LANE_SKILL[difficulty]
				var choice := right if (fancy and take_fancy) else left
				if not fancy and rng.randf() < 0.5:
					choice = right
				if choice == right and bad_r and not (fancy and difficulty >= 1):
					choice = left
				if choice == left and bad_l:
					choice = right
				_lane_choice[key] = choice
			# already inside the split on the other lane (overtake, crash, reset): stay there instead of
			# steering through the divider
			if s > float(sp.s0) - 2.0 and absf(r.lat) > float(sp.div) * 0.5 and signf(r.lat) != signf(float(_lane_choice[key])):
				_lane_choice[key] = -float(_lane_choice[key])
			return _lane_choice[key]
	# item stations: steer through a station when we can afford it and the slot is free
	if r.race_coins >= ItemSystem.PRICE and race.items.enabled:
		for st in tr.stations:
			var ds: float = float(st.s) - s
			if ds > 0.0 and ds < 70.0:
				var want := (String(st.slot) == "offense" and r.offense_item == &"") or (String(st.slot) == "utility" and r.utility_item == &"")
				if want:
					return float(st.lat)
	return lat

func _lane_has_feature(tr: TrackRuntime, sp: Dictionary, lane_lat: float) -> bool:
	for rp in tr.ramps:
		if float(rp.s) >= float(sp.s0) - 5.0 and float(rp.s) <= float(sp.s1) and signf(float(rp.lat)) == signf(lane_lat):
			return true
	for pl in tr.platforms:
		if absf(float(pl.s0) - float(sp.s0)) < 20.0 and signf(float(pl.lat)) == signf(lane_lat):
			return true
	return false

func _lane_bad(tr: TrackRuntime, sp: Dictionary, lane_lat: float) -> bool:
	for z in tr.zones:
		if String(z.kind) in ["slush", "pit"] and float(z.s0) < float(sp.s1) and float(z.s1) > float(sp.s0):
			var zc := (float(z.lat0) + float(z.lat1)) * 0.5
			if signf(zc) == signf(lane_lat):
				return true
	return false

func _avoid(r: RiderController, tr: TrackRuntime, s: float, lat: float, hw: float) -> float:
	for hz in tr.hazards:
		var d := float(hz.s) - s
		if d > 0.0 and d < 45.0 and absf(lat - float(hz.lat)) < 3.2:
			fsm = S.AVOID
			var side := 1.0 if float(hz.lat) <= 0.0 else -1.0
			return clampf(float(hz.lat) + side * 4.0, -hw + 1.5, hw - 1.5)
	for z in tr.zones:
		var k := String(z.kind)
		if (k == "slush" or k == "pit") and float(z.s0) - s < 40.0 and float(z.s1) > s:
			if lat >= float(z.lat0) - 1.0 and lat <= float(z.lat1) + 1.0:
				var has_ramp := false
				for rp in tr.ramps:
					if float(rp.s) < float(z.s0) and float(z.s0) - float(rp.s) < 20.0 and absf(float(rp.lat) - lat) < float(rp.w):
						# only commit to the jump when well centred on the ramp (wide-turning riders go round)
						has_ramp = k != "pit" or absf(float(rp.lat) - r.lat) < float(rp.w) * 0.5 - 1.0
				# only take the jump over a fissure with enough speed to clear it (e.g. right after a reset)
				if k == "pit" and (r.speed < 19.0 or difficulty == 0):
					has_ramp = false   # rookies, and anyone too slow, take the safe lane around the gap
				if not has_ramp or k == "slush" and difficulty == 0:
					fsm = S.AVOID
					# go round on the nearer side that has room
					var left := float(z.lat0) - 2.2
					var right := float(z.lat1) + 2.2
					var left_ok := left > -hw + 1.0
					var right_ok := right < hw - 1.0
					var go_left := left_ok and (not right_ok or absf(lat - left) <= absf(lat - right))
					return clampf(left if go_left else right, -hw + 1.0, hw - 1.0)
	for m in race.items.mines:
		var p: Vector3 = m.node.global_position if m.node else m.p
		var pr := tr.project(p, r.proj_idx)
		if float(pr.s) - s > 0.0 and float(pr.s) - s < 30.0 and absf(float(pr.lat) - lat) < 2.0:
			fsm = S.AVOID
			return clampf(float(pr.lat) + (3.0 if float(pr.lat) < 0 else -3.0), -hw + 1.0, hw - 1.0)
	return lat

func _overtake(r: RiderController, s: float, lat: float, hw: float) -> float:
	for o in race.riders:
		if o == r or o.finished or o.lap != r.lap:
			continue
		var d: float = o.s - s
		if d > 0.0 and d < 12.0 and absf(o.lat - lat) < 1.6:
			fsm = S.OVERTAKE
			var side := 2.2 if o.lat <= 0.0 else -2.2
			return clampf(o.lat + side, -hw + 1.2, hw - 1.2)
	return lat

func _plan_trick(r: RiderController) -> void:
	var amb: float = TRICK_AMBITION[difficulty]
	_trick_dir = 1 if rng.randf() < 0.5 else -1
	var roll := rng.randf()
	_trick_goal = 0.0; _flip_goal = 0.0; _grab_goal = 0.0
	if roll < amb:
		_trick_goal = [PI, TAU, TAU + PI][rng.randi_range(0, mini(2, difficulty + 1))]
	if roll < amb * 0.35 and difficulty >= 1:
		_flip_goal = TAU
	if rng.randf() < amb * 0.6:
		_grab_goal = 0.45

func _air(r: RiderController, c: InputCommand) -> InputCommand:
	if fsm != S.TRICK and (_trick_goal > 0.0 or _flip_goal > 0.0):
		stats.tricks += 1
	fsm = S.TRICK
	# predicted remaining air time from vertical speed and height above the course
	var h := maxf(0.0, r.global_position.y - r.track.point_at(r.s, r.lat).y)
	var g := r.tuning.gravity
	var vy := r.velocity.y
	var t_left := (vy + sqrt(maxf(0.0, vy * vy + 2.0 * g * h))) / g
	# signature trick: only when the jump is clearly long enough (normal/expert, ambition-weighted)
	if r.sig_active:
		c.grab = bool(SignatureTricks.of(String(r.def.id)).grab)
		return _air_steer(r, c)
	if not r.sig_done and difficulty >= 1 and r.air_time < 0.15 and _trick_goal > 0.0:
		var sig_dur := float(SignatureTricks.of(String(r.def.id)).dur)
		if t_left > sig_dur + 0.35 and rng.randf() < TRICK_AMBITION[difficulty] * 0.5:
			if r.start_signature():
				_trick_goal = 0.0; _flip_goal = 0.0; _grab_goal = 0.0
				return _air_steer(r, c)
	if r.sig_done:
		return _air_steer(r, c)
	var spin_rate := deg_to_rad(r.tuning.spin_rate_deg) * r.m_spin
	var flip_rate := deg_to_rad(r.tuning.flip_rate_deg) * r.m_spin
	var need_spin := absf(_trick_goal) - absf(r.spin_angle)
	if _trick_goal > 0.0 and need_spin > 0.05:
		if need_spin / spin_rate < t_left - 0.12:
			c.spin_left = _trick_dir > 0
			c.spin_right = _trick_dir < 0
		else:
			_trick_goal = 0.0
	elif absf(r.spin_angle) > 0.1:
		# make sure we land aligned: finish the half-turn if it fits
		var rem := fposmod(absf(r.spin_angle), PI)
		if rem > 0.25 and (PI - rem) / spin_rate < t_left - 0.05:
			c.spin_left = r.spin_angle > 0.0
			c.spin_right = r.spin_angle < 0.0
	var need_flip := _flip_goal - absf(r.flip_angle)
	if _flip_goal > 0.0 and need_flip > 0.05 and need_flip / flip_rate < t_left - 0.15:
		c.flip_back = true
	elif absf(r.flip_angle) > 0.2:
		var remf := fposmod(absf(r.flip_angle), TAU)
		if remf > 0.3 and (TAU - remf) / flip_rate < t_left - 0.05:
			c.flip_back = r.flip_angle < 0.0
			c.flip_front = r.flip_angle > 0.0
	if _grab_goal > 0.0 and r.grab_time < _grab_goal and t_left > 0.3:
		c.grab = true
	# difficulty-based imprecision: rookies sometimes over-rotate
	if difficulty == 0 and rng.randf() < 0.004:
		c.spin_left = true
	return _air_steer(r, c)

func _air_steer(r: RiderController, c: InputCommand) -> InputCommand:
	var tgt := r.track.point_at(minf(r.s + 20.0, r.track.length - 1.0), _lat_smooth)
	var to := tgt - r.global_position
	c.steer = clampf(-wrapf(atan2(-to.x, -to.z) - r.yaw, -PI, PI) * 1.5, -1, 1)
	return c

func _items(r: RiderController, c: InputCommand, tr: TrackRuntime, kmax: float, delta: float) -> void:
	_item_t -= delta
	if _item_t > 0.0:
		return
	var ahead: RiderController = null
	var behind: RiderController = null
	var best_a := 9999.0
	var best_b := 9999.0
	for o in race.riders:
		if o == r or o.finished or o.state == RiderController.State.LIFT:
			continue
		var d: float = o.progress - r.progress
		if d > 0.0 and d < best_a:
			best_a = d; ahead = o
		elif d < 0.0 and -d < best_b:
			best_b = -d; behind = o
	if race.mode == Game.Mode.SKILL_SNOWMEN and r.offense_item != &"":
		var sm: Dictionary = race.next_target(r.s)
		if not sm.is_empty():
			var ds := float(sm.s) - r.s
			if r.offense_item == &"wave" and ds < 9.0:
				c.use_offense = true
			elif r.offense_item != &"wave" and ds < 30.0 and ds > 5.0 and absf(r.lat - float(sm.lat)) < 1.2:
				c.use_offense = true
	if race.mode == Game.Mode.SKILL_FLAKES and r.utility_item != &"":
		var high_ahead := false
		for pk in race.specials.pickups:
			if pk.kind == "flake" and not pk.taken:
				var pr2 := tr.project(pk.p, r.proj_idx)
				if float(pr2.s) - r.s > 4.0 and float(pr2.s) - r.s < 11.0 and float(pr2.height) > 3.0 and absf(float(pr2.lat) - r.lat) < 2.0:
					high_ahead = true
		if r.utility_item == &"magnet" or r.utility_item == &"gust" or (r.utility_item == &"spring" and high_ahead):
			c.use_utility = true
	if race.mode == Game.Mode.SKILL_TARGETS and r.offense_item == &"snowball":
		var tg: Dictionary = race.next_target(r.s)
		if not tg.is_empty() and float(tg.s) - r.s < 32.0 and float(tg.s) - r.s > 6.0 and absf(r.lat - float(tg.lat)) < 0.9:
			c.use_offense = true
	match r.offense_item:
		&"snowball", &"penguin":
			if ahead and best_a < 30.0 and best_a > 4.0:
				c.use_offense = true
		&"wave":
			if (ahead and best_a < 9.0) or (behind and best_b < 9.0):
				c.use_offense = true
		&"icemine":
			if behind and best_b < 25.0:
				c.use_offense = true
		&"fog":
			if ahead and best_a < 40.0:
				c.use_offense = true
		&"comet":
			if r.place > 1:
				c.use_offense = true
		&"whirl":
			if ahead and best_a < 26.0 and best_a > 3.0:
				c.use_offense = true
	match r.utility_item:
		&"gust":
			if kmax < 0.3:
				c.use_utility = true
		&"shield":
			if behind and best_b < 20.0 or rng.randf() < 0.01:
				c.use_utility = true
		&"spring":
			if kmax < 0.2 and rng.randf() < 0.02:
				c.use_utility = true
		&"magnet":
			c.use_utility = rng.randf() < 0.05
	if c.use_offense or c.use_utility:
		stats.items += 1
		_item_t = 1.0 + rng.randf() * (2.0 - difficulty * 0.6)
