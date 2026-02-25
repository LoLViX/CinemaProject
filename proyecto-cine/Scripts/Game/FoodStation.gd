extends Node3D
class_name FoodStation

# === Defaults según tu SceneTree ===
const ABS_TRAY := "/root/Main/FoodArea/TrayPreview/Tray"
const ABS_STOCKHUD := "/root/Main/UI/StockHUD"

const ABS_POPCORN := "/root/Main/FoodArea/Pickups/PopcornPickup"
const ABS_HOTDOG := "/root/Main/FoodArea/Pickups/HotdogPickup"
const ABS_CHOCOLATE := "/root/Main/FoodArea/Pickups/ChocolatePickup"

const ABS_KETCHUP := "/root/Main/FoodArea/Toppings/KetchupPickup"
const ABS_MUSTARD := "/root/Main/FoodArea/Toppings/MustardPickup"
const ABS_BUTTER := "/root/Main/FoodArea/Toppings/ButterPickup"
const ABS_CARAMEL := "/root/Main/FoodArea/Toppings/CaramelPickup"

@export var tray_path: NodePath
@export var stock_hud_path: NodePath

@export var popcorn_pickup_path: NodePath
@export var hotdog_pickup_path: NodePath
@export var chocolate_pickup_path: NodePath

@export var ketchup_pickup_path: NodePath
@export var mustard_pickup_path: NodePath
@export var butter_pickup_path: NodePath
@export var caramel_pickup_path: NodePath

@export var stock_popcorn: int = 10
@export var stock_hotdog: int = 10
@export var stock_chocolate: int = 10

@export var stock_ketchup: int = -1
@export var stock_mustard: int = -1
@export var stock_butter: int = -1
@export var stock_caramel: int = -1

var tray: Node = null
var stockhud: Node = null
var stock: Dictionary = {}

func _ready() -> void:
	if tray_path == NodePath(""): tray = get_node_or_null(ABS_TRAY)
	else: tray = get_node_or_null(tray_path)

	if stock_hud_path == NodePath(""): stockhud = get_node_or_null(ABS_STOCKHUD)
	else: stockhud = get_node_or_null(stock_hud_path)

	if tray == null:
		push_error("FoodStation: tray_path mal asignado (no encuentro Tray en escena).")
	if stockhud == null:
		push_warning("FoodStation: no encuentro StockHUD (no crítico).")

	stock = {
		"popcorn": stock_popcorn,
		"hotdog": stock_hotdog,
		"chocolate": stock_chocolate,
		"ketchup": stock_ketchup,
		"mustard": stock_mustard,
		"butter": stock_butter,
		"caramel": stock_caramel,
	}
	_push_stock()

	_connect_pickup(_pick_path(popcorn_pickup_path, ABS_POPCORN), func(): _take_popcorn())
	_connect_pickup(_pick_path(hotdog_pickup_path, ABS_HOTDOG), func(): _take_hotdog())
	_connect_pickup(_pick_path(chocolate_pickup_path, ABS_CHOCOLATE), func(): _take_chocolate())

	_connect_pickup(_pick_path(ketchup_pickup_path, ABS_KETCHUP), func(): _add_ketchup())
	_connect_pickup(_pick_path(mustard_pickup_path, ABS_MUSTARD), func(): _add_mustard())
	_connect_pickup(_pick_path(butter_pickup_path, ABS_BUTTER), func(): _add_butter())
	_connect_pickup(_pick_path(caramel_pickup_path, ABS_CARAMEL), func(): _add_caramel())

func _pick_path(p: NodePath, abs_path: String) -> NodePath:
	return NodePath(abs_path) if p == NodePath("") else p

func _push_stock() -> void:
	if stockhud != null and stockhud.has_method("set_stock"):
		stockhud.call("set_stock", stock)
		if stockhud.has_method("show_stock"):
			stockhud.call("show_stock")

func _connect_pickup(path: NodePath, fn: Callable) -> void:
	var a := get_node_or_null(path) as Area3D
	if a == null:
		push_error("FoodStation: no encuentro Area3D en " + String(path))
		return
	a.input_event.connect(func(_cam, ev, _pos, _normal, _shape_idx):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			fn.call()
	)

