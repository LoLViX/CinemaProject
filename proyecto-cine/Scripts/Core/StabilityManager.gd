extends Node
# StabilityManager — Autoload. Gestiona la estabilidad del cine de contención.
# 100 = completamente estable. 0 = final existencial.

signal stability_changed(new_value: float)
signal stability_critical  # emitido al cruzar CRITICAL_THRESHOLD hacia abajo

const MAX := 100.0
const MIN := 0.0
const CRITICAL_THRESHOLD := 20.0

var stability: float = 100.0

func reset() -> void:
	stability = MAX

## Modifica la estabilidad. delta positivo sube, negativo baja.
func modify(delta: float, reason: String = "") -> void:
	var prev := stability
	stability = clampf(stability + delta, MIN, MAX)
	if DebugConfig.ENABLE_DEBUG and reason != "":
		print("StabilityManager [%s]: %.1f → %.1f" % [reason, prev, stability])
	if stability != prev:
		emit_signal("stability_changed", stability)
		if prev > CRITICAL_THRESHOLD and stability <= CRITICAL_THRESHOLD:
			emit_signal("stability_critical")

func get_pct() -> float:
	return stability / MAX

## Alias conveniente: apply_delta(delta) = modify(delta)
func apply_delta(delta: float, reason: String = "") -> void:
	modify(delta, reason)
