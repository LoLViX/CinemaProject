extends CanvasLayer
class_name HUD

# ============================================================
# HUD.gd (REEMPLAZO COMPLETO)
# - Prompt "pulsa E" traducido con TextDB
# - Bocadillo cliente centrado
# - Debug acierto/fallo arriba derecha
# ============================================================

# RUTAS ABSOLUTAS (según tu report)
const ABS_UI: String = "/root/Main/UI"
const ABS_DEBUG_LABEL_1: String = "/root/Main/UI/@Label@36"        # esquina sup. derecha (o similar)
const ABS_DEBUG_LABEL_2: String = "/root/Main/UI/@Label@37"        # otra label (si la usabas)

# Estos nodos suelen ser instanciados por código si no existen
var _bubble: Panel = null
var _bubble_label: Label = null

var _key_panel: Panel = null
var _key_label: Label = null

var _debug_label: Label = null

var _textdb: Node = null

func _ready() -> void:
	_textdb = get_tree().root.get_node_or_null("TextDB")

	_debug_label = get_node_or_null(ABS_DEBUG_LABEL_1) as Label
	if _debug_label == null:
		_debug_label = get_node_or_null(ABS_DEBUG_LABEL_2) as Label

	# Si no hay debug label en escena, lo creamos
	if _debug_label == null:
		_debug_label = Label.new()
		add_child(_debug_label)
		_debug_label.anchor_left = 1.0
		_debug_label.anchor_right = 1.0
		_debug_label.anchor_top = 0.0
		_debug_label.anchor_bottom = 0.0
		_debug_label.offset_left = -360
		_debug_label.offset_top = 18
		_debug_label.offset_right = -18
		_debug_label.offset_bottom = 60
		_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_debug_label.visible = true
	_debug_label.text = ""

	_ensure_key_prompt()
	_ensure_bubble()

	hide_key()
	hide_bubble()

# ------------------------------------------------------------
# PROMPT "PULSA E" / "SERVE CUSTOMER"
# ------------------------------------------------------------
func _ensure_key_prompt() -> void:
	if _key_panel != null and is_instance_valid(_key_panel):
		return

	_key_panel = Panel.new()
	add_child(_key_panel)
	_key_panel.name = "KeyPromptPanel"
	_key_panel.visible = false

	_key_panel.anchor_left = 0.5
	_key_panel.anchor_right = 0.5
	_key_panel.anchor_top = 0.85
	_key_panel.anchor_bottom = 0.85
	_key_panel.offset_left = -220
	_key_panel.offset_right = 220
	_key_panel.offset_top = -26
	_key_panel.offset_bottom = 26

	_key_label = Label.new()
	_key_panel.add_child(_key_label)
	_key_label.name = "KeyPromptLabel"
	_key_label.anchor_left = 0.0
	_key_label.anchor_right = 1.0
	_key_label.anchor_top = 0.0
	_key_label.anchor_bottom = 1.0
	_key_label.offset_left = 14
	_key_label.offset_right = -14
	_key_label.offset_top = 6
	_key_label.offset_bottom = -6
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_label.autowrap_mode = TextServer.AUTOWRAP_OFF

func show_key(key_or_text: String) -> void:
	_ensure_key_prompt()

	# Si parece una key (contiene punto y empieza por ui./cust./movie.), la traducimos.
	var txt := _translate(key_or_text)

	_key_label.text = txt
	_key_panel.visible = true

func hide_key() -> void:
	if _key_panel != null and is_instance_valid(_key_panel):
		_key_panel.visible = false

# ------------------------------------------------------------
# BOCADILLO / TEXTO CLIENTE EN CENTRO
# ------------------------------------------------------------
func _ensure_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		return

	_bubble = Panel.new()
	add_child(_bubble)
	_bubble.name = "CustomerBubble"
	_bubble.visible = false

	_bubble.anchor_left = 0.5
	_bubble.anchor_right = 0.5
	_bubble.anchor_top = 0.50
	_bubble.anchor_bottom = 0.50
	_bubble.offset_left = -420
	_bubble.offset_right = 420
	_bubble.offset_top = -90
	_bubble.offset_bottom = 90

	_bubble_label = Label.new()
	_bubble.add_child(_bubble_label)
	_bubble_label.name = "CustomerBubbleLabel"
	_bubble_label.anchor_left = 0.0
	_bubble_label.anchor_right = 1.0
	_bubble_label.anchor_top = 0.0
	_bubble_label.anchor_bottom = 1.0
	_bubble_label.offset_left = 18
	_bubble_label.offset_right = -18
	_bubble_label.offset_top = 14
	_bubble_label.offset_bottom = -14
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func show_bubble(text_or_key: String) -> void:
	_ensure_bubble()
	_bubble_label.text = _translate(text_or_key)
	_bubble.visible = true

func hide_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.visible = false

# ------------------------------------------------------------
# DEBUG (ARRIBA DERECHA)
# ------------------------------------------------------------
func show_debug(msg: String) -> void:
	if _debug_label == null or not is_instance_valid(_debug_label):
		return
	_debug_label.text = msg

func clear_debug() -> void:
	show_debug("")

# Resultado rápido tipo ✅/❌
func set_result(ok: bool) -> void:
	if ok:
		show_debug("✅ ACERTO")
	else:
		show_debug("❌ FALLO")

# ------------------------------------------------------------
# UTIL
# ------------------------------------------------------------
func _translate(key_or_text: String) -> String:
	# Si TextDB existe y tiene t(), intentamos traducir siempre.
	# Si el string NO está en diccionario, TextDB devolverá [key]
	# pero aquí evitamos eso detectando si NO es key "con pinta de key".
	if _textdb != null and _textdb.has_method("t"):
		# heurística suave: si tiene "." asumimos key
		if key_or_text.find(".") != -1:
			return String(_textdb.call("t", key_or_text))
	return key_or_text
