class_name CarveTrail
extends MeshInstance3D
## Double carving trail (two board edges) laid on the snow, fading with age. Pooled ring buffer of points.

const MAX_POINTS := 70
const SPACING := 0.6
const LIFETIME := 3.5
const HALF_GAP := 0.13
const WIDTH := 0.07

var rider: RiderController
var _pts: Array[Dictionary] = []   ## {p: Vector3, r: Vector3, n: Vector3, t: float, on: bool}
var _im: ImmediateMesh

func _ready() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true   # lit like the snow: no glowing white lines at night
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m

func _process(delta: float) -> void:
	if rider == null:
		return
	for p in _pts:
		p.t += delta
	while _pts.size() > 0 and _pts[0].t > LIFETIME:
		_pts.pop_front()
	var on := rider.state == RiderController.State.GROUND and rider.speed > 3.0
	var here := rider.global_position + rider.ground_n * 0.04
	if _pts.is_empty() or _pts[-1].p.distance_to(here) > SPACING:
		var f := rider.forward_dir()
		var r := f.cross(rider.ground_n).normalized()
		_pts.append({"p": here, "r": r, "n": rider.ground_n, "t": 0.0, "on": on})
		if _pts.size() > MAX_POINTS:
			_pts.pop_front()
	_rebuild()

func _rebuild() -> void:
	_im.clear_surfaces()
	if _pts.size() < 2:
		return
	var tint := Color(0.62, 0.72, 0.9) if rider.surface != "ice" else Color(0.9, 0.97, 1.0)
	for side in [-1.0, 1.0]:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for p in _pts:
			var a := 0.0 if not p.on else clampf(1.0 - p.t / LIFETIME, 0.0, 1.0) * 0.55
			var c := Color(tint.r, tint.g, tint.b, a)
			var center: Vector3 = p.p + p.r * HALF_GAP * side
			_im.surface_set_color(c)
			_im.surface_add_vertex(center - p.r * WIDTH)
			_im.surface_set_color(c)
			_im.surface_add_vertex(center + p.r * WIDTH)
		_im.surface_end()
