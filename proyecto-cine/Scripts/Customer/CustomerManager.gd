extends Node3D

signal counter_customer_ready(customer: Node)
signal counter_customer_left(customer: Node)
signal counter_customer_changed(customer: Node)

# NUEVO: cuando el jugador pulsa E para atender
signal counter_customer_attended(customer: Node)

const CUSTOMER_SCENE_PATH := "res://Scenes/Customer.tscn"

const TRAY_PREP_ABS := "/root/Main/FoodArea/TrayPreview/Tray"
const SERVE_POINT_ABS := "/root/Main/FoodArea/ServePoint"

@export var max_in_queue: int = 5
@export var ground_y: float = 0.0
@export var queue_step: float = 1.15

@export var exit_turn_duration: float = 0.18
@export var exit_pop_height: float = 0.10
@export var exit_pop_up_time: float = 0.06
@export var exit_pop_down_time: float = 0.08
@export var force_despawn_seconds: float = 4.0

@export var serve_show_seconds: float = 0.35

@onready var spawn_point: Node3D = $"../../Points/CustomerSpawn"
@onready var counter_point: Node3D = $"../../Points/CounterPoint"
@onready var queue_start: Node3D = $"../../Points/QueueStart"
@onready var exit_point: Node3D = $"../../Points/ExitPoint"
@onready var exit_point_alt: Node3D = $"../../Points/ExitPointAlt"
@onready var special_back_point: Node3D = $"../../Points/SpecialBackPoint"

var customer_scene: PackedScene
var queue: Array[Node] = []
var leaving: Dictionary = {}
var _last_targets: Dictionary = {}
var _counter_customer: Node = null

var _day_total: int = 0
var _spawned_total: int = 0

# NUEVO: para no “atender” varias veces al mismo
var _attended: Dictionary = {} # customer -> bool

func _ready() -> void:
	customer_scene = load(CUSTOMER_SCENE_PATH) as PackedScene
	if customer_scene == null:
		push_error("CustomerManager: no se pudo cargar " + CUSTOMER_SCENE_PATH)

func start_day(total_customers: int) -> void:
	_day_total = total_customers
	_spawned_total = 0

	for child in get_children():
		child.queue_free()

	queue.clear()
	leaving.clear()
	_last_targets.clear()
	_attended.clear()
	_counter_customer = null

	_ensure_queue_filled(true)

func get_counter_customer() -> Node:
	return queue[0] if queue.size() > 0 else null

# ---------------------- ATENDER (NUEVO) ----------------------

func attend_current() -> void:
	var current := get_counter_customer()
	if current == null:
		return
	attend_customer(current)

func attend_customer(customer: Node) -> void:
	if customer == null:
		return
	if leaving.has(customer):
		return
	# solo se atiende al de mostrador
	if queue.size() == 0 or queue[0] != customer:
		return
	# no repetir
	if _attended.has(customer) and bool(_attended[customer]) == true:
		return

	_attended[customer] = true
	emit_signal("counter_customer_attended", customer)

# ---------------------- SERVE NORMAL ----------------------

func serve_current() -> void:
	var current := get_counter_customer()
	if current == null:
		return
	if current.state != current.State.WAITING:
		return

	emit_signal("counter_customer_left", current)

	# ✅ Presentar bandeja en ServePoint, luego enganchar y salir
	_present_tray_then_leave(current, _flat(exit_point.global_position), false)

# ---------------------- SERVE ESPECIAL ----------------------

func serve_current_special() -> void:
	var current := get_counter_customer()
	if current == null:
		return
	if current.state != current.State.WAITING:
		return

	emit_signal("counter_customer_left", current)

	# Especial: presentar bandeja, luego ir a backpoint y luego exit alt
	_present_tray_then_leave(current, _flat(special_back_point.global_position), true)

# ---------------------- PRESENTACIÓN BANDEJA ----------------------

func _present_tray_then_leave(customer: Node, first_target: Vector3, special_chain: bool) -> void:
	# 1) duplicar bandeja y ponerla en ServePoint (visible delante del cliente)
	var serve_tray := _spawn_tray_on_serve_point()
	# 2) limpiar la bandeja de la mesa para el siguiente cliente
	var prep_tray := get_tree().root.get_node_or_null(TRAY_PREP_ABS) as Node3D
	if prep_tray != null:
		_clear_prep_tray(prep_tray)

	# 3) esperar un pelín para que se vea “serving”
	get_tree().create_timer(serve_show_seconds).timeout.connect(func():
		# enganchar esa misma bandeja a manos (CarryPoint)
		_attach_tray_to_customer(customer, serve_tray)

		# ahora sí: inicia la salida y reassign
		if special_chain:
			# ir a backpoint
			_begin_leave(customer, first_target, false)

			# cuando llegue al backpoint, ir a ExitPointAlt
			if customer.has_signal("arrived"):
				customer.arrived.connect(func(_c):
					if not is_instance_valid(customer):
						return
					var alt_pos := _flat(exit_point_alt.global_position)
					_play_exit_turn_and_pop(customer, alt_pos)
					customer.go_to(alt_pos, false)
				, CONNECT_ONE_SHOT)
		else:
			_begin_leave(customer, first_target, true)
	)

