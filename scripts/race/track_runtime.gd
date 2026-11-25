class_name TrackRuntime
extends Node3D
## Instantiates an authored course (GLB) and its runtime data (JSON): materials, sky/light, feature colliders,
## instanced vegetation/props, coins, item stations, lift visuals. Provides spline projection for race logic and AI.

signal coin_taken(index: int)

const PROPS_GLB := "res://assets/models/props/props.glb"
const ITEMS_GLB := "res://assets/models/items/items.glb"
const COIN_RESPAWN := 6.0
const STATION_RESPAWN := 2.0

var def: TrackDefinition
var data: Dictionary = {}
var length: float = 0.0
var ds: float = 2.0
var pos: PackedVector3Array = PackedVector3Array()
var right: PackedVector3Array = PackedVector3Array()
var fwd: PackedVector3Array = PackedVector3Array()
var nrm: PackedVector3Array = PackedVector3Array()
var width: PackedFloat32Array = PackedFloat32Array()
var curv: PackedFloat32Array = PackedFloat32Array()
var checkpoints: PackedFloat32Array = PackedFloat32Array()
var finish_s: float = 0.0
var lift_s: float = 0.0
var zones: Array[Dictionary] = []
var ramps: Array[Dictionary] = []
var splits: Array[Dictionary] = []
var platforms: Array[Dictionary] = []
var rails: Array[Dictionary] = []      ## {a: Vector3, b: Vector3, pts: PackedVector3Array, s}
var hazards: Array[Dictionary] = []
var item_s: Array[float] = []
var coins: Array[Dictionary] = []      ## {p: Vector3, s, t_respawn}
var stations: Array[Dictionary] = []   ## {p, slot, node, cooldown}
var coin_mm: MultiMeshInstance3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var lift_bottom: Vector3
var lift_top: Vector3
var spawn_points: Array[Vector3] = []
var _coin_spin: float = 0.0
var _mats: Dictionary = {}
var quality: int = 1

func setup(track_def: TrackDefinition, q: int = 1, with_visuals: bool = true) -> void:
	def = track_def
	quality = q
	name = "Track_" + String(def.id)
	data = JSON.parse_string(FileAccess.get_file_as_string(def.data_path))
	_parse()
	var scene := (load(def.scene_path) as PackedScene).instantiate()
	add_child(scene)
	_apply_materials(scene)
	_build_feature_colliders()
	if with_visuals:
		_build_environment()
		_build_props()
		_build_lift()
		_build_gates()
	_build_coins(with_visuals)
	_build_stations(with_visuals)

# ---------------------------------------------------------------- data
func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _parse() -> void:
	length = float(data.length)
	ds = float(data.ds)
	for smp in data.samples:
		pos.append(_v(smp.p)); right.append(_v(smp.r)); fwd.append(_v(smp.f)); nrm.append(_v(smp.n))
		width.append(float(smp.w)); curv.append(float(smp.c))
	for c in data.checkpoints:
		checkpoints.append(float(c))
	finish_s = float(data.finish_s)
	lift_s = float(data.lift_s)
	lift_bottom = _v(data.lift.bottom)
	lift_top = _v(data.lift.top)
	for sp in data.spawns:
		spawn_points.append(_v(sp.pos))
	for f in data.features:
		match String(f.type):
			"zone":
				zones.append({"kind": String(f.kind), "s0": float(f.s0), "s1": float(f.s1), "lat0": float(f.lat0), "lat1": float(f.lat1), "force": float(f.get("force", 0.0))})
			"ramp":
				ramps.append({"s": float(f.s), "lat": float(f.lat), "w": float(f.w), "h": float(f.h), "l": float(f.l), "corners": f.corners})
			"split":
				splits.append({"s0": float(f.s0), "s1": float(f.s1), "div": float(f.div), "kind": String(f.kind), "h": float(f.get("height", 1.6))})
			"platform":
				platforms.append({"s0": float(f.s0), "s1": float(f.s1), "lat": float(f.lat), "w": float(f.w), "h": float(f.h), "kind": String(f.kind)})
			"rail":
				var pts := PackedVector3Array()
				for p in f.points:
					pts.append(_v(p))
				rails.append({"s": float(f.s), "lat": float(f.lat), "pts": pts, "a": pts[0], "b": pts[pts.size() - 1]})
			"hazard":
				hazards.append({"s": float(f.s), "lat": float(f.lat), "kind": String(f.kind), "pos": _v(f.pos), "yaw": float(f.yaw)})
			"items":
				item_s.append(float(f.s))
			"coins":
				pass

