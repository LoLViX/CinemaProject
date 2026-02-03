extends Node
class_name DaySystem

var todays_movies: Array = [] # Array[Dictionary]

func start_new_run() -> void:
	RunState.reset_run()
	start_day(1)

func start_day(day_number: int) -> void:
	RunState.day_index = day_number
	todays_movies = MovieDB.draw_unique_for_run(5)

func next_day() -> void:
	start_day(RunState.day_index + 1)
