extends CanvasLayer
class_name HUD

# ============================================================
# HUD.gd
# ============================================================

# ── Cinema 80s palette ──────────────────────────────────────────────────────
const C_BG       := Color(0.10, 0.04, 0.04, 0.96)
const C_CARD     := Color(0.07, 0.02, 0.02, 0.99)
const C_GOLD     := Color(0.95, 0.76, 0.15)
const C_GOLD_DIM := Color(0.95, 0.76, 0.15, 0.45)
const C_RED      := Color(0.70, 0.06, 0.06)
const C_CREAM    := Color(0.97, 0.93, 0.80)
const C_CREAM_D  := Color(0.80, 0.75, 0.60)

var _prompt_panel: Panel = null
var _prompt_label: Label = null

var _bubble_panel: Panel = null
var _bubble_label: Label = null

var _debug_label: Label = null

var _attend_panel: Panel = null
var _attend_open: bool = false

var _bubble_timer: SceneTreeTimer = null

# Guard para no hacer trabajo extra en cada frame
var _prompt_visible: bool = false

var _queue_panel: Panel = null
var _queue_label: Label = null
var _queue_dots: Label = null

var _sat_panel: Panel = null
var _sat_bar: ProgressBar = null
var _sat_label: Label = null

# ── Barra de paciencia (bottom-left) ────────────────────────
var _patience_bar_panel: Panel       = null
var _patience_bar:       ProgressBar = null
var _patience_pct_label: Label       = null

# ── Sala Especial indicator (bottom-right) ───────────────────
var _special_room_panel: Panel = null
var _special_room_label: Label = null
var _special_room_dots:  Label = null

var _popup_count: int = 0   # para apilar popups de dinero

func _ready() -> void:
	_build_prompt()
	_build_bubble()
	_build_debug()
	_build_attend()
	_build_queue_bar()
	_build_satisfaction_bar()
	_build_patience_bar()
	_build_special_room()
	# Ocultar todo explícitamente al arrancar (sin guards)
	_force_hide_all()

func _force_hide_all() -> void:
	# Oculta los paneles directamente sin pasar por guards de estado
	if _prompt_panel:
		_prompt_panel.visible = false
	if _bubble_panel:
		_bubble_panel.visible = false
	if _attend_panel:
		_attend_panel.visible = false
	if _queue_panel:
		_queue_panel.visible = false
	if _sat_panel:
		_sat_panel.visible = false
	if _patience_bar_panel:
		_patience_bar_panel.visible = false
	if _special_room_panel:
		_special_room_panel.visible = false
	_prompt_visible = false
	_attend_open    = false

	# Ocultar StockHUD al inicio (solo se muestra en fase de comida)
	var stockhud := get_tree().get_root().get_node_or_null("Main/UI/StockHUD")
	if stockhud != null:
		if stockhud is CanvasLayer:
			(stockhud as CanvasLayer).visible = false
		else:
			stockhud.visible = false

# ──────────────────────────────────────────────────────────────
# PROMPT  "[E] Atender cliente"
# ──────────────────────────────────────────────────────────────
func _build_prompt() -> void:
	_prompt_panel = Panel.new()
	_prompt_panel.visible = false
	_prompt_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_prompt_panel)
	_prompt_panel.name = "PromptPanel"
	_prompt_panel.anchor_left   = 0.5
	_prompt_panel.anchor_right  = 0.5
	_prompt_panel.anchor_top    = 0.88
	_prompt_panel.anchor_bottom = 0.88
	_prompt_panel.offset_left   = -220
	_prompt_panel.offset_right  =  220
	_prompt_panel.offset_top    =  -28
	_prompt_panel.offset_bottom =   28

	_prompt_label = Label.new()
	_prompt_panel.add_child(_prompt_label)
	_prompt_label.anchor_left   = 0.0
	_prompt_label.anchor_right  = 1.0
	_prompt_label.anchor_top    = 0.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left   =  14
	_prompt_label.offset_right  = -14
	_prompt_label.offset_top    =   6
	_prompt_label.offset_bottom =  -6
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt_label.add_theme_color_override("font_color", C_CREAM)
	_prompt_label.add_theme_font_size_override("font_size", 15)

