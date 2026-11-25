class_name ChaseCamera
extends Camera3D
## Chase camera: behind/above (5-8 m), FOV 65-85 by speed, exponential smoothing, lookahead,
## collision ray against scenery, partial (not full) inheritance of board rotation, optional shake.

var target: RiderController
var distance_min := 5.0
var distance_max := 7.5
var height := 2.4
var shake_enabled := true
var motion_enabled := true
var _yaw := 0.0
var _shake := 0.0
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var lift_mode := false

func add_weather(theme: String, q: int) -> void:
	## Ambient precipitation travelling with the camera: snowfall, night flakes, volcanic ash or a crosswind blizzard.
	var p := GPUParticles3D.new()
	p.amount = int([140, 320, 520][clampi(q, 0, 2)] * (1.8 if theme == "storm" else 1.0) * (0.5 if Game.perf_low() else 1.0))
	p.lifetime = 3.5
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -20, -40), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 2, 18)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2; pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(6.0, -1.5, 0) if theme == "storm" else Vector3(0.4, -1.2, 0)
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.4; pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6; pm.scale_max = 1.3
	var col: Color = {"night": Color(0.78, 0.85, 1.0, 0.85), "volcano": Color(0.42, 0.4, 0.4, 0.8), "storm": Color(0.95, 0.97, 1.0, 0.9)}.get(theme, Color(1, 1, 1, 0.85))
	pm.color = col
	p.process_material = pm
	var q_ := QuadMesh.new(); q_.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	var tex := "res://assets/sprites/fx/puff.png"
	if ResourceLoader.exists(tex):
		m.albedo_texture = load(tex)
	q_.material = m
	p.draw_pass_1 = q_
	p.position = Vector3(0, 9, -10)   # ahead of and above the lens
	add_child(p)

func snap() -> void:
	if target == null:
		return
	_yaw = target.yaw
	_pos = _desired()
	_look = target.global_position + Vector3.UP * 1.3
	global_position = _pos
	look_at(_look, Vector3.UP)
	reset_physics_interpolation()

func add_shake(a: float) -> void:
	if shake_enabled:
		_shake = maxf(_shake, a)

func _desired() -> Vector3:
	var spd := clampf(target.speed / 30.0, 0.0, 1.0)
	var dist := lerpf(distance_min, distance_max, spd)
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	return target.global_position + back * dist + Vector3.UP * (height + (0.6 if target.state == RiderController.State.AIR else 0.0))

func _physics_process(delta: float) -> void:
	if target == null:
		return
	if target.state == RiderController.State.LIFT:
		lift_mode = true
	elif lift_mode:
		lift_mode = false
		snap()
	# heading follows rider yaw (not spins/flips), lagged
	var follow_rate := 4.5 if target.state != RiderController.State.AIR else 1.5
	_yaw = lerp_angle(_yaw, target.yaw, clampf(delta * follow_rate, 0, 1))
	var want := _desired()
	if lift_mode:
		want = target.global_position + Vector3(6, 3, 6)
	var look_ahead := target.global_position + target.forward_dir() * clampf(target.speed * 0.25, 0.0, 6.0) + Vector3.UP * 1.3
	# keep the camera out of geometry
	var space := get_world_3d().direct_space_state
	var from := target.global_position + Vector3.UP * 1.5
	var q := PhysicsRayQueryParameters3D.create(from, want, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = (hit.position as Vector3) + (from - want).normalized() * 0.4
	_pos = _pos.lerp(want, 1.0 - exp(-delta * 9.0))
	_look = _look.lerp(look_ahead, 1.0 - exp(-delta * 12.0))
	var shake_off := Vector3.ZERO
	if _shake > 0.0:
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
		_shake = maxf(0.0, _shake - delta * 2.5)
	global_position = _pos + shake_off
	look_at(_look, Vector3.UP)
	var spd := clampf(target.speed / 32.0, 0.0, 1.0)
	var fov_target := lerpf(65.0, 85.0, spd) if motion_enabled else 70.0
	if target.boost_t > 0.0 and motion_enabled:
		fov_target += 4.0
	fov = lerpf(fov, fov_target, clampf(delta * 3.0, 0, 1))
