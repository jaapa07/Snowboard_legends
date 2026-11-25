class_name ResultsScreen
extends Node
## Results: animated 3D podium (top 3 rigged riders playing their own victory clip, the rest the defeat clip,
## confetti), race table with times / points, credits, trick bonus, cup standings, medals and unlocks.
## Applies progression once through Game.process_results().

const PROPS_GLB := "res://assets/models/props/props.glb"
const BOARDS_GLB := "res://assets/models/boards/boards.glb"

var world: Node3D
var cam: Camera3D
var ui: CanvasLayer
var root: Control
var summary: Dictionary
var _t: float = 0.0
var _rise: Array[Dictionary] = []

func _ready() -> void:
	summary = Game.process_results()
	_build_world()
	_build_ui()
	var me_place := 4
	for row in summary.rows:
		if row.human:
			me_place = mini(me_place, int(row.place))
	Audio.play_music("res://assets/audio/music/victory.ogg" if me_place == 1 else "res://assets/audio/music/results.ogg")
	if not summary.unlocks.is_empty():
		Audio.play("unlock")

func t(k: String) -> String:
	return Game.t(k)

# ---------------------------------------------------------------- 3D podium
func _mat(tex: String, col: Color, uv: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if ResourceLoader.exists(tex):
		m.albedo_texture = load(tex)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * uv
	m.roughness = 0.7
	return m

func _prop(name_: String, pos: Vector3, rot_y: float = 0.0, sc: float = 1.0) -> void:
	var n := Registry.prop_mesh(PROPS_GLB, name_)
	if n:
		world.add_child(n)
		n.position = pos
		n.rotation.y = rot_y
		n.scale = Vector3.ONE * sc

func _build_world() -> void:
	world = Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.5, 0.95); sm.sky_horizon_color = Color(0.75, 0.88, 1.0)
	sm.ground_horizon_color = Color(0.75, 0.88, 1.0); sm.ground_bottom_color = Color(0.6, 0.7, 0.85)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY; e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true; e.fog_light_color = Color(0.85, 0.92, 1.0); e.fog_density = 0.0025
	e.glow_enabled = true; e.glow_intensity = 0.3
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 28, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = DisplayServer.get_name() != "headless"
	world.add_child(sun)
	# snow ground
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(160, 160)
	ground.mesh = pm
	ground.material_override = _mat("res://assets/textures/snow_day_albedo.png", Color(0.78, 0.83, 0.92), 0.25)
	world.add_child(ground)
	# finish-area dressing from the authored prop library
	_prop("gate_arch", Vector3(0, 0, -7.5), 0.0, 1.0)
	for i in 7:
		_prop(["tree_pine_a", "tree_pine_b"][i % 2], Vector3(-15 + i * 5.0, 0, -16 - (i % 3) * 3.0), i * 0.7, 1.0 + (i % 3) * 0.15)
	_prop("snowbank_0", Vector3(-7.5, 0, -3), 0.4)
	_prop("snowbank_2", Vector3(7.5, 0, -3.5), -0.6)
	_prop("flag_0", Vector3(-4.6, 0, 1.0))
	_prop("flag_1", Vector3(4.6, 0, 1.0))
	_prop("lantern_0", Vector3(-6.2, 0, -1.0))
	_prop("lantern_1", Vector3(6.2, 0, -1.0))
	# podium blocks: wood sides, snow tops, numbered fronts
	var heights := {1: 1.3, 2: 0.9, 3: 0.6}
	var xs := {1: 0.0, 2: -2.2, 3: 2.2}
	for place in [1, 2, 3]:
		var blk := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(2.0, heights[place], 1.8)
		blk.mesh = bm
		blk.material_override = _mat("res://assets/textures/wood_plank_albedo.png", [Color(1, 0.85, 0.45), Color(0.85, 0.88, 0.95), Color(0.95, 0.7, 0.5)][place - 1], 0.6)
		blk.position = Vector3(xs[place], heights[place] * 0.5, 0)
		world.add_child(blk)
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new(); cm.size = Vector3(2.1, 0.12, 1.9)
		cap.mesh = cm
		cap.material_override = _mat("res://assets/textures/snow_soft_albedo.png", Color.WHITE, 0.5)
		cap.position = Vector3(xs[place], heights[place] + 0.06, 0)
		world.add_child(cap)
		var num := Label3D.new()
		num.text = str(place)
		num.font_size = 160
		num.outline_size = 24
		num.modulate = [Color(1, 0.85, 0.2), Color(0.9, 0.92, 1), Color(1, 0.65, 0.4)][place - 1]
		num.position = Vector3(xs[place], heights[place] * 0.5, 0.92)
		world.add_child(num)
	# riders: top three on the podium, others beside it
	var side_x := [-5.0, 5.0, -6.5, 6.5]
	var k := 0
	for row in summary.rows:
		var p := int(row.place)
		var def := Registry.rider(StringName(row.rider))
		var holder := Node3D.new()
		world.add_child(holder)
		var model := (load(def.model_path) as PackedScene).instantiate() as Node3D
		holder.add_child(model)
		var board := Registry.board(StringName(row.board))
		var bn := Registry.prop_mesh(BOARDS_GLB, board.node_name) if board else null
		var target: Vector3
		if p <= 3 and summary.rows.size() > 1:
			target = Vector3(xs[p], heights[p] + 0.12, 0)
			if bn:
				bn.rotation = Vector3(0, 0, deg_to_rad(80))
				bn.position = Vector3(0.7, 0.8, -0.3)
				holder.add_child(bn)
		elif summary.rows.size() == 1:
			target = Vector3(0, heights[1] + 0.12, 0)
		else:
			target = Vector3(side_x[k % 4], 0, 1.2)
			k += 1
			if bn:
				holder.add_child(bn)
		holder.position = target + Vector3(0, -2.5, 0)   # rises into place
		holder.rotation.y = -target.x * 0.08
		_rise.append({"node": holder, "to": target, "delay": 0.4 + (3 - mini(p, 3)) * 0.35})
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			var clip := "victory" if (p <= 3 and summary.rows.size() > 1) or summary.rows.size() == 1 else "defeat"
			if ap.has_animation(clip):
				ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				ap.play(clip)
	# confetti
	var conf := GPUParticles3D.new()
	conf.amount = 220 if Game.quality() >= 1 else 90
	conf.lifetime = 4.0
	conf.position = Vector3(0, 7, 0)
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(7, 0.5, 3)
	ppm.gravity = Vector3(0, -1.6, 0)
	ppm.initial_velocity_min = 0.2; ppm.initial_velocity_max = 1.0
	ppm.angular_velocity_min = -180; ppm.angular_velocity_max = 180
	ppm.turbulence_enabled = true; ppm.turbulence_noise_strength = 0.6
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.35, 0.4)); grad.set_color(1, Color(0.3, 0.8, 1))
	grad.add_point(0.5, Color(1, 0.9, 0.3))
	var gt := GradientTexture1D.new(); gt.gradient = grad
	ppm.color_initial_ramp = gt
	conf.process_material = ppm
	var qm := QuadMesh.new(); qm.size = Vector2(0.12, 0.22)
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	if ResourceLoader.exists("res://assets/sprites/fx/confetti_strip.png"):
		cmat.albedo_texture = load("res://assets/sprites/fx/confetti_strip.png")
	qm.material = cmat
	conf.draw_pass_1 = qm
	world.add_child(conf)
	cam = Camera3D.new()
	cam.fov = 50
	world.add_child(cam)
	cam.current = true
	_place_cam()