func show_prompt(key: String) -> void:
	if _prompt_panel == null or not is_instance_valid(_prompt_panel):
		_build_prompt()
	if _prompt_visible:
		return
	_prompt_label.text = TextDB.t(key)
	_prompt_panel.visible = true
	_prompt_visible = true

func hide_prompt() -> void:
	_prompt_visible = false
	if _prompt_panel != null and is_instance_valid(_prompt_panel):
		_prompt_panel.visible = false

# ──────────────────────────────────────────────────────────────
# BOCADILLO  (mensaje temporal del cliente)
# ──────────────────────────────────────────────────────────────
func _build_bubble() -> void:
	_bubble_panel = Panel.new()
	_bubble_panel.visible = false
	_bubble_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_bubble_panel)
	_bubble_panel.name = "BubblePanel"
	_bubble_panel.anchor_left   = 0.5
	_bubble_panel.anchor_right  = 0.5
	_bubble_panel.anchor_top    = 0.48
	_bubble_panel.anchor_bottom = 0.48
	_bubble_panel.offset_left   = -420
	_bubble_panel.offset_right  =  420
	_bubble_panel.offset_top    =  -90
	_bubble_panel.offset_bottom =   90

	_bubble_label = Label.new()
	_bubble_panel.add_child(_bubble_label)
	_bubble_label.anchor_left   = 0.0
	_bubble_label.anchor_right  = 1.0
	_bubble_label.anchor_top    = 0.0
	_bubble_label.anchor_bottom = 1.0
	_bubble_label.offset_left   =  18
	_bubble_label.offset_right  = -18
	_bubble_label.offset_top    =  14
	_bubble_label.offset_bottom = -14
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_bubble_label.add_theme_color_override("font_color", C_CREAM)
	_bubble_label.add_theme_font_size_override("font_size", 17)

func show_message(text: String, duration: float = 0.0) -> void:
	if _bubble_panel == null or not is_instance_valid(_bubble_panel):
		_build_bubble()
	_bubble_label.text = text
	_bubble_panel.visible = true
	if duration > 0.0:
		_bubble_timer = get_tree().create_timer(duration)
		_bubble_timer.timeout.connect(func(): hide_bubble())

func hide_message() -> void:
	hide_bubble()

func hide_bubble() -> void:
	if _bubble_panel != null and is_instance_valid(_bubble_panel):
		_bubble_panel.visible = false

# ──────────────────────────────────────────────────────────────
# PANEL RECOMENDAR PELÍCULA — tarjetas adaptativas al tamaño de ventana
# Layout por película:
#   [ Portada ]
#   Título
#   Géneros etiquetados
#   [ Elegir ]
# ──────────────────────────────────────────────────────────────
func _build_attend() -> void:
	_attend_panel = Panel.new()
	_attend_panel.visible = false
	_attend_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_attend_panel)
	_attend_panel.name = "AttendPanel"

	_attend_panel.anchor_left   = 0.5
	_attend_panel.anchor_right  = 0.5
	_attend_panel.anchor_top    = 0.05
	_attend_panel.anchor_bottom = 0.95
	_attend_panel.offset_left   = -540
	_attend_panel.offset_right  =  540
	_attend_panel.offset_top    =  0
	_attend_panel.offset_bottom =  0

	# Petición del cliente arriba
	var req_label := Label.new()
	req_label.name = "RequestLabel"
	_attend_panel.add_child(req_label)
	req_label.anchor_left   = 0.0
	req_label.anchor_right  = 1.0
	req_label.anchor_top    = 0.0
	req_label.anchor_bottom = 0.0
	req_label.offset_left   =  20
	req_label.offset_right  = -20
	req_label.offset_top    =  14
	req_label.offset_bottom =  60
	req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	req_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req_label.add_theme_font_size_override("font_size", 20)
	req_label.add_theme_color_override("font_color", C_GOLD)

	# Separador dorado bajo el request label
	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = C_GOLD_DIM
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	sep.anchor_left   = 0.0
	sep.anchor_right  = 1.0
	sep.anchor_top    = 0.0
	sep.anchor_bottom = 0.0
	sep.offset_left   =  20
	sep.offset_right  = -20
	sep.offset_top    =  60
	sep.offset_bottom =  62
	_attend_panel.add_child(sep)

	# Scroll horizontal
	var scroll := ScrollContainer.new()
	scroll.name = "MovieScroll"
	_attend_panel.add_child(scroll)
	scroll.anchor_left   = 0.0
	scroll.anchor_right  = 1.0
	scroll.anchor_top    = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left   =  10
	scroll.offset_right  = -10
	scroll.offset_top    =  70
	scroll.offset_bottom = -10

	var hbox := HBoxContainer.new()
	hbox.name = "MovieCards"
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	scroll.add_child(hbox)

