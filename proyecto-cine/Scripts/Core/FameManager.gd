extends Node
## FameManager — Autoload. Gestiona la fama del cine (0–10).
## Fama alta = más clientes + nuevos NPCs. Fama 0 = derrota.

signal fame_changed(new_value: int)

const MAX_FAME: int = 10
const MIN_FAME: int = 0
const STARTING_FAME: int = 5

var fame: int = STARTING_FAME

func reset() -> void:
	fame = STARTING_FAME
	fame_changed.emit(fame)

## Modifica la fama. Clampea entre 0 y 10.
func apply_delta(delta: int, reason: String = "") -> void:
	var prev := fame
	fame = clampi(fame + delta, MIN_FAME, MAX_FAME)
	if DebugConfig.ENABLE_DEBUG and reason != "":
		print("FameManager [%s]: %d → %d" % [reason, prev, fame])
	if fame != prev:
		fame_changed.emit(fame)

## Convierte la satisfacción diaria en cambio de fama.
## Llamar al final del día con RunState.satisfaction_fraction().
func process_end_of_day(sat_fraction: float) -> int:
	var delta: int = 0
	if sat_fraction >= 0.80:
		delta = 1    # Zona INCREÍBLE → fama +1
	elif sat_fraction >= 0.40:
		delta = 0    # Zona NORMAL → sin cambio
	else:
		delta = -1   # Zona MALA → fama -1
	if delta != 0:
		apply_delta(delta, "end_of_day sat=%.0f%%" % (sat_fraction * 100))
	return delta

## Bonus/penalización de clientes derivado de la fama.
## Devuelve un delta respecto al número base de clientes del día.
func customer_count_modifier() -> int:
	if fame >= 8:
		return 2
	elif fame >= 6:
		return 1
	elif fame <= 2:
		return -2
	elif fame <= 3:
		return -1
	return 0

func get_fame() -> int:
	return fame

func is_defeat() -> bool:
	return fame <= MIN_FAME