func _take_popcorn() -> void:
	if tray == null: return
	if int(stock["popcorn"]) <= 0:
		_debug("SIN STOCK: palomitas")
		return
	if tray.has_method("set_popcorn") and bool(tray.call("set_popcorn")):
		stock["popcorn"] = int(stock["popcorn"]) - 1
		_push_stock()

func _take_hotdog() -> void:
	if tray == null: return
	if int(stock["hotdog"]) <= 0:
		_debug("SIN STOCK: hotdog")
		return
	if tray.has_method("set_food_hotdog") and bool(tray.call("set_food_hotdog")):
		stock["hotdog"] = int(stock["hotdog"]) - 1
		_push_stock()
	else:
		_debug("YA HAY comida en Slot_Food (RMB para tirar)")

func _take_chocolate() -> void:
	if tray == null: return
	if int(stock["chocolate"]) <= 0:
		_debug("SIN STOCK: chocolate")
		return
	if tray.has_method("set_food_chocolate") and bool(tray.call("set_food_chocolate")):
		stock["chocolate"] = int(stock["chocolate"]) - 1
		_push_stock()
	else:
		_debug("YA HAY comida en Slot_Food (RMB para tirar)")

func _add_ketchup() -> void:
	if tray == null: return
	if not (tray.has_method("can_top_hotdog") and bool(tray.call("can_top_hotdog"))):
		_debug("Ketchup: necesitas HOTDOG")
		return
	if stock["ketchup"] == 0:
		_debug("SIN STOCK: ketchup")
		return
	var applied := tray.has_method("add_ketchup") and bool(tray.call("add_ketchup"))
	if not applied:
		_debug("Ketchup ya puesto (solo tirando el hotdog)")
		return
	if int(stock["ketchup"]) > 0:
		stock["ketchup"] = int(stock["ketchup"]) - 1
		_push_stock()

func _add_mustard() -> void:
	if tray == null: return
	if not (tray.has_method("can_top_hotdog") and bool(tray.call("can_top_hotdog"))):
		_debug("Mostaza: necesitas HOTDOG")
		return
	if stock["mustard"] == 0:
		_debug("SIN STOCK: mostaza")
		return
	var applied := tray.has_method("add_mustard") and bool(tray.call("add_mustard"))
	if not applied:
		_debug("Mostaza ya puesta (solo tirando el hotdog)")
		return
	if int(stock["mustard"]) > 0:
		stock["mustard"] = int(stock["mustard"]) - 1
		_push_stock()

func _add_butter() -> void:
	if tray == null: return
	if not (tray.has_method("can_top_popcorn") and bool(tray.call("can_top_popcorn"))):
		_debug("Butter: necesitas PALOMITAS")
		return
	if stock["butter"] == 0:
		_debug("SIN STOCK: butter")
		return
	var applied := tray.has_method("add_butter") and bool(tray.call("add_butter"))
	if not applied:
		_debug("Palomitas: ya tienen topping (o está caramel)")
		return
	if int(stock["butter"]) > 0:
		stock["butter"] = int(stock["butter"]) - 1
		_push_stock()

func _add_caramel() -> void:
	if tray == null: return
	if not (tray.has_method("can_top_popcorn") and bool(tray.call("can_top_popcorn"))):
		_debug("Caramel: necesitas PALOMITAS")
		return
	if stock["caramel"] == 0:
		_debug("SIN STOCK: caramel")
		return
	var applied := tray.has_method("add_caramel") and bool(tray.call("add_caramel"))
	if not applied:
		_debug("Palomitas: ya tienen topping (o está butter)")
		return
	if int(stock["caramel"]) > 0:
		stock["caramel"] = int(stock["caramel"]) - 1
		_push_stock()

func _debug(msg: String) -> void:
	var ui := get_tree().get_root().get_node_or_null("Main/UI")
	if ui != null and ui.has_method("show_debug"):
		ui.call("show_debug", "DEBUG: " + msg)
	else:
		print("DEBUG: " + msg)
