extends Node
# sin class_name para evitar "hides a global script class"

signal food_phase_done

@export var camera_path: NodePath
@export var hud_path: NodePath

@export var counter_cam_point_path: NodePath
@export var food_cam_point_path: NodePath
@export var move_time: float = 0.25
@export var finish_action: String = "ui_accept"

@export var tray_in_scene_path: NodePath
@export var drink_station_path: NodePath
@export var order_hud_path: NodePath

@export var require_any_item_to_finish: bool = true
@export var incomplete_penalty: int = 1

# StockHUD real (según tu report): /root/Main/UI/StockHUD
const ABS_STOCK_HUD: String = "/root/Main/UI/StockHUD"

var _cam: Camera3D = null
var _hud: Node = null
var _active: bool = false
var _tray: Node3D = null
var _ds: Node = null
var _stockhud: Node = null
var _order_hud: Node = null
var _current_order: Dictionary = {}
var _last_tray_state: Dictionary = {}

func _ready() -> void:
	_cam = get_node_or_null(camera_path) as Camera3D
	_hud = get_node_or_null(hud_path)
	_tray = get_node_or_null(tray_in_scene_path) as Node3D
	_ds = get_node_or_null(drink_station_path)
	_stockhud = get_node_or_null(ABS_STOCK_HUD)

	# stock HUD apagado al inicio (solo visible en food phase)
	_set_stockhud_visible(false)

	# Order HUD
	_order_hud = get_node_or_null(order_hud_path)
	if _order_hud == null:
		_order_hud = get_tree().get_root().get_node_or_null("Main/UI/CustomerOrderHUD")

func start_food_phase(order: Dictionary = {}) -> void:
	_current_order = order
	_last_tray_state = {}
	var food_point := get_node_or_null(food_cam_point_path) as Marker3D
	if _cam == null or food_point == null:
		_fail("FoodController: camera_path o food_cam_point_path mal asignado")
		return
	if _tray == null:
		_fail("FoodController: tray_in_scene_path mal asignado")
		return

	# Preparar bandeja (si existe el método, ok)
	if _tray.has_method("prepare_runtime"):
		_tray.call("prepare_runtime")

	# Limpiar items SIEMPRE
	clear_table_tray()

	_active = true
	_set_stockhud_visible(true)
	_move_camera_to_marker(food_point)

	# Mostrar pedido en OrderHUD
	if _order_hud != null and _order_hud.has_method("show_order") and not _current_order.is_empty():
		_order_hud.call("show_order", _current_order)

	if _ds != null:
		if _ds.has_method("set_tray"):
			_ds.call("set_tray", _tray)
		if _ds.has_method("set_active"):
			_ds.call("set_active", true)
		else:
			if _ds.has_variable("active"):
				_ds.set("active", true)

func _process(_delta: float) -> void:
	if not _active:
		return

	# Refrescar checks solo si el estado de la bandeja cambio
	if _order_hud != null and _order_hud.has_method("refresh") and _tray != null:
		if _tray.has_method("get_state"):
			var new_state: Dictionary = _tray.call("get_state")
			if new_state != _last_tray_state:
				_last_tray_state = new_state
				_order_hud.call("refresh", new_state)

	if Input.is_action_just_pressed(finish_action):
		if require_any_item_to_finish and not _tray_has_any_item():
			if _hud != null and _hud.has_method("show_message"):
				_hud.call("show_message", "Falta preparar la comida/bebida.", 1.2)
			return
		_end_food_phase()

func _end_food_phase() -> void:
	_active = false

	# Penalizar si el pedido esta incompleto
	if _order_hud != null and _order_hud.has_method("missing_count") and _tray != null:
		if _tray.has_method("get_state"):
			var missing: int = _order_hud.call("missing_count", _tray.call("get_state"))
			if missing > 0 and "day_misses" in RunState:
				RunState.day_misses += missing

	if _order_hud != null and _order_hud.has_method("hide_order"):
		_order_hud.call("hide_order")

	_set_stockhud_visible(false)

	if _ds != null:
		if _ds.has_method("set_active"):
			_ds.call("set_active", false)
		else:
			if _ds.has_variable("active"):
				_ds.set("active", false)

	var counter_point := get_node_or_null(counter_cam_point_path) as Marker3D
	if counter_point != null:
		_move_camera_to_marker(counter_point)

	emit_signal("food_phase_done")

func _tray_has_any_item() -> bool:
	if _tray == null:
		return false
	if _tray.has_method("has_any_item"):
		return bool(_tray.call("has_any_item"))
	var items := _tray.get_node_or_null("Items") as Node3D
	return items != null and items.get_child_count() > 0

func _move_camera_to_marker(m: Marker3D) -> void:
	var tw := create_tween()
	tw.tween_property(_cam, "global_position", m.global_position, move_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_cam, "global_rotation", m.global_rotation, move_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_stockhud_visible(on: bool) -> void:
	if _stockhud == null:
		return
	# Si tiene métodos, úsalos; si no, visible a pelo
	if on:
		if _stockhud.has_method("show_stock"):
			_stockhud.call("show_stock")
		elif _stockhud is CanvasLayer:
			(_stockhud as CanvasLayer).visible = true
		else:
			_stockhud.set("visible", true)
	else:
		if _stockhud.has_method("hide_stock"):
			_stockhud.call("hide_stock")
		elif _stockhud is CanvasLayer:
			(_stockhud as CanvasLayer).visible = false
		else:
			_stockhud.set("visible", false)

func _fail(msg: String) -> void:
	push_error(msg)
	if _hud != null and _hud.has_method("show_debug"):
		_hud.call("show_debug", "DEBUG ERROR: " + msg)
	get_tree().create_timer(0.2).timeout.connect(func():
		emit_signal("food_phase_done")
	)

func handoff_tray_to_customer(customer: Node3D) -> void:
	if _tray == null or not is_instance_valid(_tray):
		return
	if customer == null or not is_instance_valid(customer):
		return

	var carry := customer.get_node_or_null("Visual/CarryPoint") as Marker3D
	var parent_node: Node = carry if carry != null else customer

	var tray_copy := _tray.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	get_tree().get_root().add_child(tray_copy)
	tray_copy.reparent(parent_node)
	tray_copy.transform = Transform3D.IDENTITY

	clear_table_tray()

	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(tray_copy):
			tray_copy.queue_free()
	)

func clear_table_tray() -> void:
	if _tray == null or not is_instance_valid(_tray):
		return

	if _tray.has_method("clear_items"):
		_tray.call("clear_items")
		return

	var items := _tray.get_node_or_null("Items") as Node3D
	if items == null:
		return
	for ch in items.get_children():
		ch.queue_free()
