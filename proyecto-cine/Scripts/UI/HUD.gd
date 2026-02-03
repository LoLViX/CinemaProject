extends CanvasLayer
class_name HUD

# ============================================================
# HUD.gd (REEMPLAZO COMPLETO)
# - Prompt arriba-centro (NO abajo)
# - Prompt traducido con TextDB
# - Bocadillo centrado
# - Debug arriba-derecha
# ============================================================

# (opcionales) labels que ya existían en tu UI por el report
const ABS_DEBUG_LABEL_1: String = "/root/Main/UI/@Label@36"
const ABS_DEBUG_LABEL_2: String = "/root/Main/UI/@Label@37"

var _textdb: Node = null

# prompt arriba
var _prompt_label: Label = null

# bocadillo
var _bubble: Panel = null
var _bubble_label: Label = null

# debug
var _debug_label: Label = null

func _ready() -> void:
	_textdb = get_tree().root.get_node_or_null("TextDB")

	# debug (si existe en escena)
	_debug_label = get_node_or_null(ABS_DEBUG_LABEL_1) as Label
	if _debug_label == null:
		_debug_label = get_node_or_null(ABS_DEBUG_LABEL_2) as Label

	# si no existe, lo creo
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

	_ensure_prompt()
	_ensure_bubble()

	hide_prompt()
	hide_bubble()

# ------------------------------------------------------------
# PROMPT ARRIBA (E para atender)
# ------------------------------------------------------------
func _ensure_prompt() -> void:
	if _prompt_label != null and is_instance_valid(_prompt_label):
		return

	_prompt_label = Label.new()
	add_child(_prompt_label)
	_prompt_label.name = "PromptLabel"
	_prompt_label.visible = false

	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 0.02
	_prompt_label.anchor_bottom = 0.02
	_prompt_label.offset_left = -420
	_prompt_label.offset_right = 420
	_prompt_label.offset_top = 0
	_prompt_label.offset_bottom = 34

	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF

func show_prompt(text_or_key: String) -> void:
	_ensure_prompt()
	_prompt_label.text = _t(text_or_key)
	_prompt_label.visible = true

func hide_prompt() -> void:
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.visible = false

# ------------------------------------------------------------
# BOCADILLO / TEXTO CLIENTE CENTRO
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
	_bubble_label.text = _t(text_or_key)
	_bubble.visible = true

func hide_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.visible = false

# ------------------------------------------------------------
# DEBUG ARRIBA-DERECHA
# ------------------------------------------------------------
func show_debug(msg: String) -> void:
	if _debug_label == null or not is_instance_valid(_debug_label):
		return
	_debug_label.text = msg

func clear_debug() -> void:
	show_debug("")

func set_result(ok: bool) -> void:
	show_debug("✅ ACERTO" if ok else "❌ FALLO")

# ------------------------------------------------------------
# Traducción (TextDB)
# ------------------------------------------------------------
func _t(key_or_text: String) -> String:
	if _textdb != null and _textdb.has_method("t"):
		if key_or_text.find(".") != -1:
			return String(_textdb.call("t", key_or_text))
	return key_or_text
