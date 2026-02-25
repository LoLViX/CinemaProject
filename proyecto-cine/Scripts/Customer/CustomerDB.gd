extends Node

var RNG := RandomNumberGenerator.new()

# Pools de keys (reacciones / comida / despedida) -> TextDB
var FOODASK: Array[String] = ["cust.foodask.1","cust.foodask.2","cust.foodask.3"]
var REACT_OK: Array[String] = ["cust.react_ok.1","cust.react_ok.2","cust.react_ok.3","cust.react_ok.4"]
var REACT_BAD: Array[String] = ["cust.react_bad.1","cust.react_bad.2","cust.react_bad.3","cust.react_bad.4"]
var GOODBYE: Array[String] = ["cust.goodbye.1","cust.goodbye.2","cust.goodbye.3","cust.goodbye.4"]

# TextDB real en tu escena (NO autoload)
const ABS_TEXTDB: String = "/root/TextDB"
var _textdb: Node = null

# ===== Clientes especiales (vacío por ahora, como ya lo tenías) =====
var SPECIALS: Array[Dictionary] = []

func _ready() -> void:
	RNG.randomize()
	_textdb = get_node_or_null(ABS_TEXTDB)

func _pick(arr: Array[String]) -> String:
	return arr[RNG.randi_range(0, arr.size() - 1)] if arr.size() > 0 else ""

func build_day_customers(todays_movies: Array, count: int) -> Array:
	var day_tags: Array[String] = _tags_available_today(todays_movies)
	var customers: Array = []

	while customers.size() < count:
		customers.append(_make_normal(day_tags))

	return customers

# -------------------------
# Normal customers (generados)
# -------------------------
func _make_normal(day_tags: Array[String]) -> Dictionary:
	var must: Array[String] = []
	var must_not: Array[String] = []

	# 1 must
	var main := _pick_weighted_tag(day_tags)
	if main != "":
		must.append(main)

	# 35% segundo must
	if day_tags.size() > 1 and RNG.randf() < 0.35:
		var second := _pick_weighted_tag(day_tags, must)
		if second != "":
			must.append(second)

	# 35% must_not
	if day_tags.size() > 1 and RNG.randf() < 0.35:
		var avoid := _pick_weighted_tag(day_tags, must)
		if avoid != "" and not must_not.has(avoid):
			must_not.append(avoid)

	var request_text := _build_request_text(must, must_not)

	var food_order := _make_food_order()

	return {
		"type": "normal",
		"request_text": request_text,
		"food_order": food_order,
		"food_key": _build_food_text(food_order),
		"ok_key": _pick(REACT_OK),
		"bad_key": _pick(REACT_BAD),
		"bye_key": _pick(GOODBYE),
		"must": must,
		"must_not": must_not,
		"exit_lane": "main"
	}

# -------------------------
# Texto de petición (multidioma)
# -------------------------
func _build_request_text(must: Array[String], must_not: Array[String]) -> String:
	var lang := "es"

	# TextDB existe en escena, y tiene 'locale'
	if _textdb != null:
		if "locale" in _textdb:
			lang = String(_textdb.get("locale"))

	var a := _tag_name(String(must[0]) if must.size() > 0 else "", lang)
	var b := _tag_name(String(must[1]) if must.size() > 1 else "", lang)
	var n := _tag_name(String(must_not[0]) if must_not.size() > 0 else "", lang)

	if lang == "en":
		return _build_request_en(a, b, n, must.size(), must_not.size())
	return _build_request_es(a, b, n, must.size(), must_not.size())

func _build_request_es(a: String, b: String, n: String, must_count: int, not_count: int) -> String:
	var variants: Array[String] = []

	if must_count >= 2 and not_count >= 1:
		variants = [
			"Busco algo con %s y un toque de %s… pero por favor, sin %s." % [a, b, n],
			"Quiero %s, y si además tiene %s mejor. Eso sí: nada de %s." % [a, b, n],
			"Me apetece %s + %s, pero si huele a %s, paso." % [a, b, n]
		]
	elif must_count >= 2 and not_count == 0:
		variants = [
			"Quiero algo con %s y %s. Que no me suelte hasta el final." % [a, b],
			"Hoy vengo a por %s con %s. Sorpréndeme." % [a, b],
			"Me apetece %s + %s. Nada de rollos raros, al grano." % [a, b]
		]
	elif must_count == 1 and not_count >= 1:
		variants = [
			"Algo de %s, pero sin %s, por favor." % [a, n],
			"Vengo buscando %s. Y lo único que no quiero hoy es %s." % [a, n],
			"Me apetece %s… pero como sea %s, me duermo." % [a, n]
		]
	else:
		variants = [
			"Quiero algo de %s. Que se note desde el minuto uno." % [a],
			"Hoy me apetece %s. Sin complicaciones." % [a],
			"Dame %s, de lo bueno." % [a]
		]

	return variants[RNG.randi_range(0, variants.size()-1)]

func _build_request_en(a: String, b: String, n: String, must_count: int, not_count: int) -> String:
	var variants: Array[String] = []

	if must_count >= 2 and not_count >= 1:
		variants = [
			"I want something with %s and a bit of %s… but please, no %s." % [a, b, n],
			"Give me %s, and %s would be a bonus. Just not %s." % [a, b, n],
			"%s + %s sounds perfect. If it turns into %s, I’m out." % [a, b, n]
		]
	elif must_count >= 2 and not_count == 0:
		variants = [
			"I’m in the mood for %s with %s. Keep me hooked." % [a, b],
			"Tonight: %s and %s. Surprise me." % [a, b],
			"%s plus %s. Straight to the point." % [a, b]
		]
	elif must_count == 1 and not_count >= 1:
		variants = [
			"Something %s, but no %s please." % [a, n],
			"I want %s. The only thing I don’t want is %s." % [a, n],
			"%s… but if it’s %s, I’ll fall asleep." % [a, n]
		]
	else:
		variants = [
			"Give me %s. I want to feel it right away." % [a],
			"I’m in the mood for %s. Nothing complicated." % [a],
			"%s. The good stuff." % [a]
		]

	return variants[RNG.randi_range(0, variants.size()-1)]

