extends Node3D
class_name Tray

# Estructura esperada (tu escena):
# Tray
# ├─ Slots
# │  ├─ Slot_Food (Marker3D)
# │  ├─ Slot_Drink (Marker3D)
# │  └─ Slot_Popcorn (Marker3D)
# ├─ Items (Node3D)   <-- aquí instanciamos TODO (comida/bebida/toppings)
# └─ SlotColliders
#    ├─ Area_Food (Area3D)
#    ├─ Area_Drink (Area3D)
#    └─ Area_Popcorn (Area3D)

const ABS_TRAY: String = "/root/Main/FoodArea/TrayPreview/Tray"

# Rutas ABS a escenas (tú ya las tienes)
const SCN_HOTDOG: String = "res://Scenes/Props/Hotdog.tscn"
const SCN_CHOCOLATE: String = "res://Scenes/Props/Chocolate.tscn"
const SCN_POPCORN: String = "res://Scenes/Props/PopcornUsed.tscn"
const SCN_DRINK_DONE: String = "res://Scenes/Props/DrinkDone.tscn"

const SCN_KETCHUP_HOTDOG: String = "res://Scenes/Props/Toppings/Ketchup_Hotdog.tscn"
const SCN_MUSTARD_HOTDOG: String = "res://Scenes/Props/Toppings/Mustard_Hotdog.tscn"
const SCN_BUTTER_POPCORN: String = "res://Scenes/Props/Toppings/Butter_Popcorn.tscn"
const SCN_CARAMEL_POPCORN: String = "res://Scenes/Props/Toppings/Caramel_Popcorn.tscn"

@onready var slots: Node3D = $Slots
@onready var items: Node3D = $Items
@onready var slot_colliders: Node3D = $SlotColliders

@onready var slot_food: Marker3D = $Slots/Slot_Food
@onready var slot_drink: Marker3D = $Slots/Slot_Drink
@onready var slot_pop: Marker3D = $Slots/Slot_Popcorn

@onready var area_food: Area3D = $SlotColliders/Area_Food
@onready var area_drink: Area3D = $SlotColliders/Area_Drink
@onready var area_pop: Area3D = $SlotColliders/Area_Popcorn

# Estado actual
var _food_kind: String = ""        # "hotdog" | "chocolate" | ""
var _pop_kind: String = ""         # "popcorn" | ""
var _drink_kind: String = ""       # "cola"|"orange"|"rootbeer"|"" (hoy no diferenciamos mesh, solo presencia)

var _food_node: Node3D = null
var _pop_node: Node3D = null
var _drink_node: Node3D = null

# Hotdog toppings
var _hotdog_ketchup: bool = false
var _hotdog_mustard: bool = false
var _hotdog_k_node: Node3D = null
var _hotdog_m_node: Node3D = null

# Popcorn topping (uno u otro)
var _pop_topping: String = ""      # "butter"|"caramel"|"" (solo si hay popcorn)
var _pop_t_node: Node3D = null

func _ready() -> void:
	# Click izquierdo para borrar slot
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit_path := _raycast_hit_path()
		if hit_path == "":
			return
		# Si haces click en Area_X o en su CollisionShape, subimos parents hasta encontrar el Area
		if hit_path.begins_with(area_food.get_path()):
			clear_food()
		elif hit_path.begins_with(area_drink.get_path()):
			clear_drink()
		elif hit_path.begins_with(area_pop.get_path()):
			clear_popcorn()

func _raycast_hit_path() -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return ""
	var mp := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var to := origin + dir * 200.0
	var q := PhysicsRayQueryParameters3D.create(origin, to)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	var collider_obj: Object = hit.get("collider") as Object
	var n: Node = collider_obj as Node
	while n != null:
		# devolvemos el path del nodo que tocamos (para debug)
		if n == area_food or n == area_drink or n == area_pop:
			return String(n.get_path())
		n = n.get_parent()
	# fallback
	if collider_obj != null and collider_obj is Node:
		return String((collider_obj as Node).get_path())
	return ""

# ------------------------------------------------------------
# Helpers de instanciado
# ------------------------------------------------------------
func _load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		push_error("Tray: no existe scene: " + path)
		return null
	return load(path) as PackedScene

func _spawn_into_slot(scene_path: String, slot: Marker3D) -> Node3D:
	var ps := _load_scene(scene_path)
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	if n == null:
		return null
	items.add_child(n)
	n.global_position = slot.global_position
	n.global_rotation = slot.global_rotation
	return n

func _clear_node(n: Node3D) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()

# ------------------------------------------------------------
# API usada por FoodStation / DrinkStation
# ------------------------------------------------------------

# --- Food (hotdog/chocolate comparten slot)
func set_food_hotdog() -> bool:
	clear_food()
	var n := _spawn_into_slot(SCN_HOTDOG, slot_food)
	if n == null:
		return false
	_food_kind = "hotdog"
	_food_node = n
	_hotdog_ketchup = false
	_hotdog_mustard = false
	_clear_node(_hotdog_k_node); _hotdog_k_node = null
	_clear_node(_hotdog_m_node); _hotdog_m_node = null
	return true

