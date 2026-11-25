class_name RaceHUD
extends Control
## Per-player HUD. Listens to rider/race signals; never touches physics.
## Vertical progress bar with 4 portraits (10 Hz, stable on ties), big position, lap x/5, coins, two item slots,
## speed, minimap, trick/combo popups, warnings and countdown.

var race: RaceManager
var rider: RiderController
var scale_f: float = 1.0
var lbl_pos: Label
var lbl_lap: Label
var lbl_speed: Label
var lbl_coins: Label
var lbl_center: Label
var lbl_trick: Label
var lbl_msg: Label
var lbl_timer: Label
var slot_off: TextureRect
var slot_util: TextureRect
var warn: Label
var bar: Control
var portraits: Dictionary = {}
var minimap: MinimapView
var fog_overlay: ColorRect
var slots: HBoxContainer
var _center_t: float = 0.0
var _trick_t: float = 0.0
var _msg_t: float = 0.0
var _tick: float = 0.0
var _last_place: int = 0

func setup(r: RaceManager, rd: RiderController, screens: int) -> void:
	race = r
	rider = rd
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale_f = 1.0 if screens == 1 else (0.75 if screens == 2 else 0.6)
	fog_overlay = ColorRect.new()
	fog_overlay.color = Color(0.85, 0.82, 0.95, 0.0)
	fog_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog_overlay)
	lbl_pos = _label(96, Color(1, 0.85, 0.2), Vector2(24, -150), Control.PRESET_BOTTOM_LEFT)
	lbl_lap = _label(34, Color.WHITE, Vector2(24, 18), Control.PRESET_TOP_LEFT)
	lbl_timer = _label(26, Color(0.9, 0.95, 1), Vector2(24, 62), Control.PRESET_TOP_LEFT)
	lbl_speed = _label(30, Color.WHITE, Vector2(-250, -70), Control.PRESET_BOTTOM_RIGHT)
	lbl_coins = _label(34, Color(1, 0.82, 0.2), Vector2(-250, -120), Control.PRESET_BOTTOM_RIGHT)
	lbl_center = _label(110, Color(1, 1, 1), Vector2(0, -60), Control.PRESET_CENTER)
	lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_trick = _label(36, Color(0.5, 1.0, 0.95), Vector2(0, 90), Control.PRESET_CENTER_TOP)
	lbl_trick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg = _label(32, Color(1, 0.6, 0.4), Vector2(0, 150), Control.PRESET_CENTER_TOP)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn = _label(40, Color(1, 0.3, 0.25), Vector2(0, -170), Control.PRESET_CENTER_BOTTOM)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.text = "⚠  !!!  ⚠"
	warn.visible = false
	# item slots (offense red frame, utility blue frame) with icon + key hint
	slots = HBoxContainer.new()
	slots.position = Vector2(230, 16) * scale_f
	slots.add_theme_constant_override("separation", int(12 * scale_f))
	add_child(slots)
	slot_off = _slot(slots, Color(1, 0.3, 0.3), "F / Y")
	slot_util = _slot(slots, Color(0.3, 0.6, 1), "R / B")
	# vertical progress bar
	bar = Control.new()
	bar.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	bar.offset_left = -70 * scale_f; bar.offset_right = -20 * scale_f; bar.offset_top = 90 * scale_f; bar.offset_bottom = -190 * scale_f
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var track_line := ColorRect.new()
	track_line.color = Color(1, 1, 1, 0.55)
	track_line.set_anchors_preset(Control.PRESET_CENTER)
	track_line.anchor_top = 0; track_line.anchor_bottom = 1
	track_line.offset_left = -4; track_line.offset_right = 4
	bar.add_child(track_line)
	for rr in race.riders:
		var tex := TextureRect.new()
		var pth := rr.def.portrait_path
		if ResourceLoader.exists(pth):
			tex.texture = load(pth)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(52, 52) * scale_f
		tex.size = tex.custom_minimum_size
		var frame := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = rr.def.color.darkened(0.2)
		sb.set_corner_radius_all(int(26 * scale_f))
		sb.border_color = Color.WHITE if rr == rider else Color(0, 0, 0, 0.6)
		sb.set_border_width_all(int((4 if rr == rider else 2) * scale_f))
		frame.add_theme_stylebox_override("panel", sb)
		frame.size = tex.size
		frame.add_child(tex)
		bar.add_child(frame)
		portraits[rr] = frame
	minimap = MinimapView.new()
	minimap.setup(race, rider)
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.custom_minimum_size = Vector2(210, 210) * scale_f
	minimap.size = minimap.custom_minimum_size
	minimap.position = Vector2(-310, -400) * scale_f
	add_child(minimap)
	if TouchControls.enabled() and screens == 1 and rider.device == "touch":
		_touch_layout()
	if screens > 1:
		var human_idx := race.riders.filter(func(x): return x.is_human).find(rider)
		var tag := _label(40, [Color(1, 0.5, 0.4), Color(0.4, 0.75, 1), Color(0.5, 1, 0.55), Color(1, 0.85, 0.3)][clampi(human_idx, 0, 3)], Vector2(-120, 18), Control.PRESET_TOP_RIGHT)
		tag.text = "%s%d" % [Game.t("player_short"), human_idx + 1]
	race.countdown.connect(_on_count)
	race.lap_changed.connect(_on_lap)
	race.rider_finished.connect(_on_finish)
	rider.trick_landed.connect(_on_trick)
	rider.message.connect(_on_msg)
	rider.got_hit.connect(_on_hit)
	rider.items_changed.connect(func(_r): _refresh_slots())
	_refresh_slots()