func _begin_leave(customer: Node, target: Vector3, do_turn_fx: bool) -> void:
	leaving[customer] = true

	# quitar del array queue si sigue siendo el primero
	if queue.size() > 0 and queue[0] == customer:
		queue.remove_at(0)

	_start_despawn_guard(customer)

	if do_turn_fx:
		_play_exit_turn_and_pop(customer, target)

	_last_targets[customer] = target
	customer.go_to(target, false)

	_reassign_targets(true)
	_ensure_queue_filled(false)

func _spawn_tray_on_serve_point() -> Node3D:
	var prep_tray := get_tree().root.get_node_or_null(TRAY_PREP_ABS) as Node3D
	var serve_point := get_tree().root.get_node_or_null(SERVE_POINT_ABS) as Marker3D
	if prep_tray == null or serve_point == null:
		return null

	var tray := prep_tray.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	if tray == null:
		return null

	serve_point.get_parent().add_child(tray)
	tray.global_transform = serve_point.global_transform
	return tray

func _attach_tray_to_customer(customer: Node, tray: Node3D) -> void:
	if tray == null or not is_instance_valid(tray):
		return
	var carry := customer.get_node_or_null("Visual/CarryPoint") as Marker3D
	if carry == null:
		return

	var g := tray.global_transform
	tray.get_parent().remove_child(tray)
	carry.add_child(tray)
	tray.global_transform = g

# ---------------------- QUEUE / SPAWN ----------------------

func _ensure_queue_filled(force_reassign: bool) -> void:
	while queue.size() < max_in_queue and _spawned_total < _day_total:
		_spawn_customer()
	if force_reassign:
		_reassign_targets(true)

func _spawn_customer() -> void:
	if customer_scene == null:
		return

	var c = customer_scene.instantiate()
	add_child(c)

	c.collision_layer = 0
	c.collision_mask = 0

	if c.has_signal("arrived"):
		c.arrived.connect(_on_customer_arrived)

	# Spawn separado (evita “caterpillar”)
	var idx := queue.size() + 1
	var base_spawn := _flat(spawn_point.global_position)

	var to_counter := (_flat(counter_point.global_position) - _flat(queue_start.global_position))
	to_counter.y = 0.0
	if to_counter.length() < 0.001:
		to_counter = Vector3(0, 0, -1)
	var back_dir := (-to_counter).normalized()

	c.global_position = base_spawn + back_dir * queue_step * float(idx - 1)

	queue.append(c)
	_spawned_total += 1

func _reassign_targets(force: bool) -> void:
	var new_counter: Node = get_counter_customer()
	if new_counter != _counter_customer:
		_counter_customer = new_counter
		emit_signal("counter_customer_changed", _counter_customer)

	for i in range(queue.size()):
		var c = queue[i]
		if i == 0:
			_set_target(c, _flat(counter_point.global_position), true, force)
		else:
			_set_target(c, _queue_pos(i), false, force)

func _set_target(c: Node, target: Vector3, look_at_cam: bool, force: bool) -> void:
	if leaving.has(c):
		return

	if (not force) and _last_targets.has(c):
		if (_last_targets[c] as Vector3).distance_to(target) < 0.01:
			return

	_last_targets[c] = target
	c.go_to(target, look_at_cam)

func _queue_pos(slot_index: int) -> Vector3:
	var start := _flat(queue_start.global_position)

	var to_counter := (_flat(counter_point.global_position) - start)
	to_counter.y = 0.0
	if to_counter.length() < 0.001:
		to_counter = Vector3(0, 0, -1)
	var back_dir := (-to_counter).normalized()

	return start + back_dir * queue_step * float(slot_index - 1)

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, ground_y, p.z)

func _on_customer_arrived(c: Node) -> void:
	if leaving.has(c):
		return
	if queue.size() > 0 and queue[0] == c:
		emit_signal("counter_customer_ready", c)

# ---------------------- DESPAWN GUARD ----------------------

func _start_despawn_guard(customer: Node) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = force_despawn_seconds
	add_child(t)
	t.timeout.connect(func():
		if is_instance_valid(customer):
			customer.queue_free()
		if is_instance_valid(t):
			t.queue_free()
	)
	t.start()

# ---------------------- EXIT FX ----------------------

func _play_exit_turn_and_pop(c: Node, target: Vector3) -> void:
	var visual := c.get_node_or_null("Visual") as Node3D
	if visual:
		var base_y := visual.position.y
		var pop := create_tween()
		pop.tween_property(visual, "position:y", base_y + exit_pop_height, exit_pop_up_time)
		pop.tween_property(visual, "position:y", base_y, exit_pop_down_time)

	var dir: Vector3 = target - c.global_position
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var yaw := atan2(-dir.x, -dir.z)
	var turn := create_tween()
	turn.tween_property(c, "rotation:y", yaw, exit_turn_duration)

# ---------------------- CLEAR PREP TRAY ----------------------

func _clear_prep_tray(prep_tray: Node3D) -> void:
	var items := prep_tray.get_node_or_null("Items")
	if items != null:
		for ch in items.get_children():
			ch.queue_free()

	var keep := {"bandeja": true, "Slots": true, "Items": true, "SlotColliders": true}
	for ch in prep_tray.get_children():
		if keep.has(ch.name):
			continue
		ch.queue_free()
