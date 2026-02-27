extends CanvasLayer
class_name EndingScreenUI
# ============================================================
# EndingScreenUI.gd — Pantalla de final de partida (no reversible).
# La crea EndingManager cuando se activa un final.
# ============================================================

const ENDING_DATA: Dictionary = {
	"economic": {
		"title":  "CIERRE ECONÓMICO",
		"body":   "El cine no puede seguir operando.\nLas deudas han superado los ingresos.",
		"color":  Color(1.0, 0.30, 0.30),
	},
	"existential": {
		"title":  "BRECHA EXISTENCIAL",
		"body":   "La estabilidad del cine ha colapsado.\nLas entidades han ganado.",
		"color":  Color(0.45, 0.15, 0.90),
	},
	"grey": {
		"title":  "FIN GRIS",
		"body":   "El cine sobrevive económicamente,\npero ya no contiene nada real.",
		"color":  Color(0.55, 0.55, 0.55),
	},
	"fame": {
		"title":  "CINE OLVIDADO",
		"body":   "La fama del cine ha caído a cero.\nNadie recuerda que este lugar existía.",
		"color":  Color(0.85, 0.55, 0.10),
	},
	"victory": {
		"title":  "EL CINE SOBREVIVE",
		"body":   "Has completado los 10 días.\nEl cine sigue en pie, las entidades contenidas.\nLa realidad aguanta… por ahora.",
		"color":  Color(0.95, 0.85, 0.25),
	},
	"hollow": {
		"title":  "VICTORIA PÍRRICA",
		"body":   "El cine sigue abierto, pero la distorsión\nse ha cobrado su precio.\nLas paredes ya no parecen del todo sólidas.",
		"color":  Color(0.60, 0.50, 0.70),
	},
}

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

var _ending_type: String = ""

func show_ending(type: String) -> void:
	_ending_type = type
	var data: Dictionary = ENDING_DATA.get(type, ENDING_DATA["grey"])
	_build_ui(data)

func _build_ui(data: Dictionary) -> void:
	# Fondo opaco
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.01, 0.01, 0.97)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Contenedor central
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left   = -300
	vb.offset_right  =  300
	vb.offset_top    = -200
	vb.offset_bottom =  200
	vb.add_theme_constant_override("separation", 28)
	add_child(vb)

	# Título del final
	var title := Label.new()
	title.text = data["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", data["color"])
	vb.add_child(title)

	vb.add_child(UITheme.gold_separator())

	# Cuerpo narrativo
	var body := Label.new()
	body.text = data["body"]
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", UITheme.C_CREAM)
	vb.add_child(body)

	# Día alcanzado + stats
	var day_lbl := Label.new()
	var is_victory := _ending_type in ["victory", "hollow"]
	if is_victory:
		day_lbl.text = "Día final: %d  |  Dinero: $%d  |  Fama: %d" % [RunState.day_index, RunState.total_money, FameManager.get_fame()]
	else:
		day_lbl.text = "Día alcanzado: %d" % RunState.day_index
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_lbl.add_theme_font_size_override("font_size", 14)
	day_lbl.add_theme_color_override("font_color", UITheme.C_CREAM_D)
	vb.add_child(day_lbl)

	vb.add_child(UITheme.gold_separator())

	# Botón reiniciar
	var btn := Button.new()
	btn.text = "VOLVER AL MENÚ" if is_victory else "VOLVER A EMPEZAR"
	btn.custom_minimum_size = Vector2(220, 48)
	btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	btn.add_theme_color_override("font_color", UITheme.C_CREAM)
	btn.add_theme_font_size_override("font_size", 17)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(_on_restart)
	vb.add_child(btn)

func _on_restart() -> void:
	get_tree().paused = false
	if _ending_type in ["victory", "hollow"]:
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	else:
		get_tree().reload_current_scene()
