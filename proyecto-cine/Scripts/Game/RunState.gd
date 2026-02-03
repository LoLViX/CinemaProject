extends Node

var todays_movies: Array = []             # Array[Dictionary]
var player_tags_by_movie: Dictionary = {} # movie_id -> Array[String]
var used_movie_ids: Dictionary = {}       # id -> true
var day_index: int = 1

var day_hits: int = 0
var day_misses: int = 0

func reset_run() -> void:
	used_movie_ids.clear()
	todays_movies.clear()
	player_tags_by_movie.clear()
	day_index = 1
	reset_day_stats()

func reset_day_stats() -> void:
	day_hits = 0
	day_misses = 0

func is_used(id: String) -> bool:
	return used_movie_ids.has(id)

func mark_used(id: String) -> void:
	if id != "":
		used_movie_ids[id] = true
