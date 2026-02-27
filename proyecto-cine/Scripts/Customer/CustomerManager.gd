extends Node3D

signal counter_customer_ready(customer: Node)
signal counter_customer_left(customer: Node)
signal counter_customer_changed(customer: Node)

const CUSTOMER_SCENE_PATH := "res://Scenes/Customer.tscn"

@export var max_in_queue: int = 5
@export var ground_y: float = 0.0
@export var queue_step: float = 1.8
@export var queue_stagger: float = 0.25   # zigzag alterno para evitar clipping de sprites
@export var queue_lateral_offset: float = 0.50  # desplazamiento lateral fijo de toda la cola

@export var exit_turn_duration: float = 0.18
@export var exit_pop_height: float = 0.10
@export var exit_pop_up_time: float = 0.06
@export var exit_pop_down_time: float = 0.08

@export var force_despawn_seconds: float = 8.0

@onready var spawn_point: Node3D = $"../../Points/CustomerSpawn"
@onready var counter_point: Node3D = $"../../Points/CounterPoint"
@onready var queue_start: Node3D = $"../../Points/QueueStart"
@onready var exit_point: Node3D = $"../../Points/ExitPoint"

# DOS PUNTOS para especial
@onready var special_back_point: Node3D = $"../../Points/SpecialBackPoint" if has_node("../../Points/SpecialBackPoint") else null
@onready var exit_point_alt: Node3D = $"../../Points/ExitPointAlt" if has_node("../../Points/ExitPointAlt") else null

var customer_scene: PackedScene
var queue: Array[Node] = []
var leaving: Dictionary = {}
var _last_targets: Dictionary = {}
var _counter_customer: Node = null

var _day_total: int = 0
var _spawned_total: int = 0
var _illustrations: Array = []   # illustration paths, indexado por orden de spawn

# special leaving: c -> phase (0 back, 1 exit)
var _special_leaving: Dictionary = {}
var _counter_locked: bool = false

func _ready() -> void:
	customer_scene = load(CUSTOMER_SCENE_PATH) as PackedScene
	if customer_scene == null:
		push_error("CustomerManager: no se pudo cargar " + CUSTOMER_SCENE_PATH)

## Configura las ilustraciones para el día. Llamar ANTES de start_day().
func set_illustrations(list: Array) -> void:
	_illustrations = list

func start_day(total_customers: int) -> void:
	_day_total = total_customers
	_spawned_total = 0

	for child in get_children():
		child.queue_free()

	queue.clear()
	leaving.clear()
	_last_targets.clear()
	_counter_customer = null
	_special_leaving.clear()
	_counter_locked = false

	_ensure_queue_filled(true)

func get_counter_customer() -> Node:
	return queue[0] if queue.size() > 0 else null

func serve_current() -> void:
	var current := get_counter_customer()
	if current == null:
		return
	if current.state != current.State.WAITING:
		return

	emit_signal("counter_customer_left", current)

	var exit_pos := _flat(exit_point.global_position)
	_play_exit_turn_and_pop(current, exit_pos)
	_last_targets[current] = exit_pos
	current.go_to(exit_pos, false)

	leaving[current] = true
	queue.remove_at(0)

	_start_despawn_guard(current)

	_reassign_targets(true)
	_ensure_queue_filled(false)

func serve_current_special() -> void:
	var current := get_counter_customer()
	if current == null:
		return
	if current.state != current.State.WAITING:
		return

	if special_back_point == null:
		# fallback: si no existe el punto, sale normal
		serve_current()
		return

	emit_signal("counter_customer_left", current)

	_counter_locked = true
	queue.remove_at(0)
	_special_leaving[current] = 0

	var back_pos := _flat(special_back_point.global_position)
	_last_targets[current] = back_pos
	current.go_to(back_pos, false)

	_start_despawn_guard(current)

	_reassign_targets(true)
	_ensure_queue_filled(false)

