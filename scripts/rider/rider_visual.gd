class_name RiderVisual
extends Node3D
## Presentation of a rider: rigged model + board, animation state blending, body orientation, VFX and SFX hooks.
## Never feeds back into physics.

const BOARDS_GLB := "res://assets/models/boards/boards.glb"
const ITEMS_GLB := "res://assets/models/items/items.glb"
const LOOPING := ["idle", "push", "glide", "tuck", "carveLeft", "carveRight", "brake", "jumpCharge", "airIdle", "grab", "spin", "flip", "grind", "liftIdle", "victory", "defeat"]

var rider: RiderController
var model: Node3D
var pivot: Node3D            ## yaw + ground alignment
var trick_pivot: Node3D      ## spin / flip rotation
var anim: AnimationPlayer
var board_node: Node3D
var spray: GPUParticles3D
var boost_fx: GPUParticles3D
var stars: GPUParticles3D
var puff: GPUParticles3D
var sparkle: GPUParticles3D
var shield_mesh: MeshInstance3D
var aura: GlowHalo        ## power state around the rider: gold = magnet, cyan = turbo, red flash = hit
var trail: CarveTrail
var _oneshot: String = ""
var _oneshot_t: float = 0.0
var _cur: String = ""
var _up: Vector3 = Vector3.UP
var _lean: float = 0.0
var holder: Node3D
var _squash: float = 0.0       ## landing compression (presentation only)
var _bob_t: float = 0.0
var _pitch: float = 0.0
var _wind_player: AudioStreamPlayer3D
var _carve_player: AudioStreamPlayer3D

func setup(r: RiderController) -> void:
	rider = r
	name = "Visual"
	pivot = Node3D.new(); add_child(pivot)
	trick_pivot = Node3D.new(); trick_pivot.position = Vector3(0, 0.7, 0); pivot.add_child(trick_pivot)
	holder = Node3D.new(); holder.position = Vector3(0, -0.7, 0); trick_pivot.add_child(holder)
	model = (load(r.def.model_path) as PackedScene).instantiate()
	model.rotation.y = PI  # authored facing Blender -Y (= +Z here); race forward is -Z
	holder.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for a in anim.get_animation_list():
			var res := anim.get_animation(a)
			res.loop_mode = Animation.LOOP_LINEAR if a in LOOPING else Animation.LOOP_NONE
	board_node = Registry.prop_mesh(BOARDS_GLB, r.board.node_name)
	if board_node:
		board_node.rotation.y = PI
		holder.add_child(board_node)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_build_fx()
	trail = CarveTrail.new()
	trail.rider = r
	trail.top_level = true
	add_child(trail)
	if not r.is_human or Game.human_count() > 1:
		pass
	_wind_player = _loop_player("wind_loop", -14.0)
	_carve_player = _loop_player("carve_loop", -10.0)
	play("idle")

