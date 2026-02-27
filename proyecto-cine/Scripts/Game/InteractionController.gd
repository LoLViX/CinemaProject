extends Node
class_name InteractionController

const _StockPurchaseUIScript  = preload("res://Scripts/UI/StockPurchaseUI.gd")
const _PatienceSystemScript   = preload("res://Scripts/Game/PatienceSystem.gd")
const _DialogueSystemScript   = preload("res://Scripts/Game/DialogueSystem.gd")

# ── FUNCTION MAP (leer solo líneas necesarias en cada sesión) ─────────────────
# _ready()                    L57  — setup nodos, señales, patience, dialogue
# _start_day()                L117 — init lista clientes, satisfacción máx
# _process()                  L162 — barra paciencia + input E
# _on_recommend_movie()       L225 — matching, dinero, → fase comida
# _on_food_done()             L305 — propina, stock, satisfacción bandeja
# _show_reaction()            L409 — label flotante sobre cliente 3D
# _advance_customer()         L441 — avanzar índice, fin de día
# _show_end_of_day()          L454 — eventos fin día, StockPurchaseUI
# _show_results_screen()      L497 — EndOfDayUI
# _on_next_day()              L510 — DaySystem.next_day(), DaySetupUI
# _on_patience_warning()      L562 — aviso paciencia baja
# _on_patience_depleted()     L574 — cliente se va sin ser atendido
# _on_counter_ready()         L602 — cliente llega al mostrador
# _on_counter_left()          L618 — cliente sale
# _needs_dialogue()           L633 — ¿NPC necesita diálogo previo?
# _show_npc_dialogue()        L644 — familia / grief / NPC encounter
# _open_movie_panel()         L685 — abre panel de recomendar película
# _get_supplanted_encounter() L691 — encuentro entidad para suplantado (Fase 2+)
# _start_food_directly()      L718 — fase comida sin película (duelo, Fase 2+)
# _update_special_room_hud()  L755 — actualiza indicador Sala Especial (Fase 2+)
# ─────────────────────────────────────────────────────────────────────────────

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

# PatienceSystem
var _patience: Node = null

# DialogueSystem
var _dialogue: Node = null

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

	# PatienceSystem
	_patience = _PatienceSystemScript.new()
	add_child(_patience)
	_patience.patience_depleted.connect(_on_patience_depleted)
	_patience.patience_warning.connect(_on_patience_warning)
	_patience.patience_critical.connect(_on_patience_critical)

	# DialogueSystem — se adjunta al HUD para que el panel salga en 2D
	_dialogue = _DialogueSystemScript.new()
	add_child(_dialogue)
	_dialogue.init(hud)
	# Drenar paciencia cuando el jugador hace una pregunta al NPC
	_dialogue.question_asked.connect(func():
		if _patience != null:
			_patience.drain_wrong_answer()
	)

	# ContaminationManager — aplicar tinte cuando el nivel cambia (Fase 2+)
	if RunState.CURRENT_PHASE >= 2:
		if ContaminationManager.has_signal("level_changed"):
			ContaminationManager.level_changed.connect(func(_lv: float):
				ContaminationManager.apply_hud_tint(hud)
			)
		ContaminationManager.apply_hud_tint(hud)

	# SpecialRoom — actualizar indicador de sala especial (Fase 2+)
	if RunState.CURRENT_PHASE >= 2:
		if SpecialRoom.has_signal("neutralized"):
			SpecialRoom.neutralized.connect(func(_id: String): _update_special_room_hud())
		if SpecialRoom.has_signal("capacity_recharged"):
			SpecialRoom.capacity_recharged.connect(func(_cap: int): _update_special_room_hud())

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
	# day_max_satisfaction se calcula después de saber cuántos clientes hay

	var day_i := int(RunState.day_index) if "day_index" in RunState else 1

	# Dificultad escala con el día (1→3)
	var difficulty := clampi(day_i, 1, 3)
	_customer_list = DayPlanDB.build_day(day_i, difficulty)

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

	# Pasar ilustraciones al CustomerManager para asignar sprites
	if manager.has_method("set_illustrations"):
		var illus_list: Array = []
		for c in _customer_list:
			illus_list.append(c.get("illustration", ""))
		manager.call("set_illustrations", illus_list)

	if manager.has_method("start_day"):
		manager.call("start_day", _customer_list.size())

	# Calcular satisfacción máxima posible del día
	var normal_count: int = 0
	for c in _customer_list:
		if not _is_special(c):
			normal_count += 1
	RunState.day_max_satisfaction = normal_count * RunState.SAT_MAX_PER_CUSTOMER
	_update_satisfaction_hud()

	# Actualizar cola visual
	_update_queue()


