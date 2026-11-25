class_name SignatureTricks
extends RefCounted
## One original signature trick per rider. Input (in the air): spin-left, spin-right, grab pressed in sequence within
## 0.8 s (keyboard Q, E, Shift / pad LB, RB, X). The rotation then plays automatically for `dur` seconds; landing
## before it completes is a crash, landing after it scores `points` (subject to the normal combo/repetition rules).

const INPUT_WINDOW := 0.8
## spin/flip in degrees (sign = direction), grab = held during the trick
const DATA := {
	"niko":  {"pt": "Hélice Turquesa", "en": "Turquoise Propeller", "spin": 540.0, "flip": 0.0, "grab": true, "dur": 1.0, "points": 520},
	"mika":  {"pt": "Trança Coral", "en": "Coral Braid", "spin": 180.0, "flip": 360.0, "grab": false, "dur": 1.05, "points": 560},
	"taro":  {"pt": "Bala Laranja", "en": "Orange Bullet", "spin": 0.0, "flip": 360.0, "grab": true, "dur": 0.95, "points": 480},
	"luna":  {"pt": "Órbita Estelar", "en": "Star Orbit", "spin": 720.0, "flip": 0.0, "grab": false, "dur": 1.1, "points": 560},
	"boro":  {"pt": "Avalanche", "en": "Avalanche", "spin": 0.0, "flip": -360.0, "grab": true, "dur": 1.0, "points": 500},
	"yuki":  {"pt": "Floco Duplo", "en": "Double Flake", "spin": 360.0, "flip": 360.0, "grab": false, "dur": 1.15, "points": 600},
	"zed":   {"pt": "Pulso Neon", "en": "Neon Pulse", "spin": 900.0, "flip": 0.0, "grab": false, "dur": 1.15, "points": 600},
	"pippa": {"pt": "Luvas ao Vento", "en": "Gloves in the Wind", "spin": 0.0, "flip": 720.0, "grab": false, "dur": 1.2, "points": 620},
	"kaito": {"pt": "Corte do Andarilho", "en": "Wanderer's Cut", "spin": -540.0, "flip": -360.0, "grab": true, "dur": 1.2, "points": 650},
}

static func of(rider_id: String) -> Dictionary:
	return DATA.get(rider_id, DATA["niko"])

static func label(rider_id: String, lang: String) -> String:
	var d := of(rider_id)
	return String(d.en if lang == "en" else d.pt)
