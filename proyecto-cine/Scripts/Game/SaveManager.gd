extends Node
## SaveManager.gd — Autoload
## Serializa / deserializa el estado completo del run a disco (JSON).
## Slots: save_slot_1.json … save_slot_3.json en user://

const SAVE_VERSION: int = 1
const MAX_SLOTS:    int = 3

## Devuelve la ruta del archivo de un slot (1-3).
func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % clamp(slot, 1, MAX_SLOTS)

## True si existe un archivo de guardado para ese slot.
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

## Borra la partida del slot (para empezar de nuevo).
func delete_slot(slot: int) -> void:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ── Guardar ───────────────────────────────────────────────────────────────────

func save_slot(slot: int) -> bool:
	var data := _collect()
	var json_str := JSON.stringify(data, "\t")

	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se puede escribir en " + slot_path(slot))
		return false
	file.store_string(json_str)
	file.close()

	if DebugConfig.ENABLE_DEBUG:
		print("SaveManager: partida guardada en slot %d (día %d)" % [slot, RunState.day_index])
	return true

## Recolecta el estado de todos los managers en un Dictionary serializable.
func _collect() -> Dictionary:
	var out: Dictionary = {
		"version":    SAVE_VERSION,
		"timestamp":  Time.get_datetime_string_from_system(),

		# ── RunState ──────────────────────────────────────────
		"run_state": {
			"day_index":           RunState.day_index,
			"customers_per_day":   RunState.customers_per_day,
			"total_money":         RunState.total_money,
			"used_movie_ids":      RunState.used_movie_ids.duplicate(),
			"npc_state":           RunState.npc_state.duplicate(true),
			"last_stock_orders":   RunState.last_stock_orders.duplicate(),
			"must_appear_tomorrow":RunState.must_appear_tomorrow.duplicate(),
			"pending_grief_npc":   RunState.pending_grief_npc,
			"ending_type":         RunState.ending_type,
			"run_npc_pool":        RunState.run_npc_pool.duplicate(),
			"run_wildcard_roles":  RunState.run_wildcard_roles.duplicate(),
		},

		# ── StockManager ──────────────────────────────────────
		"stock": {
			"items": StockManager.get_stock().duplicate(),
		},

		# ── FameManager ───────────────────────────────────────
		"fame": {
			"value": FameManager.get_fame(),
		},
	}

	# ── Fase 2+: serializar sistemas de estabilidad/distorsión ──
	if RunState.CURRENT_PHASE >= 2:
		out["stability"]     = {"value": StabilityManager.stability}
		out["special_room"]  = {
			"capacity":        SpecialRoom.get_capacity(),
			"used":            SpecialRoom.get_used(),
			"neutralized_ids": SpecialRoom._neutralized_ids.duplicate(),
		}
		out["contamination"] = {"level": ContaminationManager.get_level()}

	return out

# ── Cargar ────────────────────────────────────────────────────────────────────

func load_slot(slot: int) -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: no existe save en " + path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: no se puede leer " + path)
		return false
	var raw := file.get_as_text()
	file.close()

	var parse_result: Variant = JSON.parse_string(raw)
	if parse_result == null:
		push_error("SaveManager: JSON inválido en " + path)
		return false

	var data: Dictionary = parse_result as Dictionary
	if data.is_empty():
		push_error("SaveManager: datos vacíos al cargar " + path)
		return false

	# Comprobar versión
	var ver: int = int(data.get("version", 0))
	if ver < SAVE_VERSION:
		push_warning("SaveManager: save de versión antigua (%d), puede haber incompatibilidades" % ver)

	# Marcar que venimos de un save para que Main.gd no haga reset
	RunState._coming_from_save = true
	_restore(data)

	if DebugConfig.ENABLE_DEBUG:
		print("SaveManager: partida cargada desde slot %d (día %d)" % [slot, RunState.day_index])
	return true

## Restaura el estado desde un Dictionary cargado.
func _restore(data: Dictionary) -> void:
	# ── RunState ──────────────────────────────────────────────
	var rs: Dictionary = data.get("run_state", {})
	if not rs.is_empty():
		RunState.day_index           = int(rs.get("day_index",  1))
		RunState.customers_per_day   = int(rs.get("customers_per_day", 5))
		RunState.total_money         = int(rs.get("total_money", 0))
		RunState.used_movie_ids      = (rs.get("used_movie_ids", {}) as Dictionary).duplicate()
		RunState.npc_state           = (rs.get("npc_state", {}) as Dictionary).duplicate(true)
		RunState.last_stock_orders   = (rs.get("last_stock_orders", {}) as Dictionary).duplicate()
		RunState.must_appear_tomorrow = (rs.get("must_appear_tomorrow", []) as Array).duplicate()
		RunState.pending_grief_npc   = String(rs.get("pending_grief_npc", ""))
		RunState.ending_type         = String(rs.get("ending_type", ""))
		RunState.run_npc_pool        = (rs.get("run_npc_pool", []) as Array).duplicate()
		RunState.run_wildcard_roles  = (rs.get("run_wildcard_roles", {}) as Dictionary).duplicate()
		RunState.reset_day_stats()   # las stats del día empiezan desde 0 al continuar

	# NPCRegistry state vive en RunState.npc_state (ya restaurado arriba)
	# Aseguramos que NPCRegistry initializa las entradas faltantes
	if NPCRegistry.has_method("_ensure_npc_state"):
		NPCRegistry.call("_ensure_npc_state")

	# ── Fase 2+: restaurar estabilidad, sala especial, contaminación ──
	if RunState.CURRENT_PHASE >= 2:
		var stb: Dictionary = data.get("stability", {})
		if not stb.is_empty():
			StabilityManager.stability = float(stb.get("value", 100.0))
			if StabilityManager.has_signal("stability_changed"):
				StabilityManager.stability_changed.emit(StabilityManager.stability)

		var sr: Dictionary = data.get("special_room", {})
		if not sr.is_empty():
			SpecialRoom._capacity        = int(sr.get("capacity", 3))
			SpecialRoom._used_today      = int(sr.get("used", 0))
			SpecialRoom._neutralized_ids = (sr.get("neutralized_ids", []) as Array).duplicate()

		var cm: Dictionary = data.get("contamination", {})
		if not cm.is_empty():
			ContaminationManager._level = float(cm.get("level", 0.0))
			if ContaminationManager.has_signal("level_changed"):
				ContaminationManager.level_changed.emit(ContaminationManager._level)

	# ── StockManager ──────────────────────────────────────────
	var sm: Dictionary = data.get("stock", {})
	if not sm.is_empty():
		var items: Dictionary = sm.get("items", {}) as Dictionary
		for key in items.keys():
			StockManager.stock[key] = int(items[key])

	# ── FameManager ───────────────────────────────────────────
	var fm: Dictionary = data.get("fame", {})
	if not fm.is_empty():
		FameManager.fame = int(fm.get("value", FameManager.STARTING_FAME))
		FameManager.fame_changed.emit(FameManager.fame)

# ── Metadata para UI ──────────────────────────────────────────────────────────

## Devuelve info rápida de un slot para mostrar en el menú (o {} si no existe).
func get_slot_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_as_text()
	file.close()
	var parse_result: Variant = JSON.parse_string(raw)
	if parse_result == null:
		return {}
	var data: Dictionary = parse_result as Dictionary
	var rs: Dictionary = data.get("run_state", {}) as Dictionary
	return {
		"slot":       slot,
		"day":        int(rs.get("day_index", 1)),
		"money":      int(rs.get("total_money", 0)),
		"timestamp":  String(data.get("timestamp", "")),
	}
