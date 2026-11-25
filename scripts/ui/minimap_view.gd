class_name MinimapView
extends Control
## Top-down course outline with rider dots (drawn with Control draw calls — HUD only, not gameplay).

var race: RaceManager
var rider: RiderController
var _pts: PackedVector2Array = PackedVector2Array()
var _lo := Vector2.ZERO
var _span := 1.0

func setup(r: RaceManager, rd: RiderController) -> void:
	race = r; rider = rd
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := r.track
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for i in range(0, tr.pos.size(), 3):
		var p := Vector2(tr.pos[i].x, tr.pos[i].z)
		_pts.append(p)
		lo = lo.min(p); hi = hi.max(p)
	_lo = lo
	_span = maxf(hi.x - lo.x, hi.y - lo.y)

func _map(p: Vector3) -> Vector2:
	var s := size.x * 0.86
	var off := Vector2(size.x * 0.07, size.y * 0.07)
	return off + (Vector2(p.x, p.z) - _lo) / _span * s

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.07, 0.18, 0.45), true)
	var pl := PackedVector2Array()
	for p in _pts:
		pl.append(_map(Vector3(p.x, 0, p.y)))
	draw_polyline(pl, Color(1, 1, 1, 0.85), 5.0, true)
	draw_polyline(pl, Color(0.55, 0.75, 1.0, 0.9), 2.5, true)
	for st in race.track.stations:
		draw_circle(_map(st.p), 3.0, Color(1, 0.35, 0.35) if st.slot == "offense" else Color(0.35, 0.6, 1))
	for r in race.riders:
		var c: Color = r.def.color
		var rad := 6.0 if r == rider else 4.5
		draw_circle(_map(r.global_position), rad + 1.5, Color.WHITE if r == rider else Color(0, 0, 0, 0.7))
		draw_circle(_map(r.global_position), rad, c)
