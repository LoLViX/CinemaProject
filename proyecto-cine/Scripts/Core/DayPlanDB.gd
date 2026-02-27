extends Node
# DayPlanDB — Autoload
# Parsea los archivos day_XX.txt y construye la lista de clientes del día.
# Formato del archivo:
#   slots: N              → N slots de clientes humanos
#   entity_slots: N       → N slots de entidades (defecto 0)
#   story_npc: id         → NPC de historia requerido (puede repetirse)
#   warning_entities      → insertar evento especial de aviso de entidades
#   special: "texto"      → insertar mensaje especial

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

## Construye y devuelve la lista de clientes para el día indicado.
func build_day(day_index: int, difficulty: int) -> Array:
	var cfg := _parse_config(day_index)
	var slots:        int   = cfg.get("slots", 4)
	var entity_slots: int   = cfg.get("entity_slots", 0)
	var story_npcs:   Array = cfg.get("story_npcs", [])
	var specials:     Array = cfg.get("specials", [])

	# ── Fase 1: desactivar sistemas de fases posteriores ─────
	if RunState.CURRENT_PHASE < 2:
		entity_slots = 0
		var filtered: Array = []
		for sp in specials:
			var kind: String = sp.get("kind", "")
			if kind in ["warning_entities", "familia_alterada"]:
				continue  # Fase 2+
			filtered.append(sp)
		specials = filtered

	# ── 1. NPCs requeridos: historia + must_appear_tomorrow ──────
	var required: Array = []
	for npc_id in story_npcs:
		if not required.has(npc_id) and _npc_available(npc_id):
			required.append(npc_id)

	for npc_id in RunState.must_appear_tomorrow:
		if not required.has(npc_id) and _npc_available(npc_id):
			required.append(npc_id)

	# ── 2. Rellenar con NPCs no vistos ───────────────────────────
	var unseen := _get_unseen_npcs()
	unseen.shuffle()
	var idx := 0
	while required.size() < slots and idx < unseen.size():
		required.append(unseen[idx])
		idx += 1

	# ── 3. Si aún faltan, rellenar con cualquier NPC disponible ──
	while required.size() < slots:
		var any_npc := _pick_any_available(required)
		if any_npc != "":
			required.append(any_npc)
		else:
			break  # no quedan NPCs

	# ── 4. Construir customer dicts ──────────────────────────────
	var customers: Array = []
	for npc_id in required:
		var c := CustomerDB.make_npc_customer_by_id(npc_id, RunState.todays_movies, difficulty)
		customers.append(c)

	# ── 5. Insertar eventos especiales (antes de entidades) ───────
	# warning_entities → al final de los humanos, justo antes de que lleguen las entidades
	for sp in specials:
		var kind: String = sp.get("kind", "")
		var pos:  int    = int(sp.get("pos", customers.size()))
		pos = clampi(pos, 0, customers.size())
		if kind == "special":
			customers.insert(pos, {
				"type": "special",
				"request_text": String(sp.get("text", "")),
				"exit_lane": "alt",
			})
		elif kind == "warning_entities":
			# El aviso siempre va AL FINAL de la lista de humanos (antes de entidades)
			var msgs: Array = _load_warning_messages()
			var txt: String = String(msgs[_rng.randi_range(0, msgs.size() - 1)]) if msgs.size() > 0 else "Hay algo interesado en el cine."
			customers.append({
				"type": "special",
				"request_text": txt,
				"exit_lane": "alt",
			})
		elif kind == "familia_alterada":
			pos = clampi(pos, 0, customers.size())
			customers.insert(pos, {
				"type":         "familia_alterada",
				"display_name": "The Hendersons",
				"request_text": "Buenas noches. Somos los Henderson. Venimos todos los miércoles. Es nuestra tradición.",
				"food_key":     "cust.foodask.1",
				"ok_key":       "cust.react_ok.1",
				"bad_key":      "cust.react_bad.1",
				"bye_key":      "cust.goodbye.1",
				"must":         [],
				"must_not":     ["horror", "dark", "crime"],
				"exit_lane":    "main",
				"patience_profile": "high",
				"food_order": {
					"drink": true, "drink_type": "cola",
					"popcorn": true, "food": "",
					"ketchup": false, "mustard": false,
					"butter": false, "caramel": false,
				},
			})

	# ── 6. Suplantación (día 4+, si contaminación > 0.3) — Fase 2+ ──
	if RunState.CURRENT_PHASE >= 2 and day_index >= 4 and entity_slots > 0:
		var contam := ContaminationManager.get_level()
		var supplant_chance := clampf((contam - 0.3) * 1.5, 0.0, 0.6)
		if _rng.randf() < supplant_chance:
			var human_indices: Array = []
			for ci in range(customers.size()):
				if String(customers[ci].get("type", "")) == "npc":
					human_indices.append(ci)
			if human_indices.size() > 0:
				var pick_idx: int = human_indices[_rng.randi_range(0, human_indices.size() - 1)]
				var original: Dictionary = customers[pick_idx]
				# Transformar: mantiene apariencia pero es entidad
				original["is_supplanted"] = true
				original["original_npc_id"] = String(original.get("npc_id", ""))
				original["patience_profile"] = "entity"
				original["tip"] = 0
				entity_slots = maxi(entity_slots - 1, 0)

	# ── 7. Entidades (siempre al final) ──────────────────────────
	var entity_ids := _get_entity_npcs()
	entity_ids.shuffle()
	var e_added := 0
	for eid in entity_ids:
		if e_added >= entity_slots:
			break
		var ec := CustomerDB.make_npc_customer_by_id(eid, RunState.todays_movies, difficulty)
		customers.append(ec)
		e_added += 1

	# ── 8. Pending grief: modificar primer cliente humano — Fase 2+ ──
	if RunState.CURRENT_PHASE >= 2 and RunState.pending_grief_npc != "":
		var grief_npc_id := RunState.pending_grief_npc
		var grief_npc_def := NPCRegistry.get_npc(grief_npc_id)
		var grief_npc_name := String(grief_npc_def.get("name", grief_npc_id))
		var msgs: Array = _load_grief_messages()
		var tmpl: String = String(msgs[_rng.randi_range(0, msgs.size() - 1)]) if msgs.size() > 0 else "¿Has oído lo de {name}?"
		var grief_text: String = tmpl.replace("{name}", grief_npc_name)
		for c in customers:
			var ctype := String(c.get("type", ""))
			if ctype in ["npc", "normal"]:
				c["is_grieving"]  = true
				c["grief_text"]   = grief_text
				c["grief_target"] = grief_npc_id
				break
		RunState.pending_grief_npc = ""

	return customers

