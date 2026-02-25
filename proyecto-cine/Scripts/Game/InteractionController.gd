extends Node
class_name InteractionController

@export var customer_manager_path: NodePath
@export var hud_path: NodePath
@export var food_controller_path: NodePath

const CUSTOMERS_PER_DAY := 10

var manager: Node = null
var hud: Node = null
var food: Node = null

var _counter_ready: bool = false
var _customer_list: Array = []
var _customer_index: int = 0
var _current_customer: Dictionary = {}

var _in_food: bool = false
var _pending_goodbye_key: String = "cust.goodbye.1"
var _last_result: String = ""

var _special_waiting_ack: bool = false

func _ready() -> void:
	manager = get_node_or_null(customer_manager_path)
	hud     = get_node_or_null(hud_path)
	food    = get_node_or_null(food_controller_path)

	if manager == null or hud == null or food == null:
		push_error("InteractionController: paths mal asignados (manager/hud/food)")
		return

	if manager.has_signal("counter_customer_ready"):
		manager.connect("counter_customer_ready", Callable(self, "_on_counter_ready"))
	if manager.has_signal("counter_customer_changed"):
		manager.connect("counter_customer_changed", Callable(self, "_on_counter_changed"))
	if manager.has_signal("counter_customer_left"):
		manager.connect("counter_customer_left", Callable(self, "_on_counter_left"))

	if hud.has_signal("recommend_movie"):
		hud.connect("recommend_movie", Callable(self, "_on_recommend_movie"))

	if food.has_signal("food_phase_done"):
		food.connect("food_phase_done", Callable(self, "_on_food_done"))

	var ui := get_tree().get_first_node_in_group("day_setup_ui")
	if ui != null and ui.has_signal("day_setup_done"):
		ui.connect("day_setup_done", Callable(self, "_start_day"))
	else:
		_start_day()

func _start_day() -> void:
	RunState.reset_day_stats()
	_last_result = ""
	_update_debug()
	_special_waiting_ack = false

	var plan: Array = []
	var day_i := int(RunState.day_index) if "day_index" in RunState else 1
	plan = DayPlanDB.load_day_plan(day_i)

	if plan.size() > 0:
		_customer_list = _build_customers_from_plan(plan)
	else:
		_customer_list = CustomerDB.build_day_customers(RunState.todays_movies, CUSTOMERS_PER_DAY)

	if _customer_list.size() == 0:
		_customer_list = [{
			"type":"normal",
			"request_text":"Hola… ¿me recomiendas algo?",
			"food_key":"cust.foodask.1",
			"ok_key":"cust.react_ok.1",
			"bad_key":"cust.react_bad.1",
			"bye_key":"cust.goodbye.1",
			"must":[],
			"must_not":[],
			"exit_lane":"main"
		}]

	_customer_index = 0
	_current_customer = _customer_list[0]

	if manager.has_method("start_day"):
		manager.call("start_day", _customer_list.size())

func _build_customers_from_plan(plan: Array) -> Array:
	var out: Array = []
	for e in plan:
		var kind := String(e.get("kind","normal"))
		if kind == "special":
			out.append({
				"type":"special",
				"request_text": String(e.get("text","")),
				"exit_lane":"alt"
			})
		else:
			out.append(CustomerDB.build_day_customers(RunState.todays_movies, 1)[0])
	return out

func _process(_delta: float) -> void:
	if _in_food:
		return

	# Solo responder a E si el contador está listo
	if not _counter_ready:
		return

	if Input.is_action_just_pressed("serve_next"):
		# Si el panel de recomendar está abierto, ignorar E
		if hud.has_method("is_attend_open") and hud.call("is_attend_open"):
			return

		# Segundo E para despachar al especial
		if _special_waiting_ack:
			_special_waiting_ack = false
			hud.call("hide_message")
			hud.call("hide_prompt")

			if manager.has_method("serve_current_special"):
				manager.call("serve_current_special")
			else:
				manager.call("serve_current")

			_advance_customer()
			_update_debug()
			return

		# E normal: ocultar prompt y abrir diálogo
		hud.call("hide_prompt")

		if _is_special(_current_customer):
			# Especial: mostrar texto y esperar segundo E
			var line: String = String(_current_customer.get("request_text",""))
			hud.call("show_message", line, 0.0)
			_special_waiting_ack = true
			# Volver a mostrar el prompt para el segundo E
			hud.call("show_prompt", "ui.counter_ready")
			return

		# Normal: abrir panel de recomendar película
		var line_norm: String = String(_current_customer.get("request_text","Hola… ¿me recomiendas algo?"))
		hud.call("show_attend", line_norm, RunState.todays_movies, RunState.player_tags_by_movie)

