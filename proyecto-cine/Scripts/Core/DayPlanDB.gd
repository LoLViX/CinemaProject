extends Node

# Devuelve entries:
# { "kind":"normal" }
# { "kind":"special", "text":"..." }
func load_day_plan(day_index: int) -> Array:
	var path := "res://Data/DayPlans/day_%02d.txt" % day_index
	if not FileAccess.file_exists(path):
		return []

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []

	var entries: Array = []

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue

		var lower := line.to_lower()
		if lower.begins_with("dia"):
			continue

		if lower.begins_with("customer:"):
			entries.append({ "kind": "normal" })
			continue

		if lower.begins_with("special:"):
			var rest := line.substr(line.find(":") + 1).strip_edges()
			var txt := _unquote(rest)
			if txt != "":
				entries.append({ "kind": "special", "text": txt })
			continue

	return entries

func _unquote(s: String) -> String:
	var t := s.strip_edges()
	if t.length() >= 2 and ((t.begins_with("\"") and t.ends_with("\"")) or (t.begins_with("'") and t.ends_with("'"))):
		return t.substr(1, t.length() - 2)
	return t