func _loop_player(sfx: String, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var st := Audio.stream(sfx)
	if st is AudioStreamWAV:
		var w := (st as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = w.data.size() / (2 * (2 if w.stereo else 1))
		st = w
	p.stream = st
	p.bus = "SFX"; p.volume_db = db; p.unit_size = 8.0; p.max_distance = 60.0
	p.autoplay = false
	add_child(p)
	if st:
		p.play()
	return p

func _tex(n: String) -> Texture2D:
	var p := "res://assets/sprites/fx/%s.png" % n
	return load(p) if ResourceLoader.exists(p) else null

func _billboard_mat(tex_name: String, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tex(tex_name)
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

func _particles(tex_name: String, amount: int, life: float, size: float, additive: bool = false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(4, int(amount * [0.4, 0.75, 1.0][clampi(Game.quality(), 0, 2)]))
	p.lifetime = life
	p.local_coords = false
	var q := QuadMesh.new(); q.size = Vector2(size, size); q.material = _billboard_mat(tex_name, additive)
	p.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, -6, 0)
	var curve := Curve.new(); curve.add_point(Vector2(0, 1)); curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new(); ct.curve = curve
	pm.alpha_curve = ct
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.6)); sc.add_point(Vector2(0.3, 1.0)); sc.add_point(Vector2(1, 1.3))
	var sct := CurveTexture.new(); sct.curve = sc
	pm.scale_curve = sct
	p.process_material = pm
	add_child(p)
	return p

func _build_fx() -> void:
	# pulverised snow: soft puffs (the snowflake sprite read as giant icons behind the board)
	spray = _particles("puff", 48, 0.6, 0.42)
	var pm := spray.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 1); pm.spread = 35.0; pm.initial_velocity_min = 2.0; pm.initial_velocity_max = 5.0
	pm.color = Color(0.92, 0.96, 1.0, 0.75)
	spray.position = Vector3(0, 0.1, 0.6)
	spray.emitting = false
	boost_fx = _particles("sparkle", 80, 0.5, 0.7, true)
	var bm := boost_fx.process_material as ParticleProcessMaterial
	bm.direction = Vector3(0, 0.2, 1); bm.spread = 10; bm.initial_velocity_min = 4; bm.initial_velocity_max = 8; bm.gravity = Vector3.ZERO
	bm.color = Color(0.5, 1.0, 0.9)
	boost_fx.position = Vector3(0, 0.6, 0.6)
	boost_fx.emitting = false
	stars = _particles("star", 10, 0.9, 0.45, true)
	var sm := stars.process_material as ParticleProcessMaterial
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	sm.emission_ring_axis = Vector3.UP; sm.emission_ring_radius = 0.5; sm.emission_ring_inner_radius = 0.4; sm.emission_ring_height = 0.1
	sm.direction = Vector3(0, 1, 0); sm.initial_velocity_min = 1.5; sm.initial_velocity_max = 2.5; sm.gravity = Vector3(0, -1, 0)
	sm.orbit_velocity_min = 0.6; sm.orbit_velocity_max = 0.9
	sm.color = Color(1.0, 0.9, 0.3)
	stars.position = Vector3(0, 1.6, 0); stars.one_shot = true; stars.emitting = false; stars.explosiveness = 0.9
	puff = _particles("puff", 24, 0.6, 0.9)
	var pp := puff.process_material as ParticleProcessMaterial
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pp.emission_sphere_radius = 0.6
	pp.direction = Vector3(0, 1, 0); pp.spread = 80; pp.initial_velocity_min = 1.5; pp.initial_velocity_max = 3.5; pp.gravity = Vector3(0, -3, 0)
	puff.one_shot = true; puff.explosiveness = 1.0; puff.emitting = false
	sparkle = _particles("sparkle", 12, 0.5, 0.3, true)
	var sp := sparkle.process_material as ParticleProcessMaterial
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 0.5
	sp.initial_velocity_min = 1; sp.initial_velocity_max = 2; sp.gravity = Vector3(0, 2, 0); sp.color = Color(1, 0.85, 0.2)
	sparkle.position = Vector3(0, 1.0, 0); sparkle.one_shot = true; sparkle.explosiveness = 1.0; sparkle.emitting = false
	var sh := Registry.mesh_of(ITEMS_GLB, "item_shield")
	shield_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new(); sphere.radius = 1.25; sphere.height = 2.5
	shield_mesh.mesh = sh if sh else sphere
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.5, 0.95, 1.0, 0.25)
	smat.emission_enabled = true; smat.emission = Color(0.3, 0.8, 1.0); smat.emission_energy_multiplier = 1.2
	smat.rim_enabled = true; smat.rim = 1.0
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = smat
	shield_mesh.position = Vector3(0, 0.8, 0)
	shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_mesh.visible = false
	add_child(shield_mesh)
	aura = GlowHalo.make(Color(1, 1, 1, 0.0), 4.2, 0.15)
	aura.position = Vector3(0, 0.9, 0)
	aura.visible = false
	add_child(aura)

func play(name_: String, blend: float = 0.24) -> void:
	if anim == null or name_ == _cur or not anim.has_animation(name_):
		return
	_cur = name_
	anim.play(name_, blend)

