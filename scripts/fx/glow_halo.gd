class_name GlowHalo
extends MeshInstance3D
## Soft additive glow that always faces the camera: makes powers readable from the chase camera at speed
## (an icy snowball over white snow was nearly invisible). Cheap — one unshaded quad, no light — so it is used
## on phones too. Pulses gently; `flash()` gives a short bright burst (hits, pickups).

static var _tex: GradientTexture2D

var base_size: float = 1.0
var pulse: float = 0.12
var _t: float = 0.0
var _flash_t: float = 0.0

static func make(color: Color, size: float, pulse_amount: float = 0.12) -> GlowHalo:
	var h := GlowHalo.new()
	h.base_size = size
	h.pulse = pulse_amount
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	h.mesh = q
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.albedo_texture = _radial()
	m.albedo_color = color
	h.material_override = m
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return h

static func _radial() -> GradientTexture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 128
		_tex.height = 128
	return _tex

func set_color(c: Color) -> void:
	(material_override as StandardMaterial3D).albedo_color = c

func flash(dur: float = 0.35) -> void:
	_flash_t = dur

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var k := 1.0 + sin(_t * 7.0) * pulse
	if _flash_t > 0.0:
		_flash_t -= delta
		k += _flash_t * 3.0
	scale = Vector3.ONE * k
