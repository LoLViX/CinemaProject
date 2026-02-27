extends Node
# SpecialRoom.gd
# Gestiona las neutralizaciones de entidades en la Sala Especial.
# API:
#   try_neutralize(entity_id: String) -> bool
#   get_capacity() -> int
#   get_used() -> int
#   end_of_day()
# Señales:
#   neutralized(entity_id)       — neutralización exitosa
#   capacity_full()              — sin hueco, no se puede neutralizar
#   capacity_recharged(new_cap)  — capacidad recargada al inicio del día

signal neutralized(entity_id: String)
signal capacity_full
signal capacity_recharged(new_cap: int)

const MAX_CAPACITY := 5
const BASE_CAPACITY := 5

var _capacity:   int = BASE_CAPACITY   # hueco disponible hoy
var _used_today: int = 0
var _neutralized_ids: Array[String] = []

func _ready() -> void:
	_capacity   = BASE_CAPACITY
	_used_today = 0

# ══════════════════════════════════════════════════════════════
# API pública
# ══════════════════════════════════════════════════════════════

## Intenta neutralizar una entidad. Devuelve true si se ha podido.
func try_neutralize(entity_id: String) -> bool:
	if _used_today >= _capacity:
		capacity_full.emit()
		return false

	_used_today += 1
	if not _neutralized_ids.has(entity_id):
		_neutralized_ids.append(entity_id)

	# Desactivar el NPC en el registro
	if NPCRegistry.npc_exists(entity_id):
		NPCRegistry.deactivate(entity_id)

	# Penalizar la estabilidad levemente (es una acción extrema)
	StabilityManager.apply_delta(-5)

	neutralized.emit(entity_id)

	if DebugConfig.ENABLE_DEBUG:
		print("SpecialRoom: neutralizado '%s' (%d/%d usados)" % [entity_id, _used_today, _capacity])

	return true

## Capacidad total disponible hoy.
func get_capacity() -> int:
	return _capacity

## Cuántas neutralizaciones se han hecho hoy.
func get_used() -> int:
	return _used_today

## Capacidad libre restante hoy.
func get_remaining() -> int:
	return max(0, _capacity - _used_today)

# ══════════════════════════════════════════════════════════════
# Fin de día — recarga basada en satisfacción humana
# ══════════════════════════════════════════════════════════════

## Llamar al final del día para recalcular la capacidad del día siguiente.
## sat_fraction: 0.0–1.0 (satisfacción diaria de RunState).
func end_of_day(sat_fraction: float = 0.5) -> void:
	_used_today = 0

	# Más satisfacción humana = más capacidad de neutralización
	# sat < 0.3 → capacidad - 1, sat > 0.7 → capacidad + 1
	var delta := 0
	if sat_fraction >= 0.70:
		delta = 1
	elif sat_fraction < 0.30:
		delta = -1

	_capacity = clampi(_capacity + delta, 1, MAX_CAPACITY)
	capacity_recharged.emit(_capacity)

	if DebugConfig.ENABLE_DEBUG:
		print("SpecialRoom: capacidad recargada → %d (sat=%.2f)" % [_capacity, sat_fraction])