func show_attend(request_line: String, movies: Array, tags_by_movie: Dictionary) -> void:
	if _attend_panel == null or not is_instance_valid(_attend_panel):
		_build_attend()

	var req := _attend_panel.get_node_or_null("RequestLabel") as Label
	if req:
		req.text = request_line

	var hbox := _attend_panel.get_node_or_null("MovieScroll/MovieCards") as HBoxContainer
	if hbox:
		for child in hbox.get_children():
			child.queue_free()

		# Tarjetas fijas, el panel ya esta centrado y dimensionado para 5
		var card_w   := 200.0
		var poster_h := 280.0

		for i in range(movies.size()):
			var m: Dictionary = movies[i] as Dictionary
			var mid         := String(m.get("id", ""))
			var tkey        := String(m.get("title_key", ""))
			var poster      := String(m.get("poster", ""))
			var player_tags: Array = tags_by_movie.get(mid, [])
			var is_sr: bool = (i == movies.size() - 1)   # última siempre es Sala Especial
			var card := _make_movie_card(mid, tkey, poster, player_tags, card_w, poster_h, is_sr)
			hbox.add_child(card)

	hide_prompt()
	_attend_open = true
	_attend_panel.visible = true

func _make_movie_card(mid: String, title_key: String, poster_path: String,
		player_tags: Array, card_w: float, poster_h: float,
		is_special_room: bool = false) -> PanelContainer:

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UITheme.card_style())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)

	# Portada
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(card_w, poster_h)
	tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if poster_path != "" and ResourceLoader.exists(poster_path):
		tex_rect.texture = load(poster_path)
	vbox.add_child(tex_rect)

	# Título
	var font_size_title := int(clampf(card_w * 0.075, 11.0, 16.0))
	var title_lbl := Label.new()
	title_lbl.text = TextDB.t(title_key)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", font_size_title)
	title_lbl.add_theme_color_override("font_color", C_CREAM)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title_lbl)

	# Géneros etiquetados por el jugador (nombre localizado vía TagDB)
	var font_size_tags := int(clampf(card_w * 0.058, 9.0, 13.0))
	var tags_lbl := Label.new()
	var localized_tags: Array[String] = []
	for t in player_tags:
		localized_tags.append(TagDB.label(String(t)))
	tags_lbl.text = ", ".join(localized_tags) if localized_tags.size() > 0 else "(sin etiquetar)"
	tags_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tags_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags_lbl.add_theme_font_size_override("font_size", font_size_tags)
	tags_lbl.add_theme_color_override("font_color", C_GOLD)
	tags_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(tags_lbl)

	# Badge Sala Especial (solo en la última tarjeta)
	if is_special_room:
		var badge := Label.new()
		badge.text = "★  SALA ESPECIAL"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", C_GOLD)
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var badge_sb := StyleBoxFlat.new()
		badge_sb.bg_color = Color(0.40, 0.30, 0.00, 0.60)
		badge_sb.corner_radius_top_left = 4; badge_sb.corner_radius_top_right = 4
		badge_sb.corner_radius_bottom_left = 4; badge_sb.corner_radius_bottom_right = 4
		badge_sb.content_margin_top = 4; badge_sb.content_margin_bottom = 4
		badge.add_theme_stylebox_override("normal", badge_sb)
		vbox.add_child(badge)

	# Botón elegir
	var btn := Button.new()
	btn.text = "Elegir"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(card_w, 36)
	btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	btn.add_theme_color_override("font_color", C_CREAM)
	vbox.add_child(btn)
	var captured_mid := mid
	btn.pressed.connect(func(): _on_movie_picked(captured_mid))

	return card

