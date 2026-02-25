extends Node3D
class_name Tray

# ------------------------------------------------------------
# RUTAS ABSOLUTAS (según tu SceneTree)
# ------------------------------------------------------------
const ABS_CAMERA_PATH := "/root/Main/CameraRig/Camera"
const ABS_TRAY_PATH := "/root/Main/FoodArea/TrayPreview/Tray"

const ABS_SLOTS_PATH := ABS_TRAY_PATH + "/Slots"
const ABS_ITEMS_PATH := ABS_TRAY_PATH + "/Items"
const ABS_COLLIDERS_PATH := ABS_TRAY_PATH + "/SlotColliders"

const ABS_AREA_DRINK := ABS_COLLIDERS_PATH + "/Area_Drink"
const ABS_AREA_FOOD := ABS_COLLIDERS_PATH + "/Area_Food"
const ABS_AREA_POPCORN := ABS_COLLIDERS_PATH + "/Area_Popcorn"

# ------------------------------------------------------------
# Estado
# ------------------------------------------------------------
var _cam: Camera3D = null
var _slots: Node3D = null
var _items: Node3D = null
var _colliders: Node3D = null

var _food: Node3D = null        # HOTDOG o CHOCOLATE
var _popcorn: Node3D = null     # POPCORN

# toppings instanciados
var _hotdog_ketchup: Node3D = null
var _hotdog_mustard: Node3D = null
var _pop_butter: Node3D = null
var _pop_caramel: Node3D = null

# debug
@export var debug_raycast: bool = true

func _ready() -> void:
	_cam = get_node_or_null(ABS_CAMERA_PATH) as Camera3D
	_slots = get_node_or_null(ABS_SLOTS_PATH) as Node3D
	_items = get_node_or_null(ABS_ITEMS_PATH) as Node3D
	_colliders = get_node_or_null(ABS_COLLIDERS_PATH) as Node3D

	if _cam == null: push_error("Tray.gd: NO encuentro Camera en " + ABS_CAMERA_PATH)
	if _slots == null: push_error("Tray.gd: NO encuentro Slots en " + ABS_SLOTS_PATH)
	if _items == null: push_error("Tray.gd: NO encuentro Items en " + ABS_ITEMS_PATH)
	if _colliders == null: push_error("Tray.gd: NO encuentro SlotColliders en " + ABS_COLLIDERS_PATH)

	set_process_unhandled_input(true)

# ------------------------------------------------------------
# INPUT: RMB -> raycast -> si golpea Area_* => borrar
# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return

		var hit := _raycast_areas_only()
		if hit.is_empty():
			if debug_raycast:
				print("TRAY RMB: no hit")
			return

		var collider_obj: Object = hit.get("collider") as Object
		var n: Node = collider_obj as Node
		if n == null:
			if debug_raycast:
				print("TRAY RMB: hit collider is not Node")
			return

		# subimos padres y comparamos por PATH ABSOLUTO (no por name)
		while n != null:
			var p := String(n.get_path())
			if debug_raycast:
				print("TRAY RMB HIT:", p)

			if p == ABS_AREA_FOOD:
				clear_food()
				return
			if p == ABS_AREA_POPCORN:
				clear_popcorn()
				return
			if p == ABS_AREA_DRINK:
				clear_drink()
				return

			n = n.get_parent()

func _raycast_areas_only() -> Dictionary:
	if _cam == null:
		return {}
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := _cam.project_ray_origin(mouse_pos)
	var dir := _cam.project_ray_normal(mouse_pos)
	var to := origin + dir * 25.0

	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false # ✅ clave: NO bodies
	return get_world_3d().direct_space_state.intersect_ray(query)

# ------------------------------------------------------------
# Items base
# ------------------------------------------------------------
func set_popcorn() -> bool:
	if _popcorn != null:
		return true

	var slot := _get_slot_marker("Slot_Popcorn")
	if slot == null: return false
	var ps := FoodDB.load_scene(FoodDB.POPCORN_SCENE)
	if ps == null: return false

	_popcorn = ps.instantiate() as Node3D
	_popcorn.name = "POPCORN"
	_items.add_child(_popcorn)
	_popcorn.global_transform = slot.global_transform

	_clear_popcorn_toppings()
	return true

func set_food_hotdog() -> bool:
	if _food != null:
		return false

	var slot := _get_slot_marker("Slot_Food")
	if slot == null: return false
	var ps := FoodDB.load_scene(FoodDB.HOTDOG_SCENE)
	if ps == null: return false

	_food = ps.instantiate() as Node3D
	_food.name = "HOTDOG"
	_items.add_child(_food)
	_food.global_transform = slot.global_transform

	_clear_hotdog_toppings()
	return true

func set_food_chocolate() -> bool:
	if _food != null:
		return false

	var slot := _get_slot_marker("Slot_Food")
	if slot == null: return false
	var ps := FoodDB.load_scene(FoodDB.CHOCOLATE_SCENE)
	if ps == null: return false

	_food = ps.instantiate() as Node3D
	_food.name = "CHOCOLATE"
	_items.add_child(_food)
	_food.global_transform = slot.global_transform

	_clear_hotdog_toppings()
	return true

# ------------------------------------------------------------
# Toppings rules (los que ya tenías)
# Hotdog: se añaden, no se quitan individualmente
# Popcorn: solo uno (butter o caramel)
# ------------------------------------------------------------
func can_top_hotdog() -> bool:
	return _food != null and _food.name == "HOTDOG"

func can_top_popcorn() -> bool:
	return _popcorn != null

