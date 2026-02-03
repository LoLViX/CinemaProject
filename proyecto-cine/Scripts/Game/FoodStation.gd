extends Node
class_name FoodStation

# RUTAS ABSOLUTAS (según tu report)
const ABS_TRAY: String = "/root/Main/FoodArea/TrayPreview/Tray"
const ABS_UI: String = "/root/Main/UI"
const ABS_STOCK_HUD: String = "/root/Main/UI/StockHUD"

# Pickups (comida)
const ABS_PICK_POP: String = "/root/Main/FoodArea/Pickups/PopcornPickup"
const ABS_PICK_HOT: String = "/root/Main/FoodArea/Pickups/HotdogPickup"
const ABS_PICK_CHO: String = "/root/Main/FoodArea/Pickups/ChocolatePickup"

# Toppings pickups
const ABS_TOP_KETCHUP: String = "/root/Main/FoodArea/Toppings/KetchupPickup"
const ABS_TOP_MUSTARD: String = "/root/Main/FoodArea/Toppings/MustardPickup"
const ABS_TOP_BUTTER: String = "/root/Main/FoodArea/Toppings/ButterPickup"
const ABS_TOP_CARAMEL: String = "/root/Main/FoodArea/Toppings/CaramelPickup"

# Estado
var tray: Tray = null
var ui: Node = null
var stock_hud: Node = null

# Stock base (día 1)
var stock: Dictionary = {
	"popcorn": 10,
	"hotdog": 10,
	"chocolate": 10,
	"ketchup": 0,
	"mustard": 0,
	"butter": 0,
	"caramel": 0
}

# Labels 3D (StockLabel) que has puesto
var _label_pop: Label3D = null
var _label_hot: Label3D = null
var _label_cho: Label3D = null
var _label_k: Label3D = null
var _label_m: Label3D = null
var _label_b: Label3D = null
var _label_c: Label3D = null

func _ready() -> void:
	tray = get_node_or_null(ABS_TRAY) as Tray
	ui = get_node_or_null(ABS_UI)
	stock_hud = get_node_or_null(ABS_STOCK_HUD)

	if tray == null:
		push_error("FoodStation: no encuentro Tray en " + ABS_TRAY)
		return

	# Conectar areas
	_connect_pickup(ABS_PICK_POP, Callable(self, "_take_popcorn"))
	_connect_pickup(ABS_PICK_HOT, Callable(self, "_take_hotdog"))
	_connect_pickup(ABS_PICK_CHO, Callable(self, "_take_chocolate"))

	_connect_pickup(ABS_TOP_KETCHUP, Callable(self, "_add_ketchup"))
	_connect_pickup(ABS_TOP_MUSTARD, Callable(self, "_add_mustard"))
	_connect_pickup(ABS_TOP_BUTTER, Callable(self, "_set_butter"))
	_connect_pickup(ABS_TOP_CARAMEL, Callable(self, "_set_caramel"))

	# Cache labels 3D (StockLabel)
	_label_pop = _get_stock_label(ABS_PICK_POP)
	_label_hot = _get_stock_label(ABS_PICK_HOT)
	_label_cho = _get_stock_label(ABS_PICK_CHO)

	_label_k = _get_stock_label(ABS_TOP_KETCHUP)
	_label_m = _get_stock_label(ABS_TOP_MUSTARD)
	_label_b = _get_stock_label(ABS_TOP_BUTTER)
	_label_c = _get_stock_label(ABS_TOP_CARAMEL)

	_push_stock()

func _connect_pickup(abs_path: String, cb: Callable) -> void:
	var a := get_node_or_null(abs_path) as Area3D
	if a == null:
		push_error("FoodStation: no encuentro Area3D " + abs_path)
		return
	if not a.input_event.is_connected(cb):
		a.input_event.connect(func(_camera, _event, _pos, _normal, _shape):
			# Solo click izquierdo
			if _event is InputEventMouseButton and _event.button_index == MOUSE_BUTTON_LEFT and _event.pressed:
				cb.call()
		)

