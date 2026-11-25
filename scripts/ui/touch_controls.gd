class_name TouchControls
extends Control
## On-screen controls for phones/tablets (device "touch"). Multi-touch:
## - left half: floating thumb-stick that appears under the thumb (left/right steers; push up = tuck, pull down = brake)
##   or, with tilt steering on, the device accelerometer steers and the left half only does tuck/brake;
## - right side: JUMP (hold to charge, release to jump), GRAB, two SPIN buttons, offensive and utility item buttons
##   (showing the held item's icon), and a PAUSE button. Everything stays inside the display safe area (notch).
## InputRouter reads TouchControls.state for device "touch"; physics never sees the UI.

signal pause_pressed

static var state := {"steer": 0.0, "tuck": false, "brake": false, "jump": false, "spin_l": false, "spin_r": false,
	"grab": false, "off": false, "util": false}
static var tilt_steering: bool = false

const STICK_R := 110.0
var rider: RiderController
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _buttons: Array[Dictionary] = []      ## {id, center, r, label, col, touch}
var _safe := Rect2()
var _font: Font

static func safe_rect(vs: Vector2) -> Rect2:
	## Usable area in viewport units. Browsers report screen and safe area in different units (CSS vs device
	## pixels), which pushed the buttons off-screen on iPhone Safari: on the web use the whole canvas with a
	## notch-sized margin; elsewhere trust the OS safe area only when it is plausible.
	var full := Rect2(Vector2.ZERO, vs)
	if OS.has_feature("web"):
		return full.grow_individual(-vs.x * 0.04, -vs.y * 0.02, -vs.x * 0.04, -vs.y * 0.03)
	var screen := DisplayServer.screen_get_size()
	var sa := DisplayServer.get_display_safe_area()
	if screen.x <= 0 or screen.y <= 0 or sa.size.x <= 0:
		return full
	var k := vs / Vector2(screen)
	var r := Rect2(Vector2(sa.position) * k, Vector2(sa.size) * k)
	if r.size.x < vs.x * 0.6 or r.size.y < vs.y * 0.6 or not full.grow(2.0).encloses(r):
		return full
	return r

static func reset_state() -> void:
	for k in state:
		state[k] = 0.0 if k == "steer" else false

static func enabled() -> bool:
	## Touch UI on phones/tablets, on touchscreens, or when forced (Options / --touch).
	if "--touch" in OS.get_cmdline_user_args():
		return true
	var s: Dictionary = Save.settings()
	var mode := String(s.get("touch_controls", "auto"))
	if mode == "on":
		return true
	if mode == "off":
		return false
	return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android") or DisplayServer.is_touchscreen_available()

func setup(r: RiderController) -> void:
	rider = r
	tilt_steering = bool(Save.settings().get("tilt_steering", false))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Inter-Black.otf")
	reset_state()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var vs := get_viewport_rect().size
	_safe = TouchControls.safe_rect(vs)
	var m := 28.0
	var br := Vector2(_safe.end.x - m, _safe.end.y - m)
	var u := clampf(vs.y / 900.0, 0.6, 1.6) * 1.0
	_buttons = [
		{"id": "jump", "c": br + Vector2(-130, -130) * u, "r": 92.0 * u, "label": "SALTO" if Game.lang() != "en" else "JUMP", "col": Color(0.25, 0.65, 1.0)},
		{"id": "grab", "c": br + Vector2(-330, -80) * u, "r": 62.0 * u, "label": "GRAB", "col": Color(0.95, 0.75, 0.2)},
		{"id": "spin_l", "c": br + Vector2(-310, -250) * u, "r": 52.0 * u, "label": "◀", "col": Color(0.6, 0.45, 1.0)},
		{"id": "spin_r", "c": br + Vector2(-150, -330) * u, "r": 52.0 * u, "label": "▶", "col": Color(0.6, 0.45, 1.0)},
		{"id": "off", "c": br + Vector2(-60, -440) * u, "r": 58.0 * u, "label": "", "col": Color(1.0, 0.3, 0.3)},
		{"id": "util", "c": br + Vector2(-210, -470) * u, "r": 58.0 * u, "label": "", "col": Color(0.3, 0.6, 1.0)},
		{"id": "pause", "c": Vector2(_safe.position.x + _safe.size.x * 0.5, _safe.position.y + 46 * u), "r": 36.0 * u, "label": "II", "col": Color(1, 1, 1)},
	]
	for b in _buttons:
		b["touch"] = -1
	queue_redraw()

