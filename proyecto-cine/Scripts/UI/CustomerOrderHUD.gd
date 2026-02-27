extends Node
# CustomerOrderHUD.gd

# ── Cinema 80s palette ──────────────────────────────────────────────────────
const C_BG   := Color(0.10, 0.04, 0.04, 0.96)
const C_GOLD := Color(0.95, 0.76, 0.15)
const C_CREAM := Color(0.97, 0.93, 0.80)
# Muestra el pedido de comida del cliente con checkmarks por item.
# API:
#   show_order(order: Dictionary)   -> muestra el pedido con todo en rojo
#   refresh(tray_state: Dictionary) -> actualiza los checks segun la bandeja
#   hide_order()                    -> oculta el panel
#   is_complete(tray_state) -> bool
#   missing_count(tray_state) -> int

const PANEL_NAME := "OrderHUDPanel"

var _panel: Panel = null
var _rows: Dictionary = {}   # key -> Label
var _order: Dictionary = {}
var _complete_shown: bool = false   # evita reproducir sonido más de una vez

func _ready() -> void:
	_build_panel()

func _build_panel() -> void:
	_panel = get_node_or_null(PANEL_NAME) as Panel
	if _panel == null:
		_panel = Panel.new()
		_panel.name = PANEL_NAME
		add_child(_panel)

	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())

	# Esquina superior derecha
	_panel.anchor_left   = 1.0
	_panel.anchor_right  = 1.0
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = -260
	_panel.offset_right  =  -10
	_panel.offset_top    =   80
	_panel.offset_bottom =  320

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	_panel.add_child(vbox)
	vbox.anchor_left   = 0.0
	vbox.anchor_right  = 1.0
	vbox.anchor_top    = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left   =  12
	vbox.offset_right  = -12
	vbox.offset_top    =  10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.name = "Title"
	title.text = "PEDIDO:"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(title)

	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = Color(0.95, 0.76, 0.15, 0.40)
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	vbox.add_child(sep)

	var items_box := VBoxContainer.new()
	items_box.name = "ItemsBox"
	items_box.add_theme_constant_override("separation", 5)
	vbox.add_child(items_box)

# ──────────────────────────────────────────────────────────────
# API publica
# ──────────────────────────────────────────────────────────────

func show_order(order: Dictionary) -> void:
	_order = order
	_rows.clear()

	if _panel == null:
		_build_panel()

	var items_box := _panel.get_node_or_null("VBox/ItemsBox") as VBoxContainer
	if items_box == null:
		return

	for ch in items_box.get_children():
		ch.queue_free()

	_maybe_add_row(items_box, "drink",    _drink_label(_order.get("drink_type", "")))
	_maybe_add_row(items_box, "popcorn",  "Palomitas")
	if order.get("butter",  false): _maybe_add_row(items_box, "butter",  "+ Mantequilla")
	if order.get("caramel", false): _maybe_add_row(items_box, "caramel", "+ Caramelo")

	var food_type: String = order.get("food", "")
	if food_type == "hotdog":
		_maybe_add_row(items_box, "food",    "Hotdog")
		if order.get("ketchup", false): _maybe_add_row(items_box, "ketchup", "+ Ketchup")
		if order.get("mustard", false): _maybe_add_row(items_box, "mustard", "+ Mostaza")
	elif food_type == "chocolate":
		_maybe_add_row(items_box, "food", "Chocolate")

	_panel.visible = true

func hide_order() -> void:
	if _panel != null:
		_panel.visible = false
	_rows.clear()
	_order = {}
	_complete_shown = false

