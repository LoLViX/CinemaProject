extends Node
class_name MovieDB

# Dos clases SIEMPRE:
# Larga >= 140 min -> slow
# si no -> fast
static func pace_tag(runtime_min: int) -> String:
	return "slow" if runtime_min >= 140 else "fast"

static func movie(id: String, poster: String, runtime_min: int, tags: Array) -> Dictionary:
	var pace := pace_tag(runtime_min)
	var true_tags: Array = tags.duplicate()
	true_tags.append(pace)

	return {
		"id": id,
		"poster": poster,
		"runtime_min": runtime_min,
		"title_key": "movie.%s.title" % id,
		"syn_key": "movie.%s.syn" % id,
		"true_tags": true_tags,
		"pace": pace,
	}

static var MOVIES: Array = [
	movie("alien", "res://Assets/Posters/alien.jpg", 116, ["horror","scifi","thriller"]),
	movie("back_to_the_future", "res://Assets/Posters/back_to_the_future.jpg", 116, ["scifi","adventure","comedy"]),
	movie("blade_runner", "res://Assets/Posters/blade_runner.jpg", 117, ["scifi","thriller","crime"]),
	movie("dark_knight", "res://Assets/Posters/dark_knight.jpg", 152, ["action","thriller","crime"]),
	movie("die_hard", "res://Assets/Posters/die_hard.jpg", 132, ["action","thriller"]),
	movie("exorcist", "res://Assets/Posters/exorcist.jpg", 122, ["horror","thriller"]),
	movie("gladiator", "res://Assets/Posters/gladiator.jpg", 155, ["action","drama","adventure"]),
	movie("godfather", "res://Assets/Posters/godfather.jpg", 175, ["crime","drama"]),
	movie("jaws", "res://Assets/Posters/jaws.jpg", 124, ["thriller","horror"]),
	movie("jurassic_park", "res://Assets/Posters/jurassic_park.jpg", 127, ["adventure","scifi","thriller"]),
	movie("matrix", "res://Assets/Posters/matrix.jpg", 136, ["action","scifi","thriller"]),
	movie("monty_python_and_the_holy_grail", "res://Assets/Posters/monty_python_and_the_holy_grail.jpg", 92, ["comedy","adventure"]),
	movie("pulp_fiction", "res://Assets/Posters/pulp_fiction.jpg", 154, ["crime","drama"]),
	movie("raiders_of_the_lost_ark", "res://Assets/Posters/raiders_of_the_lost_ark.jpg", 115, ["adventure","action"]),
	movie("seven", "res://Assets/Posters/seven.jpg", 127, ["thriller","crime","mystery"]),
	movie("shining", "res://Assets/Posters/shining.jpg", 144, ["horror","mystery","thriller"]),
	movie("silence_of_the_lambs", "res://Assets/Posters/silence_of_the_lambs.jpg", 118, ["thriller","crime"]),
	movie("terminator_two", "res://Assets/Posters/terminator_two.jpg", 137, ["action","scifi","thriller"]),
	movie("thing", "res://Assets/Posters/thing.jpg", 109, ["horror","scifi","mystery"]),
	movie("two_thousand_and_one_a_space_odyssey", "res://Assets/Posters/two_thousand_and_one_a_space_odyssey.jpg", 139, ["scifi","mystery","drama"]),
]

static func draw_unique_for_run(count: int) -> Array:
	var available: Array = []
	for m in MOVIES:
		var id: String = String(m.get("id",""))
		if id != "" and not RunState.is_used(id):
			available.append(m)

	available.shuffle()

	var picked: Array = []
	var n: int = mini(count, available.size())
	for i in range(n):
		var mm: Dictionary = available[i]
		var mid: String = String(mm.get("id",""))
		RunState.mark_used(mid)
		picked.append(mm)

	return picked

static func todays_movies(count: int = 5) -> Array:
	return draw_unique_for_run(count)
