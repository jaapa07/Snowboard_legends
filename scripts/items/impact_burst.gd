class_name ImpactBurst
extends GPUParticles3D
## One-shot ice explosion: shards + stylised stars, self-freeing.

func _ready() -> void:
	one_shot = true
	explosiveness = 1.0
	amount = 24
	lifetime = 0.8
	var q := QuadMesh.new(); q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	var t := "res://assets/sprites/fx/shard.png"
	if ResourceLoader.exists(t):
		m.albedo_texture = load(t)
	q.material = m
	draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0; pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -12, 0)
	pm.color = Color(0.8, 0.95, 1.0)
	var c := Curve.new(); c.add_point(Vector2(0, 1)); c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new(); ct.curve = c
	pm.alpha_curve = ct
	process_material = pm
	emitting = true
	finished.connect(queue_free)
	Audio.play_3d("ice_burst", self, -2.0)
