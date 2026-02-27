extends Node
# DialogueSystem.gd
# Panel de encuentro interactivo con NPC.
# API:
#   init(hud: Node)
#   show_encounter(npc_id, encounter_data: Dictionary, proceed_callable: Callable)
#   show_simple(speaker, text, options)   ← para eventos no-NPC (familia_alterada, etc.)
#   hide()
#   is_open() -> bool

signal closed
signal question_asked    # emitida cada vez que el jugador hace una pregunta al NPC

const C_GOLD     := Color(0.95, 0.76, 0.15)
const C_GOLD_DIM := Color(0.95, 0.76, 0.15, 0.40)
const C_CREAM    := Color(0.97, 0.93, 0.80)
const C_CREAM_D  := Color(0.80, 0.75, 0.60)
const C_RED      := Color(0.90, 0.35, 0.35)
const C_GREEN    := Color(0.35, 0.90, 0.45)

var _hud:  Node  = null
var _panel: Panel = null
var _open: bool  = false

# Referencias a nodos internos (se reconstruyen en cada show_encounter)
var _speaker_lbl:  Label          = null
var _dialogue_lbl: Label          = null
var _q_box:        VBoxContainer  = null
var _proceed_btn:  Button         = null

var _current_npc_id: String = ""
var _proceed_action: Callable

func init(hud: Node) -> void:
	_hud = hud
	_build()

func _build() -> void:
	if _hud == null:
		return
	_panel = Panel.new()
	_panel.name = "DialoguePanel"
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	_panel.anchor_left   = 0.15; _panel.anchor_right  = 0.85
	_panel.anchor_top    = 0.58; _panel.anchor_bottom = 0.96
	_panel.offset_left   = 0;    _panel.offset_right  = 0
	_panel.offset_top    = 0;    _panel.offset_bottom = 0

	var root := VBoxContainer.new()
	root.name = "Root"
	root.anchor_left = 0.0; root.anchor_right  = 1.0
	root.anchor_top  = 0.0; root.anchor_bottom = 1.0
	root.offset_left = 18;  root.offset_right  = -18
	root.offset_top  = 12;  root.offset_bottom = -12
	root.add_theme_constant_override("separation", 6)
	_panel.add_child(root)

	# Nombre del hablante
	_speaker_lbl = Label.new()
	_speaker_lbl.name = "SpeakerLbl"
	_speaker_lbl.add_theme_font_size_override("font_size", 12)
	_speaker_lbl.add_theme_color_override("font_color", C_GOLD)
	root.add_child(_speaker_lbl)

	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = C_GOLD_DIM; sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	root.add_child(sep)

	# Área de diálogo (saludo + respuestas)
	_dialogue_lbl = Label.new()
	_dialogue_lbl.name = "DialogueLbl"
	_dialogue_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_lbl.add_theme_font_size_override("font_size", 15)
	_dialogue_lbl.add_theme_color_override("font_color", C_CREAM)
	_dialogue_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_dialogue_lbl)

	var sep2 := HSeparator.new()
	var sep2_sb := StyleBoxLine.new()
	sep2_sb.color = C_GOLD_DIM; sep2_sb.thickness = 1
	sep2.add_theme_stylebox_override("separator", sep2_sb)
	root.add_child(sep2)

	# Caja de preguntas
	_q_box = VBoxContainer.new()
	_q_box.name = "QBox"
	_q_box.add_theme_constant_override("separation", 3)
	root.add_child(_q_box)

	# Botón de proceder (siempre al final)
	_proceed_btn = Button.new()
	_proceed_btn.name = "ProceedBtn"
	_proceed_btn.text = "▶  ¿Qué va a querer de picar?"
	_proceed_btn.custom_minimum_size = Vector2(0, 36)
	_proceed_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_proceed_btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	_proceed_btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	_proceed_btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	_proceed_btn.add_theme_color_override("font_color", C_GOLD)
	_proceed_btn.add_theme_font_size_override("font_size", 14)
	_proceed_btn.pressed.connect(_on_proceed)
	root.add_child(_proceed_btn)

	_hud.add_child(_panel)

# ── API pública ───────────────────────────────────────────────────