func idx_at(s: float) -> int:
	return clampi(int(round(s / ds)), 0, pos.size() - 1)

func point_at(s: float, lat: float = 0.0, h: float = 0.0) -> Vector3:
	## Banked surface point (same math as the Blender builder).
	var i0 := clampi(int(floor(s / ds)), 0, pos.size() - 2)
	var t := clampf(s / ds - i0, 0.0, 1.0)
	var c := pos[i0].lerp(pos[i0 + 1], t)
	var r := right[i0].lerp(right[i0 + 1], t).normalized()
	var smp: Dictionary = data.samples[i0]
	var b := deg_to_rad(float(smp.b))
	return c + r * lat * cos(b) + Vector3.UP * (-lat * sin(b) + h)

func frame_at(s: float) -> Basis:
	var i := idx_at(s)
	var f := fwd[i]
	var n := nrm[i]
	var r := f.cross(n).normalized() * -1.0
	return Basis(r, n, -f).orthonormalized()

func project(p: Vector3, hint: int = -1) -> Dictionary:
	## Returns {idx, s, lat, dist, height}: nearest centreline sample in a window around hint (global search if none).
	var best := -1
	var best_d := INF
	var lo := 0
	var hi := pos.size() - 1
	if hint >= 0:
		lo = maxi(0, hint - 20)
		hi = mini(pos.size() - 1, hint + 30)
	var step := 1 if hint >= 0 else 4
	var i := lo
	while i <= hi:
		var d := Vector2(p.x - pos[i].x, p.z - pos[i].z).length_squared()
		if d < best_d:
			best_d = d; best = i
		i += step
	if hint < 0:
		var l2 := maxi(0, best - 6)
		var h2 := mini(pos.size() - 1, best + 6)
		for j in range(l2, h2 + 1):
			var d := Vector2(p.x - pos[j].x, p.z - pos[j].z).length_squared()
			if d < best_d:
				best_d = d; best = j
	var rel := p - pos[best]
	var along := rel.dot(fwd[best])
	var s := clampf(best * ds + along, 0.0, length)
	var lat := Vector2(rel.x, rel.z).dot(Vector2(right[best].x, right[best].z))
	return {"idx": best, "s": s, "lat": lat, "dist": sqrt(best_d), "height": rel.y}

func half_width(s: float) -> float:
	return width[idx_at(s)] * 0.5

func zone_at(s: float, lat: float) -> Dictionary:
	for z in zones:
		if s >= z.s0 and s <= z.s1 and lat >= z.lat0 and lat <= z.lat1:
			return z
	return {}

func zones_at(s: float, lat: float) -> Array:
	var out: Array = []
	for z in zones:
		if s >= z.s0 and s <= z.s1 and lat >= z.lat0 and lat <= z.lat1:
			out.append(z)
	return out

# ---------------------------------------------------------------- materials & environment
func _tex(name: String) -> Texture2D:
	return load("res://assets/textures/%s.png" % name)

