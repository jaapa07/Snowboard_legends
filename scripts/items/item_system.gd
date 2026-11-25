class_name ItemSystem
extends Node3D
## Purchasing at stations, position-weighted rolls, and the runtime behaviour of all 10 items.
## Projectiles expire after 4 s, never pass through walls (ray test), are telegraphed visually and audibly.

signal item_event(rider: RiderController, kind: String, item: StringName)

const PRICE := 20
const PROJECTILE_LIFE := 4.0
const MINE_LIFE := 25.0
const ITEMS_GLB := "res://assets/models/items/items.glb"

var race: Node
var rng := RandomNumberGenerator.new()
var projectiles: Array[Dictionary] = []   ## {kind, node, p, v, owner, t, target, s, lat}
var mines: Array[Dictionary] = []         ## {node, p, owner, t, armed}
var clouds: Array[Dictionary] = []        ## {node, p, t}
var enabled: bool = true
var _pool: Dictionary = {}

func setup(race_node: Node, seed_: int, on: bool) -> void:
	race = race_node
	rng.seed = seed_ ^ 0x5eed
	enabled = on

func _node(kind: String) -> Node3D:
	if not _pool.has(kind):
		_pool[kind] = []
	var arr: Array = _pool[kind]
	if arr.size() > 0:
		var n: Node3D = arr.pop_back()
		n.visible = true
		return n
	var n2 := Registry.prop_mesh(ITEMS_GLB, kind)
	add_child(n2)
	return n2

func _release(kind: String, n: Node3D) -> void:
	n.visible = false
	_pool[kind].append(n)

# ---------------------------------------------------------------- stations
func try_station(r: RiderController) -> void:
	if not enabled or r.state != RiderController.State.GROUND and r.state != RiderController.State.AIR:
		return
	var st: Dictionary = r.track.station_hit(r.global_position)
	if st.is_empty():
		return
	var slot: String = st.slot
	if (slot == "offense" and r.offense_item != &"") or (slot == "utility" and r.utility_item != &""):
		return
	st.cooldown = r.track.STATION_RESPAWN
	if r.race_coins < PRICE:
		r.message.emit(r, "no_coins")
		if r.is_human:
			Audio.play("buy_fail")
		return
	r.add_coins(-PRICE)
	var it := roll(slot, r.place)
	if slot == "offense":
		r.offense_item = it
	else:
		r.utility_item = it
	r.items_changed.emit(r)
	if r.is_human:
		Audio.play("buy")
	item_event.emit(r, "bought", it)

func roll(slot: String, place: int) -> StringName:
	var total := 0.0
	var opts: Array = []
	for id in Registry.ITEM_IDS:
		var d := Registry.item(id)
		if d.slot != slot:
			continue
		var w := d.weights[clampi(place - 1, 0, 3)]
		opts.append([id, w]); total += w
	var x := rng.randf() * total
	for o in opts:
		x -= o[1]
		if x <= 0.0:
			return o[0]
	return opts[-1][0]