func _on_recommend_movie(movie_id: String) -> void:
	if _in_food:
		return

	var movie: Dictionary = {}
	for m in RunState.todays_movies:
		if String(m.get("id","")) == movie_id:
			movie = m
			break
	if movie.is_empty():
		return

	var ok: bool = MatchingSystem.pass_fail(_current_customer, movie.get("true_tags", []), 2)

	if ok:
		RunState.day_hits += 1
		_last_result = "OK"
	else:
		RunState.day_misses += 1
		_last_result = "FALLO"
	_update_debug()

	_in_food = true

	var react_key: String = String(_current_customer.get("ok_key" if ok else "bad_key", "cust.react_ok.1"))
	var food_key:  String = String(_current_customer.get("food_key", "cust.foodask.1"))
	_pending_goodbye_key   = String(_current_customer.get("bye_key", "cust.goodbye.1"))

	hud.call("show_message", TextDB.t(react_key), 1.6)
	get_tree().create_timer(1.6).timeout.connect(func():
		hud.call("show_message", TextDB.t(food_key), 1.4)
		get_tree().create_timer(1.4).timeout.connect(func():
			if food.has_method("start_food_phase"):
				var food_order: Dictionary = _current_customer.get("food_order", {})
				food.call("start_food_phase", food_order)
			else:
				_on_food_done()
		)
	)

func _on_food_done() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	hud.call("show_message", TextDB.t(_pending_goodbye_key), 1.2)

	var mgr_ref := manager
	var food_ref := food
	var hud_ref := hud

	get_tree().create_timer(0.35).timeout.connect(func():
		if not is_instance_valid(mgr_ref) or not is_instance_valid(food_ref):
			return
		if mgr_ref.has_method("get_counter_customer") and food_ref.has_method("handoff_tray_to_customer"):
			var c := mgr_ref.call("get_counter_customer") as Node3D
			if c != null and is_instance_valid(c):
				food_ref.call("handoff_tray_to_customer", c)

		get_tree().create_timer(0.2).timeout.connect(func():
			if not is_instance_valid(mgr_ref):
				return
			mgr_ref.call("serve_current")
			_in_food = false
			_advance_customer()
			_update_debug()
		)
	)

func _advance_customer() -> void:
	_customer_index += 1
	if _customer_index < _customer_list.size():
		_current_customer = _customer_list[_customer_index]

func _update_debug() -> void:
	if not DebugConfig.ENABLE_DEBUG:
		return
	var hits   := int(RunState.day_hits)
	var misses := int(RunState.day_misses)
	var s := "DEBUG: Aciertos %d | Fallos %d" % [hits, misses]
	if _last_result != "":
		s += " | Último: %s" % _last_result
	hud.call("show_debug", s)

func _is_special(c: Dictionary) -> bool:
	return String(c.get("type","")) == "special"

# ── Señales del CustomerManager ────────────────────────────────

func _on_counter_ready(_customer: Node) -> void:
	_counter_ready = true
	# Mostrar el prompt solo en este momento exacto
	if not _in_food:
		hud.call("show_prompt", "ui.counter_ready")

func _on_counter_changed(customer: Node) -> void:
	_counter_ready = (customer != null)

func _on_counter_left(_customer: Node) -> void:
	_counter_ready = false
	_special_waiting_ack = false
	hud.call("hide_prompt")
	hud.call("hide_message")
