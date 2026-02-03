extends Node
class_name FoodController

signal food_phase_done

@export var camera_path: NodePath
@export var hud_path: NodePath

@export var counter_cam_point_path: NodePath
@export var food_cam_point_path: NodePath
@export var move_time: float = 0.25
@export var finish_action: String = "ui_accept"

@export var tray_in_scene_path: NodePath
@export var drink_station_path: NodePath

const STOCKHUD_ABS := "/root/Main/UI/StockHUD"
const TRAY_ABS := "/root/Main/FoodArea/TrayPreview/Tray"

var _cam: Camera3D = null
var _hud: Node = null
var _active: bool = false
var _tray: Node3D = null
var _ds: Node = null

var _stock_root: Node = null
var _stock_canvas: CanvasItem = null
var _stock_panel: CanvasItem = null

var _tray_node: Node = null

func _ready() -> void:
	_cam = get_node_or_null(camera_path) as Camera3D
	_hud = get_node_or_null(hud_path)
	_tray = get_node_or_null(tray_in_scene_path) as Node3D
	_ds = get_node_or_null(drink_station_path)

	_stock_root = get_tree().root.get_node_or_null("Main/UI/StockHUD")
	_stock_canvas = _stock_root as CanvasItem
	_stock_panel = _find_first_canvasitem_child(_stock_root)

	_tray_node = get_tree().root.get_node_or_null("Main/FoodArea/TrayPreview/Tray")

	_set_stock_visible(false)

func start_food_phase() -> void:
	var food_point := get_node_or_null(food_cam_point_path) as Marker3D
	if _cam == null or food_point == null:
		_fail("FoodController: camera_path o food_cam_point_path mal asignado")
		return
	if _tray == null:
		_fail("FoodController: tray_in_scene_path mal asignado (no encuentro la bandeja en escena)")
		return

	_active = true

	# ✅ OCULTAR BOCADILLO AL ENTRAR EN COMIDA
	if _hud != null and _hud.has_method("hide_customer_text"):
		_hud.call("hide_customer_text")

	_move_camera_to_marker(food_point)

	# ✅ Stock solo aquí
	_set_stock_visible(true)

	# ✅ Activar Tray (para permitir borrar con click)
	if _tray_node != null and _tray_node.has_method("set_active"):
		_tray_node.call("set_active", true)

	# Activar DrinkStation
	if _ds != null:
		if _ds.has_method("set_tray"):
			_ds.call("set_tray", _tray)
		if _ds.has_method("set_active"):
			_ds.call("set_active", true)
		elif "active" in _ds:
			_ds.set("active", true)

func _process(_delta: float) -> void:
	if not _active:
		return
	if Input.is_action_just_pressed(finish_action):
		_end_food_phase()

func _end_food_phase() -> void:
	_active = false

	# ✅ Ocultar StockHUD al salir
	_set_stock_visible(false)

	# ✅ Desactivar Tray (ya no borres fuera de comida)
	if _tray_node != null and _tray_node.has_method("set_active"):
		_tray_node.call("set_active", false)

	# ✅ Ocultar bocadillo también al salir (por si acaso)
	if _hud != null and _hud.has_method("hide_customer_text"):
		_hud.call("hide_customer_text")

	# Desactivar DrinkStation
	if _ds != null:
		if _ds.has_method("set_active"):
			_ds.call("set_active", false)
		elif "active" in _ds:
			_ds.set("active", false)

	var counter_point := get_node_or_null(counter_cam_point_path) as Marker3D
	if counter_point != null:
		_move_camera_to_marker(counter_point)

	emit_signal("food_phase_done")

func _set_stock_visible(on: bool) -> void:
	if _stock_canvas != null:
		_stock_canvas.visible = on
		return
	if _stock_panel != null:
		_stock_panel.visible = on

func _find_first_canvasitem_child(n: Node) -> CanvasItem:
	if n == null:
		return null
	for c in n.get_children():
		var ci := c as CanvasItem
		if ci != null:
			return ci
		var deeper := _find_first_canvasitem_child(c)
		if deeper != null:
			return deeper
	return null

func _move_camera_to_marker(m: Marker3D) -> void:
	var target_pos: Vector3 = m.global_position
	var target_rot: Vector3 = m.global_rotation

	var tw := create_tween()
	tw.tween_property(_cam, "global_position", target_pos, move_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_cam, "global_rotation", target_rot, move_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _fail(msg: String) -> void:
	push_error(msg)
	if _hud != null and _hud.has_method("show_debug"):
		_hud.call("show_debug", "DEBUG ERROR: " + msg)
	get_tree().create_timer(0.2).timeout.connect(func():
		emit_signal("food_phase_done")
	)
