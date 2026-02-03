extends Node
class_name ProjectReport

@export var max_depth: int = 6
@export var auto_run: bool = true
@export var auto_free: bool = true

func _ready() -> void:
	if auto_run:
		dump_runtime()
	if auto_free:
		queue_free()

func dump_runtime() -> void:
	print("\n=== RUNTIME REPORT ===")

	_print_autoloads()
	_print_input_actions()
	_print_tree()

	print("=== END REPORT ===\n")

func _print_autoloads() -> void:
	print("-- Autoload singletons --")
	var autoloads_any = ProjectSettings.get_setting("autoload")
	if autoloads_any == null:
		print("  (none)")
		return

	var autoloads: Dictionary = autoloads_any as Dictionary
	for k in autoloads.keys():
		var d: Dictionary = autoloads[k]
		print("  ", k, " -> ", String(d.get("path","")))

func _print_input_actions() -> void:
	print("-- InputMap actions --")
	var actions := InputMap.get_actions()
	actions.sort()
	for a in actions:
		print("  ", a)

func _print_tree() -> void:
	print("-- SceneTree nodes (top) --")
	var root := get_tree().root
	_print_node(root, 0)

func _print_node(n: Node, depth: int) -> void:
	if depth > max_depth:
		return

	var pad := "  ".repeat(depth)
	print(pad, n.name, " : ", n.get_class(), "  [", n.get_path(), "]")

	for c in n.get_children():
		_print_node(c, depth + 1)
