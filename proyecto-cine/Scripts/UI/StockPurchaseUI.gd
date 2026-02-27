extends CanvasLayer
class_name StockPurchaseUI
# ============================================================
# StockPurchaseUI.gd — Panel de compra de stock entre días.
# Se muestra tras el último cliente, antes de EndOfDayUI.
# ============================================================

signal purchase_confirmed(cost: int)

# Solo los items comprables (los toppings son siempre ilimitados)
const PURCHASABLE: Array[String] = ["cola", "orange", "rootbeer", "popcorn", "hotdog", "chocolate"]
const LABELS: Dictionary = {
	"cola":      "COLA",
	"orange":    "NARANJADA",
	"rootbeer":  "ROOT BEER",
	"popcorn":   "PALOMITAS",
	"hotdog":    "HOTDOG",
	"chocolate": "CHOCOLATE",
}

var _summary: Dictionary = {}
var _orders: Dictionary = {}   # item → qty para mañana
var _total_label: Label = null
var _confirm_btn: Button = null
var _panel: Panel = null

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

## Inicializa y muestra el panel con el resumen del día.
func show_purchase(summary: Dictionary) -> void:
	_summary = summary
	for item in PURCHASABLE:
		if RunState.last_stock_orders.has(item):
			# Días 2+ → lo que se pidió ayer (elección explícita del jugador)
			_orders[item] = int(RunState.last_stock_orders[item])
		else:
			# Día 1: empezar en 0, el jugador decide cuánto compra
			_orders[item] = 0
	_build_ui()
	_refresh_total()

# ── Construcción UI ──────────────────────────────────────────

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -380
	_panel.offset_right  =  380
	_panel.offset_top    = -340
	_panel.offset_bottom =  340
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 28; vb.offset_right = -28
	vb.offset_top  = 22; vb.offset_bottom = -22
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	# Título
	var title := Label.new()
	title.text = "APROVISIONAMIENTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UITheme.C_GOLD)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "Elige el stock para mañana. Lo que no se venda se pierde."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UITheme.C_CREAM_D)
	vb.add_child(sub)

	vb.add_child(UITheme.gold_separator())

	# Cabecera de columnas
	vb.add_child(_make_header())

	vb.add_child(UITheme.gold_separator())

	# Filas por producto
	for item in PURCHASABLE:
		vb.add_child(_make_item_row(item))

	vb.add_child(UITheme.gold_separator())

	# Fila de total
	var total_row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(spacer)
	_total_label = Label.new()
	_total_label.add_theme_font_size_override("font_size", 17)
	_total_label.add_theme_color_override("font_color", UITheme.C_GOLD)
	total_row.add_child(_total_label)
	vb.add_child(total_row)

	# Botón confirmar
	_confirm_btn = Button.new()
	_confirm_btn.text = "CONFIRMAR PEDIDO  ▶"
	_confirm_btn.custom_minimum_size = Vector2(0, 48)
	_confirm_btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	_confirm_btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	_confirm_btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	_confirm_btn.add_theme_color_override("font_color", UITheme.C_CREAM)
	_confirm_btn.add_theme_font_size_override("font_size", 17)
	_confirm_btn.pressed.connect(_on_confirm)
	vb.add_child(_confirm_btn)

func _make_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	_col_label(row, "PRODUCTO",     UITheme.C_CREAM_D, true,  0)
	_col_label(row, "VENDIDO",      UITheme.C_CREAM_D, false, 70,  HORIZONTAL_ALIGNMENT_CENTER)
	_col_label(row, "DESPERDICIO",  UITheme.C_CREAM_D, false, 90,  HORIZONTAL_ALIGNMENT_CENTER)
	_col_label(row, "MAÑANA",       UITheme.C_CREAM_D, false, 110, HORIZONTAL_ALIGNMENT_CENTER)
	_col_label(row, "COSTE",        UITheme.C_CREAM_D, false, 70,  HORIZONTAL_ALIGNMENT_RIGHT)
	return row

