extends Node
class_name MatchingSystem

# Devuelve true si pasa el umbral de coincidencia entre el cliente y los tags de la película.
static func pass_fail(customer: Dictionary, movie_tags: Array, threshold: int = 2) -> bool:
	return score(customer, movie_tags) >= threshold

# Score simple: +1 por cada "must" presente, -1 por cada "must_not" presente
static func score(customer: Dictionary, movie_tags: Array) -> int:
	var s := 0

	var must: Array = customer.get("must", [])
	var must_not: Array = customer.get("must_not", [])

	for t in must:
		if movie_tags.has(t):
			s += 1

	for t in must_not:
		if movie_tags.has(t):
			s -= 1

	return s

# Alias por compatibilidad si lo usabas en algún punto
static func match_score(customer: Dictionary, movie_tags: Array) -> int:
	return score(customer, movie_tags)
