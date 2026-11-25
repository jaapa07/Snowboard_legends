class_name InputCommand
extends RefCounted
## One frame of rider intent. Produced identically by humans (InputRouter) and AI (AIDriver).

var steer: float = 0.0          ## -1 left .. +1 right
var tuck: bool = false
var brake: bool = false
var jump_held: bool = false
var spin_left: bool = false
var spin_right: bool = false
var grab: bool = false
var flip_front: bool = false
var flip_back: bool = false
var use_offense: bool = false   ## edge-triggered
var use_utility: bool = false   ## edge-triggered

func copy_from(o: InputCommand) -> void:
	steer = o.steer; tuck = o.tuck; brake = o.brake; jump_held = o.jump_held
	spin_left = o.spin_left; spin_right = o.spin_right; grab = o.grab
	flip_front = o.flip_front; flip_back = o.flip_back
	use_offense = o.use_offense; use_utility = o.use_utility

func clear() -> void:
	steer = 0.0; tuck = false; brake = false; jump_held = false; spin_left = false; spin_right = false
	grab = false; flip_front = false; flip_back = false; use_offense = false; use_utility = false
