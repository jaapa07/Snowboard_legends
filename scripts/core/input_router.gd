extends Node
## Registers input actions, persists remaps, and builds InputCommands per local device.
## Devices: "kb" (full keyboard), "kb_left" (WASD group), "kb_right" (arrows/numpad group), "joy0".."joy3".

const DEADZONE := 0.15
const ACTIONS := {
	"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT], "tuck": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE], "spin_left": [KEY_Q], "spin_right": [KEY_E], "grab": [KEY_SHIFT], "item_offense": [KEY_F], "item_utility": [KEY_R],
	"pause": [KEY_ESCAPE],
}
## Split keyboard layouts for 2 players on one keyboard.
const KB_LEFT := {"steer_left": KEY_A, "steer_right": KEY_D, "tuck": KEY_W, "brake": KEY_S, "jump": KEY_SPACE, "spin_left": KEY_Q,
	"spin_right": KEY_E, "grab": KEY_SHIFT, "item_offense": KEY_F, "item_utility": KEY_R}
const KB_RIGHT := {"steer_left": KEY_LEFT, "steer_right": KEY_RIGHT, "tuck": KEY_UP, "brake": KEY_DOWN, "jump": KEY_KP_0, "spin_left": KEY_KP_4,
	"spin_right": KEY_KP_6, "grab": KEY_KP_5, "item_offense": KEY_KP_1, "item_utility": KEY_KP_2}

var vibration_enabled: bool = true
var _prev_items: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, DEADZONE)
		for k in ACTIONS[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	_add_joy("jump", JOY_BUTTON_A); _add_joy("grab", JOY_BUTTON_X); _add_joy("item_offense", JOY_BUTTON_Y)
	_add_joy("item_utility", JOY_BUTTON_B); _add_joy("spin_left", JOY_BUTTON_LEFT_SHOULDER); _add_joy("spin_right", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy("pause", JOY_BUTTON_START)
	# menu navigation by gamepad: D-pad + left stick move focus, A confirms, B goes back
	for pair in [["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN], ["ui_left", JOY_BUTTON_DPAD_LEFT],
			["ui_right", JOY_BUTTON_DPAD_RIGHT], ["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		_ensure_joy(pair[0], pair[1])
	for ax in [["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0], ["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = ax[1]; m.axis_value = ax[2]; m.device = -1
		if not InputMap.action_has_event(ax[0], m):
			InputMap.action_add_event(ax[0], m)
	# extra keyboard navigation for players resting on WASD
	for k in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A], ["ui_right", KEY_D]]:
		var ek := InputEventKey.new()
		ek.physical_keycode = k[1]
		if not InputMap.action_has_event(k[0], ek):
			InputMap.action_add_event(k[0], ek)

func _ensure_joy(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)

func _add_joy(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)

func apply_remaps(remaps: Dictionary) -> void:
	## remaps: action -> physical keycode (int). Replaces the first keyboard binding.
	for a in remaps:
		if not InputMap.has_action(a):
			continue
		# replace the primary key, keep the remaining alternatives (e.g. arrows) after it
		var keys: Array = []
		var others: Array = []
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				keys.append(ev)
			else:
				others.append(ev)
		InputMap.action_erase_events(a)
		if int(remaps[a]) > 0:   # <= 0: explicitly unbound (its key was taken by another action)
			var nk := InputEventKey.new()
			nk.physical_keycode = int(remaps[a])
			InputMap.action_add_event(a, nk)
		for i in range(1, keys.size()):
			if (keys[i] as InputEventKey).physical_keycode != int(remaps[a]):
				InputMap.action_add_event(a, keys[i])
		for ev in others:
			InputMap.action_add_event(a, ev)

func current_key_map() -> Dictionary:
	## Primary keyboard key per action (0 = unbound); persisted as settings.remaps.
	var out := {}
	for a in ACTIONS:
		var k := 0
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				k = (ev as InputEventKey).physical_keycode
				break
		out[a] = k
	return out

func reset_keyboard_defaults() -> void:
	## Restores the default keyboard bindings (gamepad bindings are untouched).
	for a in ACTIONS:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				InputMap.action_erase_event(a, ev)
		for k in ACTIONS[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

func remap(action: String, keycode: int) -> void:
	## Rebinds the primary key of an action and drops that key from other actions to avoid conflicts.
	for a in ACTIONS:
		if a == action:
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == keycode:
				InputMap.action_erase_event(a, ev)
	apply_remaps({action: keycode})

func key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "-"

func connected_devices() -> Array[String]:
	var out: Array[String] = ["kb"]
	for j in Input.get_connected_joypads():
		out.append("joy%d" % j)
	return out

func read(device: String, cmd: InputCommand) -> void:
	cmd.clear()
	var off := false
	var util := false
	if device == "kb":
		cmd.steer = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
		cmd.tuck = Input.is_action_pressed("tuck"); cmd.brake = Input.is_action_pressed("brake")
		cmd.jump_held = Input.is_action_pressed("jump"); cmd.spin_left = Input.is_action_pressed("spin_left")
		cmd.spin_right = Input.is_action_pressed("spin_right"); cmd.grab = Input.is_action_pressed("grab")
		off = Input.is_action_pressed("item_offense"); util = Input.is_action_pressed("item_utility")
	elif device == "kb_left" or device == "kb_right":
		var m: Dictionary = KB_LEFT if device == "kb_left" else KB_RIGHT
		cmd.steer = (1.0 if Input.is_physical_key_pressed(m.steer_right) else 0.0) - (1.0 if Input.is_physical_key_pressed(m.steer_left) else 0.0)
		cmd.tuck = Input.is_physical_key_pressed(m.tuck); cmd.brake = Input.is_physical_key_pressed(m.brake)
		cmd.jump_held = Input.is_physical_key_pressed(m.jump); cmd.spin_left = Input.is_physical_key_pressed(m.spin_left)
		cmd.spin_right = Input.is_physical_key_pressed(m.spin_right); cmd.grab = Input.is_physical_key_pressed(m.grab)
		off = Input.is_physical_key_pressed(m.item_offense); util = Input.is_physical_key_pressed(m.item_utility)
	elif device.begins_with("joy"):
		var d := int(device.substr(3))
		var x := Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
		cmd.steer = 0.0 if absf(x) < DEADZONE else signf(x) * (absf(x) - DEADZONE) / (1.0 - DEADZONE)
		cmd.tuck = Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.4
		cmd.brake = Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.4
		cmd.jump_held = Input.is_joy_button_pressed(d, JOY_BUTTON_A)
		cmd.spin_left = Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER)
		cmd.spin_right = Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER)
		cmd.grab = Input.is_joy_button_pressed(d, JOY_BUTTON_X)
		off = Input.is_joy_button_pressed(d, JOY_BUTTON_Y); util = Input.is_joy_button_pressed(d, JOY_BUTTON_B)
	# airborne flips reuse tuck/brake (W = frontflip, S = backflip) — resolved by the rider when in the air
	cmd.flip_front = cmd.tuck
	cmd.flip_back = cmd.brake
	var prev: Array = _prev_items.get(device, [false, false])
	cmd.use_offense = off and not prev[0]
	cmd.use_utility = util and not prev[1]
	_prev_items[device] = [off, util]

func rumble(device: String, strength: float, duration: float) -> void:
	if vibration_enabled and device.begins_with("joy"):
		Input.start_joy_vibration(int(device.substr(3)), strength * 0.5, strength, duration)
