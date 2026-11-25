class_name MainMenu
extends Node
## Front end: title over a live 3D course, modes, 4-slot participant setup with device choice, rider select
## (rotating rigged model + confirm animation), board select, course select with illustrated map, cup select,
## skill games, garage/shop, profile/save, options with remapping. Fully keyboard/gamepad navigable
## (ui_* actions; the theme draws a visible focus ring). ui_cancel goes back one screen.

const KEY_ACTIONS := ["steer_left", "steer_right", "tuck", "brake", "jump", "spin_left", "spin_right", "grab", "item_offense", "item_utility", "pause"]
const ACTION_LABEL := {"jump": "jump_act", "pause": "pause_act"}
const LOCK_TEX := preload("res://assets/sprites/ui/lock.png")

var backdrop: MenuBackdrop
var ui: CanvasLayer
var root: Control
var content: MarginContainer
var footer: Label
var toast: Label
var loading: Control
var stage: PreviewStage
var screen: String = ""
var history: Array[String] = []
var _toast_t: float = 0.0
var _capture_action: String = ""
var _capture_btn: Button

# setup flow state
var flow_mode: int = Game.Mode.QUICK_RACE
var slots: Array[Dictionary] = []      ## {type: "human"/"ai"/"empty", device}
var pick_index: int = 0                ## which human is choosing
var picks: Array[Dictionary] = []      ## per human {rider, board}
var quick := {"laps": 0, "difficulty": 1, "items": true}   ## laps 0 = the course's own number of descents
var garage_filter: int = 0
var _back_btn: Button

func _safe_inset() -> Vector2:
	## Top/side inset of the display safe area (notch / Dynamic Island) in viewport units.
	return TouchControls.safe_rect(get_viewport().get_visible_rect().size).position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop = MenuBackdrop.new()
	add_child(backdrop)
	backdrop.setup(&"vale_pinheiros", ["niko", "mika", "taro"])
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = load("res://assets/ui/theme.tres")
	ui.add_child(root)
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.05, 0.16, 0.82)); g.set_color(1, Color(0.02, 0.05, 0.16, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0.75, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(shade)
	content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 56)
	content.add_theme_constant_override("margin_bottom", 70)
	root.add_child(content)
	footer = UiKit.label("", 20, Color(0.8, 0.9, 1))
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -46; footer.offset_left = 56
	root.add_child(footer)
	toast = UiKit.label("", 30, UiKit.GOLD, true)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.offset_top = 24; toast.offset_left = -500; toast.offset_right = 500
	toast.modulate.a = 0.0
	root.add_child(toast)
	stage = PreviewStage.new()
	Audio.play_music("res://assets/audio/music/menu.ogg")
	var start: String = String(Game.get_meta("menu_screen", "title")) if Game.has_meta("menu_screen") else "title"
	if start in ["participants", "rider", "board", "track", "cup"]:
		# direct entry (evidence captures / tests): prepare a race-setup flow with the default slots
		flow_mode = Game.Mode.GRAND_PRIX if start == "cup" else Game.Mode.QUICK_RACE
		slots = [{"type": "human", "device": "kb"}, {"type": "ai", "device": ""}, {"type": "ai", "device": ""}, {"type": "ai", "device": ""}]
		picks = [{"rider": String(Save.profile().equipped.rider), "board": String(Save.profile().equipped.board)}]
		history.append("main")
	if Game.has_meta("menu_screen"):
		Game.remove_meta("menu_screen")
	if Save.last_error != "":
		show_toast(Save.last_error)
	go(start, false)

func t(k: String) -> String:
	return Game.t(k)

# ---------------------------------------------------------------- navigation
func go(name_: String, push: bool = true) -> void:
	if push and screen != "":
		history.append(screen)
	screen = name_
	_build()

func back() -> void:
	if _capture_action != "":
		return
	if history.is_empty():
		if screen != "title":
			go("title", false)
		return
	Audio.play("ui_back")
	screen = history.pop_back()
	# leaving a per-player pick screen walks back through players
	_build()

func _build() -> void:
	if stage.get_parent():
		stage.get_parent().remove_child(stage)
	for c in content.get_children():
		c.queue_free()
	footer.text = "↑↓←→ / D-pad: %s    Enter / A: %s    Esc / B: %s" % (["navegar", "confirmar", "voltar"] if Game.lang() != "en" else ["navigate", "confirm", "back"])
	if TouchControls.enabled():
		footer.text = t("touch_footer")
	var ins := _safe_inset()
	content.add_theme_constant_override("margin_left", int(56 + ins.x))
	content.add_theme_constant_override("margin_top", int(56 + ins.y))
	var focus: Control = call("_screen_" + screen)
	if focus:
		focus.grab_focus.call_deferred()
	if _back_btn:
		_back_btn.queue_free()
		_back_btn = null
	if TouchControls.enabled() and screen != "title":
		# phones have no Esc / B: an on-screen back button inside the safe area
		_back_btn = UiKit.button("◀ " + t("back"), back, 220, 72)
		_back_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_back_btn.position = Vector2(get_viewport().get_visible_rect().size.x - 260 - _safe_inset().x, 24 + _safe_inset().y)
		root.add_child(_back_btn)

func show_toast(msg: String, col: Color = UiKit.GOLD) -> void:
	toast.text = msg
	toast.add_theme_color_override("font_color", col)
	_toast_t = 2.4

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)

func _unhandled_input(e: InputEvent) -> void:
	if loading:
		return
	if screen == "title" and (e.is_action_pressed("ui_accept") or (e is InputEventJoypadButton and e.pressed and (e as InputEventJoypadButton).button_index == JOY_BUTTON_START)):
		Audio.play("ui_open")
		go("main")
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()

