extends Node
# StockManager — Autoload. Gestiona el stock diario del cine.
# Reemplaza el diccionario interno de FoodStation.

# Precios por unidad (solo los comprables)
const UNIT_COSTS: Dictionary = {
	"cola":      2,
	"orange":    2,
	"rootbeer":  2,
	"popcorn":   3,
	"hotdog":    4,
	"chocolate": 2,
}

# Precios de venta al cliente
const SALE_PRICES: Dictionary = {
	"cola":      3,
	"orange":    3,
	"rootbeer":  4,
	"popcorn":   5,
	"hotdog":    6,
	"chocolate": 4,
}

## Devuelve el ingreso por venta de un pedido de comida.
func food_revenue(food_order: Dictionary) -> int:
	var total := 0
	if food_order.get("drink", false):
		var dtype: String = String(food_order.get("drink_type", "cola"))
		if dtype == "": dtype = "cola"
		total += SALE_PRICES.get(dtype, 0)
	if food_order.get("popcorn", false):
		total += SALE_PRICES.get("popcorn", 0)
	var food: String = String(food_order.get("food", ""))
	if food == "hotdog":
		total += SALE_PRICES.get("hotdog", 0)
	elif food == "chocolate":
		total += SALE_PRICES.get("chocolate", 0)
	return total

# Stock en curso. -1 = ilimitado (toppings).
var stock: Dictionary = {
	"cola":      5,
	"orange":    5,
	"rootbeer":  5,
	"popcorn":   5,
	"hotdog":    5,
	"chocolate": 5,
	"ketchup":   -1,
	"mustard":   -1,
	"butter":    -1,
	"caramel":   -1,
}

var _sold_today: Dictionary = {}
var _initial_today: Dictionary = {}

func _ready() -> void:
	_reset_tracking()

# ── API pública ──────────────────────────────────────────────────

## Usa una unidad del item (gestión de cantidad). NO modifica _sold_today.
## Devuelve false si no hay stock.
func use(item: String) -> bool:
	if not stock.has(item):
		return false
	var qty: int = int(stock[item])
	if qty == -1:
		return true  # ilimitado, siempre ok
	if qty <= 0:
		return false
	stock[item] = qty - 1
	return true

## Registra un pedido como vendido (sin tocar las cantidades de stock).
## Llamar una vez al finalizar la fase de comida de cada cliente.
func track_sold(food_order: Dictionary) -> void:
	if food_order.get("drink", false):
		var dtype: String = String(food_order.get("drink_type", "cola"))
		if dtype == "":
			dtype = "cola"
		if stock.has(dtype):
			_sold_today[dtype] = int(_sold_today.get(dtype, 0)) + 1
	if food_order.get("popcorn", false):
		_sold_today["popcorn"] = int(_sold_today.get("popcorn", 0)) + 1
	var food: String = String(food_order.get("food", ""))
	if food == "hotdog":
		_sold_today["hotdog"] = int(_sold_today.get("hotdog", 0)) + 1
	elif food == "chocolate":
		_sold_today["chocolate"] = int(_sold_today.get("chocolate", 0)) + 1

## Devuelve true si hay stock disponible del item.
func has_stock(item: String) -> bool:
	if not stock.has(item):
		return false
	var qty: int = int(stock[item])
	return qty == -1 or qty > 0

## Resumen del día para StockPurchaseUI: vendido, desperdiciado, coste unitario.
func end_of_day_summary() -> Dictionary:
	var result: Dictionary = {}
	for item in stock:
		var initial: int = int(_initial_today.get(item, stock[item]))
		var sold: int = int(_sold_today.get(item, 0))
		var unlimited: bool = initial == -1
		result[item] = {
			"sold":          sold,
			"wasted":        0 if unlimited else max(0, initial - sold),
			"cost_per_unit": UNIT_COSTS.get(item, 0),
			"is_unlimited":  unlimited,
		}
	return result

## Compra un lote. orders = { item: qty }. Descuenta de RunState.total_money.
## Devuelve el coste total, o -1 si no hay dinero suficiente.
func purchase_batch(orders: Dictionary) -> int:
	var total_cost := 0
	for item in orders:
		if UNIT_COSTS.has(item):
			total_cost += UNIT_COSTS[item] * int(orders[item])
	if RunState.total_money < total_cost:
		return -1
	RunState.total_money -= total_cost
	for item in orders:
		stock[item] = int(orders[item])
	# Los ilimitados permanecen como -1
	for item in stock:
		if not UNIT_COSTS.has(item):
			stock[item] = -1
	_reset_tracking()
	return total_cost

## Devuelve copia del stock actual.
func get_stock() -> Dictionary:
	return stock.duplicate()

# ── Interno ──────────────────────────────────────────────────────

func _reset_tracking() -> void:
	for item in stock:
		_sold_today[item] = 0
		_initial_today[item] = int(stock[item])
