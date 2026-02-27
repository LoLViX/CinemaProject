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
@export var serve_point_path: NodePath

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
var _serve_point: Marker3D = null
var _tray_preview: Node3D = null         # padre de _tray (TrayPreview)
var _tray_home_pos: Vector3 = Vector3.ZERO  # posición original de TrayPreview
var _current_order: Dictionary = {}
var _last_tray_state: Dictionary = {}
var _tray_prev_state: Dictionary = {}   # para detectar nuevas colocaciones

func _ready() -> void:
	_cam = get_node_or_null(camera_path) as Camera3D
	_hud = get_node_or_null(hud_path)
	_tray = get_node_or_null(tray_in_scene_path) as Node3D
	_ds = get_node_or_null(drink_station_path)
	_stockhud = get_node_or_null(ABS_STOCK_HUD)

	_serve_point = get_node_or_null(serve_point_path) as Marker3D
	if _tray != null:
		_tray_preview = _tray.get_parent() as Node3D
		if _tray_preview != null:
			_tray_home_pos = _tray_preview.global_position

	# stock HUD apagado al inicio (solo visible en food phase)
	_set_stockhud_visible(false)

	# Order HUD
	_order_hud = get_node_or_null(order_hud_path)
	if _order_hud == null:
		_order_hud = get_tree().get_root().get_node_or_null("Main/UI/CustomerOrderHUD")

func start_food_phase(order: Dictionary = {}) -> void:
	_current_order = order
	_last_tray_state = {}
	_tray_prev_state = {}
	var food_point := get_node_or_null(food_cam_point_path) as Marker3D
	if _cam == null or food_point == null:
		_fail("FoodController: camera_path o food_cam_point_path mal asignado")
		return
	if _tray == null:
		_fail("FoodController: tray_in_scene_path mal asignado")
		return

	# Cachear posición home de TrayPreview (por si _ready fue demasiado pronto)
	if _tray_preview != null and is_instance_valid(_tray_preview):
		_tray_home_pos = _tray_preview.global_position

	# Preparar bandeja (si existe el método, ok)
	if _tray.has_method("prepare_runtime"):
		_tray.call("prepare_runtime")

	# Limpiar items SIEMPRE
	clear_table_tray()

	_active = true
	_set_stockhud_visible(true)
	_sync_stockhud()        # mostrar stock actual al inicio de la fase
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

	# Refrescar checks solo si el estado de la bandeja cambió
	if _order_hud != null and _order_hud.has_method("refresh") and is_instance_valid(_tray):
		if _tray.has_method("get_state"):
			var new_state: Dictionary = _tray.call("get_state")
			if new_state != _last_tray_state:
				_track_placed_items(_last_tray_state, new_state)
				_last_tray_state = new_state
				_order_hud.call("refresh", new_state)

	if Input.is_action_just_pressed(finish_action):
		# Permitir bandeja vacía si el pedido está vacío (nada pedido)
		var order_is_empty := _is_order_empty()
		if require_any_item_to_finish and not _tray_has_any_item() and not order_is_empty:
			if _hud != null and _hud.has_method("show_message"):
				_hud.call("show_message", "Falta preparar la comida/bebida.", 1.2)
			return
		_end_food_phase()

func _end_food_phase() -> void:
	_active = false

	# Penalizar si el pedido esta incompleto
	if _order_hud != null and _order_hud.has_method("missing_count") and is_instance_valid(_tray):
		if _tray.has_method("get_state"):
			var missing: int = _order_hud.call("missing_count", _tray.call("get_state"))
			if missing > 0 and "day_misses" in RunState:
				RunState.day_misses += missing

	_set_stockhud_visible(false)

	if _ds != null:
		if _ds.has_method("set_active"):
			_ds.call("set_active", false)
		else:
			if _ds.has_variable("active"):
				_ds.set("active", false)

	# Mover bandeja al ServePoint ANTES de girar cámara (ya estará ahí al llegar)
	_move_tray_to_serve_point()

	var counter_point := get_node_or_null(counter_cam_point_path) as Marker3D
	if counter_point != null:
		_move_camera_to_marker(counter_point)

	# Emitir ANTES de hide_order — el handler necesita _rows/_order intactos
	emit_signal("food_phase_done")

	if _order_hud != null and _order_hud.has_method("hide_order"):
		_order_hud.call("hide_order")

## True si el pedido actual no pide nada (todas las keys son false/"").
func _is_order_empty() -> bool:
	if _current_order.is_empty():
		return true
	if bool(_current_order.get("drink", false)):
		return false
	if bool(_current_order.get("popcorn", false)):
		return false
	if String(_current_order.get("food", "")) != "":
		return false
	return true

func _tray_has_any_item() -> bool:
	if not is_instance_valid(_tray):
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

## Mueve la bandeja al ServePoint (llamado al acabar food phase).
func _move_tray_to_serve_point() -> void:
	if _serve_point == null or _tray_preview == null:
		return
	if not is_instance_valid(_tray_preview):
		return
	_tray_preview.global_position = _serve_point.global_position

## Quita la bandeja sin VFX: limpia items y devuelve a posición original.
func dismiss_tray() -> void:
	clear_table_tray()
	_return_tray_home()

## Legacy — mantener por compatibilidad.
func plop_tray() -> void:
	dismiss_tray()

func handoff_tray_to_customer(_customer: Node3D) -> void:
	dismiss_tray()

## Devuelve el último estado conocido de la bandeja (para el sistema de propinas).
func get_last_tray_state() -> Dictionary:
	return _last_tray_state

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

## Sincroniza StockHUD con el stock actual de StockManager.
func _sync_stockhud() -> void:
	if _stockhud == null or not _stockhud.has_method("set_stock"):
		return
	_stockhud.call("set_stock", StockManager.get_stock())

## Devuelve TrayPreview a su posición original (zona de preparación).
func _return_tray_home() -> void:
	if _tray_preview != null and is_instance_valid(_tray_preview):
		_tray_preview.global_position = _tray_home_pos

## Detecta items recién colocados en la bandeja y sincroniza el HUD.
## El stock ya se descuenta en FoodStation / DrinkStation al hacer click.
func _track_placed_items(old_state: Dictionary, new_state: Dictionary) -> void:
	# Bebida: apareció?
	if not bool(old_state.get("drink", false)) and bool(new_state.get("drink", false)):
		_sync_stockhud()

	# Palomitas: apareció?
	if not bool(old_state.get("popcorn", false)) and bool(new_state.get("popcorn", false)):
		_sync_stockhud()

	# Comida: apareció o cambió?
	var old_food: String = String(old_state.get("food", ""))
	var new_food: String = String(new_state.get("food", ""))
	if new_food != "" and new_food != old_food:
		_sync_stockhud()
