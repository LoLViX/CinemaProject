extends Node
class_name InteractionController

@export var customer_manager_path: NodePath
@export var hud_path: NodePath
@export var food_controller_path: NodePath

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
var _last_food_complete: bool = false   # para la reacción flotante

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
	_last_food_complete = false
	_update_debug()
	_special_waiting_ack = false

	var plan: Array = []
	var day_i := int(RunState.day_index) if "day_index" in RunState else 1
	plan = DayPlanDB.load_day_plan(day_i)

	# Dificultad escala con el día (1→3)
	var difficulty := clampi(day_i, 1, 3)

	if plan.size() > 0:
		_customer_list = _build_customers_from_plan(plan, difficulty)
	else:
		var count := RunState.customers_per_day
		_customer_list = CustomerDB.build_day_customers(RunState.todays_movies, count, difficulty)

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

	# Actualizar cola visual
	_update_queue()

func _build_customers_from_plan(plan: Array, difficulty: int = 1) -> Array:
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
			var built := CustomerDB.build_day_customers(RunState.todays_movies, 1, difficulty)
			if built.size() > 0:
				out.append(built[0])
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
		SoundManager.play_click()

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
		RunState.earn_money(50)
		SoundManager.play_success()
		if hud.has_method("show_money_popup"):
			hud.call("show_money_popup", "+$50")
	else:
		RunState.day_misses += 1
		_last_result = "FALLO"
		RunState.earn_money(10)
		SoundManager.play_fail()
		if hud.has_method("show_money_popup"):
			hud.call("show_money_popup", "+$10")
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

	# Leer estado de la bandeja para propina y reacción
	var tray_complete := false
	if food != null and food.has_method("get_tray") or (food != null and food.has_method("get_tray_state")):
		pass  # se evalúa abajo via order_hud
	# Intentar evaluar directamente desde order_hud
	var order_hud := get_tree().get_root().find_child("*OrderHUD*", true, false)
	if order_hud == null:
		order_hud = get_tree().get_root().find_child("CustomerOrderHUD", true, false)

	# Obtener el nodo del cliente ahora (antes de que se vaya)
	var customer_node: Node = null
	if manager != null and manager.has_method("get_counter_customer"):
		customer_node = manager.call("get_counter_customer")

	# Mostrar reacción flotante y calcular propina
	if order_hud != null and order_hud.has_method("is_complete"):
		# Necesitamos el tray_state — se obtiene desde FoodController si es posible
		var tray_state: Dictionary = {}
		if food != null and food.has_method("get_last_tray_state"):
			tray_state = food.call("get_last_tray_state")
		tray_complete = order_hud.call("is_complete", tray_state)
		_last_food_complete = tray_complete

		if tray_complete:
			RunState.earn_money(20)
			SoundManager.play_cash()
			if hud.has_method("show_money_popup"):
				hud.call("show_money_popup", "+$20 propina")
		else:
			RunState.earn_money(5)
			if hud.has_method("show_money_popup"):
				hud.call("show_money_popup", "+$5")

	# Texto flotante sobre el cliente
	if is_instance_valid(customer_node):
		_show_reaction(customer_node, tray_complete)

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

func _show_reaction(customer_node: Node, is_perfect: bool) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(customer_node):
		return

	var pos3d: Vector3 = Vector3.ZERO
	if customer_node is Node3D:
		pos3d = (customer_node as Node3D).global_position + Vector3(0, 2.2, 0)
	else:
		return

	var pos2d: Vector2 = cam.unproject_position(pos3d)

	var lbl := Label.new()
	lbl.text = "¡Perfecto! 😊" if is_perfect else "Falta algo... 😕"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color",
		Color(0.20, 0.95, 0.35) if is_perfect else Color(1.0, 0.35, 0.35))
	lbl.position = pos2d - Vector2(70, 20)
	# Añadir a la CanvasLayer del HUD para que esté en 2D
	if hud is CanvasLayer:
		hud.add_child(lbl)
	else:
		get_tree().root.add_child(lbl)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -65), 1.3)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.3).set_delay(0.4)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

func _advance_customer() -> void:
	_customer_index += 1
	_update_queue()
	if _customer_index < _customer_list.size():
		_current_customer = _customer_list[_customer_index]
	else:
		# Fin del día — pequeña pausa para que el último cliente salga
		get_tree().create_timer(1.8).timeout.connect(_show_end_of_day)

func _update_queue() -> void:
	if hud != null and is_instance_valid(hud) and hud.has_method("update_queue"):
		hud.call("update_queue", _customer_index, _customer_list.size())

func _show_end_of_day() -> void:
	# Instanciar EndOfDayUI y conectar señal
	var eod := EndOfDayUI.new()
	get_tree().root.add_child(eod)
	eod.show_results(
		RunState.day_index,
		RunState.day_hits,
		_customer_list.size(),
		RunState.day_money,
		RunState.day_rating()
	)
	if eod.has_signal("next_day_requested"):
		eod.next_day_requested.connect(_on_next_day.bind(eod))

func _on_next_day(eod_ui: Node) -> void:
	if is_instance_valid(eod_ui):
		eod_ui.queue_free()

	# DaySystem NO es autoload — buscarlo en el árbol de escena
	var day_sys := get_tree().root.find_child("DaySystem", true, false)
	if day_sys != null and day_sys.has_method("next_day"):
		day_sys.call("next_day")
	else:
		# Fallback: avanzar día manualmente si DaySystem no se encuentra
		RunState.day_index += 1
		RunState.customers_per_day = clampi(3 + RunState.day_index * 2, 5, 10)
		push_warning("InteractionController: DaySystem no encontrado, avanzando día manualmente")

	# Buscar DaySetupUI y mostrarla con las nuevas películas
	var setup_nodes := get_tree().get_nodes_in_group("day_setup_ui")
	if setup_nodes.size() > 0:
		var setup := setup_nodes[0]
		if setup.has_method("load_day"):
			setup.call("load_day")
		setup.show()

func _update_debug() -> void:
	if not DebugConfig.ENABLE_DEBUG:
		return
	var hits   := int(RunState.day_hits)
	var misses := int(RunState.day_misses)
	var s := "DEBUG: Aciertos %d | Fallos %d | $%d" % [hits, misses, RunState.day_money]
	if _last_result != "":
		s += " | Último: %s" % _last_result
	if hud != null and is_instance_valid(hud):
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
