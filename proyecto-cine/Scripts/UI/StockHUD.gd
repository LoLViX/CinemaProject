extends Node
class_name StockHUD

# ── Cinema 80s palette ──────────────────────────────────────────────────────
const C_BG    := Color(0.10, 0.04, 0.04, 0.96)
const C_GOLD  := Color(0.95, 0.76, 0.15)
const C_CREAM := Color(0.97, 0.93, 0.80)
const C_CREAM_D := Color(0.80, 0.75, 0.60)

# Orden y nombres "bonitos" (luego lo pasaremos a TextDB ids)
const ORDER: Array[String] = ["popcorn", "hotdog", "chocolate", "cup", "ketchup", "mustard", "butter", "caramel"]

const LABELS := {
	"popcorn":  "PALOMITAS",
	"hotdog":   "HOTDOG",
	"chocolate":"CHOCOLATE",
	"cup":      "VASOS",
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
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(panel)

	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = 240
	panel.offset_bottom = 18 + 32 + (ORDER.size() * 22) + 18

	var v := VBoxContainer.new()
	panel.add_child(v)
	v.anchor_left = 0.0
	v.anchor_right = 1.0
	v.anchor_top = 0.0
	v.anchor_bottom = 1.0
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 5)

	var title := Label.new()
	title.text = "STOCK"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C_GOLD)
	v.add_child(title)

	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = Color(0.95, 0.76, 0.15, 0.40)
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	v.add_child(sep)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)

	# Rows
	for id in ORDER:
		var left := Label.new()
		left.text = LABELS.get(id, id).capitalize()
		left.add_theme_font_size_override("font_size", 12)
		left.add_theme_color_override("font_color", C_CREAM_D)
		grid.add_child(left)

		var right := Label.new()
		right.text = "x0"
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_theme_font_size_override("font_size", 12)
		right.add_theme_color_override("font_color", C_CREAM)
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
