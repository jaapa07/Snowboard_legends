extends Node
## Debug: one rider without input on Vale dos Pinheiros; prints physics state.
var r: RiderController
var tr: TrackRuntime
var f := 0
func _ready() -> void:
	tr = TrackRuntime.new()
	add_child(tr)
	tr.setup(load("res://resources/tracks/vale_pinheiros.tres"), 0, false)
	r = RiderController.new()
	add_child(r)
	r.setup(0, load("res://resources/riders/niko.tres"), load("res://resources/boards/starter.tres"), tr, null, false, "")
	r.place_at(tr.spawn_points[0], tr.fwd[10])
func _physics_process(_d: float) -> void:
	f += 1
	if f % 30 == 0:
		print("f=%d pos=%s v=%s floor=%s n=%s yaw=%.2f st=%d" % [f, r.global_position.snapped(Vector3.ONE*0.1), r.velocity.snapped(Vector3.ONE*0.1), r.is_on_floor(), r.get_floor_normal().snapped(Vector3.ONE*0.01), r.yaw, r.state])
	if f > 240: get_tree().quit()
