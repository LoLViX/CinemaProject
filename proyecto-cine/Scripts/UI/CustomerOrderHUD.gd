extends Node
class_name CustomerOrderHUD

# API:
# set_order({...})
# set_status({...})  # lo que llevas hecho / correcto
# show_hud(true/false)

var panel: Panel
var vbox: VBoxContainer

var row_drink: HBoxContainer
var row_food: HBoxContainer
var row_pop: HBoxContainer

var icon_drink: Label
var text_drink: Label
var mark_drink: Label

var icon_food: Label
var text_food: Label
var mark_food: Label

var icon_pop: Label
var text_pop: Label
var mark_pop: Label

func _ready() -> void:
	_build()

func _build() -> void:
	panel = Panel.new()
	add_child(panel)

	# Panel a la derecha, centrado vertical
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_right = -20
	panel.offset_top = -140
	panel.offset_bottom = 140

	# Look
	panel.modulate = Color(1, 1, 1, 1)
	panel.add_theme_color_override("panel", Color(0,0,0,0.0)) # no afecta, por si acaso

	# Contenido
	vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.anchor_left = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_top = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 14
	vbox.offset_right = -14
	vbox.offset_top = 14
	vbox.offset_bottom = -14
	vbox.add_theme_constant_override("separation", 10)

	# Título
	var title := Label.new()
	title.text = "PEDIDO"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Filas
	row_drink = _make_row("🥤", "Bebida: —")
	icon_drink = row_drink.get_child(0) as Label
	text_drink = row_drink.get_child(1) as Label
	mark_drink = row_drink.get_child(2) as Label
	vbox.add_child(row_drink)

	row_food = _make_row("🌭", "Comida: —")
	icon_food = row_food.get_child(0) as Label
	text_food = row_food.get_child(1) as Label
	mark_food = row_food.get_child(2) as Label
	vbox.add_child(row_food)

	row_pop = _make_row("🍿", "Palomitas: —")
	icon_pop = row_pop.get_child(0) as Label
	text_pop = row_pop.get_child(1) as Label
	mark_pop = row_pop.get_child(2) as Label
	vbox.add_child(row_pop)

	# estilo panel oscuro
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0,0,0,0.72)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sb)

	show_hud(false)

func _make_row(icon: String, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)

	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 16)
	h.add_child(ic)

	var tx := Label.new()
	tx.text = text
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.add_theme_font_size_override("font_size", 14)
	h.add_child(tx)

	var mk := Label.new()
	mk.text = "✖"
	mk.add_theme_font_size_override("font_size", 18)
	mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(mk)

	_set_mark(mk, false, false)
	return h

func show_hud(visible: bool) -> void:
	if panel != null:
		panel.visible = visible

# order example:
# {
#   "drink": "cola" or ""
#   "food": "hotdog" or "chocolate" or ""
#   "food_toppings": ["ketchup","mustard"]
#   "popcorn": true/false
#   "pop_topping": "butter" or "caramel" or ""
# }
func set_order(order: Dictionary) -> void:
	# Bebida
	var d := String(order.get("drink",""))
	if d == "":
		text_drink.text = "Bebida: (ninguna)"
		_set_mark(mark_drink, true, true) # trivial ok
	else:
		text_drink.text = "Bebida: " + _pretty(d)
		_set_mark(mark_drink, false, false) # pendiente

	# Comida
	var f := String(order.get("food",""))
	if f == "":
		text_food.text = "Comida: (ninguna)"
		_set_mark(mark_food, true, true)
	else:
		var tops: Array = order.get("food_toppings", [])
		var extra := ""
		if tops.size() > 0:
			extra = " + " + ", ".join(tops.map(func(x): return _pretty(String(x))))
		text_food.text = "Comida: " + _pretty(f) + extra
		_set_mark(mark_food, false, false)

	# Popcorn
	var p: bool = bool(order.get("popcorn", false))
	if not p:
		text_pop.text = "Palomitas: (no)"
		_set_mark(mark_pop, true, true)
	else:
		var pt := String(order.get("pop_topping",""))
		if pt != "":
			text_pop.text = "Palomitas: " + _pretty(pt)
		else:
			text_pop.text = "Palomitas: (sin topping)"
		_set_mark(mark_pop, false, false)

# status example:
# {
#   "drink_ok": bool,
#   "food_ok": bool,
#   "pop_ok": bool
# }
func set_status(status: Dictionary) -> void:
	if status.has("drink_ok"):
		_set_mark(mark_drink, bool(status["drink_ok"]), false)
	if status.has("food_ok"):
		_set_mark(mark_food, bool(status["food_ok"]), false)
	if status.has("pop_ok"):
		_set_mark(mark_pop, bool(status["pop_ok"]), false)

func _set_mark(lbl: Label, ok: bool, neutral: bool) -> void:
	if neutral:
		lbl.text = "—"
		lbl.add_theme_color_override("font_color", Color(0.7,0.7,0.7))
		return

	if ok:
		lbl.text = "✔"
		lbl.add_theme_color_override("font_color", Color(0.2,0.9,0.3))
	else:
		lbl.text = "✖"
		lbl.add_theme_color_override("font_color", Color(0.95,0.25,0.25))

func _pretty(id: String) -> String:
	match id:
		"cola": return "Cola"
		"orange": return "Naranja"
		"rootbeer": return "Root Beer"
		"hotdog": return "Hot Dog"
		"chocolate": return "Chocolate"
		"ketchup": return "Ketchup"
		"mustard": return "Mostaza"
		"butter": return "Mantequilla"
		"caramel": return "Caramelo"
		_: return id.capitalize()
