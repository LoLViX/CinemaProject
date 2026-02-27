extends Node
## MainMenu.gd — Menú principal del Cine
## Escena: res://Scenes/MainMenu.tscn
## Lanza desde project.godot como run/main_scene (o bien con get_tree().change_scene_to_file)

const C_BG       := Color(0.06, 0.02, 0.02)
const C_OVERLAY  := Color(0.05, 0.01, 0.01, 0.88)
const C_GOLD     := Color(0.95, 0.76, 0.15)
const C_GOLD_DIM := Color(0.95, 0.76, 0.15, 0.30)
const C_CREAM    := Color(0.97, 0.93, 0.80)
const C_CREAM_D  := Color(0.70, 0.65, 0.50)
const C_RED_D    := Color(0.40, 0.05, 0.05)

var _canvas: CanvasLayer = null

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)
	_build_ui()

func _build_ui() -> void:
	# Fondo oscuro (simula sala de cine apagada)
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	_canvas.add_child(bg)

	# Decoración: líneas horizontales de scanline (efecto CRT viejo)
	var scanlines := ColorRect.new()
	scanlines.color = Color(0.0, 0.0, 0.0, 0.06)
	scanlines.anchor_right  = 1.0
	scanlines.anchor_bottom = 1.0
	_canvas.add_child(scanlines)

	# Panel central
	var panel := Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -260
	panel.offset_right  =  260
	panel.offset_top    = -280
	panel.offset_bottom =  280
	var panel_sb := _panel_style()
	panel.add_theme_stylebox_override("panel", panel_sb)
	_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_left   = 0.0
	vbox.anchor_right  = 1.0
	vbox.anchor_top    = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left   = 32
	vbox.offset_right  = -32
	vbox.offset_top    = 28
	vbox.offset_bottom = -28
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# ── Logo / Título ──────────────────────────────────────────
	var logo_container := CenterContainer.new()
	logo_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logo_container.size_flags_stretch_ratio = 1.6
	vbox.add_child(logo_container)

	var logo_v := VBoxContainer.new()
	logo_v.add_theme_constant_override("separation", 4)
	logo_container.add_child(logo_v)

	var title_top := Label.new()
	title_top.text = "★  EL  CINE  NOCTURNO  ★"
	title_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_top.add_theme_font_size_override("font_size", 11)
	title_top.add_theme_color_override("font_color", C_GOLD_DIM)
	logo_v.add_child(title_top)

	var title_main := Label.new()
	title_main.text = "CINEMA"
	title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_main.add_theme_font_size_override("font_size", 52)
	title_main.add_theme_color_override("font_color", C_GOLD)
	logo_v.add_child(title_main)

	var title_sub := Label.new()
	title_sub.text = "D E L   M Á S   A L L Á"
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sub.add_theme_font_size_override("font_size", 14)
	title_sub.add_theme_color_override("font_color", C_CREAM_D)
	logo_v.add_child(title_sub)

	# separador
	vbox.add_child(_gold_separator())
	vbox.add_child(_spacer(12))

	# ── Botones ────────────────────────────────────────────────
	var btn_v := VBoxContainer.new()
	btn_v.add_theme_constant_override("separation", 10)
	btn_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_v.size_flags_stretch_ratio = 2.5
	vbox.add_child(btn_v)

	var has_save: bool = SaveManager.has_save(1)
	_add_button(btn_v, "▶   NUEVA PARTIDA",  true,     _on_new_game)
	_add_button(btn_v, "◈   CONTINUAR",       has_save, _on_continue)
	_add_button(btn_v, "⚙   AJUSTES",         false,    _on_settings)   # TODO
	_add_button(btn_v, "✕   SALIR",           true,     _on_quit)

	vbox.add_child(_spacer(10))
	vbox.add_child(_gold_separator())

	# Versión
	var ver := Label.new()
	ver.text = "v0.1 — ALFA"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 10)
	ver.add_theme_color_override("font_color", C_GOLD_DIM)
	vbox.add_child(ver)

# ── Acciones de botones ────────────────────────────────────────

func _on_new_game() -> void:
	# Resetear el run y arrancar la escena principal
	RunState.reset_run()
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_continue() -> void:
	# Carga slot 1 y continúa la partida en Main.tscn
	if SaveManager.load_slot(1):
		get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_settings() -> void:
	# TODO: pantalla de ajustes (audio, gráficos…)
	pass

func _on_quit() -> void:
	get_tree().quit()

# ── Helpers de construcción ────────────────────────────────────

func _add_button(parent: VBoxContainer, label: String, enabled: bool, action: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 48)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.disabled = not enabled
	btn.add_theme_font_size_override("font_size", 16)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color     = Color(0.10, 0.03, 0.03, 0.80) if enabled else Color(0.07, 0.02, 0.02, 0.50)
	normal_sb.border_color = C_GOLD if enabled else C_GOLD_DIM
	normal_sb.border_width_left = 1; normal_sb.border_width_right  = 1
	normal_sb.border_width_top  = 1; normal_sb.border_width_bottom = 1
	normal_sb.corner_radius_top_left    = 4; normal_sb.corner_radius_top_right    = 4
	normal_sb.corner_radius_bottom_left = 4; normal_sb.corner_radius_bottom_right = 4
	normal_sb.content_margin_left  = 14; normal_sb.content_margin_right  = 14
	normal_sb.content_margin_top   = 10; normal_sb.content_margin_bottom = 10

	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color     = Color(0.20, 0.08, 0.02, 0.90)
	hover_sb.border_color = C_GOLD
	hover_sb.shadow_color = Color(0.95, 0.76, 0.15, 0.35)
	hover_sb.shadow_size  = 6

	btn.add_theme_stylebox_override("normal",   normal_sb)
	btn.add_theme_stylebox_override("hover",    hover_sb)
	btn.add_theme_stylebox_override("pressed",  normal_sb)
	btn.add_theme_stylebox_override("disabled", normal_sb)
	btn.add_theme_color_override("font_color",          C_CREAM if enabled else C_CREAM_D)
	btn.add_theme_color_override("font_hover_color",    C_GOLD)
	btn.add_theme_color_override("font_pressed_color",  C_GOLD)
	btn.add_theme_color_override("font_disabled_color", C_CREAM_D)

	if enabled:
		btn.pressed.connect(action)
	parent.add_child(btn)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = C_OVERLAY
	sb.border_color = C_GOLD
	sb.border_width_left = 2; sb.border_width_right  = 2
	sb.border_width_top  = 2; sb.border_width_bottom = 2
	sb.corner_radius_top_left    = 8; sb.corner_radius_top_right    = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.70)
	sb.shadow_size  = 20
	return sb

func _gold_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color     = C_GOLD_DIM
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	return sep

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
