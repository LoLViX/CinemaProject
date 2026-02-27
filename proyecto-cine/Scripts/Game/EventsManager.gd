extends Node
# EventsManager — Autoload
# Gestiona eventos de fin de día: muertes por distorsión.
# Llamar process_end_of_day() desde InteractionController._show_end_of_day()

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

## Llama al final de cada día para calcular eventos de distorsión.
func process_end_of_day() -> void:
	# Solo a partir del día 3
	if RunState.day_index < 3:
		return

	var distortion := ContaminationManager.get_level()
	var chance := distortion * 0.35  # max 35% de probabilidad

	if _rng.randf() < chance:
		_trigger_death()

## Selecciona víctima y la mata, configurando el duelo del día siguiente.
func _trigger_death() -> void:
	var candidates := _get_death_candidates()
	if candidates.is_empty():
		return

	# El NPC con más visitas
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var va := int(NPCRegistry.get_npc_state(a).get("visits", 0))
		var vb := int(NPCRegistry.get_npc_state(b).get("visits", 0))
		return va > vb
	)

	var victim: String = candidates[0]
	NPCRegistry.mark_dead(victim)
	RunState.pending_grief_npc = victim

	if DebugConfig.ENABLE_DEBUG:
		print("EventsManager: muerte de '%s' (distorsión=%.2f)" % [victim, ContaminationManager.get_level()])

func _get_death_candidates() -> Array:
	var out: Array = []
	for npc_id in RunState.npc_state.keys():
		var st: Dictionary = RunState.npc_state[npc_id]
		if int(st.get("visits", 0)) > 0 and bool(st.get("active", true)) and not bool(st.get("dead", false)):
			out.append(npc_id)
	return out
