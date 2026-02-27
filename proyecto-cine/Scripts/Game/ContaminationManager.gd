extends Node
# ContaminationManager.gd — Autoload
# Controla el nivel de contaminación (0.0–1.0) y sus efectos visuales.
# El nivel depende de la estabilidad: stability baja → contamination sube.
#
# Reglas visuales (no modifica TextDB, usa capa de presentación):
#   0.00–0.30 → sin efecto visible
#   0.30–0.60 → géneros aleatorios mezclados en DaySetupUI
#   0.60–0.80 → módulo de color en HUD (tinte rojo/verde sutil)
#   0.80–1.00 → parpadeos de pantalla + texto de títulos con glitch
#
# API:
#   get_level() -> float
#   get_display_tags(movie_id, real_tags) -> Array   (puede devolver tags alterados)
#   get_display_title(key) -> String                 (puede devolver título con glitch)
#   apply_hud_tint(hud: Node)                        (aplana tinte sobre el HUD)
#   clear_hud_tint(hud: Node)

signal level_changed(new_level: float)

const GLITCH_CHARS := ["█", "▓", "▒", "░", "╳", "■", "◆"]

var _level: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	# Escuchar cambios de estabilidad para actualizar el nivel
	if StabilityManager.has_signal("stability_changed"):
		StabilityManager.stability_changed.connect(_on_stability_changed)
	_recalculate()

# ══════════════════════════════════════════════════════════════
# API pública
# ══════════════════════════════════════════════════════════════

## Nivel actual de contaminación (0.0 a 1.0).
func get_level() -> float:
	return _level

## Devuelve los tags a mostrar para una película.
## Por encima de nivel 0.30, puede mezclar o inventar algún tag.
func get_display_tags(_movie_id: String, real_tags: Array) -> Array:
	if _level < 0.30:
		return real_tags

	var out: Array = real_tags.duplicate()

	if _level >= 0.60:
		# Nivel alto: invertir algún tag con probabilidad proporcional al nivel
		var all_tags: Array[String] = ["action","drama","comedy","horror","thriller","mystery",
			"scifi","crime","fantasy","adventure","dark","popcorn"]
		if out.size() > 0 and _rng.randf() < (_level - 0.60) * 2.0:
			var replace_idx := _rng.randi_range(0, out.size() - 1)
			var fake: String = all_tags[_rng.randi_range(0, all_tags.size() - 1)]
			out[replace_idx] = fake
	elif _level >= 0.30:
		# Nivel medio: añadir un tag fantasma ocasional
		var ghost_pool: Array[String] = ["horror", "dark", "crime", "mystery"]
		if _rng.randf() < (_level - 0.30) * 1.5:
			var ghost: String = ghost_pool[_rng.randi_range(0, ghost_pool.size() - 1)]
			if not out.has(ghost):
				out.append(ghost)

	return out

## Devuelve el título a mostrar para una clave de TextDB.
## Por encima de nivel 0.60, puede añadir caracteres glitch.
func get_display_title(key: String) -> String:
	var base := TextDB.t(key)
	if _level < 0.60 or base == "":
		return base

	# A nivel 0.60+ hay probabilidad de glitch proporcional al exceso
	var glitch_prob := (_level - 0.60) * 2.5   # 0.0 a 1.0 a nivel 1.0
	if _rng.randf() > glitch_prob:
		return base

	# Sustituir 1-2 caracteres aleatorios por glitch
	var chars := base.split("", false)
	var num_glitch := 1 if _level < 0.80 else 2
	for _i in range(num_glitch):
		var idx := _rng.randi_range(0, chars.size() - 1)
		chars[idx] = GLITCH_CHARS[_rng.randi_range(0, GLITCH_CHARS.size() - 1)]
	return "".join(chars)

## Aplica un tinte al CanvasLayer del HUD según el nivel de contaminación.
## CanvasLayer no tiene modulate propio — se modula el primer hijo CanvasItem.
func apply_hud_tint(hud: Node) -> void:
	if hud == null or not is_instance_valid(hud):
		return

	var color: Color
	if _level < 0.60:
		color = Color(1, 1, 1, 1)
	else:
		# Tinte rojo-verdoso progresivo entre 0.60 y 1.0
		var t := (_level - 0.60) / 0.40
		color = Color(1.0, lerpf(1.0, 0.78, t), lerpf(1.0, 0.72, t), 1.0)

	_set_hud_modulate(hud, color)

## Elimina el tinte del HUD.
func clear_hud_tint(hud: Node) -> void:
	_set_hud_modulate(hud, Color(1, 1, 1, 1))

## Aplica el color a los hijos CanvasItem directos del CanvasLayer.
func _set_hud_modulate(hud: Node, color: Color) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	for child in hud.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate = color

## Distorsiona un pedido de comida según el nivel de contaminación.
## A nivel 0.30+: puede intercambiar ketchup ↔ mostaza
## A nivel 0.50+: puede intercambiar butter ↔ caramel
## A nivel 0.70+: puede cambiar el tipo de bebida
## Devuelve una copia del order (no muta el original).
func distort_food_order(order: Dictionary) -> Dictionary:
	if order.is_empty() or _level < 0.30:
		return order
	var out: Dictionary = order.duplicate(true)
	# Ketchup ↔ Mustard (level >= 0.30)
	if _level >= 0.30 and _rng.randf() < (_level - 0.20) * 0.8:
		var k: bool = bool(out.get("ketchup", false))
		var m: bool = bool(out.get("mustard", false))
		if k != m:  # solo intercambiar si son diferentes
			out["ketchup"] = m
			out["mustard"] = k
	# Butter ↔ Caramel (level >= 0.50)
	if _level >= 0.50 and _rng.randf() < (_level - 0.40) * 0.9:
		var b: bool = bool(out.get("butter", false))
		var c: bool = bool(out.get("caramel", false))
		if b != c:
			out["butter"] = c
			out["caramel"] = b
	# Drink type swap (level >= 0.70)
	if _level >= 0.70 and bool(out.get("drink", false)):
		if _rng.randf() < (_level - 0.60) * 1.0:
			var current_type: String = String(out.get("drink_type", ""))
			var drink_pool: Array = ["cola", "orange", "rootbeer"]
			drink_pool.erase(current_type)
			if not drink_pool.is_empty():
				out["drink_type"] = drink_pool[_rng.randi_range(0, drink_pool.size() - 1)]
	return out

# ══════════════════════════════════════════════════════════════
# Interno
# ══════════════════════════════════════════════════════════════

func _on_stability_changed(_value: float) -> void:
	_recalculate()

func _recalculate() -> void:
	# Contaminación = inverso normalizado de la estabilidad
	var stab: float = float(StabilityManager.stability)
	var max_stab: float = float(StabilityManager.MAX)   # constante MAX = 100
	var prev := _level
	_level = clampf(1.0 - (stab / max_stab), 0.0, 1.0)
	if abs(_level - prev) > 0.005:
		level_changed.emit(_level)
		if DebugConfig.ENABLE_DEBUG:
			print("ContaminationManager: level=%.2f (stability=%d)" % [_level, stab])
