extends Node3D
# sin class_name para evitar "hides a global script class" si hay duplicados viejos

# ---- FORZADO (IGNORA INSPECTOR) ----
const USE_SCENE_PATH := "res://Scenes/Props/DrinkUse.tscn"
const DONE_SCENE_PATH := "res://Scenes/Props/DrinkDone.tscn"

@export var active: bool = false
@export var debug_prints: bool = true

@export var camera_path: NodePath
@export var hold_point_path: NodePath
@export var cup_dispenser_area_path: NodePath

@export var nozzle_cola_path: NodePath      # → stock item "cola"
@export var nozzle_orange_path: NodePath    # → stock item "orange"
@export var nozzle_rootbeer_path: NodePath  # → stock item "rootbeer"

@export var fill_seconds: float = 2.0
@export var snap_time: float = 0.10
@export var allow_multiple_drinks: bool = false
@export var debug_shift_force_spawn: bool = true

var _cam: Camera3D = null
var _hold: Node3D = null
var _cup_area: Area3D = null
var _tray: Node3D = null
var _hud: Node = null

var _nozzles: Array[Area3D] = []
var _nozzle_to_snap: Dictionary = {}   # Area3D -> Marker3D
var _nozzle_to_drink: Dictionary = {}  # Area3D -> String ("cola"/"orange"/"rootbeer")

enum State { IDLE, HOLDING, FILLING }
var _state: int = State.IDLE
var _hover_nozzle: Area3D = null
var _snap_tween: Tween = null

# escenas forzadas
var _use_scene: PackedScene = null
var _done_scene: PackedScene = null

# vaso USE (solo mano)
var _cup_use: Node3D = null
var _use_scale: Vector3 = Vector3.ONE

func set_tray(tray: Node3D) -> void:
	_tray = tray

func set_active(on: bool) -> void:
	active = on
	if active:
		sync_nozzle_visibility()
	else:
		_cleanup_use()

func _ready() -> void:
	_cam = get_node_or_null(camera_path) as Camera3D
	_hold = get_node_or_null(hold_point_path) as Node3D
	_cup_area = get_node_or_null(cup_dispenser_area_path) as Area3D
	_hud = get_tree().get_root().get_node_or_null("Main/UI")

	if _cam == null:
		push_error("DrinkStation: camera_path mal asignado")
		return

	if _hold == null:
		push_warning("DrinkStation: hold_point_path no encontrado, usando Camera como hold")
		_hold = _cam

	_use_scene = load(USE_SCENE_PATH) as PackedScene
	_done_scene = load(DONE_SCENE_PATH) as PackedScene

	if _use_scene == null:
		push_error("DrinkStation: NO puedo cargar USE_SCENE_PATH = " + USE_SCENE_PATH)
	if _done_scene == null:
		push_error("DrinkStation: NO puedo cargar DONE_SCENE_PATH = " + DONE_SCENE_PATH)

	if debug_prints:
		print("DRINKSTATION NODE PATH =", get_path())
		print("FORCED use_scene =", USE_SCENE_PATH, " ok=", _use_scene != null)
		print("FORCED done_scene =", DONE_SCENE_PATH, " ok=", _done_scene != null)

	_setup_nozzle(nozzle_cola_path,     "cola")
	_setup_nozzle(nozzle_orange_path,   "orange")
	_setup_nozzle(nozzle_rootbeer_path, "rootbeer")

	set_process(true)
	set_process_unhandled_input(true)

func _setup_nozzle(path: NodePath, drink_type: String) -> void:
	var noz := get_node_or_null(path) as Area3D
	if noz == null:
		return
	_nozzles.append(noz)
	_nozzle_to_snap[noz]  = noz.get_node_or_null("SnapPoint") as Marker3D
	_nozzle_to_drink[noz] = drink_type

func _process(_delta: float) -> void:
	if not active:
		return
	if _state == State.HOLDING and _cup_use != null:
		var noz := _hit_any_nozzle()
		if noz != _hover_nozzle:
			_hover_nozzle = noz
			if _hover_nozzle != null:
				_snap_use_to_nozzle(_hover_nozzle)
			else:
				_return_use_to_hold()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var shift: bool = (event as InputEventMouseButton).shift_pressed

		if _state == State.IDLE:
			var ok := _hit_area(_cup_area)
			if ok or (debug_shift_force_spawn and shift):
				_spawn_use_in_hand()
			return

		if _state == State.HOLDING and _cup_use != null and _hover_nozzle != null:
			_start_fill()
			return

func _spawn_use_in_hand() -> void:
	if _use_scene == null:
		push_error("DrinkStation: _use_scene es NULL (no cargó " + USE_SCENE_PATH + ")")
		return

	_cleanup_use()

	_cup_use = _use_scene.instantiate() as Node3D
	_cup_use.name = "CUP_USE"
	_hold.add_child(_cup_use)
	_cup_use.transform = Transform3D.IDENTITY
	_use_scale = _cup_use.scale

	_state = State.HOLDING
	_hover_nozzle = null

	if debug_prints:
		print("SPAWN USE (FORCED) ->", USE_SCENE_PATH)