func _process(_delta: float) -> void:
	# Actualizar barra de paciencia cada frame (tanto en fase conversación como comida)
	if _patience != null and _counter_ready:
		if hud != null and is_instance_valid(hud) and hud.has_method("set_patience_bar"):
			var profile := String(_current_customer.get("patience_profile", "normal"))
			if profile != "entity" and not _patience.is_depleted():
				var is_crit: bool = _patience.is_critical()
				hud.call("set_patience_bar", true, _patience.get_fraction(), is_crit)
			elif profile == "entity" or _patience.is_depleted():
				hud.call("set_patience_bar", false, 0.0, false)

	if _in_food:
		return

	# Solo responder a E si el contador está listo
	if not _counter_ready:
		return

	if Input.is_action_just_pressed("serve_next"):
		# Si el panel de recomendar está abierto, ignorar E
		if hud.has_method("is_attend_open") and hud.call("is_attend_open"):
			return

		# Si el diálogo de NPC está abierto, ignorar E
		if _dialogue != null and _dialogue.is_open():
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

		# NPCs con narrative_arc y familia_alterada → diálogo primero
		if _needs_dialogue(_current_customer):
			_show_npc_dialogue()
			return

		# Normal: abrir panel de recomendar película
		_open_movie_panel()

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

	# Threshold dinámico: 1 must → threshold 1, 2 musts → threshold 2.
	var must_count: int = (_current_customer.get("must", []) as Array).size()
	var match_threshold: int = max(1, must_count)
	var ok: bool = MatchingSystem.pass_fail(_current_customer, movie.get("true_tags", []), match_threshold)

	# Entrada fija independientemente del acierto
	RunState.earn_money(RunState.TICKET_PRICE)
	if hud.has_method("show_money_popup"):
		hud.call("show_money_popup", "+$%d entrada" % RunState.TICKET_PRICE)

	# Si es entidad y elige la película de la Sala Especial → neutralización (Fase 2+)
	if RunState.CURRENT_PHASE >= 2:
		var is_entity: bool = String(_current_customer.get("patience_profile", "")) == "entity"
		if is_entity and RunState.todays_movies.size() > 0:
			var sr_movie_id: String = String(RunState.todays_movies.back().get("id", ""))
			if movie_id == sr_movie_id:
				var sr_npc_id: String = String(_current_customer.get("npc_id", ""))
				if sr_npc_id != "":
					SpecialRoom.try_neutralize(sr_npc_id)

	if ok:
		RunState.day_hits += 1
		_last_result = "OK"
		RunState.add_satisfaction(RunState.SAT_MOVIE_HIT)
		SoundManager.play_success()
	else:
		RunState.day_misses += 1
		_last_result = "FALLO"
		# No satisfacción por mala recomendación (tampoco drena paciencia, solo satisfacción)
		SoundManager.play_fail()
		# La familia alterada penaliza la estabilidad (Fase 2+)
		if RunState.CURRENT_PHASE >= 2:
			if String(_current_customer.get("type", "")) == "familia_alterada":
				StabilityManager.apply_delta(-15)
				if hud != null and is_instance_valid(hud):
					hud.call("show_message", "Los Henderson parecen… incómodos.", 2.0)

	_update_debug()
	_update_satisfaction_hud()

	_in_food = true
	# Cambiar paciencia a modo comida (drena más lento)
	if _patience != null:
		_patience.set_mode_food()
	# Ocultar Sala Especial durante la fase de comida (Fase 2+)
	if RunState.CURRENT_PHASE >= 2:
		if hud != null and is_instance_valid(hud) and hud.has_method("hide_special_room"):
			hud.call("hide_special_room")

	# La película no genera reacción textual — solo afecta satisfacción y sonido.
	# El cliente pide su comida directamente.
	var food_key:  String = String(_current_customer.get("food_key", "cust.foodask.1"))
	_pending_goodbye_key   = String(_current_customer.get("bye_key", "cust.goodbye.1"))

	hud.call("show_message", TextDB.t(food_key), 1.4)
	get_tree().create_timer(1.4).timeout.connect(func():
		if food.has_method("start_food_phase"):
			var food_order: Dictionary = _current_customer.get("food_order", {})
			# Distorsión de comida solo en Fase 2+
			if RunState.CURRENT_PHASE >= 2:
				food_order = ContaminationManager.distort_food_order(food_order)
			food.call("start_food_phase", food_order)
		else:
			_on_food_done()
	)

