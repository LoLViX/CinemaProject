extends CanvasLayer
class_name PauseUI

signal exit_to_menu_requested   # Main.gd lo escucha para guardar antes de salir
# ============================================================
# PauseUI.gd — Pantalla de pausa (ESC)
# ============================================================
# Se instancia en Main._ready() y vive toda la sesión.
# process_mode = ALWAYS para seguir recibiendo input aunque el árbol esté pausado.

const C_BG      := Color(0.10, 0.04, 0.04, 0.96)
const C_GOLD    := Color(0.95, 0.76, 0.15)
const C_CREAM   := Color(0.97, 0.93, 0.80)
const C_CREAM_D := Color(0.80, 0.75, 0.60)

var _panel: Panel = null
var _stats_lbl: Label = null

func _ready() -> void:
	layer = 20            # Por encima de EndOfDayUI (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Overlay semiopaco
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.anchor_left   = 0.0
	overlay.anchor_right  = 1.0
	overlay.anchor_top    = 0.0
	overlay.anchor_bottom = 1.0
	overlay.process_mode  = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	# Panel central
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -220
	_panel.offset_right  =  220
	_panel.offset_top    = -190
	_panel.offset_bottom =  190
	_panel.process_mode  = Node.PROCESS_MODE_ALWAYS
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.anchor_left = 0.0; vb.anchor_right  = 1.0
	vb.anchor_top  = 0.0; vb.anchor_bottom = 1.0
	vb.offset_left = 28;  vb.offset_right  = -28
	vb.offset_top  = 22;  vb.offset_bottom = -22
	vb.add_theme_constant_override("separation", 14)
	vb.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.add_child(vb)

	# Título
	var title := Label.new()
	title.text = "— PAUSA —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_GOLD)
	vb.add_child(title)

	vb.add_child(UITheme.gold_separator())

	# Stats del día en curso
	_stats_lbl = Label.new()
	_stats_lbl.name = "StatsLabel"
	_stats_lbl.text = ""
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_lbl.add_theme_font_size_override("font_size", 15)
	_stats_lbl.add_theme_color_override("font_color", C_CREAM)
	vb.add_child(_stats_lbl)

	vb.add_child(UITheme.gold_separator())

	# Botón Continuar
	var btn_resume := Button.new()
	btn_resume.text = "▶  CONTINUAR"
	btn_resume.custom_minimum_size = Vector2(0, 44)
	btn_resume.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	btn_resume.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	btn_resume.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	btn_resume.add_theme_color_override("font_color", C_CREAM)
	btn_resume.add_theme_font_size_override("font_size", 16)
	btn_resume.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_resume.pressed.connect(_on_resume)
	vb.add_child(btn_resume)

	# Botón Ajustes (placeholder)
	var btn_settings := Button.new()
	btn_settings.text = "⚙  AJUSTES"
	btn_settings.custom_minimum_size = Vector2(0, 36)
	btn_settings.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	btn_settings.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	btn_settings.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	btn_settings.add_theme_color_override("font_color", C_CREAM_D)
	btn_settings.add_theme_font_size_override("font_size", 14)
	btn_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_settings.pressed.connect(_on_settings)
	vb.add_child(btn_settings)

	vb.add_child(UITheme.gold_separator())

	# Botón Volver al menú
	var btn_menu := Button.new()
	btn_menu.text = "↩  GUARDAR Y SALIR AL MENÚ"
	btn_menu.custom_minimum_size = Vector2(0, 36)
	var sb_grey := StyleBoxFlat.new()
	sb_grey.bg_color = Color(0.20, 0.08, 0.08, 0.90)
	sb_grey.border_color = Color(0.95, 0.76, 0.15, 0.40)
	sb_grey.border_width_left = 2; sb_grey.border_width_right = 2
	sb_grey.border_width_top  = 2; sb_grey.border_width_bottom = 2
	sb_grey.corner_radius_top_left = 5; sb_grey.corner_radius_top_right = 5
	sb_grey.corner_radius_bottom_left = 5; sb_grey.corner_radius_bottom_right = 5
	btn_menu.add_theme_stylebox_override("normal",  sb_grey)
	btn_menu.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	btn_menu.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	btn_menu.add_theme_color_override("font_color", C_CREAM_D)
	btn_menu.add_theme_font_size_override("font_size", 14)
	btn_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_menu.pressed.connect(_on_menu)
	vb.add_child(btn_menu)

# ── Input ────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			_toggle()
			get_viewport().set_input_as_handled()

# ── Internos ────────────────────────────────────────────────

func _toggle() -> void:
	if visible:
		_on_resume()
	else:
		_open()

func _open() -> void:
	_refresh_stats()
	visible = true
	get_tree().paused = true
	SoundManager.play_click()

func _on_resume() -> void:
	visible = false
	get_tree().paused = false
	SoundManager.play_click()

func _on_settings() -> void:
	pass  # TODO: abrir pantalla de ajustes

func _on_menu() -> void:
	visible = false
	get_tree().paused = false
	# Guardar en slot 1 automáticamente al salir
	if Engine.has_singleton("SaveManager") or get_node_or_null("/root/SaveManager") != null:
		SaveManager.save_slot(1)
	emit_signal("exit_to_menu_requested")
	# Ir al menú principal
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _refresh_stats() -> void:
	if _stats_lbl == null:
		return
	var hits   := int(RunState.day_hits)
	var misses := int(RunState.day_misses)
	var total  := hits + misses
	var money  := int(RunState.day_money)
	_stats_lbl.text = (
		"Día %d\n\nAciertos: %d  /  Fallos: %d  /  Clientes: %d\n\nPropinas hoy: $%d\nAcumulado: $%d"
		% [RunState.day_index, hits, misses, total, money, RunState.total_money]
	)
