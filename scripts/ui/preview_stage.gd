class_name PreviewStage
extends SubViewportContainer
## Isolated 3D turntable (own World3D) used by rider select, board select and the garage:
## rotating rigged rider model with its board, or a board alone for inspection; confirm animation on pick.

const BOARDS_GLB := "res://assets/models/boards/boards.glb"

var vp: SubViewport
var turntable: Node3D
var cam: Camera3D
var spin_speed: float = 0.6
var _anim: AnimationPlayer
var _back_to_idle_t: float = 0.0
var _hop_t: float = 0.0
var _current_key: String = ""
var ped: MeshInstance3D

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.85, 1.0)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.6, 0.8, 1.0)
	vp.add_child(rim)
	# snow pedestal (menu stage dressing)
	ped = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.25; cyl.bottom_radius = 1.4; cyl.height = 0.3; cyl.radial_segments = 48
	ped.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.62, 0.72, 0.9)
	pm.roughness = 0.55
	pm.albedo_texture = load("res://assets/textures/cc0/snow_powder_albedo.jpg")
	pm.normal_enabled = true
	pm.normal_texture = load("res://assets/textures/cc0/snow_powder_normal.jpg")
	pm.uv1_scale = Vector3(2, 2, 2)
	ped.material_override = pm
	ped.position = Vector3(0, -0.15, 0)
	vp.add_child(ped)
	turntable = Node3D.new()
	vp.add_child(turntable)
	cam = Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	frame_rider()

func frame_rider() -> void:
	cam.look_at_from_position(Vector3(0, 1.35, 5.4), Vector3(0, 0.85, 0), Vector3.UP)
	if ped:
		ped.visible = true

func frame_board() -> void:
	cam.look_at_from_position(Vector3(0, 1.5, 2.6), Vector3(0, 0.45, 0), Vector3.UP)

func clear() -> void:
	for c in turntable.get_children():
		c.queue_free()
	_anim = null
	_current_key = ""

func show_rider(def: RiderDefinition, board: BoardDefinition, silhouette: bool = false) -> void:
	var key := "%s/%s/%s" % [def.id, board.id if board else &"", silhouette]
	if key == _current_key:
		return
	clear()
	_current_key = key
	frame_rider()
	var holder := Node3D.new()
	turntable.add_child(holder)
	var model := (load(def.model_path) as PackedScene).instantiate() as Node3D
	holder.add_child(model)
	if board:
		var b := Registry.prop_mesh(BOARDS_GLB, board.node_name)
		if b:
			holder.add_child(b)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim and _anim.has_animation("idle"):
		_anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
	if silhouette:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.07, 0.15)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for mi in holder.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = m

func show_board(board: BoardDefinition) -> void:
	var key := "board/%s" % board.id
	if key == _current_key:
		return
	clear()
	_current_key = key
	frame_board()
	var b := Registry.prop_mesh(BOARDS_GLB, board.node_name)
	if b:
		var tilt := Node3D.new()
		tilt.rotation_degrees = Vector3(0, 0, 0)
		tilt.position = Vector3(0, 0.25, 0)
		turntable.add_child(tilt)
		tilt.add_child(b)
		# stand the board up at an angle so deck art and base are both readable while it turns
		b.rotation_degrees = Vector3(-62, 0, 0)
		b.scale = Vector3.ONE * 1.5
	ped.visible = false

func confirm() -> void:
	## Pick feedback: the rider plays its own victory pose and the turntable hops.
	_hop_t = 0.5
	if _anim and _anim.has_animation("victory"):
		_anim.play("victory", 0.1)
		_back_to_idle_t = 1.6

func _process(delta: float) -> void:
	turntable.rotation.y += delta * spin_speed
	if _hop_t > 0.0:
		_hop_t -= delta
		turntable.position.y = sin((0.5 - _hop_t) / 0.5 * PI) * 0.25
	else:
		turntable.position.y = 0.0
	if _back_to_idle_t > 0.0:
		_back_to_idle_t -= delta
		if _back_to_idle_t <= 0.0 and _anim and _anim.has_animation("idle"):
			_anim.play("idle", 0.3)