func hide_attend() -> void:
	if _attend_panel != null and is_instance_valid(_attend_panel):
		_attend_panel.visible = false
	_attend_open = false

func is_attend_open() -> bool:
	return _attend_open

signal recommend_movie(movie_id: String)

func _on_movie_picked(movie_id: String) -> void:
	hide_attend()
	emit_signal("recommend_movie", movie_id)

# ──────────────────────────────────────────────────────────────
# DEBUG  (esquina superior derecha)
# ──────────────────────────────────────────────────────────────
func _build_debug() -> void:
	_debug_label = Label.new()
	add_child(_debug_label)
	_debug_label.name = "DebugLabel"
	# Debug: centro-inferior, por encima de los paneles del fondo
	_debug_label.anchor_left   = 0.5
	_debug_label.anchor_right  = 0.5
	_debug_label.anchor_top    = 1.0
	_debug_label.anchor_bottom = 1.0
	_debug_label.offset_left   = -300
	_debug_label.offset_right  =  300
	_debug_label.offset_top    = -165
	_debug_label.offset_bottom = -140
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_label.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_label.modulate = Color(1, 1, 0, 1)
	_debug_label.text = ""

func show_debug(msg: String) -> void:
	if _debug_label == null or not is_instance_valid(_debug_label):
		_build_debug()
	_debug_label.text = msg

func clear_debug() -> void:
	show_debug("")

# ──────────────────────────────────────────────────────────────
# BARRA DE PROGRESO LLENADO BEBIDA
# ──────────────────────────────────────────────────────────────
var _fill_panel: Panel = null
var _fill_bar: ProgressBar = null
var _fill_label: Label = null

func _build_fill_bar() -> void:
	_fill_panel = Panel.new()
	_fill_panel.visible = false
	_fill_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_fill_panel)
	_fill_panel.name = "FillPanel"
	# Centro inferior
	_fill_panel.anchor_left   = 0.5
	_fill_panel.anchor_right  = 0.5
	_fill_panel.anchor_top    = 0.78
	_fill_panel.anchor_bottom = 0.78
	_fill_panel.offset_left   = -150
	_fill_panel.offset_right  =  150
	_fill_panel.offset_top    =  -36
	_fill_panel.offset_bottom =   36

	var vbox := VBoxContainer.new()
	_fill_panel.add_child(vbox)
	vbox.anchor_left   = 0.0
	vbox.anchor_right  = 1.0
	vbox.anchor_top    = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left   =  10
	vbox.offset_right  = -10
	vbox.offset_top    =   6
	vbox.offset_bottom =  -6

	_fill_label = Label.new()
	_fill_label.text = "Llenando..."
	_fill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fill_label.add_theme_font_size_override("font_size", 12)
	_fill_label.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(_fill_label)

	_fill_bar = ProgressBar.new()
	_fill_bar.min_value = 0
	_fill_bar.max_value = 100
	_fill_bar.value = 0
	_fill_bar.custom_minimum_size = Vector2(0, 14)
	_fill_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Estilo de la barra de progreso
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.06, 0.06)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	_fill_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = C_GOLD
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	_fill_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_fill_bar)