func oneshot(name_: String, dur: float) -> void:
	_oneshot = name_
	_oneshot_t = dur
	_cur = ""
	play(name_, 0.08)

func tick(delta: float) -> void:
	var r := rider
	var cmd := r.last_cmd
	# orientation: yaw, ground alignment, carving lean
	var target_up := r.ground_n if r.state == RiderController.State.GROUND or r.state == RiderController.State.FALLEN else Vector3.UP
	_up = _up.lerp(target_up, clampf(delta * 10.0, 0, 1)).normalized()  # lerp: slerp of near-parallel unit vectors trips Godot axis-normalization checks
	var fwd := r.forward_dir()
	var f := (fwd - _up * fwd.dot(_up)).normalized()
	var x := f.cross(_up).normalized()
	var b := Basis(x, _up, -f).orthonormalized()
	# carving: lean into the turn (more with speed), smoothed; a slight forward pitch when tucked, back when braking
	var lean_target := 0.0
	if r.state == RiderController.State.GROUND:
		lean_target = clampf(-r.yaw_rate * (0.16 + clampf(r.speed / 30.0, 0, 1) * 0.12), -0.62, 0.62)
	_lean = lerpf(_lean, lean_target, 1.0 - exp(-delta * 7.0))
	var pitch_target := 0.0
	if r.state == RiderController.State.GROUND:
		pitch_target = 0.10 if cmd.tuck else (-0.12 if cmd.brake else 0.0)
	_pitch = lerpf(_pitch, pitch_target, 1.0 - exp(-delta * 6.0))
	pivot.global_basis = b * Basis(Vector3.FORWARD, _lean) * Basis(Vector3.RIGHT, -_pitch)
	# body: soft bob from snow bumps at speed + squash/stretch on landing
	_bob_t += delta * (2.0 + r.speed * 0.35)
	var bob := sin(_bob_t) * clampf(r.speed / 25.0, 0, 1) * 0.025 if r.state == RiderController.State.GROUND else 0.0
	_squash = maxf(0.0, _squash - delta * 4.0)
	var sq := sin(_squash * PI) * 0.16
	holder.scale = Vector3(1.0 + sq * 0.5, 1.0 - sq, 1.0 + sq * 0.5)
	holder.position.y = -0.7 + bob - sq * 0.25
	if anim:
		var moving := _cur in ["glide", "push", "carveLeft", "carveRight", "tuck"]
		anim.speed_scale = clampf(0.75 + r.speed / 28.0, 0.75, 1.45) if moving else 1.0
	pivot.global_position = r.global_position
	var spin := r.spin_angle if r.state == RiderController.State.AIR else 0.0
	var flip := r.flip_angle if r.state == RiderController.State.AIR else 0.0
	if r.spinout_t > 0.0:
		spin = Time.get_ticks_msec() * 0.012
	trick_pivot.basis = Basis(Vector3.UP, spin) * Basis(Vector3.RIGHT, -flip)
	# animation choice
	if _oneshot_t > 0.0:
		_oneshot_t -= delta
	else:
		play(_pick(cmd))
	# fx
	var grounded := r.state == RiderController.State.GROUND
	var sp := r.speed
	spray.emitting = grounded and sp > 6.0
	spray.amount_ratio = clampf(sp / 30.0 + absf(cmd.steer) * 0.5 + (0.5 if cmd.brake else 0.0), 0.1, 1.0)
	spray.global_position = r.global_position - f * 0.7 + Vector3.UP * 0.1
	boost_fx.emitting = r.boost_t > 0.0
	boost_fx.amount_ratio = 1.0
	var ac := Color(0, 0, 0, 0)
	if r.magnet_t > 0.0:
		ac = Color(1.0, 0.8, 0.2, 0.55)
	elif r.boost_t > 0.0:
		ac = Color(0.3, 1.0, 0.9, 0.5)
	if aura._flash_t > 0.0 and ac.a == 0.0:
		ac = Color(1.0, 0.25, 0.2, 0.7)
	aura.visible = ac.a > 0.0
	if aura.visible:
		aura.set_color(ac)
	shield_mesh.visible = r.shield_t > 0.0
	if shield_mesh.visible:
		shield_mesh.rotate_y(delta * 2.0)
		var a := 0.4 if r.shield_t > 1.5 else (0.4 if int(r.shield_t * 8.0) % 2 == 0 else 0.08)
		(shield_mesh.material_override as StandardMaterial3D).albedo_color.a = a
	visible = r.state != RiderController.State.LIFT or true
	if _wind_player and _wind_player.stream:
		_wind_player.volume_db = lerpf(-30.0, -6.0, clampf(sp / 32.0, 0, 1))
		_wind_player.pitch_scale = 0.8 + clampf(sp / 32.0, 0, 1) * 0.5
	if _carve_player and _carve_player.stream:
		var carving := grounded and sp > 4.0
		_carve_player.volume_db = (lerpf(-28.0, -8.0, clampf(absf(cmd.steer) + sp / 60.0, 0, 1)) if carving else -60.0)
		_carve_player.pitch_scale = 1.3 if r.surface == "ice" else (0.8 if r.surface == "slush" else 1.0)

