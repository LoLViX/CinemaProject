extends Node
# CustomerOrderHUD.gd
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

func _ready() -> void:
	_build_panel()

func _build_panel() -> void:
	_panel = get_node_or_null(PANEL_NAME) as Panel
	if _panel == null:
		_panel = Panel.new()
		_panel.name = PANEL_NAME
		add_child(_panel)

	_panel.visible = false

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
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

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

	_maybe_add_row(items_box, "drink",    "Bebida")
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

func refresh(tray_state: Dictionary) -> void:
	if _order.is_empty() or _panel == null or not _panel.visible:
		return

	# Actualizar filas existentes (pedidas)
	for key in _rows.keys():
		var lbl := _rows[key] as Label
		if lbl == null or not is_instance_valid(lbl):
			continue
		var has_it := _item_satisfied(key, tray_state)
		var name_text := _row_label(key)
		if has_it:
			lbl.text = "V " + name_text
			lbl.modulate = Color(0.4, 1.0, 0.4)
		else:
			lbl.text = "X " + name_text
			lbl.modulate = Color(1.0, 0.35, 0.35)

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
		elif _order.get(key, false):
			continue  # estaba pedido, no es extra
		else:
			_add_extra_row(items_box, "EXTRA_" + key, String(extra_checks[key][1]))

func is_complete(tray_state: Dictionary) -> bool:
	for key in _rows.keys():
		if not _item_satisfied(key, tray_state):
			return false
	return true

func missing_count(tray_state: Dictionary) -> int:
	var count := 0
	for key in _rows.keys():
		if not _item_satisfied(key, tray_state):
			count += 1
	return count

# ──────────────────────────────────────────────────────────────
# Internos
# ──────────────────────────────────────────────────────────────

func _maybe_add_row(parent: VBoxContainer, key: String, label_text: String) -> void:
	if not _order.get(key, false) and key != "food":
		return
	if key == "food" and _order.get("food", "") == "":
		return
	var lbl := Label.new()
	lbl.text = "X " + label_text
	lbl.modulate = Color(1.0, 0.35, 0.35)
	lbl.add_theme_font_size_override("font_size", 13)
	parent.add_child(lbl)
	_rows[key] = lbl

func _row_label(key: String) -> String:
	match key:
		"drink":    return "Bebida"
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
	lbl.modulate = Color(1.0, 0.6, 0.1)  # naranja para "sobra"
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)

func _item_satisfied(key: String, tray: Dictionary) -> bool:
	match key:
		"drink":   return bool(tray.get("drink",   false))
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
