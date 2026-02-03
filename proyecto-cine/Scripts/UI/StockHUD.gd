extends Node
class_name StockHUD

# Orden y nombres “bonitos” (luego lo pasaremos a TextDB ids)
const ORDER: Array[String] = ["popcorn", "hotdog", "chocolate", "ketchup", "mustard", "butter", "caramel"]

const LABELS := {
	"popcorn":  "PALOMITAS",
	"hotdog":   "HOTDOG",
	"chocolate":"CHOCOLATE",
	"ketchup":  "KETCHUP",
	"mustard":  "MOSTAZA",
	"butter":   "MANTEQUILLA",
	"caramel":  "CARAMELO",
}

var panel: Panel = null
var rows: Dictionary = {} # id -> Label

func _ready() -> void:
	_build_ui()
	hide_stock()

func _build_ui() -> void:
	# Panel
	panel = Panel.new()
	add_child(panel)

	# Anchor arriba-izquierda (puedes mover offsets cuando quieras)
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = 260
	panel.offset_bottom = 18 + 32 + (ORDER.size() * 22) + 18

	var v := VBoxContainer.new()
	panel.add_child(v)
	v.anchor_left = 0.0
	v.anchor_right = 1.0
	v.anchor_top = 0.0
	v.anchor_bottom = 1.0
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "STOCK"
	title.add_theme_font_size_override("font_size", 14)
	v.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)

	# Rows
	for id in ORDER:
		var left := Label.new()
		left.text = LABELS.get(id, id).capitalize()
		left.add_theme_font_size_override("font_size", 12)
		grid.add_child(left)

		var right := Label.new()
		right.text = "x0"
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_theme_font_size_override("font_size", 12)
		grid.add_child(right)

		rows[id] = right

func show_stock() -> void:
	if panel: panel.visible = true

func hide_stock() -> void:
	if panel: panel.visible = false

func set_stock(stock: Dictionary) -> void:
	# stock: { "hotdog": 8, "popcorn": 4, ... }
	for id in rows.keys():
		var qty: int = int(stock.get(id, 0))
		_set_row(id, qty)

func set_item(id: String, qty: int) -> void:
	_set_row(id, qty)

func add_item(id: String, delta: int) -> void:
	var current: int = get_item(id)
	_set_row(id, current + delta)

func get_item(id: String) -> int:
	if not rows.has(id):
		return 0
	var t: String = (rows[id] as Label).text
	# formato "x12"
	if t.begins_with("x"):
		return int(t.substr(1))
	return int(t)

func _set_row(id: String, qty: int) -> void:
	if not rows.has(id):
		return
	(rows[id] as Label).text = "x%d" % max(qty, 0)