func set_fill_progress(show_it: bool, percent: int) -> void:
	if _fill_panel == null or not is_instance_valid(_fill_panel):
		_build_fill_bar()
	if not show_it:
		_fill_panel.visible = false
		return
	_fill_bar.value = percent
	_fill_panel.visible = true

# ──────────────────────────────────────────────────────────────
# COLA DE CLIENTES  (esquina inferior izquierda)
# ──────────────────────────────────────────────────────────────
func _build_queue_bar() -> void:
	_queue_panel = Panel.new()
	_queue_panel.visible = false
	_queue_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_queue_panel)
	_queue_panel.name = "QueuePanel"
	_queue_panel.anchor_left   = 0.0
	_queue_panel.anchor_right  = 0.0
	_queue_panel.anchor_top    = 1.0
	_queue_panel.anchor_bottom = 1.0
	_queue_panel.offset_left   =  18
	_queue_panel.offset_right  = 210
	_queue_panel.offset_top    = -70
	_queue_panel.offset_bottom = -18

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.0; vbox.anchor_right = 1.0
	vbox.anchor_top  = 0.0; vbox.anchor_bottom = 1.0
	vbox.offset_left = 10; vbox.offset_right = -10
	vbox.offset_top = 6; vbox.offset_bottom = -6
	vbox.add_theme_constant_override("separation", 3)
	_queue_panel.add_child(vbox)

	_queue_label = Label.new()
	_queue_label.add_theme_font_size_override("font_size", 11)
	_queue_label.add_theme_color_override("font_color", C_GOLD)
	_queue_label.text = "CLIENTES"
	vbox.add_child(_queue_label)

	_queue_dots = Label.new()
	_queue_dots.add_theme_font_size_override("font_size", 14)
	_queue_dots.add_theme_color_override("font_color", C_CREAM)
	_queue_dots.text = ""
	vbox.add_child(_queue_dots)

## Actualiza el indicador de cola. done = clientes ya servidos, total = total del día.
func update_queue(done: int, total: int) -> void:
	if _queue_panel == null or not is_instance_valid(_queue_panel):
		_build_queue_bar()
	_queue_panel.visible = total > 0
	if total <= 0:
		return
	_queue_label.text = "CLIENTES — DÍA %d" % RunState.day_index
	var dots := ""
	for i in range(total):
		dots += "● " if i < done else "○ "
	_queue_dots.text = dots.strip_edges()

# ──────────────────────────────────────────────────────────────
# POPUP DE DINERO  (+$50 propina, etc.)
# ──────────────────────────────────────────────────────────────

