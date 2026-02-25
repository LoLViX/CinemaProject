extends Node
# ============================================================
# SoundManager.gd — Efectos de sonido procedurales (Autoload)
# ============================================================
# Genera tonos de onda sinusoidal con AudioStreamGenerator.
# No requiere archivos de audio externos.
# Uso: SoundManager.play_success() / play_fail() / play_cash() / play_click()

const SAMPLE_RATE := 44100
const MAX_PLAYERS := 4

var _players: Array[AudioStreamPlayer] = []
var _player_idx: int = 0

func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		add_child(player)
		_players.append(player)

# ── API pública ──────────────────────────────────────────────

## Arpeggio ascendente: C→E→G (523→659→784 Hz) — acierto/éxito
func play_success() -> void:
	_play_sequence([
		[523.0, 0.10],
		[659.0, 0.10],
		[784.0, 0.18],
	], 0.08)

## Descenso: G→D (784→392 Hz) — fallo/error
func play_fail() -> void:
	_play_sequence([
		[523.0, 0.12],
		[392.0, 0.22],
	], 0.06)

## Caja registradora: burst rápido 880→1100 Hz
func play_cash() -> void:
	_play_sequence([
		[880.0,  0.06],
		[1100.0, 0.06],
		[880.0,  0.10],
	], 0.04)

## Click UI: tono corto suave 400 Hz
func play_click() -> void:
	_play_note(400.0, 0.07, 0.25, _next_player())

## Pedido completo: acorde rápido con reverb simulado
func play_complete() -> void:
	_play_sequence([
		[659.0, 0.08],
		[784.0, 0.08],
		[988.0, 0.20],
	], 0.05)

# ── Internos ─────────────────────────────────────────────────

func _next_player() -> AudioStreamPlayer:
	var p := _players[_player_idx % MAX_PLAYERS]
	_player_idx += 1
	return p

func _play_note(freq: float, duration: float, volume: float, player: AudioStreamPlayer) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate  = float(SAMPLE_RATE)
	gen.buffer_length = duration + 0.05
	player.stream = gen
	player.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
	player.play()

	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var num_samples := int(SAMPLE_RATE * duration)
	var buf := PackedVector2Array()
	buf.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		# Envolvente ADSR simple: attack 5%, decay+release últimos 20%
		var env := 1.0
		var attack_end := int(num_samples * 0.05)
		var release_start := int(num_samples * 0.80)
		if i < attack_end:
			env = float(i) / float(attack_end)
		elif i >= release_start:
			env = 1.0 - float(i - release_start) / float(num_samples - release_start)

		var sample := sin(TAU * freq * t) * env
		buf[i] = Vector2(sample, sample)

	playback.push_buffer(buf)

func _play_sequence(notes: Array, gap: float) -> void:
	# Reproduce notas en secuencia usando un Timer por nota
	var player := _next_player()
	var delay := 0.0
	for note in notes:
		var freq: float = float(note[0])
		var dur:  float = float(note[1])
		# Creamos un timer para cada nota
		var t := get_tree().create_timer(delay)
		# Captura local de variables para el closure
		var f := freq
		var d := dur
		var p := player
		t.timeout.connect(func(): _play_note(f, d, 0.35, p))
		delay += dur + gap
