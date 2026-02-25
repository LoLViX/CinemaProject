extends Node
class_name DaySystem

var todays_movies: Array = [] # Array[Dictionary]

# Número de películas en cartelera (más días = más variedad)
func _movies_for_day(day_number: int) -> int:
	return clampi(4 + day_number, 5, 8)  # D1→5, D2→6, D3→7, D4+→8

# Clientes por día: D1→5, D2→7, D3+→10
func _customers_for_day(day_number: int) -> int:
	return clampi(3 + day_number * 2, 5, 10)

func start_new_run() -> void:
	RunState.reset_run()
	start_day(1)

func start_day(day_number: int) -> void:
	RunState.day_index = day_number
	RunState.customers_per_day = _customers_for_day(day_number)
	todays_movies = MovieDB.draw_unique_for_run(_movies_for_day(day_number))

func next_day() -> void:
	RunState.reset_day_stats()
	start_day(RunState.day_index + 1)