func _button_at(p: Vector2) -> int:
	for i in _buttons.size():
		if p.distance_to(_buttons[i].c) <= float(_buttons[i].r) * 1.15:
			return i
	return -1

func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			var bi := _button_at(t.position)
			if bi >= 0:
				_buttons[bi].touch = t.index
				_press(String(_buttons[bi].id), true)
				get_viewport().set_input_as_handled()
			elif t.position.x < _safe.position.x + _safe.size.x * 0.5 and _stick_touch < 0:
				_stick_touch = t.index
				_stick_origin = t.position
				_stick_pos = t.position
				_update_stick()
				get_viewport().set_input_as_handled()
		else:
			if t.index == _stick_touch:
				_stick_touch = -1
				state.steer = 0.0; state.tuck = false; state.brake = false
			for b in _buttons:
				if int(b.touch) == t.index:
					b.touch = -1
					_press(String(b.id), false)
		queue_redraw()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _stick_touch:
			_stick_pos = d.position
			_update_stick()
			queue_redraw()
			get_viewport().set_input_as_handled()

func _update_stick() -> void:
	var v := (_stick_pos - _stick_origin) / STICK_R
	if v.length() > 1.0:
		v = v.normalized()
	if not tilt_steering:
		var x := v.x
		state.steer = 0.0 if absf(x) < 0.12 else signf(x) * (absf(x) - 0.12) / 0.88
	state.tuck = v.y < -0.45
	state.brake = v.y > 0.45

func _press(id: String, on: bool) -> void:
	match id:
		"jump": state.jump = on
		"grab": state.grab = on
		"spin_l": state.spin_l = on
		"spin_r": state.spin_r = on
		"off": state.off = on
		"util": state.util = on
		"pause":
			if on:
				pause_pressed.emit()
	if on and id != "pause" and bool(Save.settings().get("vibration", true)):
		Input.vibrate_handheld(12)

func _process(_delta: float) -> void:
	if tilt_steering:
		var a := Input.get_accelerometer()   # landscape: lateral tilt reads on Y
		var x := clampf(a.y / 4.0, -1.0, 1.0)
		state.steer = 0.0 if absf(x) < 0.1 else x
	queue_redraw()

func _draw() -> void:
	var u := clampf(get_viewport_rect().size.y / 900.0, 0.6, 1.6)
	# thumb-stick
	if _stick_touch >= 0:
		draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		var k := (_stick_pos - _stick_origin).limit_length(STICK_R)
		draw_circle(_stick_origin + k, 46 * u, Color(1, 1, 1, 0.45))
	else:
		var hint := Vector2(_safe.position.x + 200 * u, _safe.end.y - 180 * u)
		draw_arc(hint, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.18), 3.0)
		draw_string(_font, hint + Vector2(-70, 8) * u, "◀  ▶" if not tilt_steering else "▲ / ▼", HORIZONTAL_ALIGNMENT_CENTER, 140 * u, int(28 * u), Color(1, 1, 1, 0.35))
	for b in _buttons:
		var pressed := int(b.touch) >= 0
		var col: Color = b.col
		draw_circle(b.c, b.r, Color(col.r, col.g, col.b, 0.55 if pressed else 0.28))
		draw_arc(b.c, b.r, 0, TAU, 40, Color(1, 1, 1, 0.85 if pressed else 0.55), 4.0)
		var tex: Texture2D = null
		if rider and String(b.id) == "off" and rider.offense_item != &"":
			tex = Registry.item_texture(rider.offense_item)
		elif rider and String(b.id) == "util" and rider.utility_item != &"":
			tex = Registry.item_texture(rider.utility_item)
		if tex:
			var s := float(b.r) * 1.3
			draw_texture_rect(tex, Rect2(b.c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		elif String(b.label) != "":
			var fs := int(float(b.r) * (0.42 if String(b.label).length() > 2 else 0.8))
			draw_string(_font, b.c + Vector2(-b.r, fs * 0.36), String(b.label), HORIZONTAL_ALIGNMENT_CENTER, b.r * 2.0, fs, Color(1, 1, 1, 0.95))
		if String(b.id) == "jump" and rider and rider.jump_charge > 0.0:
			draw_arc(b.c, float(b.r) + 8, -PI / 2, -PI / 2 + TAU * clampf(rider.jump_charge / rider.tuning.jump_charge_max, 0, 1), 40, Color(1, 0.9, 0.3), 7.0)