func _input(e: InputEvent) -> void:
	if screen == "participants" and e is InputEventJoypadButton and e.pressed and (e as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		if _try_join("joy%d" % e.device):
			get_viewport().set_input_as_handled()
		return
	if _capture_action == "":
		return
	if e is InputEventKey and e.pressed and not e.echo:
		get_viewport().set_input_as_handled()
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_ESCAPE:
			_capture_action = ""
			_build()
			return
		Inputs.remap(_capture_action, k)
		Save.settings().remaps = Inputs.current_key_map()
		Save.write()
		var a := _capture_action
		_capture_action = ""
		_build()
		show_toast("%s → %s" % [t(ACTION_LABEL.get(a, a)), OS.get_keycode_string(k)])

# ---------------------------------------------------------------- layout helpers
func _two_columns(title_text: String, left_w: float = 620.0) -> Array:
	var v := UiKit.vbox(18)
	content.add_child(v)
	v.add_child(UiKit.title(title_text))
	var h := UiKit.hbox(36)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var left := UiKit.vbox(10)
	left.custom_minimum_size = Vector2(left_w, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(left_w + 30, 0)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.add_child(left)
	h.add_child(sc)
	var rp := UiKit.panel()   # dark panel keeps text readable over the bright 3D snow backdrop
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(rp)
	var right := UiKit.vbox(12)
	rp.add_child(right)
	return [left, right]

func _desc_panel(parent: Control, w: float = 520.0) -> Label:
	var l := UiKit.label("", 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	parent.add_child(l)
	return l

func _lock(b: Button, locked: bool) -> void:
	if locked:
		b.icon = LOCK_TEX
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 34)

# ---------------------------------------------------------------- title
func _screen_title() -> Control:
	var v := UiKit.vbox(26)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(v)
	var logo := UiKit.texture("res://assets/sprites/ui/logo.png", Vector2(760, 380))
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(logo)
	var press := UiKit.label(t("tap_to_play") if TouchControls.enabled() else t("press_start"), 34, Color.WHITE, true)
	v.add_child(press)
	var tw := press.create_tween().set_loops()
	tw.tween_property(press, "modulate:a", 0.25, 0.8)
	tw.tween_property(press, "modulate:a", 1.0, 0.8)
	var b := UiKit.button(t("play"), func(): go("main"), 300)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(b)
	footer.text = "v%s  ·  Godot %s" % [ProjectSettings.get_setting("application/config/version"), Engine.get_version_info().string]
	return b

# ---------------------------------------------------------------- main
func _screen_main() -> Control:
	var cols := _two_columns(t("play"), 520)
	var left: VBoxContainer = cols[0]
	var desc := _desc_panel(cols[1])
	var prof := UiKit.label("%s: %d" % [t("credits"), Save.credits()], 26, UiKit.GOLD)
	cols[1].add_child(prof)
	var entries := [
		["grand_prix", "gp_desc", func(): _begin(Game.Mode.GRAND_PRIX)],
		["quick_race", "quick_desc", func(): _begin(Game.Mode.QUICK_RACE)],
		["local_mp", "local_mp_desc", func(): _begin_multiplayer()],
		["time_trial", "tt_desc", func(): _begin(Game.Mode.TIME_TRIAL)],
		["trick_attack", "trick_desc", func(): _begin(Game.Mode.TRICK_ATTACK)],
		["skill_game", "select_challenge", func(): go("challenges")],
		["garage", "garage_desc", func(): go("garage")],
		["profile", "profile_desc", func(): go("profile")],
		["options", "options_desc", func(): go("options")],
		["quit", "quit_q", func(): get_tree().quit()],
	]
	var first: Button
	for e in entries:
		var b := UiKit.button(t(e[0]), e[2], 480)
		var dk: String = e[1]
		b.focus_entered.connect(func(): desc.text = t(dk) + ("\n\n" + t("multiplayer_hint") if dk in ["gp_desc", "quick_desc"] else ""))
		left.add_child(b)
		if first == null:
			first = b
	return first

func _begin(mode: int) -> void:
	flow_mode = mode
	slots.clear()
	slots.append({"type": "human", "device": "touch" if TouchControls.enabled() else "kb"})
	for i in 3:
		slots.append({"type": "ai" if mode in [Game.Mode.GRAND_PRIX, Game.Mode.QUICK_RACE] else "empty", "device": ""})
	if mode in [Game.Mode.GRAND_PRIX, Game.Mode.QUICK_RACE]:
		go("participants")
	else:
		_start_picks()

func _begin_multiplayer() -> void:
	## Local multiplayer: two humans pre-seated (pads first, otherwise the two keyboard halves), CPUs fill the rest.
	flow_mode = Game.Mode.QUICK_RACE
	var pads := Input.get_connected_joypads()
	var d1 := "joy%d" % pads[0] if pads.size() >= 2 else ("touch" if TouchControls.enabled() else "kb_left")
	var d2 := ("joy%d" % pads[1]) if pads.size() >= 2 else ("joy%d" % pads[0] if pads.size() == 1 else "kb_right")
	slots = [{"type": "human", "device": d1}, {"type": "human", "device": d2}, {"type": "ai", "device": ""}, {"type": "ai", "device": ""}]
	go("participants")

const PLAYER_COLORS := [Color(1, 0.5, 0.4), Color(0.4, 0.75, 1), Color(0.5, 1, 0.55), Color(1, 0.85, 0.3)]

func _try_join(device: String) -> bool:
	## "Press A / Start to join": a free pad takes the first CPU/empty slot as a new human player.
	for s in slots:
		if s.type == "human" and String(s.device) == device:
			return false
	for i in range(1, 4):
		if slots[i].type != "human":
			slots[i] = {"type": "human", "device": device}
			Audio.play("unlock", -4.0)
			show_toast(t("player_joined") % [i + 1, _device_label(device)])
			_build()
			return true
	return false

# ---------------------------------------------------------------- participants (4 slots + device)
func _device_options() -> PackedStringArray:
	var out := PackedStringArray(["touch", "kb", "kb_left", "kb_right"]) if TouchControls.enabled() else PackedStringArray(["kb", "kb_left", "kb_right"])
	for j in Input.get_connected_joypads():
		out.append("joy%d" % j)
	for j in 4:
		if not ("joy%d" % j) in out:
			out.append("joy%d" % j)
	return out

func _device_label(d: String) -> String:
	if d.begins_with("joy"):
		var j := int(d.substr(3))
		var nm := Input.get_joy_name(j) if j in Input.get_connected_joypads() else ("—" if Game.lang() != "en" else "not connected")
		return "%s %d (%s)" % [t("joy"), j + 1, nm]
	return t(d)

func _screen_participants() -> Control:
	var cols := _two_columns(t("participants"), 920)
	var left: VBoxContainer = cols[0]
	var devs := _device_options()
	var dev_labels := PackedStringArray()
	for d in devs:
		dev_labels.append(_device_label(d))
	var first: Control
	for i in 4:
		var row := UiKit.hbox(14)
		left.add_child(row)
		var tag := UiKit.label("%s %d" % [t("slot"), i + 1], 28, [Color(1, 0.5, 0.4), Color(0.4, 0.75, 1), Color(0.5, 1, 0.55), Color(1, 0.85, 0.3)][i], true)
		tag.custom_minimum_size = Vector2(130, 0)
		row.add_child(tag)
		var types := PackedStringArray([t("human"), t("cpu"), t("empty")]) if i > 0 else PackedStringArray([t("human")])
		var ty := Cycler.new().setup("", types, ["human", "ai", "empty"].find(String(slots[i].type)), 300)
		row.add_child(ty)
		var dv := Cycler.new().setup(t("device"), dev_labels, maxi(0, devs.find(String(slots[i].device))), 460)
		dv.set_enabled(slots[i].type == "human")
		row.add_child(dv)
		var idx := i
		ty.changed.connect(func(k):
			slots[idx].type = ["human", "ai", "empty"][k]
			if slots[idx].type == "human" and String(slots[idx].device) == "":
				slots[idx].device = _free_device(devs)
				dv.set_index(devs.find(String(slots[idx].device)))
			dv.set_enabled(slots[idx].type == "human"))
		dv.changed.connect(func(k): slots[idx].device = devs[k])
		if first == null:
			first = ty
	var cont := UiKit.button(t("continue_btn"), _participants_done, 420)
	left.add_child(cont)
	var info := _desc_panel(cols[1], 400)
	info.text = ("Aperte START num gamepad livre para entrar como novo jogador.\nVagas CPU são preenchidas pela IA (mesma física). Vagas vazias ficam fora da corrida.\nCada jogador humano precisa de um controle diferente. Com 2 jogadores a tela é dividida na horizontal; com 3–4, em grade." if Game.lang() != "en"
		else "Press START on a free gamepad to join as a new player.\nCPU slots are driven by the AI (same physics). Empty slots sit out.\nEach human needs a different device. 2 players split horizontally; 3–4 use a grid.")
	return first

func _free_device(devs: PackedStringArray) -> String:
	for d in devs:
		var used := false
		for s in slots:
			if s.type == "human" and String(s.device) == d:
				used = true
		if not used:
			return d
	return "kb"

func _participants_done() -> void:
	var seen := {}
	for s in slots:
		if s.type == "human":
			if seen.has(s.device):
				show_toast(t("device_conflict"), Color(1, 0.5, 0.4))
				Audio.play("buy_fail")
				return
			seen[s.device] = true
	# "kb" (whole keyboard) cannot be shared with the split keyboard halves
	if seen.has("kb") and (seen.has("kb_left") or seen.has("kb_right")):
		show_toast(t("device_conflict"), Color(1, 0.5, 0.4))
		Audio.play("buy_fail")
		return
	_start_picks()

func _humans() -> Array:
	return slots.filter(func(s): return s.type == "human")

func _start_picks() -> void:
	pick_index = 0
	picks.clear()
	for h in _humans():
		var eq: Dictionary = Save.profile().equipped
		picks.append({"rider": String(eq.rider) if picks.is_empty() else "", "board": String(eq.board) if picks.is_empty() else "starter"})
	go("rider")

# ---------------------------------------------------------------- rider select
func _rider_taken(id: String) -> bool:
	for i in pick_index:
		if picks[i].rider == id:
			return true
	return false

func _screen_rider() -> Control:
	var cols := _two_columns(t("choose_rider_p") % (pick_index + 1), 560)
	var left: VBoxContainer = cols[0]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	left.add_child(grid)
	var right: VBoxContainer = cols[1]
	stage.custom_minimum_size = Vector2(560, 430)
	right.add_child(stage)
	var name_l := UiKit.label("", 40, Color.WHITE, true)
	right.add_child(name_l)
	var tag_l := UiKit.label("", 22, Color(0.85, 0.92, 1))
	tag_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_l.custom_minimum_size = Vector2(560, 0)
	right.add_child(tag_l)
	var stats := UiKit.vbox(6)
	right.add_child(stats)
	var focus: Control
	for rid in Registry.RIDER_IDS:
		var def := Registry.rider(rid)
		var owned := Save.has_rider(String(rid))
		var secret := rid == &"kaito" and not owned
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 170)
		b.focus_mode = Control.FOCUS_ALL
		b.icon = load(def.portrait_path) if ResourceLoader.exists(def.portrait_path) and not secret else null
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = ("???" if secret else def.display_name)
		if not owned and not secret:
			b.add_child(_corner_lock())
		b.disabled = not owned or _rider_taken(String(rid))
		if not owned:
			b.modulate = Color(0.55, 0.6, 0.75)
		b.focus_mode = Control.FOCUS_ALL  # locked riders stay focusable so players can read the requirement
		var d := def
		b.focus_entered.connect(func():
			Audio.play("ui_move", -6.0)
			stage.show_rider(d, Registry.board(StringName(picks[pick_index].board if picks[pick_index].board != "" else "starter")), secret)
			name_l.text = "???" if secret else d.display_name
			tag_l.text = (t("secret") + " — " + _unlock_text(d.unlock)) if secret else ((d.tagline_pt if Game.lang() != "en" else d.tagline_en)
				+ "\n%s: %s (%d)  ·  %s" % [t("signature"), SignatureTricks.label(String(d.id), Game.lang()), int(SignatureTricks.of(String(d.id)).points), t("signature_hint")] + ("" if owned else "\n%s — %s" % [t("locked"), _unlock_text(d.unlock)]))
			for c in stats.get_children():
				c.queue_free()
			for st in [["speed", d.speed], ["control", d.control], ["jump", d.jump], ["accel", d.accel], ["resist", d.resist]]:
				stats.add_child(UiKit.stat_bar(t(st[0]), 0 if secret else st[1], 5, d.color.lightened(0.2), 300)))
		b.pressed.connect(func():
			Audio.play("ui_ok")
			picks[pick_index].rider = String(d.id)
			stage.confirm()
			Audio.play("unlock", -4.0)
			_lock_input(1.1, func(): go("board")))
		b.mouse_entered.connect(func(): b.grab_focus())
		grid.add_child(b)
		if String(rid) == picks[pick_index].rider or (focus == null and owned and not b.disabled):
			focus = b
	return focus

func _corner_lock() -> TextureRect:
	var lk := UiKit.texture("res://assets/sprites/ui/lock.png", Vector2(44, 44))
	lk.position = Vector2(118, 8)
	lk.size = Vector2(44, 44)
	lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lk

func _unlock_text(u: String) -> String:
	if u == "start":
		return ""
	var parts := u.split(":")
	var cup := int(parts[0].substr(3)) - 1
	var cname: String = Registry.CUPS[cup].name if Game.lang() != "en" else Registry.CUPS[cup].name_en
	var medal := t("medal_" + parts[1])
	return "%s: %s — %s" % [t("requirement"), cname, medal]

func _lock_input(sec: float, then: Callable) -> void:
	## Lets the confirm animation play; blocks input so the choice cannot be confirmed twice.
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(blocker)
	blocker.focus_mode = Control.FOCUS_ALL
	blocker.grab_focus()
	get_tree().create_timer(sec).timeout.connect(func():
		blocker.queue_free()
		then.call())

# ---------------------------------------------------------------- board select
func _screen_board() -> Control:
	var cols := _two_columns(t("choose_board_p") % (pick_index + 1), 520)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	stage.custom_minimum_size = Vector2(560, 360)
	right.add_child(stage)
	var info := UiKit.label("", 34, Color.WHITE, true)
	right.add_child(info)
	var desc := UiKit.label("", 22)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(560, 0)
	right.add_child(desc)
	var stats := UiKit.vbox(6)
	right.add_child(stats)
	var focus: Control
	var rdef := Registry.rider(StringName(picks[pick_index].rider))
	for bid in Registry.BOARD_IDS:
		if not Save.has_board(String(bid)):
			continue
		var bd := Registry.board(bid)
		var b := UiKit.button("%s  ·  %s" % [bd.display_name, t(bd.category)], func():
			picks[pick_index].board = String(bd.id)
			stage.show_rider(rdef, bd)
			stage.confirm()
			_lock_input(0.8, _after_board), 480)
		b.focus_entered.connect(func():
			stage.show_board(bd)
			info.text = bd.display_name
			desc.text = bd.description_pt if Game.lang() != "en" else bd.description_en
			_fill_board_stats(stats, bd, null, Save.board_level(String(bd.id))))
		left.add_child(b)
		if String(bid) == picks[pick_index].board or focus == null:
			focus = b
	return focus

func _fill_board_stats(box: VBoxContainer, bd: BoardDefinition, cmp: BoardDefinition, level: int = 0) -> void:
	for c in box.get_children():
		c.queue_free()
	var bm := bd.mods(level)
	var cm := cmp.mods(Save.board_level(String(cmp.id))) if cmp else {}
	if level > 0:
		box.add_child(UiKit.label("%s %d/%d" % [t("upgrade_level"), level, BoardDefinition.MAX_LEVEL], 22, UiKit.GOLD))
	for st in [["speed", "speed"], ["control", "control"], ["jump", "jump"], ["accel", "accel"], ["spin", "spin"]]:
		var v := float(bm[st[1]])
		var row := UiKit.stat_bar(t(st[0]), (v + 0.12) * 100.0, 24.0, Color(0.45, 1, 0.6) if v > 0.001 else (Color(1, 0.5, 0.4) if v < -0.001 else UiKit.ICE), 260)
		var pct := UiKit.label("%+d%%" % roundi(v * 100.0), 20)
		row.add_child(pct)
		if cmp:
			var dv := v - float(cm[st[1]])
			var dl := UiKit.label(("▲ %+d" % roundi(dv * 100)) if dv > 0.001 else (("▼ %+d" % roundi(dv * 100)) if dv < -0.001 else "="), 20,
				Color(0.45, 1, 0.6) if dv > 0.001 else (Color(1, 0.5, 0.4) if dv < -0.001 else Color(0.8, 0.85, 0.9)))
			row.add_child(dl)
		box.add_child(row)

func _after_board() -> void:
	if pick_index == 0:
		Save.profile().equipped = {"rider": picks[0].rider, "board": picks[0].board}
		Save.write()
	if pick_index < picks.size() - 1:
		pick_index += 1
		history.append("rider")   # back from next player's rider returns to previous board screen
		screen = "rider"
		_build()
		return
	match flow_mode:
		Game.Mode.GRAND_PRIX:
			go("cup")
		Game.Mode.TRICK_ATTACK:
			Game.track_id = &"parque_manobras"
			_launch()
		_:
			go("track")

# ---------------------------------------------------------------- course select
func _track_unlocked(id: StringName) -> bool:
	if id in Registry.EXTRA_TRACK_IDS:
		return true
	var cup := Registry.cup_of(id)
	return cup < int(Save.profile().cups_unlocked)

func _screen_track() -> Control:
	var cols := _two_columns(t("select_track"), 560)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var map := UiKit.texture("", Vector2(520, 360))
	right.add_child(map)
	var nm := UiKit.label("", 38, Color.WHITE, true)
	right.add_child(nm)
	var desc := _desc_panel(right)
	var focus: Control
	if flow_mode == Game.Mode.QUICK_RACE:
		var lap_opts := PackedStringArray([t("course_default")])
		for n in range(1, 10):
			lap_opts.append(str(n))
		var lc := Cycler.new().setup(t("laps"), lap_opts, int(quick.laps), 540)
		lc.changed.connect(func(k): quick.laps = k)
		left.add_child(lc)
		var dc := Cycler.new().setup(t("difficulty"), PackedStringArray([t("easy"), t("normal"), t("expert")]), int(quick.difficulty), 540)
		dc.changed.connect(func(k): quick.difficulty = k)
		left.add_child(dc)
		var ic := Cycler.new().setup(t("items"), PackedStringArray([t("on"), t("off")]), 0 if quick.items else 1, 540)
		ic.changed.connect(func(k): quick.items = k == 0)
		left.add_child(ic)
	var ids: Array = Registry.TRACK_IDS.duplicate()
	if flow_mode in [Game.Mode.QUICK_RACE, Game.Mode.TIME_TRIAL, Game.Mode.SKILL_LANDING, Game.Mode.SKILL_COINS]:
		ids += Registry.EXTRA_TRACK_IDS
	for tid in ids:
		var td := Registry.track(tid)
		var ok := _track_unlocked(tid)
		var nm_txt := td.display_name if Game.lang() != "en" else td.display_name_en
		var b := UiKit.button(nm_txt, func():
			Game.track_id = td.id
			_launch(), 540)
		b.disabled = not ok
		_lock(b, not ok)
		b.focus_mode = Control.FOCUS_ALL
		b.focus_entered.connect(func():
			map.texture = load(td.map_path) if ResourceLoader.exists(td.map_path) else null
			nm.text = nm_txt
			var rec := ""
			if flow_mode == Game.Mode.TIME_TRIAL:
				var board: String = picks[0].board if picks.size() > 0 else "starter"
				rec = "\n%s (%s): %s" % [t("best"), Registry.board(StringName(board)).display_name, UiKit.fmt_time(Save.record(String(td.id), board))]
			desc.text = "%s\n%s: %d m  ·  %s: %d%s%s" % [td.description_pt if Game.lang() != "en" else td.description_en, t("length"), int(td.length_m), t("laps"), td.default_laps, rec,
				"" if ok else "\n%s — %s" % [t("locked"), t("cup_locked")]])
		left.add_child(b)
		if focus == null and ok:
			focus = b
	return focus

# ---------------------------------------------------------------- cup select
func _screen_cup() -> Control:
	var cols := _two_columns(t("select_cup"), 560)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var maps := UiKit.hbox(12)
	right.add_child(maps)
	var m1 := UiKit.texture("", Vector2(300, 210)); var m2 := UiKit.texture("", Vector2(300, 210))
	maps.add_child(m1); maps.add_child(m2)
	var desc := _desc_panel(right)
	var dc := Cycler.new().setup(t("difficulty"), PackedStringArray([t("easy"), t("normal"), t("expert")]), int(quick.difficulty), 540)
	dc.changed.connect(func(k): quick.difficulty = k)
	left.add_child(dc)
	var focus: Control
	for i in Registry.CUPS.size():
		var cup: Dictionary = Registry.CUPS[i]
		var ok := i < int(Save.profile().cups_unlocked)
		var md := Save.medal(String(cup.id))
		var row := UiKit.hbox(10)
		var cname: String = cup.name if Game.lang() != "en" else cup.name_en
		var b := UiKit.button(cname, func(): _launch_cup(i), 470)
		b.disabled = not ok
		_lock(b, not ok)
		row.add_child(b)
		row.add_child(UiKit.medal_icon(md, 52))
		left.add_child(row)
		b.focus_entered.connect(func():
			var t1 := Registry.track(cup.tracks[0]); var t2 := Registry.track(cup.tracks[1])
			m1.texture = load(t1.map_path); m2.texture = load(t2.map_path)
			var names := "%s  +  %s" % [t1.display_name, t2.display_name] if Game.lang() != "en" else "%s  +  %s" % [t1.display_name_en, t2.display_name_en]
			desc.text = "%s\n%s: %s\n%s" % [names, t("medal"), t(["no_medal", "medal_bronze", "medal_silver", "medal_gold"][md]) if md > 0 else t("no_medal"),
				"" if ok else "%s — %s" % [t("locked"), t("cup_locked")]])
		if focus == null and ok:
			focus = b
	return focus

# ---------------------------------------------------------------- challenges
func _screen_challenges() -> Control:
	var cols := _two_columns(t("select_challenge"), 520)
	var left: VBoxContainer = cols[0]
	var desc := _desc_panel(cols[1])
	var first: Control
	for e in [["slalom", "slalom_desc", Game.Mode.SKILL_SLALOM, "slalom_missed"], ["landing", "landing_desc", Game.Mode.SKILL_LANDING, "landing"],
			["coin_rush", "coins_desc", Game.Mode.SKILL_COINS, "coins"], ["targets", "targets_desc", Game.Mode.SKILL_TARGETS, "targets"],
			["snowmen", "snowmen_desc", Game.Mode.SKILL_SNOWMEN, "snowmen"], ["flake_hunt", "flake_hunt_desc", Game.Mode.SKILL_FLAKES, "flakes"],
			["trick_attack", "trick_desc", Game.Mode.TRICK_ATTACK, "trick"]]:
		var m: int = e[2]
		var b := UiKit.button(t(e[0]), func(): _begin(m), 480)
		var dk: String = e[1]
		var th: Array = Game.SKILL_THRESHOLDS[e[3]]
		b.focus_entered.connect(func(): desc.text = "%s\n\n%s: %s" % [t(dk), t("thresholds"), " / ".join(th.map(func(x): return str(x)))])
		left.add_child(b)
		if first == null:
			first = b
	return first

# ---------------------------------------------------------------- launch (with real loading progress)
func _launch_cup(i: int) -> void:
	Game.difficulty = int(quick.difficulty)
	Game.items_enabled = true
	_set_participants()
	Game.mode = Game.Mode.GRAND_PRIX
	Game.cup_index = i
	Game.cup_race = 0
	Game.cup_points.clear()
	Game.cup_credits_earned = 0
	Game.track_id = Registry.CUPS[i].tracks[0]
	Game.laps = Registry.track(Game.track_id).default_laps
	_load_then(Game.goto_race)

func _launch() -> void:
	Game.mode = flow_mode
	Game.laps = int(quick.laps) if flow_mode == Game.Mode.QUICK_RACE and int(quick.laps) > 0 else Registry.track(Game.track_id).default_laps
	Game.difficulty = int(quick.difficulty)
	Game.items_enabled = bool(quick.items)
	Game.seed_value = int(Time.get_ticks_usec() % 100000)
	_set_participants()
	_load_then(Game.goto_race)

func _set_participants() -> void:
	var humans: Array = []
	var hi := 0
	for s in slots:
		if s.type == "human":
			humans.append({"type": "human", "device": String(s.device), "rider": picks[hi].rider, "board": picks[hi].board,
				"board_level": Save.board_level(picks[hi].board)})
			hi += 1
	var cpu := slots.filter(func(s): return s.type == "ai").size()
	Game.participants.clear()
	Game.participants.append_array(humans)
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.seed_value
	var pool: Array = []
	for r in Registry.RIDER_IDS:
		if r == &"kaito" and not Save.has_rider("kaito"):
			continue   # the secret rider stays secret until unlocked
		if not humans.any(func(h): return h.rider == String(r)):
			pool.append(String(r))
	var boards := ["starter", "carver", "float", "rocket", "grip", "twin", "powder", "aurora"]
	for i in cpu:
		var k := rng.randi_range(0, pool.size() - 1)
		Game.participants.append({"type": "ai", "device": "", "rider": pool[k], "board": boards[rng.randi_range(0, boards.size() - 1)]})
		pool.remove_at(k)

func _load_then(cb: Callable) -> void:
	## Real loading screen: threaded load of the course GLB and every rider model, progress from ResourceLoader.
	loading = Control.new()
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(loading)
	var bg := ColorRect.new(); bg.color = Color(0.02, 0.05, 0.15, 0.92); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var td := Registry.track(Game.track_id)
	var v := UiKit.vbox(16)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -420; v.offset_right = 420; v.offset_top = -260; v.offset_bottom = 260
	loading.add_child(v)
	v.add_child(UiKit.texture(td.map_path, Vector2(840, 360)))
	v.add_child(UiKit.label("%s — %s" % [t("loading"), td.display_name if Game.lang() != "en" else td.display_name_en], 32, Color.WHITE, true))
	var pb := ProgressBar.new(); pb.custom_minimum_size = Vector2(840, 26); pb.max_value = 1.0
	v.add_child(pb)
	var paths: Array[String] = [td.scene_path, TrackRuntime.PROPS_GLB, TrackRuntime.ITEMS_GLB, PreviewStage.BOARDS_GLB]
	for p in Game.participants:
		var mp := Registry.rider(StringName(p.rider)).model_path
		if not mp in paths:
			paths.append(mp)
	for p in paths:
		ResourceLoader.load_threaded_request(p)
	var held: Array = []
	while true:
		var total := 0.0
		var done := true
		for p in paths:
			var prog := []
			var st := ResourceLoader.load_threaded_get_status(p, prog)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				done = false
				total += float(prog[0]) if prog.size() > 0 else 0.0
			else:
				total += 1.0
		pb.value = total / paths.size()
		if done:
			break
		await get_tree().process_frame
	for p in paths:
		held.append(ResourceLoader.load_threaded_get(p))   # keep references alive across the scene change
	Game.set_meta("preloaded", held)
	cb.call()

# ---------------------------------------------------------------- options
func _screen_options() -> Control:
	var cols := _two_columns(t("options"), 700)
	var left: VBoxContainer = cols[0]
	var s: Dictionary = Save.settings()
	var first := Cycler.new().setup(t("language"), PackedStringArray(["Português (BR)", "English"]), 1 if String(s.lang) == "en" else 0, 680)
	first.changed.connect(func(k):
		s.lang = "en" if k == 1 else "pt"
		Save.write()
		_build())
	left.add_child(first)
	for vk in ["music", "sfx"]:   # no voice clips ship, so no (inert) voice slider
		var row := UiKit.hbox(14)
		var l := UiKit.label(t(vk), 26)
		l.custom_minimum_size = Vector2(200, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.05; sl.value = float(s[vk])
		sl.custom_minimum_size = Vector2(380, 40)
		sl.focus_mode = Control.FOCUS_ALL
		var pct := UiKit.label("%d%%" % roundi(sl.value * 100), 24)
		var key: String = vk
		sl.value_changed.connect(func(x):
			s[key] = x
			pct.text = "%d%%" % roundi(x * 100)
			Audio.apply_volumes()
			Audio.play("ui_move"))
		sl.drag_ended.connect(func(_c): Save.write())
		sl.focus_exited.connect(func(): Save.write())
		row.add_child(sl)
		row.add_child(pct)
		left.add_child(row)
	var q := Cycler.new().setup(t("quality"), PackedStringArray([t("low"), t("medium"), t("high")]), int(s.quality), 680)
	q.changed.connect(func(k): s.quality = k; Save.write())
	left.add_child(q)
	for tk in ["fullscreen", "shake", "motion", "vibration", "assist"]:
		var key: String = tk
		var c := Cycler.new().setup(t(tk), PackedStringArray([t("on"), t("off")]), 0 if bool(s[tk]) else 1, 680)
		c.changed.connect(func(k):
			s[key] = k == 0
			Save.write()
			if key == "fullscreen":
				Game.apply_display()
			if key == "vibration":
				Inputs.vibration_enabled = bool(s.vibration))
		left.add_child(c)
	var tmodes := ["auto", "on", "off"]
	var tc := Cycler.new().setup(t("touch_controls"), PackedStringArray([t("auto"), t("on"), t("off")]), maxi(0, tmodes.find(String(s.get("touch_controls", "auto")))), 680)
	tc.changed.connect(func(k): s.touch_controls = tmodes[k]; Save.write(); _build())
	left.add_child(tc)
	var tl := Cycler.new().setup(t("tilt_steering"), PackedStringArray([t("off"), t("on")]), 1 if bool(s.get("tilt_steering", false)) else 0, 680)
	tl.changed.connect(func(k): s.tilt_steering = k == 1; Save.write())
	left.add_child(tl)
	left.add_child(UiKit.button(t("controls"), func(): go("controls"), 680))
	left.add_child(UiKit.button(t("about_credits"), func(): go("credits"), 680))
	var desc := _desc_panel(cols[1])
	desc.text = ("Qualidade afeta escala de renderização (0,75/0,9/1,0), sombras, SSAO e partículas.\nAssistência de IA: aproximação limitada a 5%% e respeita o teto físico." if Game.lang() != "en"
		else "Quality changes render scale (0.75/0.9/1.0), shadows, SSAO and particles.\nAI assist: catch-up capped at 5%% and never above the physical limit.").replace("%%", "%")
	return first

func _screen_controls() -> Control:
	var cols := _two_columns(t("controls"), 760)
	var left: VBoxContainer = cols[0]
	var first: Control
	for a in KEY_ACTIONS:
		var row := UiKit.hbox(14)
		var l := UiKit.label(t(ACTION_LABEL.get(a, a)), 24)
		l.custom_minimum_size = Vector2(420, 0)
		row.add_child(l)
		var act: String = a
		var b := UiKit.button(Inputs.key_name(a), func(): pass, 300, 52)
		b.pressed.connect(func():
			_capture_action = act
			_capture_btn = b
			b.text = t("press_key"))
		row.add_child(b)
		left.add_child(row)
		if first == null:
			first = b
	left.add_child(UiKit.button(t("reset_controls"), func():
		Inputs.reset_keyboard_defaults()
		Save.settings().remaps = {}
		Save.write()
		_build(), 400))
	var desc := _desc_panel(cols[1])
	desc.text = ("Gamepad: analógico esquerdo dirige, RT tuck, LT freio, A salto, X grab, LB/RB giro, Y item ofensivo, B utilitário, Start pausa. Zona morta 0,15.\nMultiplayer em um teclado: J1 usa WASD+Espaço+Q/E/Shift/F/R; J2 usa setas + numérico (0 salto, 4/6 giro, 5 grab, 1/2 itens)." if Game.lang() != "en"
		else "Gamepad: left stick steers, RT tuck, LT brake, A jump, X grab, LB/RB spin, Y offensive item, B utility, Start pause. Deadzone 0.15.\nShared keyboard: P1 WASD+Space+Q/E/Shift/F/R; P2 arrows + numpad (0 jump, 4/6 spin, 5 grab, 1/2 items).")
	return first

func _screen_credits() -> Control:
	## Third-party credits (mirrors ASSET_LICENSES.md).
	var cols := _two_columns(t("about_credits"), 760)
	var left: VBoxContainer = cols[0]
	var en := Game.lang() == "en"
	var rows := [
		["Snowboard Legends 3D", "Jogo, personagens, pistas, música e efeitos sonoros originais do projeto." if not en else "Game, characters, courses, music and sound effects are original to the project."],
		["Rokoko — Free Mocap", "Animações de captura de movimento: danças de vitória, esperas e queda. rokoko.com" if not en else "Motion-capture animation: victory dances, idles and fall. rokoko.com"],
		["Mixamo (Adobe)", "Animações: remada, tombo de costas, levantar e tropeço. mixamo.com" if not en else "Animation: push, knock-down, get-up and stumble. mixamo.com"],
		["Poly Haven · ambientCG", "Texturas fotográficas e céus HDRI (CC0)." if not en else "Photographic textures and HDRI skies (CC0)."],
		["Inter", "Fonte — The Inter Project Authors (SIL OFL 1.1)." if not en else "Typeface — The Inter Project Authors (SIL OFL 1.1)."],
		["Godot Engine", "Motor do jogo (MIT) — Godot Engine contributors." if not en else "Game engine (MIT) — Godot Engine contributors."],
	]
	for r in rows:
		left.add_child(UiKit.label(String(r[0]), 26, UiKit.GOLD, true))
		var d := UiKit.label(String(r[1]), 20)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(720, 0)
		left.add_child(d)
	var ok := UiKit.button(t("back"), func(): back(), 360)
	left.add_child(ok)
	return ok

# ---------------------------------------------------------------- garage / shop
func _screen_garage() -> Control:
	var cols := _two_columns(t("garage"), 600)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var cats := ["all", "balanced", "speed", "freestyle", "carving"]
	var cat_labels := PackedStringArray()
	for c in cats:
		cat_labels.append(t(c))
	var fc := Cycler.new().setup(t("category"), cat_labels, garage_filter, 580)
	fc.changed.connect(func(k): garage_filter = k; _build())
	left.add_child(fc)
	var credits_l := UiKit.label("%s: %d" % [t("your_credits"), Save.credits()], 30, UiKit.GOLD, true)
	right.add_child(credits_l)
	stage.custom_minimum_size = Vector2(560, 330)
	right.add_child(stage)
	var nm := UiKit.label("", 34, Color.WHITE, true)
	right.add_child(nm)
	var st := UiKit.label("", 22)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(560, 0)
	right.add_child(st)
	var stats := UiKit.vbox(6)
	right.add_child(stats)
	var equipped := Registry.board(StringName(Save.profile().equipped.board))
	stage.show_board(equipped)
	nm.text = "%s — %s" % [equipped.display_name, t("equipped")]
	_fill_board_stats(stats, equipped, null)
	for bid in Registry.BOARD_IDS:
		var bd := Registry.board(bid)
		if garage_filter > 0 and bd.category != cats[garage_filter]:
			continue
		var state := _board_state(bd)
		var lbl := "%s   %s" % [bd.display_name, {"equipped": "★ " + t("equipped"), "owned": "✓ " + t("owned"), "buy": "● %d" % bd.price, "locked": ""}[state]]
		var row := UiKit.hbox(8)
		var lvl := Save.board_level(String(bd.id))
		if state in ["owned", "equipped"]:
			lbl += "   ▲%d" % lvl
		var b := UiKit.button(lbl, func(): _garage_press(bd), 400 if state in ["owned", "equipped"] else 560)
		_lock(b, state == "locked")
		row.add_child(b)
		if state in ["owned", "equipped"]:
			var up_txt := ("%s ● %d" % [t("upgrade"), BoardDefinition.upgrade_cost(lvl)]) if lvl < BoardDefinition.MAX_LEVEL else t("max_level")
			var ub := UiKit.button(up_txt, func(): _confirm_upgrade(bd), 152)
			ub.add_theme_font_size_override("font_size", 18)
			ub.disabled = lvl >= BoardDefinition.MAX_LEVEL
			ub.focus_entered.connect(func():
				stage.show_board(bd)
				nm.text = "%s — %s %d/%d" % [bd.display_name, t("upgrade_level"), lvl, BoardDefinition.MAX_LEVEL]
				st.text = t("upgrade_desc_" + bd.category)
				_fill_board_stats(stats, bd, null, mini(lvl + 1, BoardDefinition.MAX_LEVEL)))
			row.add_child(ub)
		b.focus_entered.connect(func():
			stage.show_board(bd)
			nm.text = "%s — %s" % [bd.display_name, t(bd.category)]
			var s2 := bd.description_pt if Game.lang() != "en" else bd.description_en
			if state == "locked":
				s2 += "\n%s — %s" % [t("locked"), _unlock_text(bd.unlock)]
			elif state == "buy":
				s2 += "\n%s: %d" % [t("price"), bd.price]
			st.text = s2
			_fill_board_stats(stats, bd, equipped, Save.board_level(String(bd.id))))
		left.add_child(row)
	left.add_child.call_deferred(Control.new())
	return fc

func _confirm_upgrade(bd: BoardDefinition) -> void:
	var lvl := Save.board_level(String(bd.id))
	if lvl >= BoardDefinition.MAX_LEVEL:
		return
	var cost := BoardDefinition.upgrade_cost(lvl)
	var dlg := PanelContainer.new()
	dlg.set_anchors_preset(Control.PRESET_CENTER)
	dlg.offset_left = -360; dlg.offset_right = 360; dlg.offset_top = -150; dlg.offset_bottom = 150
	root.add_child(dlg)
	var v := UiKit.vbox(18)
	dlg.add_child(v)
	v.add_child(UiKit.label(t("confirm_upgrade"), 34, UiKit.GOLD, true))
	v.add_child(UiKit.label("%s ▲%d → ▲%d — %d %s  (%s: %d)" % [bd.display_name, lvl, lvl + 1, cost, t("credits"), t("your_credits"), Save.credits()], 22))
	var h := UiKit.hbox(20)
	v.add_child(h)
	var done := [false]
	var yes := UiKit.button(t("yes"), func():
		if done[0]:
			return   # repeated confirm never charges twice
		done[0] = true
		var r := Save.try_upgrade_board(String(bd.id))
		dlg.queue_free()
		if r == "ok":
			Audio.play("buy")
			show_toast("%s ▲%d" % [bd.display_name, Save.board_level(String(bd.id))])
		else:
			Audio.play("buy_fail")
			show_toast(t("not_enough") if r == "credits" else t("max_level"), Color(1, 0.6, 0.5))
		_build(), 280)
	var no := UiKit.button(t("no"), func(): dlg.queue_free(); _build(), 280)
	h.add_child(yes); h.add_child(no)
	no.grab_focus.call_deferred()

func _board_state(bd: BoardDefinition) -> String:
	if String(Save.profile().equipped.board) == String(bd.id):
		return "equipped"
	if Save.has_board(String(bd.id)):
		return "owned"
	if Save.board_unlocked(String(bd.id)):
		return "buy"
	return "locked"

func _garage_press(bd: BoardDefinition) -> void:
	match _board_state(bd):
		"owned":
			Save.profile().equipped.board = String(bd.id)
			Save.write()
			show_toast("%s: %s" % [t("equipped"), bd.display_name])
			_build()
		"equipped":
			pass
		"locked":
			Audio.play("buy_fail")
			show_toast(t("locked") + " — " + _unlock_text(bd.unlock), Color(1, 0.6, 0.5))
		"buy":
			_confirm_buy(bd)

func _confirm_buy(bd: BoardDefinition) -> void:
	var dlg := PanelContainer.new()
	dlg.set_anchors_preset(Control.PRESET_CENTER)
	dlg.offset_left = -330; dlg.offset_right = 330; dlg.offset_top = -150; dlg.offset_bottom = 150
	root.add_child(dlg)
	var v := UiKit.vbox(18)
	dlg.add_child(v)
	v.add_child(UiKit.label(t("confirm_buy"), 36, UiKit.GOLD, true))
	v.add_child(UiKit.label("%s — %d %s  (%s: %d)" % [bd.display_name, bd.price, t("credits"), t("your_credits"), Save.credits()], 24))
	var h := UiKit.hbox(20)
	v.add_child(h)
	var done := [false]
	var yes := UiKit.button(t("yes"), func():
		if done[0]:
			return   # guard: a second confirm press never charges again
		done[0] = true
		var r := Save.try_buy_board(String(bd.id), bd.price)
		dlg.queue_free()
		if r == "ok":
			Audio.play("buy")
			show_toast(t("bought"))
		else:
			Audio.play("buy_fail")
			show_toast(t("not_enough") if r == "credits" else t(r), Color(1, 0.6, 0.5))
		_build(), 280)
	var no := UiKit.button(t("no"), func(): dlg.queue_free(); _build(), 280)
	h.add_child(yes); h.add_child(no)
	no.grab_focus.call_deferred()

# ---------------------------------------------------------------- profile
func _screen_profile() -> Control:
	var cols := _two_columns(t("profile"), 640)
	var left: VBoxContainer = cols[0]
	var right: VBoxContainer = cols[1]
	var p: Dictionary = Save.profile()
	left.add_child(UiKit.label("%s: %d" % [t("credits"), Save.credits()], 32, UiKit.GOLD, true))
	for i in Registry.CUPS.size():
		var cup: Dictionary = Registry.CUPS[i]
		var row := UiKit.hbox(12)
		row.add_child(UiKit.medal_icon(Save.medal(String(cup.id)), 44))
		row.add_child(UiKit.label(cup.name if Game.lang() != "en" else cup.name_en, 26))
		if i >= int(p.cups_unlocked):
			row.add_child(UiKit.texture("res://assets/sprites/ui/lock.png", Vector2(30, 30)))
		left.add_child(row)
	left.add_child(UiKit.label("%s: %d/%d" % [t("album"), (p.get("flake_album", {}) as Dictionary).size(), (Registry.TRACK_IDS.size() + Registry.EXTRA_TRACK_IDS.size()) * 3], 24, UiKit.GOLD))
	left.add_child(UiKit.label("%s: %d/%d   ·   %s: %d/%d" % [t("participants"), p.riders.size(), Registry.RIDER_IDS.size(), t("garage"), p.boards_owned.size(), Registry.BOARD_IDS.size()], 22))
	var exp := UiKit.button(t("export_save"), func():
		var path := OS.get_user_data_dir().path_join("save_export.json")
		if Save.export_to("user://save_export.json"):
			show_toast("%s %s" % [t("export_ok"), path])
		else:
			show_toast(t("import_fail"), Color(1, 0.5, 0.4)), 600)
	left.add_child(exp)
	left.add_child(UiKit.button(t("import_save"), func():
		if Save.import_from("user://save_export.json"):
			show_toast(t("import_ok"))
			_build()
		else:
			show_toast("%s: %s" % [t("import_fail"), Save.last_error], Color(1, 0.5, 0.4)), 600))
	right.add_child(UiKit.label(t("records"), 30, UiKit.ICE, true))
	var recs := UiKit.vbox(4)
	right.add_child(recs)
	for tid in Registry.TRACK_IDS + Registry.EXTRA_TRACK_IDS:
		var best := 0.0
		var best_board := ""
		for b in Save.data.records.get(String(tid), {}):
			var tv := float(Save.data.records[String(tid)][b])
			if best <= 0.0 or tv < best:
				best = tv; best_board = b
		var trick := int(p.trick_best.get(String(tid), 0))
		var td := Registry.track(tid)
		recs.add_child(UiKit.label("%s:  %s%s%s" % [td.display_name if Game.lang() != "en" else td.display_name_en, UiKit.fmt_time(best),
			("  (%s)" % Registry.board(StringName(best_board)).display_name) if best_board != "" else "", ("   ·  Trick %d" % trick) if trick > 0 else ""], 20))
	var sk: Dictionary = p.skill_medals
	if not sk.is_empty():
		right.add_child(UiKit.label(t("skill_game"), 26, UiKit.ICE, true))
		var keys := sk.keys()
		keys.sort()
		for k in keys:
			right.add_child(UiKit.label("%s: %s" % [k, t(["no_medal", "medal_bronze", "medal_silver", "medal_gold"][int(sk[k])])], 20))
	return exp
