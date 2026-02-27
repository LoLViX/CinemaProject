extends Node

# ── Fase activa del juego ─────────────────────────────────────────────────────
# Cambiar a 2 para activar entidades, distorsión, sala especial, eventos, etc.
const CURRENT_PHASE: int = 1

# ── Constantes de economía ────────────────────────────────────────────────────
const TICKET_PRICE: int          = 10    # Entrada fija por cliente

# ── Constantes de satisfacción ────────────────────────────────────────────────
const SAT_MOVIE_HIT: int         = 3     # Recomendación de película acertada
const SAT_FOOD_PERFECT: int      = 2     # Bandeja de comida perfecta
const SAT_FOOD_PARTIAL: int      = 1     # Bandeja de comida parcial
const SAT_MAX_PER_CUSTOMER: int  = 5     # SAT_MOVIE_HIT + SAT_FOOD_PERFECT

# ── Estado de run ─────────────────────────────────────────────────────────────
var todays_movies: Array = []             # Array[Dictionary]
var player_tags_by_movie: Dictionary = {} # movie_id -> Array[String]
var used_movie_ids: Dictionary = {}       # id -> true
var day_index: int = 1
var customers_per_day: int = 5

# ── Estado de día ─────────────────────────────────────────────────────────────
var day_hits: int = 0
var day_misses: int = 0
var day_money: int = 0                   # dinero ganado hoy
var total_money: int = 0                 # acumulado de toda la partida

var day_satisfaction: int = 0            # satisfacción conseguida hoy
var day_max_satisfaction: int = 0        # máximo posible hoy (calculado al inicio)

# ── Otros ─────────────────────────────────────────────────────────────────────
var ending_type: String = ""             # "economic" | "existential" | "grey" | ""
var npc_state: Dictionary = {}           # npc_id → {visits, satisfaction, active, neutralized_count}
var _coming_from_save: bool = false      # True si acabamos de cargar desde SaveManager (evita reset en Main)
var last_stock_orders: Dictionary = {}   # item → qty pedido el día anterior (persiste entre días)

# ── Encuentros y sistema de NPCs ──────────────────────────────
var npc_seen_today: Array         = []   # ids de NPCs que han aparecido hoy
var must_appear_tomorrow: Array   = []   # ids que DEBEN aparecer mañana
var pending_grief_npc: String     = ""   # id del NPC muerto (mensaje de duelo primer cliente)
var session_asked: Dictionary     = {}   # npc_id → Array[String] (preguntas hechas en la visita actual)

# ── Pool de run ────────────────────────────────────────────────
var run_npc_pool: Array        = []   # IDs de NPCs sorteados para esta run (subconjunto del total)
var run_wildcard_roles: Dictionary = {}  # wildcard_id → "human" | "entity" (asignado al inicio de run)

func reset_run() -> void:
	used_movie_ids.clear()
	todays_movies.clear()
	player_tags_by_movie.clear()
	day_index = 1
	customers_per_day = 5
	total_money = 0
	ending_type = ""
	npc_state.clear()
	last_stock_orders.clear()
	npc_seen_today.clear()
	must_appear_tomorrow.clear()
	pending_grief_npc = ""
	session_asked.clear()
	run_npc_pool.clear()
	run_wildcard_roles.clear()
	reset_day_stats()

func reset_day_stats() -> void:
	day_hits = 0
	day_misses = 0
	day_money = 0
	day_satisfaction = 0
	day_max_satisfaction = 0
	npc_seen_today.clear()
	session_asked.clear()

func earn_money(amount: int) -> void:
	day_money += amount
	total_money += amount

func add_satisfaction(amount: int) -> void:
	day_satisfaction = mini(day_satisfaction + amount, day_max_satisfaction)

func satisfaction_fraction() -> float:
	if day_max_satisfaction <= 0:
		return 0.0
	return float(day_satisfaction) / float(day_max_satisfaction)

func day_rating() -> String:
	var total := day_hits + day_misses
	if total == 0:
		return "SIN DATOS"
	var pct := float(day_hits) / float(total)
	if pct >= 0.8:
		return "EXCELENTE"
	elif pct >= 0.6:
		return "BUENO"
	elif pct >= 0.4:
		return "REGULAR"
	else:
		return "MAL DÍA"

func is_used(id: String) -> bool:
	return used_movie_ids.has(id)

func mark_used(id: String) -> void:
	if id != "":
		used_movie_ids[id] = true

## Llama al final del día para calcular must_appear_tomorrow según satisfacción.
func compute_must_appear() -> void:
	var sat := satisfaction_fraction()
	var all_seen := npc_seen_today.duplicate()
	if sat >= 0.60:
		must_appear_tomorrow = all_seen
	elif sat >= 0.30:
		all_seen.shuffle()
		must_appear_tomorrow = all_seen.slice(0, ceili(all_seen.size() * 0.7))
	else:
		all_seen.shuffle()
		must_appear_tomorrow = all_seen.slice(0, ceili(all_seen.size() * 0.5))
