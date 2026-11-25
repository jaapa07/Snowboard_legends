class_name UiKit
extends RefCounted
## Small factory for menu widgets that share the project theme. Every interactive widget is focusable
## (keyboard / gamepad) and plays UI sounds; the theme supplies the visible focus ring.

const FONT_BLACK := "res://assets/fonts/Inter-Black.otf"
const GOLD := Color(1, 0.84, 0.25)
const ICE := Color(0.55, 0.88, 1)
const MEDAL_TEX := ["", "res://assets/sprites/ui/medal_bronze.png", "res://assets/sprites/ui/medal_silver.png", "res://assets/sprites/ui/medal_gold.png"]

static func label(text: String, size: int = 26, col: Color = Color(0.95, 0.98, 1), heavy: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if heavy:
		l.add_theme_font_override("font", load(FONT_BLACK))
		l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	return l

static func title(text: String) -> Label:
	var l := label(text, 54, GOLD, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l

static func button(text: String, cb: Callable, min_w: float = 360.0, h: float = 60.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Audio.play("ui_ok"); cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -6.0))
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	return b

static func panel() -> PanelContainer:
	return PanelContainer.new()

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func stat_bar(name_: String, value: float, max_v: float, col: Color = ICE, width: float = 260.0) -> HBoxContainer:
	var row := hbox(10)
	var l := label(name_, 22)
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	var pb := ProgressBar.new()
	pb.max_value = max_v
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(width, 18)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(6)
	pb.add_theme_stylebox_override("fill", fill)
	row.add_child(pb)
	return row

static func texture(path: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	if path != "" and ResourceLoader.exists(path):
		t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	return t

static func medal_icon(m: int, size: float = 40.0) -> TextureRect:
	return texture(MEDAL_TEX[clampi(m, 0, 3)] if m > 0 else "", Vector2(size, size))

static func fmt_time(t: float) -> String:
	if t <= 0.0:
		return "--:--.--"
	return "%d:%02d.%02d" % [int(t) / 60, int(t) % 60, int(fmod(t, 1.0) * 100)]

static func place_text(p: int) -> String:
	return "%dº" % p
