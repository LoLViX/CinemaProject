extends CanvasLayer
class_name DaySetupUI

signal day_setup_done

@export var movies_per_day: int = 5

const TAGS: Array[String] = ["action", "comedy", "drama", "horror", "scifi"]

# ── Cinema 80s palette ─────────────────────────────────────────
const C_GOLD     := Color(0.95, 0.76, 0.15)
const C_GOLD_DIM := Color(0.95, 0.76, 0.15, 0.28)
const C_CREAM    := Color(0.97, 0.93, 0.80)
const C_CREAM_D  := Color(0.80, 0.75, 0.60)

# ── Nodos ──────────────────────────────────────────────────────
var _panel:        Panel         = null
var _header_label: Label         = null
var _cards_row:    HBoxContainer = null
var _open_btn:     Button        = null
var _card_nodes:   Array         = []   # [{card_panel, poster, title, syn, tags_flow, movie_id}]

var _movies:  Array = []
var _textdb:  Node  = null

func _ready() -> void:
	add_to_group("day_setup_ui")
	_textdb = get_tree().root.get_node_or_null("TextDB")
	_build_ui()
	load_day()

# ══════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE UI
# ══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "DaySetupPanel"
	_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	_panel.anchor_left   = 0.0; _panel.anchor_right  = 1.0
	_panel.anchor_top    = 0.0; _panel.anchor_bottom = 1.0
	_panel.offset_left   =  14; _panel.offset_right  = -14
	_panel.offset_top    =  10; _panel.offset_bottom = -10
	add_child(_panel)

	var root_v := VBoxContainer.new()
	root_v.name = "RootV"
	root_v.anchor_left = 0.0;  root_v.anchor_right  = 1.0
	root_v.anchor_top  = 0.0;  root_v.anchor_bottom = 1.0
	root_v.offset_left = 18;   root_v.offset_right  = -18
	root_v.offset_top  = 12;   root_v.offset_bottom = -12
	root_v.add_theme_constant_override("separation", 8)
	_panel.add_child(root_v)

	# ── Encabezado ──────────────────────────────────────
	_header_label = Label.new()
	_header_label.name = "DayTitle"
	_header_label.text = "DÍA 1 — CARTELERA"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", C_GOLD)
	root_v.add_child(_header_label)

	root_v.add_child(UITheme.gold_separator())

	# ── Fila de tarjetas ─────────────────────────────────
	_cards_row = HBoxContainer.new()
	_cards_row.name = "CardsRow"
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", 10)
	root_v.add_child(_cards_row)

	root_v.add_child(UITheme.gold_separator())

	# ── Botón abrir el cine ──────────────────────────────
	_open_btn = Button.new()
	_open_btn.text = "★  ABRIR EL CINE"
	_open_btn.custom_minimum_size = Vector2(0, 46)
	_open_btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	_open_btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	_open_btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	_open_btn.add_theme_color_override("font_color", C_CREAM)
	_open_btn.add_theme_font_size_override("font_size", 16)
	_open_btn.pressed.connect(_on_open_cinema)
	root_v.add_child(_open_btn)

