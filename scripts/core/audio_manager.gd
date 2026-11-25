extends Node
## Mix buses (Master/Music/SFX/Voice + limiter), music player with loop, pooled SFX voices.

const MAX_VOICES := 24
var music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _current_music: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	apply_volumes()

func apply_volumes() -> void:
	var s: Dictionary = Save.settings()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(s.music))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(s.sfx))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(0.0001, float(s.voice))))

func stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := "res://assets/audio/sfx/%s.wav" % name
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("Audio: missing sfx " + name)
	_cache[name] = s
	return s

func play_music(path: String, fade: float = 0.6) -> void:
	if path == _current_music and music.playing:
		return
	_current_music = path
	if not ResourceLoader.exists(path):
		push_warning("Audio: missing music " + path)
		music.stop()
		return
	var st := load(path) as AudioStream
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	music.stream = st
	music.volume_db = -30.0
	music.play()
	create_tween().tween_property(music, "volume_db", 0.0, fade)

func stop_music() -> void:
	_current_music = ""
	music.stop()

func ui(name: String = "ui_move") -> void:
	play(name)

func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s; p.volume_db = volume_db; p.pitch_scale = pitch; p.play()
			return
	_pool[0].stop(); _pool[0].stream = s; _pool[0].play()

func play_3d(name: String, at: Node3D, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	## Spatialized one-shot for rival sounds. Total simultaneous 3D voices capped at MAX_VOICES.
	var s := stream(name)
	if s == null or at == null or not at.is_inside_tree():
		return
	if get_tree().get_nodes_in_group("sfx3d").size() >= MAX_VOICES:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s; p.bus = "SFX"; p.volume_db = volume_db; p.pitch_scale = pitch
	p.unit_size = 12.0; p.max_distance = 120.0
	p.add_to_group("sfx3d")
	at.get_tree().current_scene.add_child(p)
	p.global_position = at.global_position
	p.finished.connect(p.queue_free)
	p.play()