func _place_cam() -> void:
	var a := sin(_t * 0.25) * 0.35
	cam.position = Vector3(sin(a) * 11.5 + 3.6, 3.2, cos(a) * 11.5)
	cam.look_at(Vector3(4.2, 1.5, 0), Vector3.UP)   # podium sits in the left half, beside the results panel

func _process(delta: float) -> void:
	_t += delta
	_place_cam()
	for r in _rise:
		var n: Node3D = r.node
		var k := clampf((_t - float(r.delay)) / 0.7, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		n.position = (r.to as Vector3) + Vector3(0, -2.5 * (1.0 - e) + sin(k * PI) * 0.4, 0)

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = load("res://assets/ui/theme.tres")
	ui.add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -860; panel.offset_right = -36; panel.offset_top = 36; panel.offset_bottom = -36
	root.add_child(panel)
	var v := UiKit.vbox(10)
	panel.add_child(v)
	var mode: int = int(summary.mode)
	var head := t("results")
	if mode == Game.Mode.GRAND_PRIX:
		var cup: Dictionary = Registry.CUPS[Game.cup_index]
		head = "%s — %d/%d" % [cup.name if Game.lang() != "en" else cup.name_en, Game.cup_race + 1, cup.tracks.size()]
	v.add_child(UiKit.title(head))
	var td := Registry.track(StringName(summary.track))
	v.add_child(UiKit.label(td.display_name if Game.lang() != "en" else td.display_name_en, 26, UiKit.ICE))
	# race table
	var grid := GridContainer.new()
	grid.columns = 5 if mode == Game.Mode.GRAND_PRIX else 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for row in summary.rows:
		var def := Registry.rider(StringName(row.rider))
		grid.add_child(UiKit.label(UiKit.place_text(int(row.place)), 34, [UiKit.GOLD, Color(0.9, 0.92, 1), Color(1, 0.65, 0.4), Color(0.8, 0.85, 0.95)][clampi(int(row.place) - 1, 0, 3)], true))
		var who := UiKit.hbox(8)
		who.add_child(UiKit.texture(def.portrait_path, Vector2(48, 48)))
		var nm := def.display_name + ("  (%s)" % t("player") if row.human else "")
		who.add_child(UiKit.label(nm, 26, Color.WHITE if row.human else Color(0.85, 0.9, 1)))
		who.custom_minimum_size = Vector2(300, 0)
		grid.add_child(who)
		grid.add_child(UiKit.label(UiKit.fmt_time(float(row.time)) if float(row.time) > 0 else t("dnf"), 26))
		grid.add_child(UiKit.label("★ %d" % int(row.tricks), 22, Color(0.6, 1, 0.9)))
		if mode == Game.Mode.GRAND_PRIX:
			grid.add_child(UiKit.label("+%d %s" % [int(summary.race_points.get(int(row.index), 0)), t("points")], 24, UiKit.GOLD))
	# mode specific
	match mode:
		Game.Mode.GRAND_PRIX:
			v.add_child(UiKit.label(t("final_standings") if summary.cup_done else t("standings"), 28, UiKit.ICE, true))
			for i in summary.standings.size():
				var pi := int(summary.standings[i][0])
				var part: Dictionary = Game.participants[pi] if pi < Game.participants.size() else {"rider": "niko", "type": "ai"}
				v.add_child(UiKit.label("%s  %s%s — %d %s" % [UiKit.place_text(i + 1), Registry.rider(StringName(part.rider)).display_name,
					"  (%s)" % t("player") if part.type == "human" else "", int(summary.standings[i][1]), t("points")], 24))
			v.add_child(UiKit.label("%s: +%d  (%s +%d)" % [t("race_credits"), int(summary.credits), t("trick_bonus"), int(summary.trick_bonus)], 22, UiKit.GOLD))
			v.add_child(UiKit.label("%s: %d" % [t("cup_total_credits"), Game.cup_credits_earned], 22, UiKit.GOLD))
			if summary.cup_done:
				_medal_row(v, int(summary.medal))
		Game.Mode.QUICK_RACE:
			v.add_child(UiKit.label("%s: +%d  (%s +%d)" % [t("race_credits"), int(summary.credits), t("trick_bonus"), int(summary.trick_bonus)], 24, UiKit.GOLD))
		Game.Mode.TIME_TRIAL:
			var me: Dictionary = summary.rows[0]
			v.add_child(UiKit.label("%s: %s" % [t("best"), UiKit.fmt_time(Save.record(String(summary.track), String(me.board)))], 26))
			if summary.record:
				v.add_child(UiKit.label(t("new_record"), 40, UiKit.GOLD, true))
		_:
			if String(summary.skill_kind) != "":
				var th: Array = Game.SKILL_THRESHOLDS[summary.skill_kind]
				var val := "%d" % int(summary.skill_value)
				var lab: String = {"trick": t("score"), "landing": t("landing"), "coins": t("coins"), "slalom_missed": t("gates"), "targets": t("targets_hit")}[summary.skill_kind]
				if summary.skill_kind == "targets":
					val = "%d/%d" % [int(summary.rows[0].get("targets", 0)), int(summary.rows[0].get("targets_total", 0))]
				if summary.skill_kind == "slalom_missed":
					var me2: Dictionary = summary.rows[0]
					val = "%d/%d  (%s)" % [int(me2.gates), int(me2.gates) + int(me2.missed), UiKit.fmt_time(float(me2.time) + int(me2.missed) * 2.0)]
				v.add_child(UiKit.label("%s: %s" % [lab, val], 30, Color.WHITE, true))
				v.add_child(UiKit.label("%s: %s" % [t("thresholds"), " / ".join(th.map(func(x): return str(x)))], 22))
				if summary.record:
					v.add_child(UiKit.label(t("new_record"), 34, UiKit.GOLD, true))
				_medal_row(v, int(summary.medal))
	for u in summary.unlocks:
		var ur := UiKit.hbox(10)
		ur.add_child(UiKit.texture("res://assets/sprites/ui/unlock.png", Vector2(40, 40)))
		ur.add_child(UiKit.label("%s: %s" % [t("unlocked"), _unlock_name(String(u))], 28, Color(0.5, 1, 0.6), true))
		v.add_child(ur)
	v.add_child(UiKit.label("%s: %d" % [t("your_credits"), Save.credits()], 22, UiKit.GOLD))
	# actions
	var h := UiKit.hbox(16)
	v.add_child(h)
	var first: Button
	if mode == Game.Mode.GRAND_PRIX and not summary.cup_done:
		first = UiKit.button(t("next_race"), Game.next_cup_race, 340)
		h.add_child(first)
	elif mode != Game.Mode.GRAND_PRIX:
		first = UiKit.button(t("retry"), Game.goto_race, 300)
		h.add_child(first)
	var menu := UiKit.button(t("to_menu"), func(): Game.goto_menu("main"), 300)
	h.add_child(menu)
	(first if first else menu).grab_focus.call_deferred()

func _medal_row(v: VBoxContainer, m: int) -> void:
	var r := UiKit.hbox(12)
	r.add_child(UiKit.medal_icon(m, 64))
	r.add_child(UiKit.label(t(["failed", "medal_bronze", "medal_silver", "medal_gold"][clampi(m, 0, 3)]), 34, UiKit.GOLD if m > 0 else Color(1, 0.6, 0.5), true))
	v.add_child(r)

func _unlock_name(u: String) -> String:
	var p := u.split(":")
	match p[0]:
		"cup":
			var c: Dictionary = Registry.CUPS[int(p[1]) - 1]
			return c.name if Game.lang() != "en" else c.name_en
		"rider":
			return Registry.rider(StringName(p[1])).display_name
		"board":
			return Registry.board(StringName(p[1])).display_name
	return u