func _cleanup_use() -> void:
	_kill_snap_tween()
	_state = State.IDLE
	_hover_nozzle = null
	_set_fill_ui(false, 0)

	if is_instance_valid(_cup_use):
		_cup_use.queue_free()
	_cup_use = null

func _snap_use_to_nozzle(noz: Area3D) -> void:
	var snap := _nozzle_to_snap.get(noz, null) as Marker3D
	if snap == null or _cup_use == null:
		return

	_kill_snap_tween()
	_snap_tween = create_tween()
	_snap_tween.tween_property(_cup_use, "global_position", snap.global_position, snap_time)
	_snap_tween.parallel().tween_property(_cup_use, "global_rotation", snap.global_rotation, snap_time)
	_cup_use.scale = _use_scale

func _return_use_to_hold() -> void:
	if _cup_use == null:
		return
	_kill_snap_tween()
	_snap_tween = create_tween()
	_snap_tween.tween_property(_cup_use, "transform", Transform3D.IDENTITY, snap_time)
	_cup_use.scale = _use_scale

func _kill_snap_tween() -> void:
	if _snap_tween != null and is_instance_valid(_snap_tween):
		_snap_tween.kill()
	_snap_tween = null

func _start_fill() -> void:
	# Validar stock antes de llenar
	if _hover_nozzle != null:
		var dt: String = String(_nozzle_to_drink.get(_hover_nozzle, ""))
		if dt != "" and not StockManager.has_stock(dt):
			_cleanup_use()
			return

	_state = State.FILLING
	_set_fill_ui(true, 0)

	var tw := create_tween()
	tw.tween_method(func(v):
		_set_fill_ui(true, int(v))
	, 0.0, 100.0, fill_seconds)

	tw.tween_callback(func():
		_finish_fill()
	)

func _finish_fill() -> void:
	_set_fill_ui(false, 100)

	# Descontar stock de la bebida del grifo usado
	var drink_type: String = ""
	if _hover_nozzle != null:
		drink_type = String(_nozzle_to_drink.get(_hover_nozzle, "cola"))
		if not StockManager.use(drink_type):
			push_warning("DrinkStation: sin stock de " + drink_type)

	if is_instance_valid(_cup_use):
		_cup_use.queue_free()
	_cup_use = null

	_state = State.IDLE
	_hover_nozzle = null

	_spawn_done_on_tray()

	# Notificar a la bandeja qué tipo de bebida fue colocada (para validación)
	if _tray != null and is_instance_valid(_tray) and drink_type != "":
		if _tray.has_method("set_drink_type"):
			_tray.call("set_drink_type", drink_type)

	sync_nozzle_visibility()

func _spawn_done_on_tray() -> void:
	if _tray == null:
		push_warning("DrinkStation: no tray set")
		return
	if _done_scene == null:
		push_error("DrinkStation: _done_scene es NULL (no cargó " + DONE_SCENE_PATH + ")")
		return

	var items := _tray.get_node_or_null("Items") as Node3D
	var slot := _tray.get_node_or_null("Slots/Slot_Drink") as Marker3D
	if items == null or slot == null:
		push_error("DrinkStation: Tray/Items o Slot_Drink no encontrados")
		return

	# ✅ FIX: NO BORRAR TODA LA BANDEJA. Solo bebidas previas.
	if not allow_multiple_drinks:
		for ch in items.get_children():
			if ch.name == "DRINK_DONE" or ch.name == "CUP_USE":
				ch.queue_free()

	var done := _done_scene.instantiate() as Node3D
	done.name = "DRINK_DONE"
	items.add_child(done)
	done.global_transform = slot.global_transform

	if debug_prints:
		print("SPAWN DONE (FORCED) ->", DONE_SCENE_PATH)

func _hit_area(area: Area3D) -> bool:
	if _cam == null or area == null:
		return false
	var hit := _raycast()
	if hit.is_empty():
		return false
	var n := hit.collider as Node
	while n != null:
		if n == area:
			return true
		n = n.get_parent()
	return false

func _hit_any_nozzle() -> Area3D:
	if _cam == null:
		return null
	var hit := _raycast()
	if hit.is_empty():
		return null
	var n := hit.collider as Node
	while n != null:
		for noz in _nozzles:
			if n == noz:
				return noz
		n = n.get_parent()
	return null

func _raycast() -> Dictionary:
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := _cam.project_ray_origin(mouse_pos)
	var dir := _cam.project_ray_normal(mouse_pos)
	var to := origin + dir * 50.0
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _set_fill_ui(show_it: bool, percent: int) -> void:
	if _hud != null and _hud.has_method("set_fill_progress"):
		_hud.call("set_fill_progress", show_it, percent)

## Oculta/muestra los nozzles 3D según stock disponible.
func sync_nozzle_visibility() -> void:
	for noz in _nozzles:
		var drink_type: String = String(_nozzle_to_drink.get(noz, ""))
		if drink_type != "":
			noz.visible = StockManager.has_stock(drink_type)