func _touch_layout() -> void:
	## Phone layout: the on-screen buttons own the bottom-right and the thumb-stick the bottom-left, so the HUD moves
	## to the top (minimap top-right, coins/speed beside it, position under the lap timer, progress bar on the left);
	## the item slots are shown on the item buttons themselves.
	slots.visible = false
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-250, 20)
	for l in [lbl_coins, lbl_speed]:
		l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_coins.position = Vector2(-470, 24)
	lbl_speed.position = Vector2(-470, 70)
	lbl_pos.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lbl_pos.position = Vector2(24, 100)
	bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar.offset_left = 20; bar.offset_right = 70; bar.offset_top = 230; bar.offset_bottom = -330

func _label(size: int, col: Color, pos: Vector2, preset: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(size * scale_f))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.2))
	l.add_theme_constant_override("outline_size", int(10 * scale_f))
	l.set_anchors_preset(preset)
	l.position += pos * scale_f
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if preset == Control.PRESET_CENTER or preset == Control.PRESET_CENTER_TOP or preset == Control.PRESET_CENTER_BOTTOM:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.size.x = 900 * scale_f
		l.position.x -= 450 * scale_f
	add_child(l)
	return l

func _slot(parent: Container, col: Color, hint: String) -> TextureRect:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(84, 84) * scale_f
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.2, 0.65)
	sb.border_color = col
	sb.set_border_width_all(int(4 * scale_f))
	sb.set_corner_radius_all(int(14 * scale_f))
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 8 * scale_f; t.offset_top = 8 * scale_f; t.offset_right = -8 * scale_f; t.offset_bottom = -8 * scale_f
	p.add_child(t)
	var k := Label.new()
	k.text = hint
	k.add_theme_font_size_override("font_size", int(14 * scale_f))
	k.position = Vector2(4, 86) * scale_f
	p.add_child(k)
	return t

func _refresh_slots() -> void:
	slot_off.texture = Registry.item_texture(rider.offense_item) if rider.offense_item != &"" else null
	slot_util.texture = Registry.item_texture(rider.utility_item) if rider.utility_item != &"" else null

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.1:   # 10 Hz HUD refresh
		_tick = 0.0
		_refresh()
	if _center_t > 0.0:
		_center_t -= delta
		lbl_center.modulate.a = clampf(_center_t * 2.0, 0, 1)
	if _trick_t > 0.0:
		_trick_t -= delta
		lbl_trick.modulate.a = clampf(_trick_t * 2.0, 0, 1)
	if _msg_t > 0.0:
		_msg_t -= delta
		lbl_msg.modulate.a = clampf(_msg_t * 2.0, 0, 1)
	warn.visible = race.items.incoming_for(rider) and int(Time.get_ticks_msec() / 150) % 2 == 0
	fog_overlay.color.a = lerpf(fog_overlay.color.a, 0.72 if rider.fog_t > 0.0 else 0.0, clampf(delta * 5.0, 0, 1))