# -------------------------
# Tag picking (pesos)
# -------------------------
func _pick_weighted_tag(day_tags: Array[String], avoid: Array[String] = []) -> String:
	var pool: Array[String] = []
	for t in day_tags:
		if avoid.has(t):
			continue
		pool.append(t)
	if pool.size() == 0:
		return ""

	var weights: Array[float] = []
	for t in pool:
		var w := 1.0
		# oscura/ligera un poco menos para que no sea todo “tono”
		if t == "oscura" or t == "ligera":
			w = 0.65
		weights.append(w)

	var sum := 0.0
	for w in weights:
		sum += w
	var r := RNG.randf() * sum
	var acc := 0.0
	for i in range(pool.size()):
		acc += weights[i]
		if r <= acc:
			return pool[i]
	return pool[pool.size()-1]

# -------------------------
# Available tags today
# -------------------------
func _tags_available_today(movies: Array) -> Array[String]:
	var s: Dictionary = {}
	for m in movies:
		var tags: Array = m.get("true_tags", [])
		for t in tags:
			var tag: String = String(t)
			s[tag] = true

	var out: Array[String] = []
	for k in s.keys():
		out.append(String(k))
	out.sort()
	return out

# -------------------------
# Localized tag names (IDs españoles)
# -------------------------
func _tag_name(tag_id: String, lang: String) -> String:
	if tag_id == "":
		return ""

	if lang == "en":
		match tag_id:
			"accion": return "action"
			"drama": return "drama"
			"comedia": return "comedy"
			"terror": return "horror"
			"thriller": return "thriller"
			"misterio": return "mystery"
			"scifi": return "sci-fi"
			"crimen": return "crime"
			"fantasia": return "fantasy"
			"aventura": return "adventure"
			"oscura": return "dark tone"
			"ligera": return "light tone"
			_: return tag_id

	# ES
	match tag_id:
		"accion": return "acción"
		"drama": return "drama"
		"comedia": return "comedia"
		"terror": return "terror"
		"thriller": return "thriller"
		"misterio": return "misterio"
		"scifi": return "ciencia ficción"
		"crimen": return "crimen"
		"fantasia": return "fantasía"
		"aventura": return "aventura"
		"oscura": return "tono oscuro"
		"ligera": return "tono ligero"
		_: return tag_id

# -------------------------
# Food order generation
# -------------------------
# food_order dict keys:
#   drink: bool
#   food: "" / "hotdog" / "chocolate"
#   popcorn: bool
#   ketchup: bool  (solo si hotdog)
#   mustard: bool  (solo si hotdog)
#   butter: bool   (solo si popcorn)
#   caramel: bool  (solo si popcorn)
func _make_food_order() -> Dictionary:
	var order := {
		"drink": false,
		"food": "",
		"popcorn": false,
		"ketchup": false,
		"mustard": false,
		"butter": false,
		"caramel": false,
	}

	# Siempre al menos una cosa
	var roll := RNG.randi_range(0, 2)
	match roll:
		0: # Solo bebida
			order["drink"] = true
		1: # Palomitas (con o sin topping)
			order["popcorn"] = true
			if RNG.randf() < 0.5:
				if RNG.randf() < 0.5:
					order["butter"] = true
				else:
					order["caramel"] = true
		2: # Comida (hotdog o chocolate)
			if RNG.randf() < 0.6:
				order["food"] = "hotdog"
				if RNG.randf() < 0.5: order["ketchup"] = true
				if RNG.randf() < 0.4: order["mustard"] = true
			else:
				order["food"] = "chocolate"

	# 40% también quieren bebida además de lo anterior
	if roll != 0 and RNG.randf() < 0.4:
		order["drink"] = true

	# 30% también quieren palomitas si pidieron comida
	if roll == 2 and RNG.randf() < 0.3:
		order["popcorn"] = true
		if RNG.randf() < 0.4:
			if RNG.randf() < 0.5:
				order["butter"] = true
			else:
				order["caramel"] = true

	return order

func _build_food_text(o: Dictionary) -> String:
	var parts: Array[String] = []

	if o.get("popcorn", false):
		var pop := "palomitas"
		if o.get("butter", false): pop += " con mantequilla"
		elif o.get("caramel", false): pop += " con caramelo"
		parts.append(pop)

	if o.get("food", "") == "hotdog":
		var hd := "hotdog"
		var tops: Array[String] = []
		if o.get("ketchup", false): tops.append("ketchup")
		if o.get("mustard", false): tops.append("mostaza")
		if tops.size() > 0: hd += " con " + " y ".join(tops)
		parts.append(hd)
	elif o.get("food", "") == "chocolate":
		parts.append("chocolate")

	if o.get("drink", false):
		parts.append("una bebida")

	if parts.size() == 0:
		return "Nada más, gracias."
	if parts.size() == 1:
		return "Ponme " + parts[0] + ", porfa."
	var last: String = String(parts.pop_back())
	return "Quiero " + ", ".join(parts) + " y " + last + "."