func refresh(tray_state: Dictionary) -> void:
	if _order.is_empty() or _panel == null or not _panel.visible:
		return

	# Feedback visual: borde verde si pedido completo, dorado si no
	if is_complete(tray_state):
		_panel.add_theme_stylebox_override("panel", _complete_style())
		if not _complete_shown:
			_complete_shown = true
			SoundManager.play_complete()
	else:
		_complete_shown = false
		_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())

	# Actualizar filas existentes (pedidas)
	for key in _rows.keys():
		var lbl := _rows[key] as Label
		if lbl == null or not is_instance_valid(lbl):
			continue
		var has_it := _item_satisfied(key, tray_state)
		var name_text := _row_label(key)
		if has_it:
			lbl.text = "✓ " + name_text
			lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
		else:
			lbl.text = "✗ " + name_text
			lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))

	# Mostrar extras NO pedidos
	var items_box := _panel.get_node_or_null("VBox/ItemsBox") as VBoxContainer
	if items_box == null:
		return

	# Limpiar filas de extras anteriores
	for ch in items_box.get_children():
		if ch.name.begins_with("EXTRA_"):
			ch.queue_free()

	# Comprobar cada item posible: si esta en bandeja pero NO fue pedido
	var extra_checks := {
		"drink":    ["drink",   "Bebida (no pedida)"],
		"popcorn":  ["popcorn", "Palomitas (no pedidas)"],
		"food":     ["food",    ""],
		"ketchup":  ["ketchup", "Ketchup (no pedido)"],
		"mustard":  ["mustard", "Mostaza (no pedida)"],
		"butter":   ["butter",  "Mantequilla (no pedida)"],
		"caramel":  ["caramel", "Caramelo (no pedido)"],
	}

	for key in extra_checks.keys():
		var in_tray := _item_in_tray(key, tray_state)
		if not in_tray:
			continue
		# Si ya estaba en el pedido, no es extra
		if key == "food":
			var ordered_food: String = _order.get("food", "")
			var tray_food: String = String(tray_state.get("food", "")).to_lower()
			if ordered_food != "" and tray_food.contains(ordered_food):
				continue
			if tray_food == "":
				continue
			# Es una comida no pedida
			var food_name := "Hotdog" if tray_food.contains("hotdog") else "Chocolate"
			_add_extra_row(items_box, "EXTRA_food", food_name + " (no pedido)")
		elif key == "drink" and _order.get("drink", false):
			# Bebida pedida: comprobar que el tipo coincide
			var ordered_type: String = _order.get("drink_type", "")
			var placed_type: String  = String(tray_state.get("drink_type", ""))
			if ordered_type == "" or placed_type == ordered_type:
				continue  # tipo correcto o sin tipo especificado → no es extra
			# Tipo incorrecto → avisar
			_add_extra_row(items_box, "EXTRA_drink", _drink_label(placed_type) + " (no pedida)")
		elif _order.get(key, false):
			continue  # estaba pedido, no es extra
		else:
			_add_extra_row(items_box, "EXTRA_" + key, String(extra_checks[key][1]))

func is_complete(tray_state: Dictionary) -> bool:
	# Comprobar que todos los items pedidos están en la bandeja
	for key in _rows.keys():
		if not _item_satisfied(key, tray_state):
			return false
	# Comprobar que NO hay extras no pedidos en la bandeja
	if _has_extras(tray_state):
		return false
	return true

func missing_count(tray_state: Dictionary) -> int:
	var count := 0
	for key in _rows.keys():
		if not _item_satisfied(key, tray_state):
			count += 1
	# Items extras también cuentan como error
	if _has_extras(tray_state):
		count += 1
	return count

## Nº de items pedidos que SÍ están correctamente en la bandeja.
func correct_count(tray_state: Dictionary) -> int:
	var count := 0
	for key in _rows.keys():
		if _item_satisfied(key, tray_state):
			count += 1
	return count

