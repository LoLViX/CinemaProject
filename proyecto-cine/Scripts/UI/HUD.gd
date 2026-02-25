extends CanvasLayer
class_name HUD

# ============================================================
# HUD.gd
# ============================================================

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

func _ready() -> void:
	_build_prompt()
	_build_bubble()
	_build_debug()
	_build_attend()
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
	_prompt_panel.visible = false          # ← empieza oculto siempre
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
	add_child(_attend_panel)
	_attend_panel.name = "AttendPanel"

	# Ocupa toda la pantalla menos un margen
	# Panel centrado, ancho fijo para 5 tarjetas de ~200px
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

	# Scroll horizontal — ocupa el resto del panel bajo el label
	var scroll := ScrollContainer.new()
	scroll.name = "MovieScroll"
	_attend_panel.add_child(scroll)
	scroll.anchor_left   = 0.0
	scroll.anchor_right  = 1.0
	scroll.anchor_top    = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left   =  10
	scroll.offset_right  = -10
	scroll.offset_top    =  66
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

		for m in movies:
			var mid         := String(m.get("id", ""))
			var tkey        := String(m.get("title_key", ""))
			var poster      := String(m.get("poster", ""))
			var player_tags: Array = tags_by_movie.get(mid, [])
			var card := _make_movie_card(mid, tkey, poster, player_tags, card_w, poster_h)
			hbox.add_child(card)

	hide_prompt()
	_attend_open = true
	_attend_panel.visible = true

func _make_movie_card(mid: String, title_key: String, poster_path: String,
		player_tags: Array, card_w: float, poster_h: float) -> PanelContainer:

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title_lbl)

	# Géneros etiquetados por el jugador
	var font_size_tags := int(clampf(card_w * 0.058, 9.0, 13.0))
	var tags_lbl := Label.new()
	tags_lbl.text = ", ".join(player_tags) if player_tags.size() > 0 else "(sin etiquetar)"
	tags_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tags_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags_lbl.add_theme_font_size_override("font_size", font_size_tags)
	tags_lbl.modulate = Color(0.7, 0.9, 1.0)
	tags_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(tags_lbl)

	# Botón elegir
	var btn := Button.new()
	btn.text = "Elegir"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(card_w, 36)
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
	_debug_label.anchor_left   = 1.0
	_debug_label.anchor_right  = 1.0
	_debug_label.anchor_top    = 0.0
	_debug_label.anchor_bottom = 0.0
	_debug_label.offset_left   = -380
	_debug_label.offset_top    =   18
	_debug_label.offset_right  =  -18
	_debug_label.offset_bottom =   70
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	vbox.add_child(_fill_label)

	_fill_bar = ProgressBar.new()
	_fill_bar.min_value = 0
	_fill_bar.max_value = 100
	_fill_bar.value = 0
	_fill_bar.custom_minimum_size = Vector2(0, 16)
	_fill_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_fill_bar)

func set_fill_progress(show_it: bool, percent: int) -> void:
	if _fill_panel == null or not is_instance_valid(_fill_panel):
		_build_fill_bar()
	if not show_it:
		_fill_panel.visible = false
		return
	_fill_bar.value = percent
	_fill_panel.visible = true