func material(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var snow := String(data.snow)
	match key:
		"track_groomed":
			m.albedo_texture = _tex(snow + "_albedo"); m.normal_enabled = true; m.normal_texture = _tex(snow + "_normal")
			m.normal_scale = 0.6; m.roughness = 0.55; m.uv1_scale = Vector3(1, 1, 1)
		"track_berm":
			m.albedo_texture = _tex("snow_soft_albedo"); m.normal_enabled = true; m.normal_texture = _tex("snow_soft_normal")
			m.roughness = 0.75; m.albedo_color = Color(0.97, 0.98, 1.0)
			if snow == "snow_night":
				m.albedo_color = Color(0.62, 0.68, 0.92)
			elif snow == "snow_ash":
				m.albedo_color = Color(0.82, 0.78, 0.78)
		"track_ice":
			m.albedo_texture = _tex("ice_albedo"); m.normal_enabled = true; m.normal_texture = _tex("ice_normal")
			m.roughness = 0.08; m.metallic = 0.15; m.metallic_specular = 0.8
		"track_slush":
			m.albedo_texture = _tex("snow_soft_albedo"); m.albedo_color = Color(0.68, 0.76, 0.86); m.roughness = 0.9
		"track_boost":
			m.albedo_color = Color(1.0, 0.82, 0.2); m.emission_enabled = true; m.emission = Color(1.0, 0.7, 0.1); m.emission_energy_multiplier = 0.8
		"terrain_snow":
			m.albedo_texture = _tex(snow + "_albedo"); m.normal_enabled = true; m.normal_texture = _tex("snow_soft_normal")
			m.uv1_triplanar = true; m.uv1_scale = Vector3(0.08, 0.08, 0.08); m.vertex_color_use_as_albedo = true; m.roughness = 0.8
		_:
			return null
	m.resource_name = key
	_mats[key] = m
	return m

func _apply_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(si)
			if sm == null:
				continue
			var rep := material(sm.resource_name)
			if rep:
				m.set_surface_override_material(si, rep)
			elif sm is BaseMaterial3D and sm.resource_name.begins_with("tunnel"):
				(sm as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		if quality == 0:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.name.begins_with("terrain") or m.name.begins_with("course_surface") or m.name.begins_with("mtn"):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	var top := Color(String(data.sky[0])); var hor := Color(String(data.sky[1]))
	sm.sky_top_color = top; sm.sky_horizon_color = hor
	sm.ground_horizon_color = hor; sm.ground_bottom_color = hor.darkened(0.3)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY; e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_exposure = 1.0
	e.fog_enabled = true; e.fog_light_color = Color(String(data.fog)); e.fog_density = 0.0016
	e.fog_aerial_perspective = 0.4; e.fog_sky_affect = 0.3
	e.glow_enabled = quality >= 1; e.glow_intensity = 0.35; e.glow_bloom = 0.02; e.glow_hdr_threshold = 1.2
	e.ssao_enabled = quality >= 2; e.ssao_intensity = 1.2
	e.adjustment_enabled = true; e.adjustment_saturation = 1.12; e.adjustment_contrast = 1.04
	var theme := String(data.theme)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(float(data.sun[0]), float(data.sun[1]), 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = quality >= 1
	sun.directional_shadow_max_distance = 140.0 if quality >= 2 else 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	match theme:
		"night":
			sun.light_energy = 0.35; sun.light_color = Color(0.6, 0.7, 1.0); e.ambient_light_energy = 0.8
			e.fog_density = 0.004; e.glow_intensity = 0.8; e.glow_hdr_threshold = 0.9
		"volcano":
			sun.light_color = Color(1.0, 0.8, 0.65); e.fog_density = 0.0028
		"storm":
			sun.light_energy = 0.8; e.fog_density = 0.0045
		"sky":
			sun.light_color = Color(1.0, 0.9, 0.95)
	env.environment = e
	add_child(env)
	add_child(sun)

# ---------------------------------------------------------------- colliders for features
func _static(name_: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name_
	b.collision_layer = 1
	b.collision_mask = 0
	add_child(b)
	return b

func _convex(body: StaticBody3D, pts: PackedVector3Array) -> void:
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	cs.shape = sh
	body.add_child(cs)

func _strip_convex(body: StaticBody3D, s0: float, s1: float, lat: float, w: float, h: float, step: float = 4.0, taper: float = 4.0) -> void:
	var s := s0
	while s < s1 - 0.01:
		var s2 := minf(s + step, s1)
		var pts := PackedVector3Array()
		for sv in [s, s2]:
			var t := 1.0 if taper <= 0.0 else clampf(minf((sv - s0) / taper, (s1 - sv) / taper), 0.0, 1.0)
			for dl in [-w * 0.5, w * 0.5]:
				pts.append(point_at(sv, lat + dl, -0.3))
				pts.append(point_at(sv, lat + dl * 0.8, maxf(0.05, h * t)))
		_convex(body, pts)
		s = s2

func _build_feature_colliders() -> void:
	var b := _static("FeatureColliders")
	for r in ramps:
		var pts := PackedVector3Array()
		for c in r.corners:
			pts.append(_v(c))
		pts.append(_v(r.corners[0]) + Vector3.DOWN * 0.3)
		pts.append(_v(r.corners[1]) + Vector3.DOWN * 0.3)
		_convex(b, pts)
	for sp in splits:
		_strip_convex(b, sp.s0, sp.s1, 0.0, sp.div, sp.h + 0.6)
	for pl in platforms:
		var L := 7.0
		var inp := PackedVector3Array([point_at(pl.s0, pl.lat - pl.w / 2, -0.05), point_at(pl.s0, pl.lat + pl.w / 2, -0.05),
			point_at(pl.s0 + L, pl.lat - pl.w / 2, pl.h), point_at(pl.s0 + L, pl.lat + pl.w / 2, pl.h),
			point_at(pl.s0 + L, pl.lat - pl.w / 2, -0.3), point_at(pl.s0 + L, pl.lat + pl.w / 2, -0.3)])
		_convex(b, inp)
		_strip_convex(b, pl.s0 + L - 0.3, pl.s1 - L + 0.3, pl.lat, pl.w * 1.25, pl.h, 4.0, 0.0)
		var outp := PackedVector3Array([point_at(pl.s1 - L, pl.lat - pl.w / 2, pl.h), point_at(pl.s1 - L, pl.lat + pl.w / 2, pl.h),
			point_at(pl.s1, pl.lat - pl.w / 2, -0.05), point_at(pl.s1, pl.lat + pl.w / 2, -0.05),
			point_at(pl.s1 - L, pl.lat - pl.w / 2, -0.3), point_at(pl.s1 - L, pl.lat + pl.w / 2, -0.3)])
		_convex(b, outp)
	for hz in hazards:
		var hb := _static("Hazard_" + hz.kind)
		var cs := CollisionShape3D.new()
		match String(hz.kind):
			"log":
				var bx := BoxShape3D.new(); bx.size = Vector3(6.0, 0.9, 0.9); cs.shape = bx; cs.position = Vector3(0, 0.45, 0)
			"wagon":
				var bx := BoxShape3D.new(); bx.size = Vector3(2.6, 3.2, 7.0); cs.shape = bx; cs.position = Vector3(0, 1.6, 0)
			_:
				var sp := SphereShape3D.new(); sp.radius = 1.6; cs.shape = sp; cs.position = Vector3(0, 0.6, 0)
		hb.add_child(cs)
		hb.position = hz.pos
		hb.rotation.y = hz.yaw
		var lib_name: String = hz.kind
		var mesh := Registry.mesh_of(PROPS_GLB, lib_name)
		if mesh:
			var mi := MeshInstance3D.new(); mi.mesh = mesh
			hb.add_child(mi)

# ---------------------------------------------------------------- props & vegetation (instanced)
func _build_props() -> void:
	var groups: Dictionary = {}
	for arr_name in ["props", "vegetation"]:
		for pr in data.get(arr_name, []):
			var k: String = pr.kind
			if not groups.has(k):
				groups[k] = []
			groups[k].append(pr)
	var veg_scale := [0.55, 0.8, 1.0][clampi(quality, 0, 2)]
	for k in groups:
		var mesh := Registry.mesh_of(PROPS_GLB, k)
		if mesh == null:
			continue
		var list: Array = groups[k]
		var is_tree := String(k).begins_with("tree") or String(k).begins_with("bush")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var use := list.size() if not is_tree else int(ceil(list.size() * veg_scale))
		mm.instance_count = use
		for i in use:
			var pr: Dictionary = list[i]
			var t := Transform3D(Basis(Vector3.UP, float(pr.yaw)).scaled(Vector3.ONE * float(pr.scale)), _v(pr.pos))
			mm.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + k
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (quality >= 1 and is_tree) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 420.0 if quality >= 1 else 260.0
		add_child(mmi)
	if String(data.theme) == "night" or String(data.theme) == "station":
		var n := 0
		for pr in data.props:
			if String(pr.kind).begins_with("lantern") and n < (14 if quality >= 1 else 6):
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.75, 0.45); l.light_energy = 2.2; l.omni_range = 14.0
				l.position = _v(pr.pos) + Vector3(0, 2.8, 0)
				add_child(l)
				n += 1

# ---------------------------------------------------------------- lift
var cabins: Array[Node3D] = []
var _cabin_t: float = 0.0

func _build_lift() -> void:
	for p in [lift_bottom, lift_top]:
		var st := Registry.prop_mesh(PROPS_GLB, "lift_station")
		add_child(st)
		st.global_position = p + Vector3(0, -7.5, 0)
		var dir := (lift_top - lift_bottom); dir.y = 0
		st.rotation.y = atan2(dir.x, dir.z)
	for tw in data.lift.towers:
		var t := Registry.prop_mesh(PROPS_GLB, "lift_tower")
		add_child(t)
		var base := _v(tw.pos)
		var h := float(tw.cable_y) - base.y
		t.global_position = base
		t.scale = Vector3(1, maxf(0.3, h / 18.0), 1)
		var dir := (lift_top - lift_bottom); dir.y = 0
		t.rotation.y = atan2(dir.x, dir.z) + PI / 2
	for side in [-2.6, 2.6]:
		var off := (lift_top - lift_bottom).cross(Vector3.UP).normalized() * side
		_cable(lift_bottom + off, lift_top + off)
	for i in 10:
		var c := Registry.prop_mesh(PROPS_GLB, "lift_cabin_%d" % (i % 4))
		add_child(c)
		cabins.append(c)

func _cable(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05; cm.bottom_radius = 0.05; cm.height = a.distance_to(b); cm.radial_segments = 6
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.15, 0.16, 0.18); m.metallic = 0.6; m.roughness = 0.4
	cm.material = m
	mi.mesh = cm
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT
	var z := x.cross(y).normalized()
	mi.global_basis = Basis(x, y, z)

func cable_point(t: float, up_side: bool) -> Vector3:
	var off := (lift_top - lift_bottom).cross(Vector3.UP).normalized() * (2.6 if up_side else -2.6)
	var a := lift_bottom + off
	var b := lift_top + off
	return a.lerp(b, t) if up_side else b.lerp(a, t)

func _build_gates() -> void:
	for s in [30.0, finish_s]:
		var g := Registry.prop_mesh(PROPS_GLB, "gate_arch")
		add_child(g)
		g.global_position = point_at(s, 0.0, 0.0)
		g.global_basis = Basis(Vector3.UP, atan2(-fwd[idx_at(s)].x, -fwd[idx_at(s)].z))
		g.scale = Vector3(half_width(s) / 9.0 + 0.1, 1, 1)
	var ls := Registry.prop_mesh(PROPS_GLB, "sign_lift")
	add_child(ls)
	ls.global_position = point_at(lift_s - 30.0, half_width(lift_s - 30.0) + 3.0, 0.0)
	ls.rotation.y = atan2(-fwd[idx_at(lift_s)].x, -fwd[idx_at(lift_s)].z)

func _process(delta: float) -> void:
	_coin_spin += delta * 3.0
	_cabin_t += delta / 14.0
	for i in cabins.size():
		var t := fmod(_cabin_t + float(i) / cabins.size(), 1.0)
		var up := t < 0.5
		var tt := t * 2.0 if up else (t - 0.5) * 2.0
		cabins[i].global_position = cable_point(tt, up)
		if not up:
			cabins[i].global_position = cable_point(tt, false)
	_update_coins(delta)
	for st in stations:
		if st.cooldown > 0.0:
			st.cooldown -= delta
		if st.node:
			var n: Node3D = st.node
			n.rotation.y += delta * 0.8
			n.scale = Vector3.ONE * (0.55 if st.cooldown > 0.0 else 1.0)

# ---------------------------------------------------------------- coins
func _build_coins(with_visuals: bool) -> void:
	for f in data.features:
		if String(f.type) != "coins":
			continue
		var n := int(f.n)
		for k in n:
			var s := float(f.s) + k * 3.0
			coins.append({"p": point_at(s, float(f.lat), 1.0), "s": s, "t": 0.0})
	if not with_visuals:
		return
	coin_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Registry.mesh_of(ITEMS_GLB, "coin")
	mm.instance_count = coins.size()
	coin_mm.multimesh = mm
	coin_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coin_mm)

func _update_coins(delta: float) -> void:
	for i in coins.size():
		if coins[i].t > 0.0:
			coins[i].t -= delta
	if coin_mm == null:
		return
	var mm := coin_mm.multimesh
	for i in coins.size():
		var c: Dictionary = coins[i]
		var sc := 0.0 if c.t > 0.0 else 1.2
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _coin_spin + i * 0.4).scaled(Vector3.ONE * maxf(sc, 0.001)), c.p + Vector3(0, sin(_coin_spin + i) * 0.12, 0)))

func take_coins_near(p: Vector3, radius: float) -> int:
	var n := 0
	var r2 := radius * radius
	for i in coins.size():
		if coins[i].t <= 0.0 and coins[i].p.distance_squared_to(p) < r2:
			coins[i].t = COIN_RESPAWN
			n += 1
			coin_taken.emit(i)
	return n

# ---------------------------------------------------------------- item stations
func _build_stations(with_visuals: bool) -> void:
	for s in item_s:
		var hw := half_width(s)
		for slot in ["offense", "utility"]:
			var lat := -hw * 0.5 if slot == "offense" else hw * 0.5
			var p := point_at(s, lat, 0.0)
			var node: Node3D = null
			if with_visuals:
				node = Registry.prop_mesh(ITEMS_GLB, "station_" + slot)
				add_child(node)
				node.global_position = p
			stations.append({"p": p, "slot": slot, "node": node, "cooldown": 0.0, "s": s, "lat": lat})

func station_hit(p: Vector3) -> Dictionary:
	for st in stations:
		if st.cooldown <= 0.0 and Vector2(p.x - st.p.x, p.z - st.p.z).length() < 2.4 and absf(p.y - st.p.y) < 4.0:
			return st
	return {}