func add_ketchup() -> bool:
	if not can_top_hotdog(): return false
	if _hotdog_ketchup != null and is_instance_valid(_hotdog_ketchup): return false

	var marker := _food.get_node_or_null("Markers/M_Ketchup") as Marker3D
	if marker == null:
		push_error("Tray: falta Hotdog/Markers/M_Ketchup")
		return false

	var ps := FoodDB.load_scene(FoodDB.KETCHUP_HOTDOG_SCENE)
	if ps == null: return false

	_hotdog_ketchup = ps.instantiate() as Node3D
	_hotdog_ketchup.name = "TOP_KETCHUP"
	marker.add_child(_hotdog_ketchup)
	_hotdog_ketchup.transform = Transform3D.IDENTITY
	return true

func add_mustard() -> bool:
	if not can_top_hotdog(): return false
	if _hotdog_mustard != null and is_instance_valid(_hotdog_mustard): return false

	var marker := _food.get_node_or_null("Markers/M_Mustard") as Marker3D
	if marker == null:
		push_error("Tray: falta Hotdog/Markers/M_Mustard")
		return false

	var ps := FoodDB.load_scene(FoodDB.MUSTARD_HOTDOG_SCENE)
	if ps == null: return false

	_hotdog_mustard = ps.instantiate() as Node3D
	_hotdog_mustard.name = "TOP_MUSTARD"
	marker.add_child(_hotdog_mustard)
	_hotdog_mustard.transform = Transform3D.IDENTITY
	return true

func add_butter() -> bool:
	if not can_top_popcorn(): return false
	if _pop_caramel != null and is_instance_valid(_pop_caramel): return false
	if _pop_butter != null and is_instance_valid(_pop_butter): return false

	var marker := _popcorn.get_node_or_null("Markers/M_Butter") as Marker3D
	if marker == null:
		push_error("Tray: falta Popcorn/Markers/M_Butter")
		return false

	var ps := FoodDB.load_scene(FoodDB.BUTTER_POPCORN_SCENE)
	if ps == null: return false

	_pop_butter = ps.instantiate() as Node3D
	_pop_butter.name = "TOP_BUTTER"
	marker.add_child(_pop_butter)
	_pop_butter.transform = Transform3D.IDENTITY
	return true

func add_caramel() -> bool:
	if not can_top_popcorn(): return false
	if _pop_butter != null and is_instance_valid(_pop_butter): return false
	if _pop_caramel != null and is_instance_valid(_pop_caramel): return false

	var marker := _popcorn.get_node_or_null("Markers/M_Caramel") as Marker3D
	if marker == null:
		push_error("Tray: falta Popcorn/Markers/M_Caramel")
		return false

	var ps := FoodDB.load_scene(FoodDB.CARAMEL_POPCORN_SCENE)
	if ps == null: return false

	_pop_caramel = ps.instantiate() as Node3D
	_pop_caramel.name = "TOP_CARAMEL"
	marker.add_child(_pop_caramel)
	_pop_caramel.transform = Transform3D.IDENTITY
	return true

# ------------------------------------------------------------
# Clear
# ------------------------------------------------------------
func clear_drink() -> void:
	if _items == null: return
	for ch in _items.get_children():
		if ch.name == "DRINK_DONE":
			ch.queue_free()
			return

func clear_food() -> void:
	_clear_hotdog_toppings()
	if is_instance_valid(_food): _food.queue_free()
	_food = null

func clear_popcorn() -> void:
	_clear_popcorn_toppings()
	if is_instance_valid(_popcorn): _popcorn.queue_free()
	_popcorn = null

func _clear_hotdog_toppings() -> void:
	if is_instance_valid(_hotdog_ketchup): _hotdog_ketchup.queue_free()
	if is_instance_valid(_hotdog_mustard): _hotdog_mustard.queue_free()
	_hotdog_ketchup = null
	_hotdog_mustard = null

func _clear_popcorn_toppings() -> void:
	if is_instance_valid(_pop_butter): _pop_butter.queue_free()
	if is_instance_valid(_pop_caramel): _pop_caramel.queue_free()
	_pop_butter = null
	_pop_caramel = null

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
func _get_slot_marker(name_str: String) -> Marker3D:
	if _slots == null: return null
	var m := _slots.get_node_or_null(name_str) as Marker3D
	if m == null:
		push_error("Tray.gd: falta Slots/" + name_str)
	return m

# ------------------------------------------------------------
# Estado consultable (para el OrderHUD)
# ------------------------------------------------------------
func get_state() -> Dictionary:
	var has_drink := false
	if _items != null:
		for ch in _items.get_children():
			if ch.name == "DRINK_DONE":
				has_drink = true
				break
	return {
		"drink":    has_drink,
		"food":     _food.name.to_lower() if _food != null and is_instance_valid(_food) else "",
		"popcorn":  _popcorn != null and is_instance_valid(_popcorn),
		"ketchup":  _hotdog_ketchup != null and is_instance_valid(_hotdog_ketchup),
		"mustard":  _hotdog_mustard != null and is_instance_valid(_hotdog_mustard),
		"butter":   _pop_butter != null and is_instance_valid(_pop_butter),
		"caramel":  _pop_caramel != null and is_instance_valid(_pop_caramel),
	}

func has_any_item() -> bool:
	var s := get_state()
	return s["drink"] or s["food"] != "" or s["popcorn"]
func clear_items() -> void:
	clear_food()
	clear_popcorn()
	clear_drink()
	_clear_hotdog_toppings()
	_clear_popcorn_toppings()