func _start_despawn_guard(current: Node) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = force_despawn_seconds
	add_child(t)
	t.timeout.connect(func():
		if is_instance_valid(current):
			current.queue_free()
		if is_instance_valid(t):
			t.queue_free()
	)
	t.start()

func _ensure_queue_filled(force_reassign: bool) -> void:
	while queue.size() < max_in_queue and _spawned_total < _day_total:
		_spawn_customer()
	if force_reassign:
		_reassign_targets(true)

func _spawn_customer() -> void:
	var c = customer_scene.instantiate()
	add_child(c)

	c.collision_layer = 0
	c.collision_mask = 0

	if c.has_signal("arrived"):
		c.arrived.connect(_on_customer_arrived)

	# Aplicar ilustración PNG si está disponible
	var illus_idx := _spawned_total  # 0-based
	if illus_idx < _illustrations.size():
		var illus_path: String = String(_illustrations[illus_idx])
		if illus_path != "" and c.has_method("set_illustration"):
			c.call("set_illustration", illus_path)

	# spawn espaciado
	var start_spawn := _flat(spawn_point.global_position)
	var back_dir := _back_dir()
	var offset := back_dir * queue_step * float(queue.size())
	c.global_position = start_spawn + offset

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
			if _counter_locked:
				_set_target(c, _flat(queue_start.global_position), false, force)
			else:
				_set_target(c, _flat(counter_point.global_position), true, force)
		else:
			_set_target(c, _queue_pos(i), false, force)

func _set_target(c: Node, target: Vector3, look_at_cam: bool, force: bool) -> void:
	if leaving.has(c):
		return
	if _special_leaving.has(c):
		return

	if (not force) and _last_targets.has(c):
		if (_last_targets[c] as Vector3).distance_to(target) < 0.01:
			return

	_last_targets[c] = target
	c.go_to(target, look_at_cam)

func _queue_pos(slot_index: int) -> Vector3:
	var start := _flat(queue_start.global_position)
	var back_dir := _back_dir()
	var perp := Vector3(-back_dir.z, 0.0, back_dir.x)  # perpendicular en XZ
	var base := start + back_dir * queue_step * float(slot_index - 1)
	# Offset fijo: toda la cola se desplaza lateralmente respecto al mostrador
	base += perp * queue_lateral_offset
	# Zigzag alterno: pares a un lado, impares al otro → evita clipping
	if queue_stagger > 0.0:
		var side := 1.0 if slot_index % 2 == 0 else -1.0
		base += perp * queue_stagger * side
	return base

func _back_dir() -> Vector3:
	var start := _flat(queue_start.global_position)
	var to_counter := (_flat(counter_point.global_position) - start)
	to_counter.y = 0.0
	if to_counter.length() < 0.001:
		return Vector3(0, 0, -1)
	return (-to_counter).normalized()

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, ground_y, p.z)

func _on_customer_arrived(c: Node) -> void:
	# SPECIAL
	if _special_leaving.has(c):
		var phase := int(_special_leaving[c])

		if phase == 0:
			# terminó BACK -> desbloquear mostrador
			_counter_locked = false
			_reassign_targets(true)

			_special_leaving[c] = 1

			var exit_target := exit_point_alt if exit_point_alt != null else exit_point
			var exit_pos := _flat(exit_target.global_position)

			# giro antes de moverse (pequeño delay para que se note)
			_play_exit_turn_and_pop(c, exit_pos)
			get_tree().create_timer(exit_turn_duration * 0.9).timeout.connect(func():
				if is_instance_valid(c):
					_last_targets[c] = exit_pos
					c.go_to(exit_pos, false)
			)
			return

		# phase 1: al llegar al exit, despawn
		_special_leaving.erase(c)
		_last_targets.erase(c)
		if is_instance_valid(c):
			c.queue_free()
		return

	# NORMAL leaving
	if leaving.has(c):
		leaving.erase(c)
		_last_targets.erase(c)
		if is_instance_valid(c):
			c.queue_free()
		return

	# Counter ready
	if not _counter_locked and queue.size() > 0 and queue[0] == c:
		emit_signal("counter_customer_ready", c)

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