func _make_item_row(item: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var data: Dictionary = _summary.get(item, {})
	var sold:   int = int(data.get("sold",   0))
	var wasted: int = int(data.get("wasted", 0))
	var cost_u: int = int(data.get("cost_per_unit", 0))

	# Nombre (expansivo)
	_col_label(row, LABELS.get(item, item), UITheme.C_CREAM, true, 0)

	# Vendido
	_col_label(row, str(sold), UITheme.C_GREEN, false, 70, HORIZONTAL_ALIGNMENT_CENTER)

	# Desperdiciado
	var waste_col := UITheme.C_RED if wasted > 0 else UITheme.C_CREAM_D
	_col_label(row, str(wasted), waste_col, false, 90, HORIZONTAL_ALIGNMENT_CENTER)

	# Controles cantidad mañana
	var qty_hb := HBoxContainer.new()
	qty_hb.custom_minimum_size = Vector2(110, 0)
	qty_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_hb.add_theme_constant_override("separation", 2)

	var btn_minus := Button.new()
	btn_minus.text = "−"
	btn_minus.custom_minimum_size = Vector2(26, 26)
	btn_minus.pressed.connect(func(): _change_qty(item, -1))
	qty_hb.add_child(btn_minus)

	var qty_lbl := Label.new()
	qty_lbl.name = "Qty_" + item
	qty_lbl.text = str(_orders.get(item, 0))
	qty_lbl.custom_minimum_size = Vector2(42, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.add_theme_font_size_override("font_size", 15)
	qty_lbl.add_theme_color_override("font_color", UITheme.C_CREAM)
	qty_hb.add_child(qty_lbl)

	var btn_plus := Button.new()
	btn_plus.text = "+"
	btn_plus.custom_minimum_size = Vector2(26, 26)
	btn_plus.pressed.connect(func(): _change_qty(item, +1))
	qty_hb.add_child(btn_plus)

	row.add_child(qty_hb)

	# Coste de línea
	var cost_lbl := Label.new()
	cost_lbl.name = "Cost_" + item
	cost_lbl.text = "$%d" % (cost_u * _orders.get(item, 0))
	cost_lbl.custom_minimum_size = Vector2(70, 0)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.add_theme_font_size_override("font_size", 15)
	cost_lbl.add_theme_color_override("font_color", UITheme.C_CREAM_D)
	row.add_child(cost_lbl)

	return row

func _col_label(parent: HBoxContainer, text: String, color: Color,
		expand: bool, min_w: int,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		lbl.custom_minimum_size = Vector2(min_w, 0)
	parent.add_child(lbl)
	return lbl

# ── Lógica ───────────────────────────────────────────────────

func _change_qty(item: String, delta: int) -> void:
	_orders[item] = max(0, int(_orders.get(item, 0)) + delta)

	var qty_lbl := _panel.find_child("Qty_" + item, true, false) as Label
	if qty_lbl:
		qty_lbl.text = str(_orders[item])

	var cost_lbl := _panel.find_child("Cost_" + item, true, false) as Label
	if cost_lbl:
		var cost_u: int = int(_summary.get(item, {}).get("cost_per_unit", 0))
		cost_lbl.text = "$%d" % (cost_u * _orders[item])

	_refresh_total()

func _refresh_total() -> void:
	var total := 0
	for item in PURCHASABLE:
		var cost_u: int = int(_summary.get(item, {}).get("cost_per_unit", 0))
		total += cost_u * int(_orders.get(item, 0))

	if _total_label:
		_total_label.text = "TOTAL: $%d   (Disponible: $%d)" % [total, RunState.total_money]

	if _confirm_btn:
		_confirm_btn.disabled = total > RunState.total_money

func _on_confirm() -> void:
	SoundManager.play_click()
	# Guardar cantidades para el día siguiente
	RunState.last_stock_orders = _orders.duplicate()
	var cost := StockManager.purchase_batch(_orders)
	if cost < 0:
		return  # Sin fondos (no debería ocurrir si el botón está habilitado)

	# Comprobar si el gasto activó algún final
	EndingManager.check()
	if EndingManager.is_ended():
		return  # EndingManager toma el control

	emit_signal("purchase_confirmed", cost)