func _build_card(m: Dictionary, is_special: bool) -> Dictionary:
	var mid := String(m.get("id", ""))

	# ── Card panel ───────────────────────────────────────
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color     = Color(0.06, 0.02, 0.02, 0.90)
	card_sb.border_color = C_GOLD_DIM
	card_sb.border_width_left   = 1; card_sb.border_width_right  = 1
	card_sb.border_width_top    = 1; card_sb.border_width_bottom = 1
	card_sb.corner_radius_top_left    = 4; card_sb.corner_radius_top_right    = 4
	card_sb.corner_radius_bottom_left = 4; card_sb.corner_radius_bottom_right = 4

	var card_panel := Panel.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	card_panel.add_theme_stylebox_override("panel", card_sb)
	_cards_row.add_child(card_panel)

	var card_v := VBoxContainer.new()
	card_v.anchor_right  = 1.0
	card_v.anchor_bottom = 1.0
	card_v.offset_left   =  8; card_v.offset_right  = -8
	card_v.offset_top    =  8; card_v.offset_bottom = -8
	card_v.add_theme_constant_override("separation", 5)
	card_panel.add_child(card_v)

	# ── Póster ───────────────────────────────────────────
	var poster := TextureRect.new()
	poster.custom_minimum_size      = Vector2(0, 160)
	poster.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	poster.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	poster.size_flags_stretch_ratio = 2.0
	poster.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_v.add_child(poster)

	# ── Badge Sala Especial (si aplica) ──────────────────
	if is_special:
		var badge_sb := StyleBoxFlat.new()
		badge_sb.bg_color    = Color(0.0, 0.0, 0.0, 0.86)
		badge_sb.border_color = C_GOLD
		badge_sb.border_width_left = 1; badge_sb.border_width_right  = 1
		badge_sb.border_width_top  = 1; badge_sb.border_width_bottom = 1
		badge_sb.content_margin_left  = 6; badge_sb.content_margin_right  = 6
		badge_sb.content_margin_top   = 3; badge_sb.content_margin_bottom = 3

		var badge := Label.new()
		badge.text = "★ SALA ESPECIAL"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", C_GOLD)
		badge.add_theme_stylebox_override("normal", badge_sb)
		card_v.add_child(badge)

	# ── Separador fino ───────────────────────────────────
	var div_sb := StyleBoxFlat.new()
	div_sb.bg_color = C_GOLD_DIM
	var div := Panel.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.add_theme_stylebox_override("panel", div_sb)
	card_v.add_child(div)

	# ── Título ───────────────────────────────────────────
	var title_lbl := Label.new()
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", C_CREAM)
	title_lbl.custom_minimum_size = Vector2(0, 34)
	card_v.add_child(title_lbl)

	# ── Sinopsis ─────────────────────────────────────────
	var syn_lbl := Label.new()
	syn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	syn_lbl.add_theme_font_size_override("font_size", 12)
	syn_lbl.add_theme_color_override("font_color", C_CREAM_D)
	syn_lbl.custom_minimum_size      = Vector2(0, 40)
	syn_lbl.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	syn_lbl.size_flags_stretch_ratio = 1.0
	card_v.add_child(syn_lbl)

	# ── Tags ─────────────────────────────────────────────
	var tags_flow := FlowContainer.new()
	tags_flow.add_theme_constant_override("h_separation", 4)
	tags_flow.add_theme_constant_override("v_separation", 4)
	card_v.add_child(tags_flow)

	return {
		"card_panel": card_panel,
		"poster":     poster,
		"title":      title_lbl,
		"syn":        syn_lbl,
		"tags_flow":  tags_flow,
		"movie_id":   mid,
	}

# ══════════════════════════════════════════════════════════════
# CARGA Y ACTUALIZACIÓN
# ══════════════════════════════════════════════════════════════

func load_day() -> void:
	if RunState.todays_movies == null or RunState.todays_movies.size() == 0:
		RunState.todays_movies = MovieDB.todays_movies(movies_per_day)

	_movies = RunState.todays_movies

	# Pre-populate tags con los true_tags de cada película como punto de partida
	RunState.player_tags_by_movie = {}
	for m in _movies:
		var mid := String(m.get("id", ""))
		RunState.player_tags_by_movie[mid] = []  # el jugador marca desde cero

	# Actualizar título con el día actual
	if _header_label != null:
		_header_label.text = "DÍA %d — CARTELERA" % int(RunState.day_index)

	# Limpiar y reconstruir tarjetas
	for ch in _cards_row.get_children():
		ch.queue_free()
	_card_nodes.clear()

	var total := _movies.size()
	for i in range(total):
		var is_sr: bool = (i == total - 1) and RunState.CURRENT_PHASE >= 2
		var nd := _build_card(_movies[i], is_sr)
		_card_nodes.append(nd)
		_refresh_card(i)

	# Resetear estado visual (la animación de salida lo deja en 0)
	_panel.modulate = Color.WHITE
	_panel.visible = true
	if _open_btn != null:
		_open_btn.disabled = false
	show()

	if _header_label:
		_header_label.text = "DÍA %d — CARTELERA" % RunState.day_index

func _refresh_card(idx: int) -> void:
	if idx >= _movies.size() or idx >= _card_nodes.size():
		return
	var m:  Dictionary = _movies[idx]
	var nd: Dictionary = _card_nodes[idx]
	var mid := String(m.get("id", ""))

	# Póster
	var poster_path := String(m.get("poster", ""))
	if poster_path != "" and ResourceLoader.exists(poster_path):
		(nd["poster"] as TextureRect).texture = load(poster_path)
	else:
		(nd["poster"] as TextureRect).texture = null

	# Textos
	(nd["title"] as Label).text = _t(String(m.get("title_key", "")))
	(nd["syn"]   as Label).text = _t(String(m.get("syn_key",   "")))

	# Tags
	_rebuild_tags(nd["tags_flow"] as FlowContainer, mid)