func _on_food_done() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if _patience != null:
		_patience.stop()
	if hud.has_method("set_patience_bar"):
		hud.call("set_patience_bar", false, 0.0)

	# Registrar lo que ha consumido este cliente (tracking de stock vendido)
	var customer_food_order: Dictionary = _current_customer.get("food_order", {})
	StockManager.track_sold(customer_food_order)

	# Ingresos por venta de comida
	var food_rev: int = StockManager.food_revenue(customer_food_order)
	if food_rev > 0:
		RunState.earn_money(food_rev)
		if hud != null and is_instance_valid(hud) and hud.has_method("show_money_popup"):
			hud.call("show_money_popup", "+$%d comida" % food_rev)

	# ── Evaluar bandeja ANTES de dar propina ──────────────────
	var tray_complete := false
	var order_hud := get_tree().get_root().find_child("*OrderHUD*", true, false)
	if order_hud == null:
		order_hud = get_tree().get_root().find_child("CustomerOrderHUD", true, false)

	# Obtener el nodo del cliente ahora (antes de que se vaya)
	var customer_node: Node = null
	if manager != null and manager.has_method("get_counter_customer"):
		customer_node = manager.call("get_counter_customer")

	# Evaluar bandeja para satisfacción
	if order_hud != null and order_hud.has_method("is_complete"):
		var tray_state: Dictionary = {}
		if food != null and food.has_method("get_last_tray_state"):
			tray_state = food.call("get_last_tray_state")
		tray_complete = order_hud.call("is_complete", tray_state)
		_last_food_complete = tray_complete

		if tray_complete:
			RunState.add_satisfaction(RunState.SAT_FOOD_PERFECT)
			SoundManager.play_cash()
		else:
			# Parcial solo si al menos 1 item pedido está bien Y no hay extras
			var correct: int = 0
			if order_hud.has_method("correct_count"):
				correct = order_hud.call("correct_count", tray_state)
			if correct > 0:
				RunState.add_satisfaction(RunState.SAT_FOOD_PARTIAL)
			# correct == 0 → 0 satisfacción (todo mal o todo vacío)

	_update_satisfaction_hud()

	# Propina solo si la comida fue perfecta
	if tray_complete:
		var tip_amount: int = int(_current_customer.get("tip", 2))
		if tip_amount > 0:
			RunState.earn_money(tip_amount)
			if hud != null and is_instance_valid(hud) and hud.has_method("show_money_popup"):
				hud.call("show_money_popup", "+$%d propina" % tip_amount)

	# Texto flotante sobre el cliente (solo valora comida)
	if is_instance_valid(customer_node):
		_show_reaction(customer_node, tray_complete)

	hud.call("show_message", TextDB.t(_pending_goodbye_key), 1.2)

	var mgr_ref := manager
	var food_ref := food
	var _hud_ref := hud

	# Registrar visita NPC si corresponde (satisfacción solo por comida)
	var npc_id: String = String(_current_customer.get("npc_id", ""))
	if npc_id != "":
		var sat_delta: int = 10 if tray_complete else -5
		NPCRegistry.record_visit(npc_id, sat_delta)

	# Marcar NPC como visto hoy
	var npc_id_track: String = String(_current_customer.get("npc_id", ""))
	if npc_id_track != "" and not RunState.npc_seen_today.has(npc_id_track):
		RunState.npc_seen_today.append(npc_id_track)

	# La bandeja ya está en el ServePoint (movida al acabar food phase).
	# Esperar 2s para que el jugador la vea, luego quitar y despachar.
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(food_ref) and food_ref.has_method("dismiss_tray"):
			food_ref.call("dismiss_tray")
		if not is_instance_valid(mgr_ref):
			return
		mgr_ref.call("serve_current")
		_in_food = false
		_advance_customer()
		_update_debug()
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
	# Calcular must_appear_tomorrow
	RunState.compute_must_appear()

	# Procesar eventos de fin de día — Fase 2+
	if RunState.CURRENT_PHASE >= 2:
		EventsManager.process_end_of_day()       # muertes por distorsión
		SpecialRoom.end_of_day(RunState.satisfaction_fraction())  # recarga sala especial

	# Convertir satisfacción diaria en cambio de fama
	FameManager.process_end_of_day(RunState.satisfaction_fraction())

	# Auto-save al final del día (slot 1)
	SaveManager.save_slot(1)

	# Comprobar finales antes de mostrar aprovisionamiento
	EndingManager.check()
	if EndingManager.is_ended():
		return

	# Victoria: completar día 10
	if RunState.day_index >= 10:
		if RunState.CURRENT_PHASE >= 2:
			# Fase 2+: victoria condicionada por estabilidad
			var victory_type: String = "victory"
			if StabilityManager.stability < 40.0:
				victory_type = "hollow"
			EndingManager.trigger_victory(victory_type)
		else:
			# Fase 1: victoria simple
			EndingManager.trigger_victory("victory")
		return

	# Mostrar panel de compra de stock primero
	var spu := _StockPurchaseUIScript.new()
	get_tree().root.add_child(spu)
	spu.show_purchase(StockManager.end_of_day_summary())
	spu.purchase_confirmed.connect(func(_cost: int):
		if is_instance_valid(spu):
			spu.queue_free()
		_show_results_screen()
	)

