extends Node

func label(tag_id: String) -> String:
	match tag_id:
		"action": return "Acción"
		"comedy": return "Comedia"
		"horror": return "Terror"
		"thriller": return "Thriller"
		"mystery": return "Misterio"
		"scifi": return "Sci-Fi"
		"drama": return "Drama"
		"crime": return "Crimen"
		"fantasy": return "Fantasía"
		"adventure": return "Aventura"
		"dark": return "Oscura"
		"light": return "Ligera"
		"fast": return "Corta"
		"slow": return "Larga"
		_: return tag_id

# Colores fijos por tag (para UI consistente)
func color(tag_id: String) -> Color:
	match tag_id:
		"action":    return Color(0.80, 0.20, 0.20)
		"comedy":    return Color(0.20, 0.75, 0.30)
		"horror":    return Color(0.15, 0.15, 0.18)
		"thriller":  return Color(0.60, 0.20, 0.70)
		"mystery":   return Color(0.20, 0.55, 0.75)
		"scifi":     return Color(0.10, 0.70, 0.70)
		"drama":     return Color(0.80, 0.55, 0.15)
		"crime":     return Color(0.35, 0.35, 0.35)
		"fantasy":   return Color(0.45, 0.35, 0.85)
		"adventure": return Color(0.85, 0.40, 0.10)
		"dark":      return Color(0.10, 0.10, 0.12)
		"light":     return Color(0.70, 0.70, 0.70)
		"fast":      return Color(0.85, 0.75, 0.20) # Corta
		"slow":      return Color(0.20, 0.35, 0.55) # Larga
		_:           return Color(0.25, 0.25, 0.28)

# El jugador NO puede elegir corta/larga (viene por duración)
func is_selectable(tag_id: String) -> bool:
	return not (tag_id == "fast" or tag_id == "slow")

func all_tags() -> Array[String]:
	return [
		"action","drama","comedy",
		"horror","thriller","mystery",
		"scifi","crime","fantasy",
		"adventure","dark","light",
		"fast","slow"
	]