func _pick(cmd: InputCommand) -> String:
	var r := rider
	match r.state:
		RiderController.State.GROUND, RiderController.State.FROZEN:
			if cmd.jump_held:
				return "jumpCharge"
			if cmd.brake:
				return "brake"
			if cmd.tuck:
				return "tuck"
			if cmd.steer > 0.3:
				return "carveRight"
			if cmd.steer < -0.3:
				return "carveLeft"
			if r.speed < 2.5:
				return "idle"
			if r.speed < 7.0:
				return "push"
			return "glide"
		RiderController.State.AIR:
			if cmd.grab:
				return "grab"
			if cmd.flip_front or cmd.flip_back:
				return "flip"
			if cmd.spin_left or cmd.spin_right:
				return "spin"
			return "airIdle"
		RiderController.State.GRIND:
			return "grind"
		RiderController.State.FALLEN:
			return "fall"
		RiderController.State.LIFT:
			return "liftIdle"
		RiderController.State.FINISHED:
			return "victory" if r.place <= 2 else "defeat"
	return "glide"

# ------------------------------------------------------------------ events
func on_takeoff() -> void:
	oneshot("takeoff", 0.25)
	Audio.play_3d("jump", rider, -4.0)

func on_land(quality: String) -> void:
	puff.restart(); puff.emitting = true
	_squash = 1.0 if quality == "sloppy" else 0.7
	if quality == "sloppy":
		oneshot("landHard", 0.5)
		Audio.play_3d("land_hard", rider, -2.0)
	else:
		oneshot("landSoft", 0.3)
		Audio.play_3d("land", rider, -3.0)
	if rider.is_human:
		Inputs.rumble(rider.device, 0.4 if quality == "sloppy" else 0.2, 0.15)

func on_fall() -> void:
	oneshot("fall", 0.9)
	stars.restart(); stars.emitting = true
	puff.restart(); puff.emitting = true
	Audio.play_3d("crash", rider, 0.0)
	if rider.is_human:
		Inputs.rumble(rider.device, 0.9, 0.4)

func on_recover() -> void:
	oneshot("recover", 0.6)

func on_hit() -> void:
	oneshot("hit", 0.7)
	stars.restart(); stars.emitting = true
	aura.flash(0.6)
	Audio.play_3d("hit", rider, 0.0)
	if rider.is_human:
		Inputs.rumble(rider.device, 0.7, 0.3)

func on_shield_break() -> void:
	Audio.play_3d("shield_break", rider, 0.0)
	sparkle.restart(); sparkle.emitting = true

func on_coin() -> void:
	sparkle.restart(); sparkle.emitting = true
	if rider.is_human:
		Audio.play("coin", -6.0, randf_range(0.95, 1.1))

func on_grind(on: bool) -> void:
	if on:
		Audio.play_3d("grind", rider, -4.0)

func on_lift(on: bool) -> void:
	oneshot("liftEnter" if on else "liftExit", 0.5)

func on_finish() -> void:
	_oneshot_t = 0.0
