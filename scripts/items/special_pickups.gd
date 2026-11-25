class_name SpecialPickups
extends Node3D
## Special collectibles placed on every course (authored models from items.glb):
## - Golden snowflake (3 per course, hidden off the racing line / above jumps): +10 credits each at the end of
##   the race; each flake is remembered per course in the profile (album 3 x 9 courses).
## - Turbo crystal: instant 1.5 s boost.
## - Mystery box: fills every empty item slot for free (position-weighted roll, like the stations).
## - Giant coin: +25 race coins.
## Placement is deterministic from the course data (no randomness per race). Pickups respawn after RESPAWN s,
## except golden flakes (once per race, first rider to touch it).
## The power minigames reuse this system: SKILL_FLAKES lays out a dense, harder flake trail.

signal collected(rider: RiderController, kind: String)

const ITEMS_GLB := "res://assets/models/items/items.glb"
const RESPAWN := 8.0
const PICK_RADIUS := 1.7
const KIND_NODE := {"flake": "special_flake", "crystal": "special_crystal", "box": "special_box", "bigcoin": "special_bigcoin"}

var race: Node
var track: TrackRuntime
var pickups: Array[Dictionary] = []   ## {kind, p, node, cooldown, id, taken}
var flakes_by_rider: Dictionary = {}  ## rider index -> [flake ids]
var _t: float = 0.0
var visuals: bool = true

func setup(race_node: Node, trk: TrackRuntime, minigame_flakes: bool) -> void:
	race = race_node
	track = trk
	visuals = DisplayServer.get_name() != "headless"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if minigame_flakes:
		_layout_flake_hunt()
	else:
		_layout_course()

func _add(kind: String, p: Vector3, id: String = "") -> void:
	var n: Node3D = null
	if visuals:
		n = Registry.prop_mesh(ITEMS_GLB, KIND_NODE[kind])
		if n:
			add_child(n)
			n.global_position = p
			n.scale = Vector3.ONE * (1.1 if kind == "flake" else 1.0)
	pickups.append({"kind": kind, "p": p, "node": n, "cooldown": 0.0, "id": id, "taken": false})

func _ramp_after(s0: float) -> Dictionary:
	for rp in track.ramps:
		if float(rp.s) > s0:
			return rp
	return {}

func _layout_course() -> void:
	var L := track.finish_s
	# golden flakes: one off the line near the edge, one high above the first jump after 45 %, one near a split
	var s1 := L * 0.28
	_add("flake", track.point_at(s1, track.half_width(s1) * 0.82, 1.3), "%s:1" % track.def.id)
	var rp := _ramp_after(L * 0.45)
	if not rp.is_empty():
		var s2 := float(rp.s) + float(rp.l) * 0.5 + 9.0
		_add("flake", track.point_at(s2, float(rp.lat), 3.6), "%s:2" % track.def.id)   # only reachable in the air
	else:
		var s2b := L * 0.55
		_add("flake", track.point_at(s2b, -track.half_width(s2b) * 0.82, 1.3), "%s:2" % track.def.id)
	var s3 := L * 0.78
	if not track.splits.is_empty():
		var sp: Dictionary = track.splits[track.splits.size() - 1]
		s3 = (float(sp.s0) + float(sp.s1)) * 0.5
	_add("flake", track.point_at(s3, -track.half_width(s3) * 0.7, 1.3), "%s:3" % track.def.id)
	# turbo crystals on the racing line, mystery boxes and giant coins near the edges
	for f in [0.18, 0.42, 0.66, 0.9]:
		var s: float = L * float(f)
		if s < L - 30.0:
			_add("crystal", track.point_at(s, 0.0, 1.0))
	for f in [0.34, 0.6]:
		var s: float = L * float(f)
		_add("box", track.point_at(s, track.half_width(s) * 0.45 * (1.0 if f < 0.5 else -1.0), 0.6))
	for f in [0.24, 0.5, 0.84]:
		var s: float = L * float(f)
		_add("bigcoin", track.point_at(s, -track.half_width(s) * 0.55 * (1.0 if int(f * 100) % 2 == 0 else -1.0), 1.1))

func _layout_flake_hunt() -> void:
	## Minigame: 20 golden flakes in spots that need powers — high ones (spring), far off-line ones (magnet radius 9 m),
	## and clusters after the boost crystals.
	var L := track.finish_s
	var n := 20
	for i in n:
		var s := 70.0 + (L - 110.0) * float(i) / float(n - 1)
		var hw := track.half_width(s)
		var kind := i % 3
		var lat := 0.0
		var h := 1.3
		match kind:
			0: lat = hw * 0.25 * (1.0 if i % 2 == 0 else -1.0)            # easy
			1: lat = hw * 0.95 * (1.0 if i % 4 == 1 else -1.0)            # far edge: magnet reaches it
			2: h = 4.2                                                     # high: spring / jump
		_add("flake", track.point_at(s, lat, h), "hunt:%d" % i)
	for f in [0.2, 0.5, 0.8]:
		_add("crystal", track.point_at(L * f, 0.0, 1.0))

func _physics_process(delta: float) -> void:
	if race == null or race.phase != 2:
		return
	_t += delta
	for pk in pickups:
		if pk.taken:
			continue
		if float(pk.cooldown) > 0.0:
			pk.cooldown = float(pk.cooldown) - delta
			if float(pk.cooldown) <= 0.0 and pk.node:
				(pk.node as Node3D).visible = true
			continue
		var p: Vector3 = pk.p
		for r in race.riders:
			if r.finished or r.state == RiderController.State.LIFT:
				continue
			var radius := PICK_RADIUS
			if r.magnet_t > 0.0 and pk.kind in ["flake", "bigcoin"]:
				radius = 9.0
			if r.global_position.distance_to(p - Vector3.UP * 0.6) < radius:
				_collect(r, pk)
				break

func _collect(r: RiderController, pk: Dictionary) -> void:
	match String(pk.kind):
		"flake":
			pk.taken = true
			if not flakes_by_rider.has(r.index):
				flakes_by_rider[r.index] = []
			flakes_by_rider[r.index].append(String(pk.id))
			if r.is_human:
				Audio.play("unlock", -3.0)
		"crystal":
			r.boost_t = maxf(r.boost_t, 1.5)
			if r.is_human:
				Audio.play("boost", -2.0)
		"box":
			var items: ItemSystem = race.items
			var got := false
			if r.offense_item == &"":
				r.offense_item = items.roll("offense", r.place); got = true
			if r.utility_item == &"":
				r.utility_item = items.roll("utility", r.place); got = true
			if got:
				r.items_changed.emit(r)
			if r.is_human:
				Audio.play("buy", -2.0)
		"bigcoin":
			r.add_coins(25)
			if r.is_human:
				Audio.play("coin", 0.0, 0.8)
	if pk.kind != "flake":
		pk.cooldown = RESPAWN
	if pk.node:
		(pk.node as Node3D).visible = false
	collected.emit(r, String(pk.kind))

func flakes_of(r: RiderController) -> Array:
	return flakes_by_rider.get(r.index, [])

func _process(delta: float) -> void:
	if not visuals:
		return
	for pk in pickups:
		var n: Node3D = pk.node
		if n and n.visible:
			n.rotation.y += delta * (2.2 if pk.kind == "flake" else 1.2)
			n.position.y = (pk.p as Vector3).y + sin(_t * 2.0 + (pk.p as Vector3).x) * 0.15
