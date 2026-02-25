extends Node
class_name ProjectReport

@export var dump_on_ready: bool = true
@export var max_depth: int = 8
@export var max_children_per_node: int = 140

func _ready() -> void:
	if dump_on_ready:
		dump_runtime()

func dump_runtime() -> void:
	var lines: Array[String] = []
	lines.append("=== RUNTIME REPORT ===")
	lines.append(_engine_block())
	lines.append(_autoload_block())
	lines.append(_inputmap_block())
	lines.append(_globals_block())
	lines.append(_node_tree_block())
	lines.append(_scripts_spotcheck_block())
	lines.append("=== END REPORT ===")

	var txt := "\n".join(lines)
	print(txt)

	_save_to_user_file("project_report.txt", txt)
	DisplayServer.clipboard_set(txt)

# ------------------------------------------------------------
# BLOQUES
# ------------------------------------------------------------

func _engine_block() -> String:
	var v: Dictionary = Engine.get_version_info()
	var major := int(v.get("major", 0))
	var minor := int(v.get("minor", 0))
	var patch := int(v.get("patch", 0))
	var status := String(v.get("status", ""))
	var build := String(v.get("build", ""))

	var version_str := "%d.%d.%d.%s.%s" % [major, minor, patch, status, build]

	var renderer := String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	var gpu := String(RenderingServer.get_video_adapter_name())

	return "-- Engine --\nGodot: %s\nRenderer: %s\nGPU: %s\n" % [version_str, renderer, gpu]

func _autoload_block() -> String:
	var out: Array[String] = []
	out.append("-- Autoloads --")

	var raw = ProjectSettings.get_setting("autoload", {})
	var autoloads: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		autoloads = raw
	else:
		out.append("  (autoload setting not found or invalid)")
		return "\n".join(out) + "\n"

	var key_variants: Array = autoloads.keys()
	var keys: Array[String] = []
	for k in key_variants:
		keys.append(String(k))
	keys.sort()

	if keys.is_empty():
		out.append("  (none)")
	else:
		for k in keys:
			var d_raw = autoloads.get(k, {})
			var d: Dictionary = {}
			if typeof(d_raw) == TYPE_DICTIONARY:
				d = d_raw

			var path := String(d.get("path", ""))
			var singleton := bool(d.get("singleton", true))
			out.append("  %s : %s  singleton=%s" % [k, path, str(singleton)])

	return "\n".join(out) + "\n"

func _inputmap_block() -> String:
	var out: Array[String] = []
	out.append("-- InputMap actions --")

	var acts: Array = InputMap.get_actions()
	var a_str: Array[String] = []
	for a in acts:
		a_str.append(String(a))
	a_str.sort()

	for s in a_str:
		out.append("  " + s)

	return "\n".join(out) + "\n"

func _globals_block() -> String:
	var out: Array[String] = []
	out.append("-- SceneTree root children --")

	var root := get_tree().root
	for c in root.get_children():
		out.append("  %s  [%s]" % [String(c.name), String(c.get_path())])

	return "\n".join(out) + "\n"

func _node_tree_block() -> String:
	var out: Array[String] = []
	out.append("-- SceneTree nodes (top) --")
	var root := get_tree().root
	_dump_node(root, 0, out)
	return "\n".join(out) + "\n"

func _dump_node(n: Node, depth: int, out: Array[String]) -> void:
	if depth > max_depth:
		return

	var indent := "  ".repeat(depth)
	out.append("%s%s : %s  [%s]" % [
		indent, String(n.name), String(n.get_class()), String(n.get_path())
	])

	var children := n.get_children()
	if children.size() > max_children_per_node:
		out.append("%s  ... (%d children truncated)" % [indent, children.size()])
		return

	for ch in children:
		_dump_node(ch, depth + 1, out)

func _scripts_spotcheck_block() -> String:
	var out: Array[String] = []
	out.append("-- Script spotcheck (key nodes) --")

	var paths: Array[String] = [
		"/root/Main/Systems/InteractionController",
		"/root/Main/Customers/CustomerManager",
		"/root/Main/Systems/FoodController",
		"/root/Main/FoodArea/DrinkStation",
		"/root/Main/UI",
		"/root/Main/UI/DaySetupUI",
		"/root/Main/UI/StockHUD",
		"/root/Main/UI/CustomerOrderHUD",
		"/root/Main/Reporter"
	]

	for p in paths:
		var node := get_tree().root.get_node_or_null(p)
		if node == null:
			out.append("  %s : (missing)" % p)
			continue

		var s = node.get_script()
		if s == null:
			out.append("  %s : script=(none) node_class=%s" % [p, String(node.get_class())])
		else:
			var sp := ""
			if s is Script:
				sp = String((s as Script).resource_path)
			out.append("  %s : script=%s node_class=%s" % [p, sp, String(node.get_class())])

	return "\n".join(out) + "\n"

# ------------------------------------------------------------
# FILE
# ------------------------------------------------------------

func _save_to_user_file(filename: String, text: String) -> void:
	var fpath := "user://%s" % filename
	var f := FileAccess.open(fpath, FileAccess.WRITE)
	if f == null:
		push_error("ProjectReport: cannot write " + fpath)
		return
	f.store_string(text)
	f.flush()
	f.close()
