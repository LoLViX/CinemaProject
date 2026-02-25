extends CanvasLayer
class_name EndOfDayUI
# ============================================================
# EndOfDayUI.gd — Pantalla de resultados al final del día
# ============================================================
# Uso: instanciar, añadir a escena, llamar show_results(), conectar next_day_requested.

signal next_day_requested

# ── Paleta Cinema 80s ────────────────────────────────────────
const C_BG       := Color(0.10, 0.04, 0.04, 0.96)
const C_GOLD     := Color(0.95, 0.76, 0.15)
const C_CREAM    := Color(0.97, 0.93, 0.80)
const C_CREAM_D  := Color(0.80, 0.75, 0.60)
const C_RED      := Color(0.70, 0.06, 0.06)
const C_GREEN    := Color(0.20, 0.85, 0.30)

# Colores de rating
const RATING_COLORS := {
	"EXCELENTE": Color(0.20, 0.95, 0.35),
	"BUENO":     Color(0.60, 0.90, 0.20),
	"REGULAR":   Color(0.95, 0.76, 0.15),
	"MAL DÍA":   Color(1.00, 0.30, 0.30),
	"SIN DATOS": Color(0.60, 0.60, 0.60),
}

var _panel: Panel = null

func _ready() -> void:
	layer = 10   # Por encima de todo
	_build_ui()

func _build_ui() -> void:
	# Overlay oscuro de fondo
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.anchor_left   = 0.0
	overlay.anchor_right  = 1.0
	overlay.anchor_top    = 0.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)

	# Panel central
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -240
	_panel.offset_right  =  240
	_panel.offset_top    = -220
	_panel.offset_bottom =  220
	add_child(_panel)

	# VBox interior
	var vb := VBoxContainer.new()
	vb.anchor_left = 0.0; vb.anchor_right = 1.0
	vb.anchor_top  = 0.0; vb.anchor_bottom = 1.0
	vb.offset_left = 28; vb.offset_right  = -28
	vb.offset_top  = 22; vb.offset_bottom = -22
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)

	# Título
	var title := Label.new()
	title.name = "Title"
	title.text = "FIN DEL DÍA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_GOLD)
	vb.add_child(title)

	vb.add_child(UITheme.gold_separator())

	# Estadísticas (se rellenan en show_results)
	var stats_lbl := Label.new()
	stats_lbl.name = "Stats"
	stats_lbl.text = ""
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_lbl.add_theme_font_size_override("font_size", 16)
	stats_lbl.add_theme_color_override("font_color", C_CREAM)
	vb.add_child(stats_lbl)

	# Badge de rating
	var rating_lbl := Label.new()
	rating_lbl.name = "Rating"
	rating_lbl.text = ""
	rating_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_lbl.add_theme_font_size_override("font_size", 28)
	rating_lbl.add_theme_color_override("font_color", C_GOLD)
	vb.add_child(rating_lbl)

	# Dinero
	var money_lbl := Label.new()
	money_lbl.name = "Money"
	money_lbl.text = ""
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_lbl.add_theme_font_size_override("font_size", 20)
	money_lbl.add_theme_color_override("font_color", C_GREEN)
	vb.add_child(money_lbl)

	# Acumulado
	var total_lbl := Label.new()
	total_lbl.name = "Total"
	total_lbl.text = ""
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.add_theme_font_size_override("font_size", 13)
	total_lbl.add_theme_color_override("font_color", C_CREAM_D)
	vb.add_child(total_lbl)

	vb.add_child(UITheme.gold_separator())

	# Botón siguiente día
	var btn := Button.new()
	btn.name = "NextBtn"
	btn.text = "SIGUIENTE DÍA  ▶"
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	btn.add_theme_color_override("font_color", C_CREAM)
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(_on_next_pressed)
	vb.add_child(btn)

# ── API pública ──────────────────────────────────────────────

## Muestra los resultados del día.
func show_results(day: int, hits: int, total_customers: int, money: int, rating: String) -> void:
	if _panel == null:
		_build_ui()

	var title := _panel.get_node_or_null("VBox/Title") as Label  # no funciona directo
	# Buscar por nombre dentro del árbol del panel
	var vb := _panel.get_child(0)  # VBoxContainer

	_set_label(vb, "Title",  "FIN DEL DÍA %d" % day)

	var misses := total_customers - hits
	var stats := "Clientes atendidos: %d\nAciertos: %d  |  Fallos: %d" % [total_customers, hits, misses]
	_set_label(vb, "Stats",  stats)

	_set_label(vb, "Rating", rating)
	var rc: Color = RATING_COLORS.get(rating, C_GOLD)
	var r_lbl := _find_label(vb, "Rating")
	if r_lbl != null:
		r_lbl.add_theme_color_override("font_color", rc)

	_set_label(vb, "Money",  "Propinas hoy: $%d" % money)
	_set_label(vb, "Total",  "Acumulado total: $%d" % RunState.total_money)

	# Sonido de fin de día
	SoundManager.play_success()

	visible = true

# ── Internos ────────────────────────────────────────────────

func _find_label(parent: Node, lbl_name: String) -> Label:
	for ch in parent.get_children():
		if ch.name == lbl_name and ch is Label:
			return ch as Label
	return null

func _set_label(parent: Node, lbl_name: String, text: String) -> void:
	var lbl := _find_label(parent, lbl_name)
	if lbl != null:
		lbl.text = text

func _on_next_pressed() -> void:
	SoundManager.play_click()
	emit_signal("next_day_requested")
