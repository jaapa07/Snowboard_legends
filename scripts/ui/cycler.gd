class_name Cycler
extends Button
## Focusable option selector: ui_left / ui_right (keyboard, d-pad, stick) or click cycles through values.

signal changed(index: int)

var caption: String = ""
var options: PackedStringArray = PackedStringArray()
var index: int = 0

func setup(caption_: String, options_: PackedStringArray, start: int, min_w: float = 520.0) -> Cycler:
	caption = caption_
	options = options_
	index = clampi(start, 0, maxi(0, options.size() - 1))
	custom_minimum_size = Vector2(min_w, 56)
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	pressed.connect(func(): step(1))
	focus_entered.connect(func(): Audio.play("ui_move", -6.0))
	mouse_entered.connect(func(): grab_focus())
	_refresh()
	return self

func step(d: int) -> void:
	if options.is_empty() or disabled:
		return
	index = posmod(index + d, options.size())
	Audio.play("ui_move")
	_refresh()
	changed.emit(index)

func set_index(i: int) -> void:
	index = clampi(i, 0, options.size() - 1)
	_refresh()

func set_enabled(on: bool) -> void:
	disabled = not on
	_refresh()

func _refresh() -> void:
	var v := options[index] if index < options.size() else ""
	if disabled:
		text = "%s:   —" % caption if caption != "" else "—"
		return
	text = "%s:   ◀  %s  ▶" % [caption, v] if caption != "" else "◀  %s  ▶" % v

func _gui_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left"):
		step(-1)
		accept_event()
	elif e.is_action_pressed("ui_right"):
		step(1)
		accept_event()
