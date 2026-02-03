extends Node
class_name InteractionController

const ABS_DAYSETUP: String = "/root/Main/UI/DaySetupUI"
const ABS_UI_ROOT: String = "/root/Main/UI"
const ABS_CUSTOMER_MANAGER: String = "/root/Main/Customers/CustomerManager"
const ABS_DAYPLANDB: String = "/root/DayPlanDB"
const ABS_RUNSTATE: String = "/root/RunState"

@export var fallback_customers_per_day: int = 12

var _daysetup: Node = null
var _hud: Node = null
var _cm: Node = null
var _dayplan: Node = null
var _runstate: Node = null

var _waiting_day_setup: bool = true
var _day_started: bool = false

var _counter_ready: bool = false
var _attending: bool = false

func _ready() -> void:
	_daysetup = get_node_or_null(ABS_DAYSETUP)
	_hud = get_node_or_null(ABS_UI_ROOT)
	_cm = get_node_or_null(ABS_CUSTOMER_MANAGER)
	_dayplan = get_node_or_null(ABS_DAYPLANDB)
	_runstate = get_node_or_null(ABS_RUNSTATE)

	_counter_ready = false
	_attending = false
	_day_started = false

	# DaySetupUI
	if _daysetup != null and _daysetup.has_signal("day_setup_done"):
		if not _daysetup.is_connected("day_setup_done", Callable(self, "_on_day_setup_done")):
			_daysetup.connect("day_setup_done", Callable(self, "_on_day_setup_done"))
	else:
		_waiting_day_setup = false
		_start_day()

	# CustomerManager signals
	if _cm == null:
		push_error("IC: no encuentro CustomerManager en " + ABS_CUSTOMER_MANAGER)
	else:
		if _cm.has_signal("counter_customer_ready"):
			if not _cm.is_connected("counter_customer_ready", Callable(self, "_on_counter_ready")):
				_cm.connect("counter_customer_ready", Callable(self, "_on_counter_ready"))

		if _cm.has_signal("counter_customer_left"):
			if not _cm.is_connected("counter_customer_left", Callable(self, "_on_counter_left")):
				_cm.connect("counter_customer_left", Callable(self, "_on_counter_left"))

		if _cm.has_signal("counter_customer_changed"):
			if not _cm.is_connected("counter_customer_changed", Callable(self, "_on_counter_changed")):
				_cm.connect("counter_customer_changed", Callable(self, "_on_counter_changed"))

func _on_day_setup_done() -> void:
	_waiting_day_setup = false
	get_viewport().gui_release_focus()
	_start_day()

func _start_day() -> void:
	if _day_started:
		return
	_day_started = true

	if _cm == null:
		return

	var total := _get_total_customers_for_today()

	if _cm.has_method("start_day"):
		_cm.call("start_day", total)
	elif _cm.has_method("start"):
		_cm.call("start")
	else:
		push_error("IC: CustomerManager sin start_day/start")

func _process(_dt: float) -> void:
	if _waiting_day_setup:
		_hud_hide_prompt()
		return

	if _counter_ready and not _attending:
		_hud_show_prompt("ui.counter_ready")
	else:
		_hud_hide_prompt()

	# E = ATENDER (NO SERVIR)
	if _counter_ready and not _attending and Input.is_action_just_pressed("serve_next"):
		_on_press_attend()

func _on_press_attend() -> void:
	if _cm == null:
		return
	if not _cm.has_method("attend_current"):
		push_error("IC: CustomerManager no tiene attend_current() (debería existir).")
		return

	_attending = true
	_hud_hide_prompt()
	_cm.call("attend_current")

	# OJO: aquí NO seguimos el flujo.
	# El sistema de diálogo/pedido lo debe activar HUD o el manager
	# cuando reciba la señal counter_customer_attended.

func _on_counter_ready(_customer: Node) -> void:
	_counter_ready = true
	_attending = false

func _on_counter_left(_customer: Node) -> void:
	_counter_ready = false
	_attending = false

func _on_counter_changed(customer: Node) -> void:
	_counter_ready = (customer != null)
	if customer == null:
		_attending = false

func _get_total_customers_for_today() -> int:
	var day_index := _get_day_index_safe()

	if _dayplan != null:
		if _dayplan.has_method("get_total_customers_for_day"):
			var v = _dayplan.call("get_total_customers_for_day", day_index)
			if typeof(v) == TYPE_INT:
				return int(v)
		if _dayplan.has_method("get_day_total"):
			var v2 = _dayplan.call("get_day_total", day_index)
			if typeof(v2) == TYPE_INT:
				return int(v2)

	return max(1, fallback_customers_per_day)

func _get_day_index_safe() -> int:
	if _runstate != null:
		if "day_index" in _runstate:
			return int(_runstate.get("day_index"))
		if _runstate.has_method("get_day_index"):
			return int(_runstate.call("get_day_index"))
	return 1

func _hud_show_prompt(key: String) -> void:
	if _hud == null:
		return
	if _hud.has_method("show_prompt"):
		_hud.call("show_prompt", key)

func _hud_hide_prompt() -> void:
	if _hud == null:
		return
	if _hud.has_method("hide_prompt"):
		_hud.call("hide_prompt")