## Muestra un texto flotante animado de dinero ("+$50") que sube y desaparece.
## Hasta 4 popups apilados verticalmente sin solaparse.
func show_money_popup(text: String) -> void:
	var row := _popup_count % 4
	_popup_count += 1

	var y_base := -20 - row * 30   # apila hacia arriba
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_GOLD)
	# Posición: lado derecho, medio-abajo (no tapa barra paciencia ni diálogo)
	lbl.anchor_left   = 1.0
	lbl.anchor_right  = 1.0
	lbl.anchor_top    = 0.75
	lbl.anchor_bottom = 0.75
	lbl.offset_left   = -160
	lbl.offset_right  =  -8
	lbl.offset_top    = y_base
	lbl.offset_bottom = y_base + 26
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lbl)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "offset_top",    y_base - 55, 1.4)
	tw.tween_property(lbl, "offset_bottom", y_base + 26 - 55, 1.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.tween_callback(lbl.queue_free).set_delay(1.4)

# ──────────────────────────────────────────────────────────────
# BARRA DE SATISFACCIÓN DIARIA  (esquina superior derecha)
# ──────────────────────────────────────────────────────────────
func _build_satisfaction_bar() -> void:
	_sat_panel = Panel.new()
	_sat_panel.visible = false
	_sat_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_sat_panel)
	_sat_panel.name = "SatPanel"
	_sat_panel.anchor_left   = 1.0
	_sat_panel.anchor_right  = 1.0
	_sat_panel.anchor_top    = 0.0
	_sat_panel.anchor_bottom = 0.0
	_sat_panel.offset_left   = -270
	_sat_panel.offset_right  =  -18
	_sat_panel.offset_top    =   18
	_sat_panel.offset_bottom =   80

	var vbox := VBoxContainer.new()
	vbox.anchor_left   = 0.0; vbox.anchor_right  = 1.0
	vbox.anchor_top    = 0.0; vbox.anchor_bottom = 1.0
	vbox.offset_left   =  10; vbox.offset_right  = -10
	vbox.offset_top    =   6; vbox.offset_bottom =  -6
	vbox.add_theme_constant_override("separation", 4)
	_sat_panel.add_child(vbox)

	_sat_label = Label.new()
	_sat_label.text = "SATISFACCIÓN — 0 / 0"
	_sat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sat_label.add_theme_font_size_override("font_size", 11)
	_sat_label.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(_sat_label)

	_sat_bar = ProgressBar.new()
	_sat_bar.min_value = 0
	_sat_bar.max_value = 100
	_sat_bar.value = 0
	_sat_bar.show_percentage = false
	_sat_bar.custom_minimum_size = Vector2(0, 12)
	_sat_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.06, 0.06)
	bg.corner_radius_top_left = 3; bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3; bg.corner_radius_bottom_right = 3
	_sat_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.25, 0.70, 0.35)  # verde satisfacción
	fill.corner_radius_top_left = 3; fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3; fill.corner_radius_bottom_right = 3
	_sat_bar.add_theme_stylebox_override("fill", fill)
	vbox.add_child(_sat_bar)

## Actualiza la barra de satisfacción diaria. Muestra el panel si max_sat > 0.
func update_satisfaction(current: int, max_sat: int) -> void:
	if _sat_panel == null or not is_instance_valid(_sat_panel):
		_build_satisfaction_bar()
	if max_sat <= 0:
		_sat_panel.visible = false
		return
	_sat_panel.visible = true
	_sat_bar.max_value = max_sat
	_sat_bar.value = current
	var pct := int(100.0 * current / max_sat)
	_sat_label.text = "SATISFACCIÓN — %d%% (%d/%d)" % [pct, current, max_sat]

# ──────────────────────────────────────────────────────────────
# BARRA DE PACIENCIA  (franja delgada en el borde superior)
# ──────────────────────────────────────────────────────────────
func _build_patience_bar() -> void:
	_patience_bar_panel = Panel.new()
	_patience_bar_panel.name = "PatienceBarPanel"
	_patience_bar_panel.visible = false
	_patience_bar_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_patience_bar_panel)
	# Posición: esquina superior izquierda (no tapa el diálogo)
	_patience_bar_panel.anchor_left   = 0.0
	_patience_bar_panel.anchor_right  = 0.0
	_patience_bar_panel.anchor_top    = 0.0
	_patience_bar_panel.anchor_bottom = 0.0
	_patience_bar_panel.offset_left   =  18
	_patience_bar_panel.offset_right  = 210
	_patience_bar_panel.offset_top    =  18
	_patience_bar_panel.offset_bottom =  66

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	_patience_bar_panel.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	var lbl_title := Label.new()
	lbl_title.text = "Paciencia"
	lbl_title.add_theme_font_size_override("font_size", 11)
	lbl_title.add_theme_color_override("font_color", C_GOLD)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl_title)

	_patience_pct_label = Label.new()
	_patience_pct_label.text = "100%"
	_patience_pct_label.add_theme_font_size_override("font_size", 11)
	_patience_pct_label.add_theme_color_override("font_color", C_CREAM)
	_patience_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_patience_pct_label)

	_patience_bar = ProgressBar.new()
	_patience_bar.min_value = 0
	_patience_bar.max_value = 100
	_patience_bar.value = 100
	_patience_bar.show_percentage = false
	_patience_bar.custom_minimum_size = Vector2(0, 8)
	_patience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_patience_bar)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.03, 0.03, 0.85)
	_patience_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.25, 0.80, 0.35)
	_patience_bar.add_theme_stylebox_override("fill", bar_fill)

