class_name I18n
extends RefCounted
## PT-BR / EN user interface strings.

const S := {
	"play": ["JOGAR", "PLAY"], "grand_prix": ["Grand Prix", "Grand Prix"], "quick_race": ["Corrida rápida", "Quick race"],
	"time_trial": ["Contra o relógio", "Time trial"], "trick_attack": ["Trick Attack", "Trick Attack"], "skill_game": ["Desafios", "Skill games"],
	"garage": ["Garagem / Loja", "Garage / Shop"], "options": ["Opções", "Options"], "quit": ["Sair", "Quit"], "back": ["Voltar", "Back"],
	"continue": ["Continuar", "Continue"], "restart": ["Reiniciar", "Restart"], "to_menu": ["Menu principal", "Main menu"],
	"lap": ["VOLTA", "LAP"], "final_lap": ["ÚLTIMA DESCIDA!", "FINAL RUN!"], "go": ["VAI!", "GO!"], "finish": ["CHEGADA!", "FINISH!"],
	"position": ["Posição", "Position"], "coins": ["Moedas", "Coins"], "credits": ["Créditos", "Credits"], "points": ["Pontos", "Points"],
	"time": ["Tempo", "Time"], "best": ["Recorde", "Best"], "results": ["Resultados", "Results"], "next": ["Próxima", "Next"],
	"select_rider": ["Escolha seu piloto", "Choose your rider"], "select_board": ["Escolha sua prancha", "Choose your board"],
	"select_track": ["Escolha a pista", "Choose the course"], "laps": ["Descidas", "Runs"], "difficulty": ["Dificuldade", "Difficulty"],
	"items": ["Itens", "Items"], "on": ["Ligado", "On"], "off": ["Desligado", "Off"], "easy": ["Iniciante", "Rookie"], "normal": ["Normal", "Normal"],
	"expert": ["Expert", "Expert"], "start": ["Começar", "Start"], "locked": ["Bloqueado", "Locked"], "buy": ["Comprar", "Buy"],
	"equip": ["Equipar", "Equip"], "owned": ["Adquirida", "Owned"], "confirm_buy": ["Confirmar compra?", "Confirm purchase?"],
	"yes": ["Sim", "Yes"], "no": ["Não", "No"], "not_enough": ["Créditos insuficientes", "Not enough credits"],
	"no_coins": ["Moedas insuficientes!", "Not enough coins!"], "perfect": ["POUSO PERFEITO!", "PERFECT LANDING!"],
	"overtake": ["Ultrapassagem!", "Overtake!"], "lift": ["Teleférico", "Lift"], "wrong_way": ["Volte para a pista!", "Back on track!"],
	"participants": ["Participantes", "Participants"], "human": ["Humano", "Human"], "cpu": ["CPU", "CPU"], "empty": ["Vazio", "Empty"],
	"device": ["Controle", "Device"], "language": ["Idioma", "Language"], "music": ["Música", "Music"], "sfx": ["Efeitos", "SFX"],
	"voice": ["Vozes", "Voice"], "quality": ["Qualidade", "Quality"], "low": ["Baixa", "Low"], "medium": ["Média", "Medium"], "high": ["Alta", "High"],
	"shake": ["Tremor de câmera", "Camera shake"], "motion": ["Efeitos de movimento", "Motion effects"], "vibration": ["Vibração", "Vibration"],
	"assist": ["Assistência de IA", "AI catch-up assist"], "controls": ["Controles", "Controls"], "press_key": ["Pressione uma tecla...", "Press a key..."],
	"fullscreen": ["Tela cheia", "Fullscreen"], "export_save": ["Exportar save", "Export save"], "import_save": ["Importar save", "Import save"],
	"medal_gold": ["Ouro", "Gold"], "medal_silver": ["Prata", "Silver"], "medal_bronze": ["Bronze", "Bronze"], "unlocked": ["DESBLOQUEADO", "UNLOCKED"],
	"cup": ["Copa", "Cup"], "standings": ["Classificação", "Standings"], "trick_bonus": ["Bônus de manobras", "Trick bonus"],
	"slalom": ["Slalom", "Slalom"], "landing": ["Pousos limpos", "Clean landings"], "coin_rush": ["Corrida das moedas", "Coin rush"],
	"failed": ["Não foi desta vez", "Not this time"], "score": ["Pontuação", "Score"], "gates": ["Portões", "Gates"],
	"ghost": ["Fantasma", "Ghost"], "pause": ["PAUSA", "PAUSED"], "loading": ["Carregando", "Loading"], "profile": ["Perfil", "Profile"],
	"speed": ["Velocidade", "Speed"], "control": ["Controle", "Control"], "jump": ["Salto", "Jump"], "accel": ["Aceleração", "Acceleration"],
	"resist": ["Resistência", "Toughness"], "spin": ["Giro", "Spin"], "category": ["Categoria", "Category"],
	"balanced": ["Equilibrada", "Balanced"], "freestyle": ["Freestyle", "Freestyle"], "carving": ["Carving", "Carving"],
	"credits_screen": ["Créditos do jogo", "Game credits"], "press_start": ["Pressione ENTER / START", "Press ENTER / START"],
}

static func t(key: String, lang: String) -> String:
	if not S.has(key):
		return key
	return S[key][1 if lang == "en" else 0]