## True si la bandeja contiene items que NO fueron pedidos.
func _has_extras(tray_state: Dictionary) -> bool:
	# Bebida no pedida
	if bool(tray_state.get("drink", false)) and not bool(_order.get("drink", false)):
		return true
	# Tipo de bebida incorrecto
	if bool(tray_state.get("drink", false)) and bool(_order.get("drink", false)):
		var otype: String = String(_order.get("drink_type", ""))
		var ptype: String = String(tray_state.get("drink_type", ""))
		if otype != "" and ptype != "" and otype != ptype:
			return true
	# Palomitas no pedidas
	if bool(tray_state.get("popcorn", false)) and not bool(_order.get("popcorn", false)):
		return true
	# Comida no pedida o tipo equivocado
	var tray_food: String = String(tray_state.get("food", ""))
	var order_food: String = String(_order.get("food", ""))
	if tray_food != "" and (order_food == "" or not tray_food.contains(order_food)):
		return true
	# Toppings no pedidos
	if bool(tray_state.get("ketchup", false)) and not bool(_order.get("ketchup", false)):
		return true
	if bool(tray_state.get("mustard", false)) and not bool(_order.get("mustard", false)):
		return true
	if bool(tray_state.get("butter", false)) and not bool(_order.get("butter", false)):
		return true
	if bool(tray_state.get("caramel", false)) and not bool(_order.get("caramel", false)):
		return true
	return false

# ──────────────────────────────────────────────────────────────
# Internos
# ──────────────────────────────────────────────────────────────

func _maybe_add_row(parent: VBoxContainer, key: String, label_text: String) -> void:
	if not _order.get(key, false) and key != "food":
		return
	if key == "food" and _order.get("food", "") == "":
		return
	var lbl := Label.new()
	lbl.text = "✗ " + label_text
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	lbl.add_theme_font_size_override("font_size", 13)
	parent.add_child(lbl)
	_rows[key] = lbl

func _row_label(key: String) -> String:
	match key:
		"drink":    return _drink_label(_order.get("drink_type", ""))
		"popcorn":  return "Palomitas"
		"butter":   return "+ Mantequilla"
		"caramel":  return "+ Caramelo"
		"food":
			var ft: String = _order.get("food", "")
			if ft == "hotdog":     return "Hotdog"
			if ft == "chocolate":  return "Chocolate"
			return "Comida"
		"ketchup":  return "+ Ketchup"
		"mustard":  return "+ Mostaza"
	return key

func _item_in_tray(key: String, tray: Dictionary) -> bool:
	match key:
		"drink":   return bool(tray.get("drink",   false))
		"popcorn": return bool(tray.get("popcorn", false))
		"butter":  return bool(tray.get("butter",  false))
		"caramel": return bool(tray.get("caramel", false))
		"ketchup": return bool(tray.get("ketchup", false))
		"mustard": return bool(tray.get("mustard", false))
		"food":    return String(tray.get("food", "")) != ""
	return false

func _add_extra_row(parent: VBoxContainer, node_name: String, label_text: String) -> void:
	# Evitar duplicados
	if parent.get_node_or_null(node_name) != null:
		return
	var lbl := Label.new()
	lbl.name = node_name
	lbl.text = "! " + label_text
	lbl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.10))
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)

func _complete_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.14, 0.04, 0.96)     # verde oscuro en lugar de burdeos
	sb.border_width_left   = 3
	sb.border_width_right  = 3
	sb.border_width_top    = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.20, 0.95, 0.35)        # verde brillante
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.0, 0.6, 0.2, 0.55)
	sb.shadow_size  = 8
	return sb

func _drink_label(drink_type: String) -> String:
	match drink_type:
		"cola":     return "Cola"
		"orange":   return "Naranjada"
		"rootbeer": return "Root Beer"
	return "Bebida"

func _item_satisfied(key: String, tray: Dictionary) -> bool:
	match key:
		"drink":
			if not bool(tray.get("drink", false)):
				return false
			# Validar que el tipo de bebida coincide con el pedido
			var ordered_type: String = _order.get("drink_type", "")
			if ordered_type == "":
				return true  # no se especificó tipo, cualquier bebida vale
			var placed_type: String = String(tray.get("drink_type", ""))
			return placed_type == ordered_type
		"popcorn": return bool(tray.get("popcorn", false))
		"butter":  return bool(tray.get("butter",  false))
		"caramel": return bool(tray.get("caramel", false))
		"ketchup": return bool(tray.get("ketchup", false))
		"mustard": return bool(tray.get("mustard", false))
		"food":
			var needed: String = _order.get("food", "")
			var got: String    = String(tray.get("food", "")).to_lower()
			return needed != "" and got.contains(needed)
	return false