func _show_results_screen() -> void:
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

	# Ocultar Sala Especial durante la pantalla de cartelera (Fase 2+)
	if RunState.CURRENT_PHASE >= 2:
		if hud != null and is_instance_valid(hud) and hud.has_method("hide_special_room"):
			hud.call("hide_special_room")

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

func _update_satisfaction_hud() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if hud.has_method("update_satisfaction"):
		hud.call("update_satisfaction",
			RunState.day_satisfaction,
			RunState.day_max_satisfaction
		)

# ── PatienceSystem ─────────────────────────────────────────────

func _on_patience_warning(fraction: float) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if fraction <= 0.25:
		if hud.has_method("show_message"):
			hud.call("show_message", "…", 0.8)

func _on_patience_critical() -> void:
	# Fase 2 activada — mostrar aviso visual
	if hud != null and is_instance_valid(hud) and hud.has_method("show_message"):
		hud.call("show_message", "El cliente se está impacientando...", 2.0)

func _on_patience_depleted() -> void:
	if _in_food:
		# En fase comida: ya no hay vuelta atrás, dejar que _on_food_done lo gestione
		return
	if not _counter_ready:
		return

	# Cliente se va por falta de paciencia
	if RunState.CURRENT_PHASE >= 2:
		StabilityManager.apply_delta(-5)  # Estabilidad solo en Fase 2+
	_counter_ready = false

	if hud != null and is_instance_valid(hud):
		hud.call("hide_prompt")
		hud.call("hide_attend")
		hud.call("show_message", _random_impatience_message(), 2.0)
		if hud.has_method("set_patience_bar"):
			hud.call("set_patience_bar", false, 0.0)

	if manager != null and is_instance_valid(manager):
		manager.call("serve_current")

	_in_food = false
	_advance_customer()
	_update_debug()

# ── Señales del CustomerManager ────────────────────────────────

func _on_counter_ready(_customer: Node) -> void:
	_counter_ready = true
	# Mostrar el prompt solo en este momento exacto
	if not _in_food:
		hud.call("show_prompt", "ui.counter_ready")
	# Iniciar paciencia con el perfil del cliente actual
	if _patience != null and not _current_customer.is_empty():
		var profile: String = String(_current_customer.get("patience_profile", "normal"))
		_patience.start_for(profile)
	# Restaurar indicador Sala Especial al llegar un cliente (Fase 2+)
	if RunState.CURRENT_PHASE >= 2 and not _in_food:
		_update_special_room_hud()

func _on_counter_changed(customer: Node) -> void:
	_counter_ready = (customer != null)

func _on_counter_left(_customer: Node) -> void:
	_counter_ready = false
	_special_waiting_ack = false
	hud.call("hide_prompt")
	hud.call("hide_message")
	if hud.has_method("set_patience_bar"):
		hud.call("set_patience_bar", false, 0.0)
	if _patience != null:
		_patience.stop()
	if _dialogue != null:
		_dialogue.hide()

# ── DialogueSystem y eventos narrativos ────────────────────────

## True si este cliente necesita pasar por el diálogo antes del panel de películas.
func _needs_dialogue(c: Dictionary) -> bool:
	if bool(c.get("is_grieving", false)):
		return true
	if String(c.get("type", "")) == "familia_alterada":
		return true
	var npc_id := String(c.get("npc_id", ""))
	if npc_id == "":
		return false
	return true  # todos los NPCs pasan por diálogo

