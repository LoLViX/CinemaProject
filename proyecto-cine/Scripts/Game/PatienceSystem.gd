extends Node

# PatienceSystem — nodo helper (NO autoload)
# Instanciado y gestionado por InteractionController.
# Respeta get_tree().paused al estar en _process.
#
# 2 FASES:
#   Fase 1 (normal): barra verde→ámbar→roja que drena según perfil.
#   Fase 2 (crítica): barra roja de 15 segundos. Si se agota → cliente abandona.
#   Si el jugador atiende durante la fase 2, el cliente se queda.

signal patience_warning(fraction: float)  # emitida al 50% y 25%
signal patience_depleted                  # fase 2 agotada — cliente abandona
signal patience_critical                  # emitida al entrar en fase 2

const PROFILES: Dictionary = {
	"high":   { "max": 120.0, "drain_wait": 0.3, "drain_food": 0.2, "drain_question": 3.0 },
	"normal": { "max": 60.0,  "drain_wait": 0.5, "drain_food": 0.4, "drain_question": 5.0 },
	"low":    { "max": 30.0,  "drain_wait": 1.0, "drain_food": 0.8, "drain_question": 8.0 },
	"entity": { "max": 90.0,  "drain_wait": 0.0, "drain_food": 0.0, "drain_question": 0.0 },
}

const CRITICAL_DURATION: float = 15.0  # segundos de barra roja fase 2

enum Mode { IDLE, WAITING, FOOD }
enum Phase { NORMAL, CRITICAL }

var _mode: Mode = Mode.IDLE
var _phase: Phase = Phase.NORMAL
var _patience: float = 60.0
var _max_patience: float = 60.0
var _critical_time: float = 0.0  # tiempo restante en fase crítica
var _profile: Dictionary = {}
var _warned_50: bool = false
var _warned_25: bool = false
var _depleted: bool = false

# Inicia el sistema con el perfil dado ("normal", "high", "low", "entity").
func start_for(patience_profile: String) -> void:
	var prof: Dictionary = PROFILES.get(patience_profile, PROFILES["normal"])
	_profile = prof
	_max_patience = float(prof["max"])
	_patience = _max_patience
	_mode = Mode.WAITING
	_phase = Phase.NORMAL
	_critical_time = 0.0
	_warned_50 = false
	_warned_25 = false
	_depleted = false

func set_mode_food() -> void:
	if _mode != Mode.IDLE:
		_mode = Mode.FOOD

func set_mode_waiting() -> void:
	if _mode != Mode.IDLE:
		_mode = Mode.WAITING

func stop() -> void:
	_mode = Mode.IDLE
	_phase = Phase.NORMAL
	_depleted = false

# Drenaje instantáneo (ej. por pregunta al NPC).
func drain_wrong_answer() -> void:
	if _mode == Mode.IDLE or _depleted:
		return
	if _phase == Phase.CRITICAL:
		# En fase crítica, las preguntas aceleran el drenaje
		_critical_time = maxf(_critical_time - 3.0, 0.0)
		return
	_apply_drain(float(_profile.get("drain_question", 5.0)))

## Fracción de paciencia (0.0–1.0). En fase crítica devuelve la fracción de la barra roja.
func get_fraction() -> float:
	if _phase == Phase.CRITICAL:
		return _critical_time / CRITICAL_DURATION
	if _max_patience <= 0.0:
		return 1.0
	return _patience / _max_patience

func is_depleted() -> bool:
	return _depleted

func is_critical() -> bool:
	return _phase == Phase.CRITICAL

func _process(delta: float) -> void:
	if _mode == Mode.IDLE or _depleted:
		return

	if _phase == Phase.CRITICAL:
		_critical_time = maxf(_critical_time - delta, 0.0)
		if _critical_time <= 0.0:
			_depleted = true
			_mode = Mode.IDLE
			patience_depleted.emit()
		return

	# Fase normal
	var rate: float = 0.0
	match _mode:
		Mode.WAITING:
			rate = float(_profile.get("drain_wait", 0.5))
		Mode.FOOD:
			rate = float(_profile.get("drain_food", 0.4))

	if rate > 0.0:
		_apply_drain(rate * delta)

func _apply_drain(amount: float) -> void:
	_patience = maxf(_patience - amount, 0.0)

	var frac := get_fraction()
	if not _warned_50 and frac <= 0.5:
		_warned_50 = true
		patience_warning.emit(frac)
	if not _warned_25 and frac <= 0.25:
		_warned_25 = true
		patience_warning.emit(frac)

	if _patience <= 0.0 and _phase == Phase.NORMAL:
		# Entrar en fase crítica (barra roja 15s)
		_phase = Phase.CRITICAL
		_critical_time = CRITICAL_DURATION
		patience_critical.emit()