# ---------------------------------------------------------------- use
func use_item(r: RiderController, id: StringName) -> bool:
	var fwd := r.forward_dir()
	match id:
		&"snowball":
			var n := _node("item_snowball")
			var p := r.global_position + Vector3.UP * 0.8 + fwd * 1.5
			n.global_position = p
			projectiles.append({"kind": "snowball", "node": n, "p": p, "v": fwd * (r.speed + 25.0), "owner": r, "t": 0.0})
			Audio.play_3d("throw", r)
		&"penguin":
			var target := _nearest_ahead(r, 80.0)
			var n := _node("item_penguin")
			projectiles.append({"kind": "penguin", "node": n, "owner": r, "t": 0.0, "target": target, "s": r.s + 2.0, "lat": r.lat,
				"p": r.global_position, "spd": maxf(r.speed + 8.0, 22.0)})
			Audio.play_3d("penguin", r)
		&"icemine":
			var n := _node("item_icemine")
			var pr: Dictionary = r.track.project(r.global_position - fwd * 2.5, r.proj_idx)
			var p := r.track.point_at(float(pr.s), float(pr.lat), 0.1)
			n.global_position = p
			mines.append({"node": n, "p": p, "owner": r, "t": 0.0, "armed": false})
			Audio.play_3d("mine_drop", r)
		&"fog":
			var target := _nearest_ahead(r, 45.0)
			var at: Vector3 = target.global_position if target else r.track.point_at(minf(r.s + 20.0, r.track.length - 2.0), r.lat)
			var n := _node("item_fog")
			n.global_position = at + Vector3.UP * 1.0
			n.scale = Vector3.ONE * 6.0
			clouds.append({"node": n, "p": at, "t": 0.0, "owner": r})
			Audio.play_3d("fog", r)
		&"wave":
			var n := _node("item_wave")
			n.global_position = r.global_position + Vector3.UP * 0.2
			n.scale = Vector3.ONE
			projectiles.append({"kind": "wave", "node": n, "owner": r, "t": 0.0, "p": r.global_position})
			for o in race.riders:
				if o != r and o.global_position.distance_to(r.global_position) < 12.0:
					var away: Vector3 = (o.global_position - r.global_position)
					away.y = 0
					if o.apply_hit("wave"):
						o.push(away.normalized() * 7.0)
			Audio.play_3d("wave", r)
		&"comet":
			# seeker: flies along the course to the current leader (never used by the leader itself)
			var leader: RiderController = null
			for o in race.riders:
				if o != r and o.place == 1 and not o.finished and o.state != RiderController.State.LIFT:
					leader = o
			if leader == null or leader.progress <= r.progress:
				return false
			var n := _node("item_comet")
			projectiles.append({"kind": "comet", "node": n, "owner": r, "t": 0.0, "target": leader, "s": r.s + 2.0, "lat": r.lat,
				"lap": r.lap, "p": r.global_position, "spd": maxf(leader.speed * 1.6, 42.0)})
			Audio.play_3d("boost", r)
		&"whirl":
			var n := _node("item_whirl")
			var p := r.global_position + fwd * 1.8
			n.global_position = p
			projectiles.append({"kind": "whirl", "node": n, "p": p, "v": fwd * (r.speed + 18.0), "owner": r, "t": 0.0})
			Audio.play_3d("wave", r)
		&"gust":
			r.boost_t = 2.0
			Audio.play_3d("boost", r)
		&"shield":
			r.shield_t = 6.0
			Audio.play_3d("shield", r)
		&"spring":
			if r.state != RiderController.State.GROUND:
				return false
			r.velocity += r.ground_n * 11.0
			r._enter_air(true)
			Audio.play_3d("spring", r)
		&"magnet":
			r.magnet_t = 5.0
			Audio.play_3d("magnet", r)
		&"repair":
			if r.state != RiderController.State.FALLEN:
				r.message.emit(r, "repair_hint")
				return false
			r.fallen_t = 0.1
			Audio.play_3d("repair", r)
		_:
			return false
	item_event.emit(r, "used", id)
	return true

func _nearest_ahead(r: RiderController, max_d: float) -> RiderController:
	var best: RiderController = null
	var bd := max_d
	for o in race.riders:
		if o == r or o.finished or o.state == RiderController.State.LIFT:
			continue
		var d: float = o.progress - r.progress
		if d > 0.0 and d < bd:
			bd = d; best = o
	return best

