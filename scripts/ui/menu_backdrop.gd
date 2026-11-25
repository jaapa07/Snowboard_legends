class_name MenuBackdrop
extends Node3D
## Animated 3D title background: the real authored course (GLB + props + lift) with a slow camera flight
## along the racing line and two riders (rigged models, glide/carve clips) running ahead of the camera.
## Purely presentational: no physics bodies are simulated.

var track: TrackRuntime
var cam: Camera3D
var riders: Array[Dictionary] = []   ## {node, anim, s, lat, phase}
var _s: float = 40.0
var speed: float = 11.0

func setup(track_id: StringName, rider_ids: Array) -> void:
	track = TrackRuntime.new()
	add_child(track)
	track.setup(Registry.track(track_id), mini(Game.quality(), 1), true)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 1200.0
	if Game.perf_low() and Game.quality() == 0:
		cam.far = 600.0
		get_viewport().scaling_3d_scale = 0.6   # phones / web: the title backdrop is the real course too
	add_child(cam)
	cam.current = true
	var i := 0
	for rid in rider_ids:
		var def := Registry.rider(StringName(rid))
		var holder := Node3D.new()
		add_child(holder)
		var model := (load(def.model_path) as PackedScene).instantiate() as Node3D
		model.rotation.y = PI
		holder.add_child(model)
		var bd := Registry.board([&"rocket", &"aurora", &"twin"][i % 3])
		var b := Registry.prop_mesh(PreviewStage.BOARDS_GLB, bd.node_name)
		if b:
			b.rotation.y = PI
			holder.add_child(b)
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for a in ["glide", "carveLeft", "carveRight", "tuck"]:
			if ap and ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		if ap:
			ap.play("glide")
		riders.append({"node": holder, "anim": ap, "s": 0.0, "lat": 0.0, "phase": i * 2.1, "cur": "glide"})
		i += 1
	_place(0.0)

func _process(delta: float) -> void:
	_place(delta)

func _place(delta: float) -> void:
	if track == null:
		return
	_s += speed * delta
	var end := track.lift_s - 30.0
	if _s > end:
		_s = 40.0
	var t := Time.get_ticks_msec() / 1000.0
	var cp := track.point_at(_s, sin(t * 0.13) * 3.0, 5.5)
	cam.global_position = cam.global_position.lerp(cp, clampf(delta * 3.0, 0, 1)) if delta > 0.0 else cp
	var look := track.point_at(minf(_s + 26.0, track.length - 1.0), 0.0, 1.0)
	cam.look_at(look, Vector3.UP)
	for k in riders.size():
		var r: Dictionary = riders[k]
		var ph := float(r.phase)
		var rs := _s + 8.0 + k * 5.0 + sin(t * 0.4 + ph) * 3.0
		var lat := sin(t * 0.55 + ph) * track.half_width(rs) * 0.45
		var dlat := cos(t * 0.55 + ph)
		var n: Node3D = r.node
		n.global_position = track.point_at(rs, lat, 0.05)
		var f := track.fwd[track.idx_at(rs)]
		var yaw := atan2(-f.x, -f.z) - dlat * 0.35
		n.rotation = Vector3(0, yaw, -dlat * 0.25)
		var want := "carveRight" if dlat > 0.55 else ("carveLeft" if dlat < -0.55 else "glide")
		var ap: AnimationPlayer = r.anim
		if ap and want != String(r.cur) and ap.has_animation(want):
			ap.play(want, 0.3)
			r.cur = want