func _rebuild_tags(flow: FlowContainer, movie_id: String) -> void:
	for ch in flow.get_children():
		ch.queue_free()

	for tag_id in TAGS:
		var arr: Array = RunState.player_tags_by_movie.get(movie_id, [])
		var on: bool   = arr.has(tag_id)

		var chip := Button.new()
		chip.toggle_mode    = true
		chip.button_pressed = on
		chip.text           = TagDB.label(tag_id)
		chip.add_theme_font_size_override("font_size", 11)
		_apply_chip_style(chip, on)

		var c_mid := movie_id
		var c_tag := tag_id
		var c_chip := chip
		chip.toggled.connect(func(pressed: bool) -> void:
			_toggle_tag(c_mid, c_tag, pressed)
			_apply_chip_style(c_chip, pressed)
		)

		flow.add_child(chip)

func _apply_chip_style(chip: Button, selected: bool) -> void:
	chip.add_theme_stylebox_override("normal",  _chip_style(selected))
	chip.add_theme_stylebox_override("pressed", _chip_style(true))
	chip.add_theme_stylebox_override("hover",   _chip_style(selected))
	if selected:
		chip.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0))
		chip.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		chip.add_theme_color_override("font_hover_color",   Color(1.0, 1.0, 1.0))
	else:
		chip.add_theme_color_override("font_color",         C_CREAM_D)
		chip.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		chip.add_theme_color_override("font_hover_color",   C_CREAM)

func _toggle_tag(movie_id: String, tag_id: String, on: bool) -> void:
	var arr: Array = RunState.player_tags_by_movie.get(movie_id, [])
	if on:
		if not arr.has(tag_id):
			arr.append(tag_id)
	else:
		arr.erase(tag_id)
	RunState.player_tags_by_movie[movie_id] = arr

# ══════════════════════════════════════════════════════════════
# ACCIONES DE USUARIO
# ══════════════════════════════════════════════════════════════

func _on_open_cinema() -> void:
	_open_btn.disabled = true
	SoundManager.play_click()
	_animate_and_done()

# ══════════════════════════════════════════════════════════════
# ANIMACIÓN Y SALIDA
# ══════════════════════════════════════════════════════════════

func _animate_and_done() -> void:
	var tw := create_tween()
	tw.set_parallel(true)

	for nd in _card_nodes:
		var cp := nd["card_panel"] as Panel
		if cp == null or not is_instance_valid(cp):
			continue
		tw.tween_property(cp, "position", cp.position + Vector2(0, -60), 0.55)
		tw.tween_property(cp, "modulate:a", 0.0, 0.45).set_delay(0.10)

	tw.tween_property(_panel, "modulate:a", 0.0, 0.35).set_delay(0.30)

	tw.set_parallel(false)
	tw.tween_callback(_on_animation_finished)

func _on_animation_finished() -> void:
	_panel.visible = false
	hide()
	emit_signal("day_setup_done")

# ══════════════════════════════════════════════════════════════
# ESTILOS
# ══════════════════════════════════════════════════════════════

func _chip_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color    = Color(0.95, 0.76, 0.15, 0.14)
		sb.border_color = C_GOLD
		sb.border_width_left = 1; sb.border_width_right  = 1
		sb.border_width_top  = 1; sb.border_width_bottom = 1
	else:
		sb.bg_color    = Color(0.08, 0.04, 0.04, 0.65)
		sb.border_color = Color(0.95, 0.76, 0.15, 0.40)
		sb.border_width_left = 1; sb.border_width_right  = 1
		sb.border_width_top  = 1; sb.border_width_bottom = 1
	sb.corner_radius_top_left    = 8; sb.corner_radius_top_right    = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left  = 7; sb.content_margin_right  = 7
	sb.content_margin_top   = 3; sb.content_margin_bottom = 3
	return sb

func _t(key: String) -> String:
	if key == "":
		return ""
	if _textdb != null and _textdb.has_method("t"):
		return String(_textdb.call("t", key))
	return key
