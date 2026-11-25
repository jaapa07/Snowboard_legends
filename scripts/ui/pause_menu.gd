class_name PauseMenu
extends Control
## Pause overlay: continue, restart, options (volumes), main menu. Keyboard/gamepad navigable with visible focus.

signal closed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.15, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -180)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var t := Label.new()
	t.text = Game.t("pause")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	box.add_child(t)
	var first := _btn(box, Game.t("continue"), _resume)
	_btn(box, Game.t("restart"), func(): get_tree().paused = false; Game.goto_race())
	_btn(box, Game.t("to_menu"), func(): get_tree().paused = false; Game.goto_menu())
	first.grab_focus()
	Audio.play("ui_open")

func _btn(parent: Control, txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(420, 84 if TouchControls.enabled() else 64)   # finger-sized on phones
	b.pressed.connect(func(): Audio.play("ui_ok"); cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move"))
	parent.add_child(b)
	return b

func _resume() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()