func _refresh() -> void:
	var L := race.laps
	var lap_txt: String
	if race.mode == Game.Mode.TRICK_ATTACK or race.mode == Game.Mode.SKILL_LANDING:
		lap_txt = "%s  %d" % [Game.t("score"), rider.trick_points_total] if race.mode == Game.Mode.TRICK_ATTACK else "%s  %d" % [Game.t("landing"), race.landings_clean]
		lbl_timer.text = "%d:%02d" % [int(race.trick_time_left) / 60, int(race.trick_time_left) % 60]
	else:
		lap_txt = "%s %d/%d" % [Game.t("lap"), mini(rider.lap + 1, L), L]
		lbl_timer.text = _fmt(race.race_time)
		if race.mode == Game.Mode.SKILL_TARGETS:
			lbl_timer.text += "   %s %d/%d" % [Game.t("targets_hit"), race.targets_hit, race.targets.size()]
		if race.mode == Game.Mode.SKILL_SLALOM:
			lbl_timer.text += "   %s %d  ×%d" % [Game.t("gates"), race.gates_passed, race.gates_missed]
	lbl_lap.text = lap_txt
	var p := rider.place
	lbl_pos.text = "%d%s" % [p, ["º", "º", "º", "º"][clampi(p - 1, 0, 3)]]
	lbl_pos.visible = race.riders.size() > 1
	if _last_place != 0 and p < _last_place and race.phase == RaceManager.Phase.RACE:
		_show_msg(Game.t("overtake"), Color(0.5, 1, 0.6))
	_last_place = p
	lbl_speed.text = "%d km/h" % int(rider.speed * 3.6)
	lbl_coins.text = "● %d" % rider.race_coins
	# vertical progress: normalized progress within the whole race
	var h := bar.size.y
	var total := race.track.length * maxf(1.0, float(mini(L, 99)))
	if race.mode == Game.Mode.TRICK_ATTACK or race.mode == Game.Mode.SKILL_LANDING:
		total = race.track.length
	for rr in portraits:
		var fr: Control = portraits[rr]
		var t := clampf(fmod(rr.progress, total + 0.001) / total if total > 0 else 0.0, 0.0, 1.0)
		if rr.finished:
			t = 1.0
		var y := h - t * h - fr.size.y * 0.5
		fr.position = Vector2(bar.size.x * 0.5 - fr.size.x * 0.5, lerpf(fr.position.y, y, 0.5))
		fr.z_index = 10 if rr == rider else 0

func _fmt(t: float) -> String:
	return "%d:%02d.%02d" % [int(t) / 60, int(t) % 60, int(fmod(t, 1.0) * 100)]

func _show_center(txt: String, dur: float, col: Color = Color.WHITE) -> void:
	lbl_center.text = txt
	lbl_center.add_theme_color_override("font_color", col)
	_center_t = dur

func _show_msg(txt: String, col: Color) -> void:
	lbl_msg.text = txt
	lbl_msg.add_theme_color_override("font_color", col)
	_msg_t = 1.6

func _on_count(v: int) -> void:
	if v > 0:
		_show_center(str(v), 0.9, Color(1, 0.9, 0.3))
	else:
		_show_center(Game.t("go"), 1.2, Color(0.4, 1, 0.5))

func _on_lap(r: RiderController) -> void:
	if r != rider:
		return
	if r.lap == race.laps - 1:
		_show_center(Game.t("final_lap"), 1.8, Color(1, 0.4, 0.3))
	else:
		_show_center("%s %d" % [Game.t("lap"), r.lap + 1], 1.2)

func _on_finish(r: RiderController) -> void:
	if r == rider:
		_show_center(Game.t("finish") + "  %dº" % r.place, 3.0, Color(1, 0.85, 0.2))

func _on_trick(_r: RiderController, label: String, pts: int, coins: int, quality: String) -> void:
	var extra := "  " + Game.t("perfect") if quality == "perfect" else ""
	lbl_trick.text = "%s  +%d%s%s" % [label.to_upper(), pts, ("  ●+%d" % coins) if coins > 0 else "", extra]
	_trick_t = 2.0
	if quality == "perfect":
		Audio.play("perfect")

func _on_msg(_r: RiderController, key: String) -> void:
	var txt := Game.t(key) if key != "repair_hint" else ("Use o reparador durante uma queda" if Game.lang() != "en" else "Use the repair kit while fallen")
	_show_msg(txt, Color(1, 0.55, 0.4))

func _on_hit(_r: RiderController, kind: String, blocked: bool) -> void:
	_show_msg(("Escudo!" if Game.lang() != "en" else "Shielded!") if blocked else "!", Color(0.5, 0.9, 1) if blocked else Color(1, 0.4, 0.3))
	if not blocked and race.cameras.size() > 0:
		for c in race.cameras:
			if c.target == rider:
				c.add_shake(0.8)