# ── Parseo del archivo de configuración ──────────────────────────

func _parse_config(day_index: int) -> Dictionary:
	var path := "res://Data/DayPlans/day_%02d.txt" % day_index
	var out := {
		"slots": 4,
		"entity_slots": 0,
		"story_npcs": [],
		"specials": [],
	}
	if not FileAccess.file_exists(path):
		return out

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out

	var special_pos := 0  # posición de inserción para specials (al final por defecto)

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var lower := line.to_lower()

		if lower.begins_with("slots:"):
			out["slots"] = int(line.substr(line.find(":") + 1).strip_edges())
		elif lower.begins_with("entity_slots:"):
			out["entity_slots"] = int(line.substr(line.find(":") + 1).strip_edges())
		elif lower.begins_with("story_npc:"):
			var npc_id := line.substr(line.find(":") + 1).strip_edges().to_lower()
			if npc_id != "":
				(out["story_npcs"] as Array).append(npc_id)
		elif lower.begins_with("special:"):
			var rest := line.substr(line.find(":") + 1).strip_edges()
			var txt := _unquote(rest)
			if txt != "":
				(out["specials"] as Array).append({"kind": "special", "text": txt, "pos": special_pos})
		elif lower.begins_with("warning_entities"):
			(out["specials"] as Array).append({"kind": "warning_entities", "pos": special_pos})
		elif lower.begins_with("familia_alterada"):
			(out["specials"] as Array).append({"kind": "familia_alterada", "pos": special_pos})

		special_pos += 1

	return out

# ── Helpers ───────────────────────────────────────────────────────

func _npc_available(npc_id: String) -> bool:
	return NPCRegistry.npc_exists(npc_id) and NPCRegistry.is_in_run_pool(npc_id)

func _get_unseen_npcs() -> Array:
	var out: Array = []
	for npc_id in NPCRegistry._defs.keys():
		if not NPCRegistry.is_in_run_pool(npc_id):
			continue
		if NPCRegistry.get_effective_type(npc_id) != "human":
			continue
		if NPCRegistry.is_dead(npc_id):
			continue
		var state := NPCRegistry.get_npc_state(npc_id)
		if int(state.get("visits", 0)) == 0:
			out.append(npc_id)
	return out

func _get_entity_npcs() -> Array:
	var out: Array = []
	for npc_id in NPCRegistry._defs.keys():
		if not NPCRegistry.is_in_run_pool(npc_id):
			continue
		if NPCRegistry.get_effective_type(npc_id) != "entity":
			continue
		if NPCRegistry.npc_exists(npc_id):
			out.append(npc_id)
	return out

func _pick_any_available(exclude: Array) -> String:
	for npc_id in NPCRegistry._defs.keys():
		if not NPCRegistry.is_in_run_pool(npc_id):
			continue
		if NPCRegistry.get_effective_type(npc_id) != "human":
			continue
		if exclude.has(npc_id):
			continue
		if NPCRegistry.is_dead(npc_id):
			continue
		return npc_id
	return ""

func _load_grief_messages() -> Array:
	return _load_json_array("res://Data/events.json", "grief_messages")

func _load_warning_messages() -> Array:
	return _load_json_array("res://Data/events.json", "warning_entities")

func _load_json_array(path: String, key: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not (parsed is Dictionary):
		return []
	var arr = (parsed as Dictionary).get(key, [])
	if arr is Array:
		return arr as Array
	return []

func _unquote(s: String) -> String:
	var t := s.strip_edges()
	if t.length() >= 2 and ((t.begins_with("\"") and t.ends_with("\"")) or (t.begins_with("'") and t.ends_with("'"))):
		return t.substr(1, t.length() - 2)
	return t
