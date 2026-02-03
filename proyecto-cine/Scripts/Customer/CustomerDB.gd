extends Node

var RNG := RandomNumberGenerator.new()

# Pools de keys (reacciones / comida / despedida) -> TextDB
var FOODASK: Array[String] = ["cust.foodask.1","cust.foodask.2","cust.foodask.3"]
var REACT_OK: Array[String] = ["cust.react_ok.1","cust.react_ok.2","cust.react_ok.3","cust.react_ok.4"]
var REACT_BAD: Array[String] = ["cust.react_bad.1","cust.react_bad.2","cust.react_bad.3","cust.react_bad.4"]
var GOODBYE: Array[String] = ["cust.goodbye.1","cust.goodbye.2","cust.goodbye.3","cust.goodbye.4"]

# ===== Clientes especiales (tú los añadirás a mano) =====
# Estructura recomendada:
# {
#   "type":"special",
#   "id":"special.001",
#   "request_text_es":"...", "request_text_en":"...",
#   "food_key":"cust.foodask.2",
#   "ok_key":"...", "bad_key":"...",
#   "bye_key":"...",
#   "must":["thriller"], "must_not":["comedy"],
#   "exit_lane":"alt" # <- para el futuro (otra fila)
# }
var SPECIALS: Array[Dictionary] = []

func _pick(arr: Array[String]) -> String:
	return arr[RNG.randi_range(0, arr.size() - 1)] if arr.size() > 0 else ""

func build_day_customers(todays_movies: Array, count: int) -> Array:
	RNG.randomize()

	var day_tags: Array[String] = _tags_available_today(todays_movies)

	var customers: Array = []

	# (Por ahora NO meto specials automáticamente. Los meterás cuando quieras por día/evento.)
	# Ejemplo futuro: customers.append(SPECIALS[0]) si toca.

	while customers.size() < count:
		customers.append(_make_normal(day_tags))

	return customers

# -------------------------
# Normal customers (generados)
# -------------------------
func _make_normal(day_tags: Array[String]) -> Dictionary:
	var must: Array[String] = []
	var must_not: Array[String] = []

	# Elegimos 1 o 2 "must" del set del día (con peso)
	var main := _pick_weighted_tag(day_tags)
	if main != "":
		must.append(main)

	# 35% añade un segundo must distinto
	if day_tags.size() > 1 and RNG.randf() < 0.35:
		var second := _pick_weighted_tag(day_tags, must)
		if second != "":
			must.append(second)

	# 35% añade un must_not (si hay variedad)
	if day_tags.size() > 1 and RNG.randf() < 0.35:
		var avoid := _pick_weighted_tag(day_tags, must)
		if avoid != "" and not must_not.has(avoid):
			must_not.append(avoid)

	var request_text := _build_request_text(must, must_not)

	return {
		"type": "normal",
		"request_text": request_text,      # <-- YA listo para mostrar (multidioma)
		"food_key": _pick(FOODASK),
		"ok_key": _pick(REACT_OK),
		"bad_key": _pick(REACT_BAD),
		"bye_key": _pick(GOODBYE),
		"must": must,
		"must_not": must_not,
		"exit_lane": "main"                # <-- para futuro (alt para especiales)
	}

# -------------------------
# Texto de petición (lo importante)
# -------------------------
func _build_request_text(must: Array[String], must_not: Array[String]) -> String:
	var lang := "es"
	if Engine.has_singleton("TextDB") and TextDB.has_method("t"):
		# TextDB es autoload, tiene variable "locale"
		if "locale" in TextDB:
			lang = String(TextDB.locale)

	# Nombres human-friendly por idioma
	var a := _tag_name(String(must[0]) if must.size() > 0 else "", lang)
	var b := _tag_name(String(must[1]) if must.size() > 1 else "", lang)
	var n := _tag_name(String(must_not[0]) if must_not.size() > 0 else "", lang)


	# Plantillas (ES/EN). Naturales, accionables, sin decir “tags” explícitamente.
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
		# must_count==1 y not_count==0
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
# Tag picking (con pesos para evitar combinaciones raras)
# -------------------------
func _pick_weighted_tag(day_tags: Array[String], avoid: Array[String] = []) -> String:
	# Filtra
	var pool: Array[String] = []
	for t in day_tags:
		if avoid.has(t):
			continue
		pool.append(t)
	if pool.size() == 0:
		return ""

	# Pesos simples: preferimos géneros “decidibles” y evitamos que todo sea dark/light siempre
	var weights: Array[float] = []
	for t in pool:
		var w := 1.0
		if t == "dark" or t == "light":
			w = 0.6
		if t == "fast" or t == "slow":
			w = 0.8
		weights.append(w)

	# Roulette
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
# Available tags today (NO pide tags inexistentes)
# -------------------------
func _tags_available_today(movies: Array) -> Array[String]:
	var s: Dictionary = {}
	for m in movies:
		var tags: Array = m.get("true_tags", [])
		for t in tags:
			var tag: String = String(t)
			# Aquí SÍ permitimos fast/slow para que el cliente pueda pedir “corta/larga”
			s[tag] = true

	var out: Array[String] = []
	for k in s.keys():
		out.append(String(k))
	out.sort()
	return out

# -------------------------
# Localized tag names
# -------------------------
func _tag_name(tag_id: String, lang: String) -> String:
	if tag_id == "":
		return ""

	if lang == "en":
		match tag_id:
			"action": return "action"
			"comedy": return "comedy"
			"horror": return "horror"
			"thriller": return "thriller"
			"mystery": return "mystery"
			"scifi": return "sci-fi"
			"drama": return "drama"
			"crime": return "crime"
			"fantasy": return "fantasy"
			"adventure": return "adventure"
			"dark": return "dark tone"
			"light": return "light tone"
			"fast": return "short"
			"slow": return "long"
			_: return tag_id

	# ES
	match tag_id:
		"action": return "acción"
		"comedy": return "comedia"
		"horror": return "terror"
		"thriller": return "thriller"
		"mystery": return "misterio"
		"scifi": return "ciencia ficción"
		"drama": return "drama"
		"crime": return "crimen"
		"fantasy": return "fantasía"
		"adventure": return "aventura"
		"dark": return "tono oscuro"
		"light": return "tono ligero"
		"fast": return "una película corta"
		"slow": return "una película larga"
		_: return tag_id
