extends Node
class_name DaySystem

var todays_movies: Array = [] # Array[Dictionary]

# Número de películas en cartelera
func _movies_for_day(day_number: int) -> int:
	if RunState.CURRENT_PHASE == 1:
		return 5  # Fase 1: siempre 5 películas
	return clampi(4 + day_number, 5, 8)  # Fase 2+: D1→5, D2→6, D3→7, D4+→8

# Clientes por día: base por día + modificador de fama
func _customers_for_day(day_number: int) -> int:
	var base := clampi(3 + day_number * 2, 5, 10)
	var fame_mod := FameManager.customer_count_modifier()
	return clampi(base + fame_mod, 3, 13)  # mínimo 3, máximo 13

func start_new_run() -> void:
	RunState.reset_run()
	start_day(1)

func start_day(day_number: int) -> void:
	RunState.day_index = day_number
	RunState.customers_per_day = _customers_for_day(day_number)
	var movies := MovieDB.draw_unique_for_run(_movies_for_day(day_number))
	todays_movies = movies
	RunState.todays_movies = movies   # propagar para que DaySetupUI vea las nuevas

func next_day() -> void:
	RunState.reset_day_stats()
	start_day(RunState.day_index + 1)
