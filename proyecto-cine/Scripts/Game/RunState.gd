extends Node

var todays_movies: Array = []             # Array[Dictionary]
var player_tags_by_movie: Dictionary = {} # movie_id -> Array[String]
var used_movie_ids: Dictionary = {}       # id -> true
var day_index: int = 1
var customers_per_day: int = 5           # escala con el día

var day_hits: int = 0
var day_misses: int = 0
var day_money: int = 0                   # dinero ganado hoy
var total_money: int = 0                 # acumulado de toda la partida

func reset_run() -> void:
	used_movie_ids.clear()
	todays_movies.clear()
	player_tags_by_movie.clear()
	day_index = 1
	customers_per_day = 5
	total_money = 0
	reset_day_stats()

func reset_day_stats() -> void:
	day_hits = 0
	day_misses = 0
	day_money = 0

func earn_money(amount: int) -> void:
	day_money += amount
	total_money += amount

func day_rating() -> String:
	var total := day_hits + day_misses
	if total == 0:
		return "SIN DATOS"
	var pct := float(day_hits) / float(total)
	if pct >= 0.8:
		return "EXCELENTE"
	elif pct >= 0.6:
		return "BUENO"
	elif pct >= 0.4:
		return "REGULAR"
	else:
		return "MAL DÍA"

func is_used(id: String) -> bool:
	return used_movie_ids.has(id)

func mark_used(id: String) -> void:
	if id != "":
		used_movie_ids[id] = true
