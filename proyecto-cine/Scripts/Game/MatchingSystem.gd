extends Node
class_name MatchingSystem

# customer dict:
# {
#   "must": [tag_id...],
#   "must_not": [tag_id...]
# }
#
# true_tags: Array[String] de la peli real

static func pass_fail(customer: Dictionary, true_tags: Array, threshold: int = 2) -> bool:
	var must: Array = customer.get("must", [])
	var must_not: Array = customer.get("must_not", [])

	# Si viola un "must_not", fail directo
	for t in must_not:
		if true_tags.has(t):
			return false

	# Puntúa cuántos "must" cumple
	var score_value: int = 0  # <-- NO usar "score" (evita shadowing)
	for t in must:
		if true_tags.has(t):
			score_value += 1

	return score_value >= threshold
