extends Node

# NPCRegistry — autoload
# Carga los datos de NPCs desde Data/NPCs/<id>.json (un archivo por NPC).
# Los slots y el orden de aparición se definen en Data/DayPlans/day_XX.txt.
# El estado per-run (visitas, satisfacción) vive en RunState.npc_state.

const DATA_FOLDER := "res://Data/NPCs"

var _defs: Dictionary = {}  # npc_id → Dictionary con sus datos

func _ready() -> void:
	_load_from_folder()
	_ensure_npc_state()

# ── Carga ────────────────────────────────────────────────────────────────────

func _load_from_folder() -> void:
	var dir := DirAccess.open(DATA_FOLDER)
	if dir == null:
		push_error("NPCRegistry: no se puede abrir carpeta " + DATA_FOLDER)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			_load_single(DATA_FOLDER + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	if DebugConfig.ENABLE_DEBUG:
		print("NPCRegistry: cargados %d NPCs desde %s" % [_defs.size(), DATA_FOLDER])

func _load_single(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("NPCRegistry: no se puede abrir " + path)
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("NPCRegistry: JSON inválido en " + path)
		return
	var npc := parsed as Dictionary
	var npc_id: String = npc.get("id", "")
	if npc_id == "":
		push_error("NPCRegistry: NPC sin campo 'id' en " + path)
		return
	_defs[npc_id] = npc

# ── API pública ───────────────────────────────────────────────────────────────

## Devuelve la definición del NPC con ese ID, o {} si no existe.
func get_npc(npc_id: String) -> Dictionary:
	return _defs.get(npc_id, {})

## True si el NPC existe en el JSON, está activo y no está muerto en esta run.
func npc_exists(npc_id: String) -> bool:
	return _defs.has(npc_id) and _is_active(npc_id) and not is_dead(npc_id)

## Registra una visita y actualiza la satisfacción del NPC.
## satisfaction_delta: positivo = buena visita, negativo = mala.
func record_visit(npc_id: String, satisfaction_delta: int) -> void:
	if not ("npc_state" in RunState):
		return
	_ensure_entry(npc_id)
	RunState.npc_state[npc_id]["visits"] = int(RunState.npc_state[npc_id]["visits"]) + 1
	var current: int = int(RunState.npc_state[npc_id]["satisfaction"])
	RunState.npc_state[npc_id]["satisfaction"] = clampi(current + satisfaction_delta, 0, 100)

func get_npc_state(npc_id: String) -> Dictionary:
	if not ("npc_state" in RunState):
		return {}
	return RunState.npc_state.get(npc_id, {})

func deactivate(npc_id: String) -> void:
	if not ("npc_state" in RunState):
		return
	_ensure_entry(npc_id)
	RunState.npc_state[npc_id]["active"] = false

func reset_run() -> void:
	if not ("npc_state" in RunState):
		return
	RunState.npc_state.clear()
	_ensure_npc_state()

# ── Interno ───────────────────────────────────────────────────────────────────

func _ensure_npc_state() -> void:
	if not ("npc_state" in RunState):
		return
	for npc_id in _defs:
		_ensure_entry(npc_id)

func _ensure_entry(npc_id: String) -> void:
	if not RunState.npc_state.has(npc_id):
		RunState.npc_state[npc_id] = {
			"visits": 0,
			"satisfaction": 50,
			"active": true,
			"neutralized_count": 0,
			"dead": false,
		}

func _is_active(npc_id: String) -> bool:
	if not ("npc_state" in RunState):
		return true
	var state: Dictionary = RunState.npc_state.get(npc_id, {})
	return bool(state.get("active", true))

# ── Métodos de encuentro ──────────────────────────────────────────────────────

## Devuelve el índice del encuentro actual del NPC (basado en visitas).
func get_encounter_index(npc_id: String) -> int:
	var def := get_npc(npc_id)
	var encounters: Array = def.get("encounters", [])
	if encounters.is_empty():
		return 0
	var visits: int = int(get_npc_state(npc_id).get("visits", 0))
	return mini(visits, encounters.size() - 1)

## Devuelve los datos del encuentro actual del NPC.
func get_current_encounter(npc_id: String) -> Dictionary:
	var def := get_npc(npc_id)
	var encounters: Array = def.get("encounters", [])
	var idx := get_encounter_index(npc_id)
	if encounters.size() > idx:
		return encounters[idx] as Dictionary
	return {}

## Marca un NPC como muerto.
func mark_dead(npc_id: String) -> void:
	_ensure_entry(npc_id)
	RunState.npc_state[npc_id]["active"] = false
	RunState.npc_state[npc_id]["dead"]   = true

## True si el NPC está muerto.
func is_dead(npc_id: String) -> bool:
	if not ("npc_state" in RunState):
		return false
	return bool(RunState.npc_state.get(npc_id, {}).get("dead", false))

# ── Pool de run ───────────────────────────────────────────────────────────────

## Construye el pool de NPCs para esta run.
## Selecciona ~65 % de humanos y entidades disponibles (mínimos garantizados).
## Los wildcards entran todos y se asignan aleatoriamente a "human" o "entity".
## Llámalo una sola vez al inicio de cada partida nueva (Main._ready).
func build_run_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var humans:    Array = []
	var entities:  Array = []
	var wildcards: Array = []

	for npc_id in _defs.keys():
		var def := _defs[npc_id] as Dictionary
		var ntype: String = String(def.get("npc_type", ""))
		# Compatibilidad retroactiva: sin npc_type → inferir por patience
		if ntype == "":
			ntype = "entity" if int(def.get("patience", 7)) == 0 else "human"
		match ntype:
			"human":    humans.append(npc_id)
			"entity":   entities.append(npc_id)
			"wildcard": wildcards.append(npc_id)

	humans.shuffle()
	entities.shuffle()

	var pool: Array = []
	var wildcard_roles: Dictionary = {}

	# Humanos: TODOS entran (son pocos, ~13, y los días piden 4-7)
	for h in humans:
		pool.append(h)

	# Entidades: todas (solo hay 2)
	for e in entities:
		pool.append(e)

	# Wildcards: todos entran; se les asigna rol aleatorio
	for wid in wildcards:
		pool.append(wid)
		wildcard_roles[wid] = "entity" if rng.randi() % 2 == 0 else "human"

	# Guía: siempre en pool (solo aparece si está en story_npc del día)
	if _defs.has("guia") and not pool.has("guia"):
		pool.append("guia")

	RunState.run_npc_pool       = pool
	RunState.run_wildcard_roles = wildcard_roles

	if DebugConfig.ENABLE_DEBUG:
		print("NPCRegistry: pool run=%s" % str(pool))
		print("NPCRegistry: wildcards=%s" % str(wildcard_roles))

## True si el NPC está en el pool de esta run.
## Si el pool está vacío (aún no construido) deja pasar todo por seguridad.
func is_in_run_pool(npc_id: String) -> bool:
	if RunState.run_npc_pool.is_empty():
		return true
	return RunState.run_npc_pool.has(npc_id)

## Devuelve el tipo efectivo del NPC en esta run: "human" o "entity".
## Los wildcards se resuelven según run_wildcard_roles.
func get_effective_type(npc_id: String) -> String:
	var def := get_npc(npc_id)
	var ntype: String = String(def.get("npc_type", ""))
	if ntype == "":
		# Compatibilidad retroactiva
		return "entity" if int(def.get("patience", 7)) == 0 else "human"
	if ntype == "wildcard":
		return String(RunState.run_wildcard_roles.get(npc_id, "human"))
	return ntype

# ─────────────────────────────────────────────────────────────────────────────

## Convierte patience numérico (1-10, 0=entity) a perfil string.
static func patience_to_profile(patience: int) -> String:
	if patience == 0:
		return "entity"
	if patience <= 4:
		return "low"
	if patience <= 7:
		return "normal"
	return "high"