## Muestra el encuentro de un NPC con sus preguntas interactivas.
func show_encounter(npc_id: String, encounter: Dictionary, on_proceed: Callable) -> void:
	if _panel == null or not is_instance_valid(_panel):
		return

	_current_npc_id = npc_id
	_proceed_action = on_proceed

	var def := NPCRegistry.get_npc(npc_id)
	var npc_name := String(def.get("name", def.get("display_name", npc_id)))

	_speaker_lbl.text = npc_name.to_upper()
	_dialogue_lbl.text = String(encounter.get("greeting", "..."))

	# Texto del botón según si es primera visita o visita de retorno
	var visit_count: int = int(NPCRegistry.get_npc_state(npc_id).get("visits", 0))
	if visit_count == 0:
		_proceed_btn.text = "▶  ¡Encantado/a de conocerte! ¿Qué te gustaría ver?"
	else:
		_proceed_btn.text = "▶  ¿Qué va a querer de picar?"

	# Reconstruir botones de preguntas
	for ch in _q_box.get_children():
		ch.queue_free()

	var questions: Array = encounter.get("questions", [])
	var already_asked: Array = RunState.session_asked.get(npc_id, [])

	for q in questions:
		var q_id:   String = String(q.get("id", ""))
		var q_text: String = String(q.get("text", ""))
		var q_resp: String = String(q.get("response", ""))
		var asked := already_asked.has(q_id)

		var btn := Button.new()
		btn.text = ("✓  " if asked else "▷  ") + q_text
		btn.custom_minimum_size = Vector2(0, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = false
		btn.disabled = asked
		btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
		btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
		btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
		btn.add_theme_color_override("font_color",
			C_CREAM_D if asked else C_CREAM)
		btn.add_theme_font_size_override("font_size", 13)

		if not asked:
			var cap_id   := q_id
			var cap_resp := q_resp
			var cap_text := q_text
			btn.pressed.connect(func():
				_on_question(cap_id, cap_text, cap_resp, btn)
			)
		_q_box.add_child(btn)

	_proceed_btn.visible = true
	_panel.visible = true
	_open = true

## Muestra un diálogo simple con opciones (para eventos no-NPC).
func show_simple(speaker: String, text: String, options: Array) -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	_current_npc_id = ""

	_speaker_lbl.text = speaker.to_upper()
	_dialogue_lbl.text = text

	for ch in _q_box.get_children():
		ch.queue_free()

	for opt in options:
		var opt_text:   String   = String(opt.get("text", "..."))
		var opt_action: Callable = opt.get("action", Callable())
		var disabled:   bool     = bool(opt.get("disabled", false))

		var btn := Button.new()
		btn.text = "▶  " + opt_text
		btn.custom_minimum_size = Vector2(0, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = disabled
		btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
		btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
		btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
		btn.add_theme_color_override("font_color", C_CREAM)
		btn.add_theme_font_size_override("font_size", 13)
		if not disabled and opt_action.is_valid():
			var cap := opt_action
			btn.pressed.connect(func():
				hide()
				cap.call()
				closed.emit()
			)
		_q_box.add_child(btn)

	_proceed_btn.visible = false
	_panel.visible = true
	_open = true

## Compatibilidad con la API antigua (InteractionController antiguo).
func show_dialogue(speaker: String, text: String, options: Array) -> void:
	show_simple(speaker, text, options)

func hide() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.visible = false
	_proceed_btn.visible = true   # restaurar para próxima vez
	_open = false

func is_open() -> bool:
	return _open

# ── Interno ───────────────────────────────────────────────────────

func _on_question(q_id: String, _q_text: String, response: String, btn: Button) -> void:
	# Registrar pregunta hecha
	if not RunState.session_asked.has(_current_npc_id):
		RunState.session_asked[_current_npc_id] = []
	(RunState.session_asked[_current_npc_id] as Array).append(q_id)

	# Mostrar respuesta
	_dialogue_lbl.text = response

	# Deshabilitar botón
	btn.disabled = true
	btn.text = "✓  " + btn.text.substr(3)  # quitar "▷  " y poner "✓  "
	btn.add_theme_color_override("font_color", C_CREAM_D)

	# Drenar paciencia por hacer una pregunta
	question_asked.emit()

func _on_proceed() -> void:
	hide()
	if _proceed_action.is_valid():
		_proceed_action.call()
	closed.emit()
