extends Node
class_name MovieDB

# Pace automático: >= 140 min → slow_burn
static func pace_tag(runtime_min: int) -> String:
	return "slow_burn" if runtime_min >= 140 else "fast"

static func movie(id: String, poster: String, runtime_min: int, tags: Array) -> Dictionary:
	var pace := pace_tag(runtime_min)
	var true_tags: Array = tags.duplicate()
	if not true_tags.has(pace):
		true_tags.append(pace)

	# Compute main genre (6 options) from existing tags
	var main_genre := main_genre_from_tags(true_tags)

	return {
		"id": id,
		"poster": poster,
		"runtime_min": runtime_min,
		"title_key": "movie.%s.title" % id,
		"syn_key": "movie.%s.syn" % id,
		"true_tags": true_tags,  # keep fine-grained tags in English (existing system)
		"pace": pace,
		"genre": main_genre,      # NEW: 6-genre label for UI
	}

# ── Genre normalization (UI-friendly) ─────────────────────────────────────────
# Keep your existing tags in English:
# action, drama, comedy, horror, thriller, mystery,
# scifi, crime, fantasy, adventure, dark, popcorn
#
# NEW: main genre output (5 only): Action, Comedy, Drama, Horror, Sci-Fi
#
# Priority rules:
# - If it's tagged horror -> Horror (even if thriller/mystery)
# - Else if tagged scifi -> Sci-Fi
# - Else if tagged comedy -> Comedy
# - Else if tagged action -> Action
# - Else -> Drama (fallback: crime/thriller/mystery/adventure/fantasy often live here)
static func main_genre_from_tags(tags: Array) -> String:
	if tags.has("horror"):
		return "Horror"
	if tags.has("scifi"):
		return "Sci-Fi"
	if tags.has("comedy"):
		return "Comedy"
	if tags.has("action"):
		return "Action"
	return "Drama"

# Convenience: get main genre for a movie dictionary
static func get_main_genre(m: Dictionary) -> String:
	var g := String(m.get("genre", ""))
	if g != "":
		return g
	return main_genre_from_tags(m.get("true_tags", []))

# Optional: get list of available main genres (for UI buttons)
static func main_genres() -> Array:
	return ["Action", "Comedy", "Drama", "Horror", "Sci-Fi"]