## Muestra el panel de diálogo contextual para el cliente actual (NPC o familia).
func _show_npc_dialogue() -> void:
	if _dialogue == null:
		_open_movie_panel()
		return

	var ctype := String(_current_customer.get("type", ""))

	if ctype == "familia_alterada":
		_dialogue.show_simple(
			"The Hendersons",
			String(_current_customer.get("request_text", "...")),
			[{"text": "Recomendar una película →", "action": Callable(self, "_open_movie_panel")}]
		)
		return

	# Grief: primer cliente en duelo
	if bool(_current_customer.get("is_grieving", false)):
		_dialogue.show_simple(
			String(_current_customer.get("display_name", "Cliente")),
			String(_current_customer.get("grief_text", "...")),
			[{"text": "Claro... pasa.", "action": Callable(self, "_start_food_directly")}]
		)
		return

	# NPC normal o suplantado con encounter
	var npc_id := String(_current_customer.get("npc_id", ""))
	var encounter: Dictionary = {}

	if bool(_current_customer.get("is_supplanted", false)):
		# Suplantado: usar encuentro de entidad en vez del humano
		encounter = _get_supplanted_encounter(npc_id)
	else:
		encounter = NPCRegistry.get_current_encounter(npc_id)

	if encounter.is_empty():
		_open_movie_panel()
		return

	_dialogue.show_encounter(npc_id, encounter, Callable(self, "_open_movie_panel"))

## Abre el panel de selección de película (llamado desde el diálogo o directamente).
func _open_movie_panel() -> void:
	var line: String = String(_current_customer.get("request_text", "Hola… ¿me recomiendas algo?"))
	hud.call("show_attend", line, RunState.todays_movies, RunState.player_tags_by_movie)

## Devuelve un encuentro de entidad aleatorio para un NPC suplantado.
## El humano mantiene su apariencia pero usa diálogos de entidad.
func _get_supplanted_encounter(_npc_id: String) -> Dictionary:
	# Buscar todos los NPCs entidad en el pool
	var entity_ids: Array = []
	for eid in RunState.run_npc_pool:
		if NPCRegistry.get_effective_type(eid) == "entity":
			entity_ids.append(eid)
	if entity_ids.is_empty():
		# Fallback: buscar cualquier entidad en el registro
		for eid in ["entidad_a", "entidad_b"]:
			if NPCRegistry.npc_exists(eid):
				entity_ids.append(eid)
	if entity_ids.is_empty():
		return {}
	# Elegir entidad y encuentro al azar
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen_entity: String = entity_ids[rng.randi_range(0, entity_ids.size() - 1)]
	var def: Dictionary = NPCRegistry.get_npc(chosen_entity)
	var encounters: Array = def.get("encounters", [])
	if encounters.is_empty():
		return {}
	# Usar un encuentro aleatorio (evitar el 0 que es presentación si hay más)
	var min_idx: int = 1 if encounters.size() > 1 else 0
	var idx: int = rng.randi_range(min_idx, encounters.size() - 1)
	return encounters[idx] as Dictionary

## Inicia la fase de comida directamente sin recomendar película (cliente en duelo — Fase 2+).
func _start_food_directly() -> void:
	_in_food = true
	if _patience != null:
		_patience.set_mode_food()
	if RunState.CURRENT_PHASE >= 2:
		if hud != null and is_instance_valid(hud) and hud.has_method("hide_special_room"):
			hud.call("hide_special_room")
	var food_order: Dictionary = _current_customer.get("food_order", {})
	if RunState.CURRENT_PHASE >= 2:
		food_order = ContaminationManager.distort_food_order(food_order)
	if food != null and food.has_method("start_food_phase"):
		food.call("start_food_phase", food_order)
	else:
		_on_food_done()

# ── Mensajes de impaciencia ─────────────────────────────────────

func _random_impatience_message() -> String:
	var path := "res://Data/events.json"
	if not FileAccess.file_exists(path):
		return "…"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "…"
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not (parsed is Dictionary):
		return "…"
	var msgs: Array = ((parsed as Dictionary).get("impatience_messages", []) as Array)
	if msgs.is_empty():
		return "…"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return String(msgs[rng.randi_range(0, msgs.size() - 1)])

# ── Sala Especial ───────────────────────────────────────────────

func _update_special_room_hud() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if hud.has_method("update_special_room"):
		hud.call("update_special_room", SpecialRoom.get_capacity(), SpecialRoom.get_used())