func set_food_chocolate() -> bool:
	clear_food()
	var n := _spawn_into_slot(SCN_CHOCOLATE, slot_food)
	if n == null:
		return false
	_food_kind = "chocolate"
	_food_node = n
	_hotdog_ketchup = false
	_hotdog_mustard = false
	_clear_node(_hotdog_k_node); _hotdog_k_node = null
	_clear_node(_hotdog_m_node); _hotdog_m_node = null
	return true

func clear_food() -> void:
	_clear_node(_food_node); _food_node = null
	_food_kind = ""
	# al tirar hotdog se van toppings también
	_hotdog_ketchup = false
	_hotdog_mustard = false
	_clear_node(_hotdog_k_node); _hotdog_k_node = null
	_clear_node(_hotdog_m_node); _hotdog_m_node = null

func has_food() -> bool:
	return _food_kind != ""

func food_kind() -> String:
	return _food_kind

# --- Hotdog toppings (solo si hay hotdog). Se quedan; se quitan tirando el hotdog.
func add_ketchup() -> bool:
	if _food_kind != "hotdog" or _food_node == null:
		return false
	if _hotdog_ketchup:
		return false
	_hotdog_ketchup = true
	_hotdog_k_node = _spawn_topping_on_food(SCN_KETCHUP_HOTDOG)
	return true

func add_mustard() -> bool:
	if _food_kind != "hotdog" or _food_node == null:
		return false
	if _hotdog_mustard:
		return false
	_hotdog_mustard = true
	_hotdog_m_node = _spawn_topping_on_food(SCN_MUSTARD_HOTDOG)
	return true

func _spawn_topping_on_food(scene_path: String) -> Node3D:
	# Si tu Hotdog.tscn tiene Markers/M_Ketchup etc, lo usamos. Si no, lo ponemos encima.
	var marker: Marker3D = null
	if _food_node != null:
		if scene_path.find("Ketchup") != -1:
			marker = _food_node.get_node_or_null("Markers/M_Ketchup") as Marker3D
		elif scene_path.find("Mustard") != -1:
			marker = _food_node.get_node_or_null("Markers/M_Mustard") as Marker3D

	var ps := _load_scene(scene_path)
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	if n == null:
		return null
	items.add_child(n)

	if marker != null:
		n.global_position = marker.global_position
		n.global_rotation = marker.global_rotation
	else:
		# fallback: encima del hotdog
		n.global_position = _food_node.global_position + Vector3(0, 0.05, 0)
		n.global_rotation = _food_node.global_rotation
	return n

# --- Popcorn (slot propio)
func set_popcorn() -> bool:
	if _pop_kind == "popcorn":
		return false # ya hay
	var n := _spawn_into_slot(SCN_POPCORN, slot_pop)
	if n == null:
		return false
	_pop_kind = "popcorn"
	_pop_node = n
	# reset topping
	_pop_topping = ""
	_clear_node(_pop_t_node); _pop_t_node = null
	return true

func clear_popcorn() -> void:
	_clear_node(_pop_node); _pop_node = null
	_pop_kind = ""
	_pop_topping = ""
	_clear_node(_pop_t_node); _pop_t_node = null

func has_popcorn() -> bool:
	return _pop_kind == "popcorn"

# Popcorn topping: SOLO 1 (butter o caramel). Si pones el otro, reemplaza.
func set_popcorn_topping(kind: String) -> bool:
	if not has_popcorn() or _pop_node == null:
		return false
	if kind != "butter" and kind != "caramel":
		return false

	if _pop_topping == kind:
		return false

	_pop_topping = kind
	_clear_node(_pop_t_node); _pop_t_node = null

	var scene_path := SCN_BUTTER_POPCORN if kind == "butter" else SCN_CARAMEL_POPCORN
	_pop_t_node = _spawn_topping_on_popcorn(scene_path)
	return true

func _spawn_topping_on_popcorn(scene_path: String) -> Node3D:
	var marker: Marker3D = null
	if _pop_node != null:
		if scene_path.find("Butter") != -1:
			marker = _pop_node.get_node_or_null("Markers/M_Butter") as Marker3D
		elif scene_path.find("Caramel") != -1:
			marker = _pop_node.get_node_or_null("Markers/M_Caramel") as Marker3D

	var ps := _load_scene(scene_path)
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	if n == null:
		return null
	items.add_child(n)

	if marker != null:
		n.global_position = marker.global_position
		n.global_rotation = marker.global_rotation
	else:
		n.global_position = _pop_node.global_position + Vector3(0, 0.05, 0)
		n.global_rotation = _pop_node.global_rotation
	return n

# --- Drink (slot propio). DrinkStation llamará esto.
func set_drink_done(kind: String = "") -> bool:
	# kind es solo meta (cola/orange/rootbeer). Mesh es el mismo DrinkDone por ahora.
	clear_drink()
	var n := _spawn_into_slot(SCN_DRINK_DONE, slot_drink)
	if n == null:
		return false
	_drink_kind = kind
	_drink_node = n
	return true

func clear_drink() -> void:
	_clear_node(_drink_node); _drink_node = null
	_drink_kind = ""

func has_drink() -> bool:
	return _drink_node != null

# Utilidad: estado resumido para comprobar pedido
func snapshot() -> Dictionary:
	return {
		"food": _food_kind,
		"hotdog_ketchup": _hotdog_ketchup,
		"hotdog_mustard": _hotdog_mustard,
		"popcorn": has_popcorn(),
		"pop_topping": _pop_topping,
		"drink": (_drink_kind if has_drink() else "")
	}