# ── Catálogo ───────────────────────────────────────────────────────────────────
static var MOVIES: Array = [

	# Alien (1979) — terror espacial claustrofóbico
	movie("alien", "res://Assets/Posters/alien.jpg", 116,
		["horror", "scifi", "thriller", "dark"]),

	# Back to the Future (1985) — comedia sci-fi familiar
	movie("back_to_the_future", "res://Assets/Posters/back_to_the_future.jpg", 116,
		["scifi", "adventure", "comedy", "popcorn"]),

	# Blade Runner (1982) — sci-fi noir contemplativo
	movie("blade_runner", "res://Assets/Posters/blade_runner.jpg", 117,
		["scifi", "thriller", "crime", "mystery", "dark"]),

	# The Dark Knight (2008) — acción con drama y crimen
	movie("dark_knight", "res://Assets/Posters/dark_knight.jpg", 152,
		["action", "thriller", "crime", "drama", "dark"]),

	# Die Hard (1988) — acción entretenida con humor
	movie("die_hard", "res://Assets/Posters/die_hard.jpg", 132,
		["action", "thriller", "comedy", "popcorn"]),

	# The Exorcist (1973) — terror dramático e intenso
	movie("exorcist", "res://Assets/Posters/exorcist.jpg", 122,
		["horror", "thriller", "drama", "dark", "mystery"]),

	# Gladiator (2000) — épica de acción y drama
	movie("gladiator", "res://Assets/Posters/gladiator.jpg", 155,
		["action", "drama", "adventure", "dark"]),

	# The Godfather (1972) — drama criminal denso
	movie("godfather", "res://Assets/Posters/godfather.jpg", 175,
		["crime", "drama", "thriller", "dark"]),

	# Jaws (1975) — thriller de suspense con aventura
	movie("jaws", "res://Assets/Posters/jaws.jpg", 124,
		["thriller", "horror", "adventure"]),

	# Jurassic Park (1993) — aventura sci-fi espectacular
	movie("jurassic_park", "res://Assets/Posters/jurassic_park.jpg", 127,
		["adventure", "scifi", "thriller", "popcorn"]),

	# The Matrix (1999) — acción sci-fi filosófica
	movie("matrix", "res://Assets/Posters/matrix.jpg", 136,
		["action", "scifi", "thriller", "adventure"]),

	# Monty Python (1975) — comedia pura para pasar el rato
	movie("monty_python_and_the_holy_grail",
		"res://Assets/Posters/monty_python_and_the_holy_grail.jpg", 92,
		["comedy", "adventure", "fantasy", "popcorn"]),

	# Pulp Fiction (1994) — crimen oscuro con humor negro
	movie("pulp_fiction", "res://Assets/Posters/pulp_fiction.jpg", 154,
		["crime", "drama", "thriller", "dark"]),

	# Raiders of the Lost Ark (1981) — aventura de acción ligera
	movie("raiders_of_the_lost_ark",
		"res://Assets/Posters/raiders_of_the_lost_ark.jpg", 115,
		["adventure", "action", "comedy", "popcorn"]),

	# Se7en (1995) — thriller policiaco muy oscuro
	movie("seven", "res://Assets/Posters/seven.jpg", 127,
		["thriller", "crime", "mystery", "dark", "drama"]),

	# The Shining (1980) — terror psicológico y oscuro
	movie("shining", "res://Assets/Posters/shining.jpg", 144,
		["horror", "mystery", "thriller", "dark", "drama"]),

	# The Silence of the Lambs (1991) — thriller perturbador
	movie("silence_of_the_lambs",
		"res://Assets/Posters/silence_of_the_lambs.jpg", 118,
		["thriller", "crime", "horror", "mystery", "dark"]),

	# Terminator 2 (1991) — acción sci-fi trepidante
	movie("terminator_two", "res://Assets/Posters/terminator_two.jpg", 137,
		["action", "scifi", "thriller", "adventure", "popcorn"]),

	# The Thing (1982) — horror sci-fi oscuro y claustrofóbico
	movie("thing", "res://Assets/Posters/thing.jpg", 109,
		["horror", "scifi", "mystery", "dark", "thriller"]),

	# 2001: A Space Odyssey (1968) — sci-fi filosófico muy contemplativo
	movie("two_thousand_and_one_a_space_odyssey",
		"res://Assets/Posters/two_thousand_and_one_a_space_odyssey.jpg", 139,
		["scifi", "mystery", "drama", "dark"]),
]

static func draw_unique_for_run(count: int) -> Array:
	# Cada día se baraja el catálogo completo — las pelis PUEDEN repetirse entre días.
	# Solo se garantiza diversidad de género dentro del mismo día.
	var available: Array = MOVIES.duplicate()
	available.shuffle()

	var picked: Array = []
	var genre_count: Dictionary = {}

	# Step 1: Fill with genre diversity (max 2 per genre)
	for m in available:
		if picked.size() >= count:
			break
		var genre: String = get_main_genre(m)
		if genre_count.get(genre, 0) < 2:
			picked.append(m)
			genre_count[genre] = genre_count.get(genre, 0) + 1

	# Step 2: Fallback — relax constraint if still short
	if picked.size() < count:
		for m in available:
			if picked.size() >= count:
				break
			if not picked.has(m):
				picked.append(m)

	# Step 3: Special Room guarantee — solo en Fase 2+
	if RunState.CURRENT_PHASE >= 2 and picked.size() >= 2:
		var sr_genre := get_main_genre(picked[picked.size() - 1])
		var has_match := false
		for i in range(picked.size() - 1):
			if get_main_genre(picked[i]) == sr_genre:
				has_match = true
				break
		if not has_match:
			for m in available:
				if not picked.has(m) and get_main_genre(m) == sr_genre:
					picked[0] = m
					break

	return picked

static func todays_movies(count: int = 5) -> Array:
	return draw_unique_for_run(count)