## Actualiza la barra de paciencia. fraction: 0.0–1.0.
func set_patience_bar(show_it: bool, fraction: float, is_critical: bool = false) -> void:
	if _patience_bar_panel == null or not is_instance_valid(_patience_bar_panel):
		_build_patience_bar()
	if not show_it:
		_patience_bar_panel.visible = false
		return
	_patience_bar.value = fraction * 100.0
	if _patience_pct_label != null:
		if is_critical:
			_patience_pct_label.text = "!!"
		else:
			_patience_pct_label.text = "%d%%" % int(fraction * 100.0)
	# Color: verde → ámbar → rojo / fase crítica = rojo pulsante
	var bar_fill := StyleBoxFlat.new()
	if is_critical:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		bar_fill.bg_color = Color(0.90, 0.05, 0.05).lerp(Color(1.0, 0.30, 0.10), pulse)
	elif fraction > 0.5:
		bar_fill.bg_color = Color(0.25, 0.80, 0.35)   # verde
	elif fraction > 0.25:
		bar_fill.bg_color = Color(0.90, 0.60, 0.10)   # ámbar
	else:
		bar_fill.bg_color = Color(0.85, 0.12, 0.12)   # rojo
	_patience_bar.add_theme_stylebox_override("fill", bar_fill)
	_patience_bar_panel.visible = true

# ──────────────────────────────────────────────────────────────
# INDICADOR SALA ESPECIAL  (esquina inferior derecha)
# ──────────────────────────────────────────────────────────────
func _build_special_room() -> void:
	_special_room_panel = Panel.new()
	_special_room_panel.name = "SpecialRoomPanel"
	_special_room_panel.visible = false
	_special_room_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_special_room_panel)
	_special_room_panel.anchor_left   = 1.0
	_special_room_panel.anchor_right  = 1.0
	_special_room_panel.anchor_top    = 1.0
	_special_room_panel.anchor_bottom = 1.0
	_special_room_panel.offset_left   = -210
	_special_room_panel.offset_right  =  -18
	_special_room_panel.offset_top    =  -80
	_special_room_panel.offset_bottom =  -18

	var vbox := VBoxContainer.new()
	vbox.anchor_left   = 0.0; vbox.anchor_right  = 1.0
	vbox.anchor_top    = 0.0; vbox.anchor_bottom = 1.0
	vbox.offset_left   =  10; vbox.offset_right  = -10
	vbox.offset_top    =   6; vbox.offset_bottom =  -6
	vbox.add_theme_constant_override("separation", 4)
	_special_room_panel.add_child(vbox)

	_special_room_label = Label.new()
	_special_room_label.text = "Sala especial,\nasientos libres"
	_special_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_special_room_label.add_theme_font_size_override("font_size", 10)
	_special_room_label.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(_special_room_label)

	_special_room_dots = Label.new()
	_special_room_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_special_room_dots.add_theme_font_size_override("font_size", 22)
	_special_room_dots.add_theme_color_override("font_color", C_CREAM)
	_special_room_dots.text = "5"
	vbox.add_child(_special_room_dots)

## Actualiza el indicador de la Sala Especial.
## capacity = huecos totales hoy, used = neutralizaciones ya hechas.
func update_special_room(capacity: int, used: int) -> void:
	if _special_room_panel == null or not is_instance_valid(_special_room_panel):
		_build_special_room()
	_special_room_panel.visible = true
	var free_slots := capacity - used
	_special_room_dots.text = str(free_slots)

## Oculta el indicador de Sala Especial (durante fase comida o cartelera).
func hide_special_room() -> void:
	if _special_room_panel != null and is_instance_valid(_special_room_panel):
		_special_room_panel.visible = false

# Estilos: ver UITheme.gd
