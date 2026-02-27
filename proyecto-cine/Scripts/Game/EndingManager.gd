extends Node
# EndingManager — Autoload. Monitorea condiciones de final de partida.

const _EndingScreenScript = preload("res://Scripts/UI/EndingScreenUI.gd")

signal ending_triggered(type: String)

# Final gris: dinero alto pero estabilidad muy baja
const GREY_MONEY_THRESHOLD    := 2000
const GREY_STABILITY_THRESHOLD := 20.0

var _ended := false

func _ready() -> void:
	StabilityManager.stability_changed.connect(func(_v: float): check())
	FameManager.fame_changed.connect(func(_v: int): check())

func reset() -> void:
	_ended = false

## Comprueba si se cumple alguna condición de final. Llamar tras cambios en dinero o estabilidad.
func check() -> void:
	if _ended:
		return
	# ── Fase 1: solo derrota por economía o fama ──────────────
	if RunState.day_index >= 2 and RunState.total_money <= 0:
		_trigger("economic")
	elif FameManager.is_defeat():
		_trigger("fame")
	# ── Fase 2+: derrotas por estabilidad y final gris ────────
	elif RunState.CURRENT_PHASE >= 2:
		if StabilityManager.stability <= 0.0:
			_trigger("existential")
		elif RunState.total_money >= GREY_MONEY_THRESHOLD and StabilityManager.stability < GREY_STABILITY_THRESHOLD:
			_trigger("grey")

func is_ended() -> bool:
	return _ended

## Trigger victory ending (called from InteractionController after day 10).
func trigger_victory(type: String) -> void:
	_trigger(type)

func _trigger(type: String) -> void:
	if _ended:
		return
	_ended = true
	RunState.ending_type = type
	get_tree().paused = true
	emit_signal("ending_triggered", type)

	# Mostrar pantalla de final (process_mode ALWAYS para ignorar pausa)
	var screen := _EndingScreenScript.new()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(screen)
	screen.show_ending(type)
