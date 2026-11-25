class_name LiftSystem
extends RefCounted
## Return lift: strict FIFO, capacity 1 per cabin, a cabin departs every DEPART_INTERVAL seconds,
## the ride lasts RIDE_TIME seconds. Riders are invulnerable while queued and riding.
## Pure logic (no nodes) so it is unit-testable; RaceManager moves the visuals.

const DEPART_INTERVAL := 1.2
const RIDE_TIME := 3.0

var queue: Array = []        ## rider ids in arrival order
var riding: Array = []       ## [{id, t}]
var _since_depart: float = 999.0
var skip_animation: bool = false   ## only allowed for solo training modes

func enqueue(id) -> int:
	if id in queue:
		return queue.find(id)
	for r in riding:
		if r.id == id:
			return -1
	queue.append(id)
	return queue.size() - 1

func position_in_queue(id) -> int:
	return queue.find(id)

func is_busy(id) -> bool:
	if id in queue:
		return true
	for r in riding:
		if r.id == id:
			return true
	return false

func ride_progress(id) -> float:
	for r in riding:
		if r.id == id:
			return clampf(r.t / RIDE_TIME, 0.0, 1.0)
	return -1.0

func tick(delta: float) -> Array:
	## Advances the lift. Returns ids that arrived at the top during this tick (in order).
	var arrived: Array = []
	_since_depart += delta
	if skip_animation:
		while queue.size() > 0:
			arrived.append(queue.pop_front())
		return arrived
	if queue.size() > 0 and _since_depart >= DEPART_INTERVAL:
		riding.append({"id": queue.pop_front(), "t": 0.0})
		_since_depart = 0.0
	for i in range(riding.size() - 1, -1, -1):
		riding[i].t += delta
	var keep: Array = []
	for r in riding:
		if r.t >= RIDE_TIME:
			arrived.append(r.id)
		else:
			keep.append(r)
	riding = keep
	return arrived