func _get_stock_label(abs_area_path: String) -> Label3D:
	var a := get_node_or_null(abs_area_path) as Node
	if a == null:
		return null
	var lbl := a.get_node_or_null("StockLabel") as Label3D
	return lbl

# ---------------------------
# Acciones: comida
# ---------------------------
func _take_popcorn() -> void:
	if int(stock["popcorn"]) <= 0:
		_debug("SIN STOCK: palomitas")
		return
	if tray.has_popcorn():
		_debug("Ya hay palomitas (tira el slot para cambiar)")
		return
	var ok := tray.set_popcorn()
	if ok:
		stock["popcorn"] = int(stock["popcorn"]) - 1
		_push_stock()

func _take_hotdog() -> void:
	if int(stock["hotdog"]) <= 0:
		_debug("SIN STOCK: hotdog")
		return
	# Si ya hay food, lo reemplaza (hotdog/chocolate comparten slot)
	var ok := tray.set_food_hotdog()
	if ok:
		stock["hotdog"] = int(stock["hotdog"]) - 1
		_push_stock()

func _take_chocolate() -> void:
	if int(stock["chocolate"]) <= 0:
		_debug("SIN STOCK: chocolate")
		return
	var ok := tray.set_food_chocolate()
	if ok:
		stock["chocolate"] = int(stock["chocolate"]) - 1
		_push_stock()

# ---------------------------
# Acciones: toppings
# ---------------------------
func _add_ketchup() -> void:
	# Hotdog: permite 1 o 2 toppings. Se quedan. Si ya está, no hace nada.
	if int(stock["ketchup"]) <= 0:
		_debug("SIN STOCK: ketchup")
		return
	var applied = tray.add_ketchup() # OJO: "=" no ":="
	if not applied:
		_debug("Ketchup no aplicable (necesitas hotdog / ya puesto)")
		return
	stock["ketchup"] = int(stock["ketchup"]) - 1
	_push_stock()

func _add_mustard() -> void:
	if int(stock["mustard"]) <= 0:
		_debug("SIN STOCK: mostaza")
		return
	var applied = tray.add_mustard()
	if not applied:
		_debug("Mostaza no aplicable (necesitas hotdog / ya puesta)")
		return
	stock["mustard"] = int(stock["mustard"]) - 1
	_push_stock()

func _set_butter() -> void:
	if int(stock["butter"]) <= 0:
		_debug("SIN STOCK: mantequilla")
		return
	var applied = tray.set_popcorn_topping("butter")
	if not applied:
		_debug("Mantequilla: necesitas palomitas / ya está puesta")
		return
	stock["butter"] = int(stock["butter"]) - 1
	_push_stock()

func _set_caramel() -> void:
	if int(stock["caramel"]) <= 0:
		_debug("SIN STOCK: caramelo")
		return
	var applied = tray.set_popcorn_topping("caramel")
	if not applied:
		_debug("Caramelo: necesitas palomitas / ya está puesto")
		return
	stock["caramel"] = int(stock["caramel"]) - 1
	_push_stock()

# ---------------------------
# UI / Labels
# ---------------------------
func _push_stock() -> void:
	# HUD 2D (StockHUD) si existe método
	if stock_hud != null and stock_hud.has_method("set_stock"):
		stock_hud.call("set_stock", stock)

	# Labels 3D
	if _label_pop: _label_pop.text = "x" + str(stock["popcorn"])
	if _label_hot: _label_hot.text = "x" + str(stock["hotdog"])
	if _label_cho: _label_cho.text = "x" + str(stock["chocolate"])
	if _label_k: _label_k.text = "x" + str(stock["ketchup"])
	if _label_m: _label_m.text = "x" + str(stock["mustard"])
	if _label_b: _label_b.text = "x" + str(stock["butter"])
	if _label_c: _label_c.text = "x" + str(stock["caramel"])

func _debug(msg: String) -> void:
	# Intento usar tu UI show_debug si está
	if ui != null and ui.has_method("show_debug"):
		ui.call("show_debug", "DEBUG: " + msg)
	else:
		print("DEBUG: " + msg)