# ---------------------------------------------------------------- simulation
func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in range(projectiles.size() - 1, -1, -1):
		var pj: Dictionary = projectiles[i]
		pj.t += delta
		var done: bool = pj.t > PROJECTILE_LIFE
		match String(pj.kind):
			"snowball":
				var nxt: Vector3 = pj.p + pj.v * delta
				var q := PhysicsRayQueryParameters3D.create(pj.p, nxt, 1)
				var hit := space.intersect_ray(q)
				if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.6:
					done = true   # wall: never passes through
					_burst(pj.p)
				# follow the snow surface
				var down := PhysicsRayQueryParameters3D.create(nxt + Vector3.UP * 3.0, nxt + Vector3.DOWN * 6.0, 1)
				var g := space.intersect_ray(down)
				if not g.is_empty():
					nxt.y = lerpf(nxt.y, (g.position as Vector3).y + 0.6, 0.5)
				pj.p = nxt
				(pj.node as Node3D).global_position = nxt
				(pj.node as Node3D).rotate_x(delta * 12.0)
				if not done and race.has_method("hit_target") and race.hit_target(nxt):
					_burst(nxt)
					done = true
				for o in race.riders:
					if done:
						break
					if o != pj.owner and o.global_position.distance_to(nxt - Vector3.UP * 0.6) < 1.3:
						o.apply_hit("snowball")
						_burst(nxt)
						done = true
						break
			"penguin":
				var tgt: RiderController = pj.target
				var tr: TrackRuntime = race.track
				pj.s += pj.spd * delta
				if tgt and is_instance_valid(tgt):
					pj.lat = lerpf(pj.lat, tgt.lat, clampf(delta * 3.0, 0, 1))
				var np := tr.point_at(minf(pj.s, tr.length - 1.0), pj.lat, 0.3)
				(pj.node as Node3D).global_position = np
				(pj.node as Node3D).look_at(np + tr.fwd[tr.idx_at(pj.s)], Vector3.UP)
				pj.p = np
				for hz in tr.hazards:
					if (hz.pos as Vector3).distance_to(np) < 1.8:
						done = true; _burst(np)
				for o in race.riders:
					if o != pj.owner and o.global_position.distance_to(np) < 1.4:
						o.apply_hit("penguin")
						_burst(np)
						done = true
						break
			"comet":
				var tgt: RiderController = pj.target
				var tr: TrackRuntime = race.track
				if tgt == null or not is_instance_valid(tgt) or tgt.finished or tgt.state == RiderController.State.LIFT:
					done = true   # the lift is a safe zone
				else:
					# chase along the spline; once on the leader's descent, close in directly
					if pj.get("homing", false) or tgt.lap > int(pj.lap) or pj.s >= tgt.s - 12.0:
						pj.homing = true   # final approach: stays locked on (switching back made it hover beside the target)
						var to: Vector3 = tgt.global_position + Vector3.UP * 0.9 - (pj.p as Vector3)
						pj.p = (pj.p as Vector3) + to.normalized() * minf(to.length(), float(pj.spd) * delta)
					else:
						pj.s = minf(float(pj.s) + float(pj.spd) * delta, tr.length - 1.0)
						pj.lat = lerpf(float(pj.lat), tgt.lat, clampf(delta * 2.0, 0, 1))
						pj.p = tr.point_at(float(pj.s), float(pj.lat), 2.2)
					(pj.node as Node3D).global_position = pj.p
					(pj.node as Node3D).look_at((pj.p as Vector3) + (tgt.global_position - (pj.p as Vector3)).normalized() + Vector3(0.001, 0, 0), Vector3.UP)
					if tgt.global_position.distance_to(pj.p) < 1.8:
						tgt.apply_hit("comet")
						_burst(pj.p)
						done = true
			"whirl":
				var nxt: Vector3 = pj.p + pj.v * delta
				var q2 := PhysicsRayQueryParameters3D.create(pj.p, nxt, 1)
				var hit2 := space.intersect_ray(q2)
				if not hit2.is_empty() and absf((hit2.normal as Vector3).y) < 0.6:
					done = true
					_burst(pj.p)
				var down2 := PhysicsRayQueryParameters3D.create(nxt + Vector3.UP * 3.0, nxt + Vector3.DOWN * 6.0, 1)
				var g2 := space.intersect_ray(down2)
				if not g2.is_empty():
					nxt.y = lerpf(nxt.y, (g2.position as Vector3).y + 0.1, 0.5)
				pj.p = nxt
				(pj.node as Node3D).global_position = nxt
				(pj.node as Node3D).rotate_y(delta * 14.0)
				for o in race.riders:
					if o != pj.owner and o.global_position.distance_to(nxt) < 2.2:
						if o.apply_hit("whirl"):
							o.offense_item = &""
							o.utility_item = &""
							o.items_changed.emit(o)
						_burst(nxt)
						done = true
						break
			"wave":
				var sc: float = 1.0 + pj.t * 18.0
				(pj.node as Node3D).scale = Vector3(sc, 1.0, sc)
				done = pj.t > 0.6
		if done:
			_release(_model_of(String(pj.kind)), pj.node)
			projectiles.remove_at(i)
	for i in range(mines.size() - 1, -1, -1):
		var m: Dictionary = mines[i]
		m.t += delta
		m.armed = m.t > 0.5
		(m.node as Node3D).rotate_y(delta * 1.5)
		var gone: bool = m.t > MINE_LIFE
		if m.armed:
			for o in race.riders:
				if o.state == RiderController.State.GROUND and o.global_position.distance_to(m.p) < 1.4:
					o.apply_hit("icemine")
					_burst(m.p)
					gone = true
					break
		if gone:
			_release("item_icemine", m.node)
			mines.remove_at(i)
	for i in range(clouds.size() - 1, -1, -1):
		var c: Dictionary = clouds[i]
		c.t += delta
		(c.node as Node3D).rotate_y(delta * 0.3)
		for o in race.riders:
			if o != c.owner and o.global_position.distance_to(c.p) < 8.0:
				o.fog_t = 2.0
		if c.t > 5.0:
			_release("item_fog", c.node)
			clouds.remove_at(i)

func _model_of(kind: String) -> String:
	return {"snowball": "item_snowball", "penguin": "item_penguin", "wave": "item_wave", "comet": "item_comet", "whirl": "item_whirl"}[kind]

func incoming_for(r: RiderController) -> bool:
	## HUD telegraph: a projectile is heading at this rider.
	for pj in projectiles:
		if pj.owner == r:
			continue
		if (String(pj.kind) == "penguin" or String(pj.kind) == "comet") and pj.target == r:
			return true
		if String(pj.kind) == "whirl" and (pj.p as Vector3).distance_to(r.global_position) < 25.0:
			return true
		if String(pj.kind) == "snowball" and (pj.p as Vector3).distance_to(r.global_position) < 25.0:
			return true
	return false

func _burst(p: Vector3) -> void:
	var fx := ImpactBurst.new()
	fx.position = p
	add_child(fx)
