extends Node
# ============================================================
# Utils.gd — Utilidades compartidas (Autoload)
# ============================================================
# Uso: Utils.is_valid(node), Utils.raycast_areas(...), etc.

# ── Comprobación segura de nodos ────────────────────────────

## Devuelve true si el objeto existe, no es null y no ha sido liberado.
static func is_valid(obj: Object) -> bool:
	return obj != null and is_instance_valid(obj)

## Devuelve true si el nodo es válido Y tiene un padre (está en la escena).
static func is_in_tree(node: Node) -> bool:
	return is_valid(node) and node.is_inside_tree()

# ── Raycast de áreas (Godot 4 PhysicsServer3D) ──────────────

## Lanza un rayo desde la cámara en la posición del ratón contra Areas (no Bodies).
## Devuelve el diccionario de PhysicsDirectSpaceState3D.intersect_ray o {} si falla.
static func raycast_areas(
		cam: Camera3D,
		viewport: Viewport,
		max_dist: float = 25.0) -> Dictionary:
	if not is_valid(cam):
		return {}
	var mouse_pos := viewport.get_mouse_position()
	var origin := cam.project_ray_origin(mouse_pos)
	var dir    := cam.project_ray_normal(mouse_pos)
	var to     := origin + dir * max_dist
	var query  := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas  = true
	query.collide_with_bodies = false
	return cam.get_world_3d().direct_space_state.intersect_ray(query)

# ── Formato de cantidades ────────────────────────────────────

## Formatea un entero como "x12" (estilo stock HUD).
static func fmt_qty(qty: int) -> String:
	return "x%d" % max(qty, 0)

## Formatea un float como moneda: "$3.50"
static func fmt_money(amount: float) -> String:
	return "$%.2f" % amount

# ── Búsqueda de nodos ────────────────────────────────────────

## Devuelve el primer hijo inmediato con ese nombre, o null.
static func child_named(parent: Node, child_name: String) -> Node:
	if not is_valid(parent):
		return null
	return parent.get_node_or_null(child_name)

## Elimina todos los hijos de un nodo de forma segura (queue_free).
static func free_children(parent: Node) -> void:
	if not is_valid(parent):
		return
	for ch in parent.get_children():
		ch.queue_free()

# ── Matemáticas / colecciones ────────────────────────────────

## Clamp seguro para enteros (evita importar @GlobalScope redundante).
static func clampi_safe(value: int, lo: int, hi: int) -> int:
	return clampi(value, lo, hi)

## Devuelve un elemento aleatorio del array, o null si está vacío.
static func pick_random(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]

## Baraja el array in-place (Fisher-Yates) y lo devuelve.
static func shuffle_array(arr: Array) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr
