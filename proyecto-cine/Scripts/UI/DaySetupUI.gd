extends CanvasLayer
class_name DaySetupUI

signal day_setup_done

@export var movies_per_day: int = 5

const TAGS: Array[String] = [
	"accion","drama","comedia",
	"terror","thriller","misterio",
	"scifi","crimen","fantasia",
	"aventura","oscura","ligera"
]

const BTN_H := 52
const CARD_W := 220
const POSTER_H := 180
const SCROLL_H := 480

# Tipos
const TITLE_SIZE := 18
const SYN_SIZE := 12
const CHIP_SIZE := 11
const CHIP_PAD_X := 8
const CHIP_PAD_Y := 4

# ── Cinema 80s palette ──────────────────────────────────────────────────────
const C_BG      := Color(0.10, 0.04, 0.04, 0.96)
const C_CARD    := Color(0.07, 0.02, 0.02, 0.99)
const C_GOLD    := Color(0.95, 0.76, 0.15)
const C_GOLD_DIM := Color(0.95, 0.76, 0.15, 0.45)
const C_RED     := Color(0.70, 0.06, 0.06)
const C_CREAM   := Color(0.97, 0.93, 0.80)
const C_CREAM_D := Color(0.80, 0.75, 0.60)

var _textdb: Node = null

var _panel: Panel
var _root_v: VBoxContainer
var _title: Label
var _subtitle: Label
var _scroll: ScrollContainer
var _row: HBoxContainer
var _btn: Button

func _ready() -> void:
	add_to_group("day_setup_ui")
	_textdb = get_tree().root.get_node_or_null("TextDB")

	_build_ui()
	_apply_layout()
	load_day()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UITheme.cinema_panel_style())
	add_child(_panel)

	_root_v = VBoxContainer.new()
	_panel.add_child(_root_v)
	_root_v.add_theme_constant_override("separation", 10)

	_title = Label.new()
	_title.text = "DÍA 1 — CLASIFICA LA CARTELERA"
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", C_GOLD)
	_root_v.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = "Marca los tags que CREES que encajan con cada peli (no te corregimos)."
	_subtitle.add_theme_color_override("font_color", C_CREAM_D)
	_root_v.add_child(_subtitle)

	_root_v.add_child(UITheme.gold_separator())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_FILL
	_scroll.custom_minimum_size = Vector2(0, SCROLL_H)
	_root_v.add_child(_scroll)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 18)
	_scroll.add_child(_row)

	_root_v.add_child(UITheme.gold_separator())

	_btn = Button.new()
	_btn.text = "ABRIR CINE"
	_btn.custom_minimum_size = Vector2(0, BTN_H)
	_btn.add_theme_stylebox_override("normal",  UITheme.btn_style(false))
	_btn.add_theme_stylebox_override("hover",   UITheme.btn_style(true))
	_btn.add_theme_stylebox_override("pressed", UITheme.btn_style(false))
	_btn.add_theme_color_override("font_color", C_CREAM)
	_btn.add_theme_font_size_override("font_size", 16)
	_btn.pressed.connect(_on_start_pressed)
	_root_v.add_child(_btn)

func _apply_layout() -> void:
	# Panel centrado horizontalmente con ancho fijo basado en 5 tarjetas
	var total_w := CARD_W * 5 + 18 * 4 + 28  # 5 tarjetas + gaps + padding
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.03
	_panel.anchor_bottom = 0.97
	_panel.offset_left   = -total_w / 2
	_panel.offset_right  =  total_w / 2
	_panel.offset_top    = 0
	_panel.offset_bottom = 0

	_root_v.anchor_left = 0.0
	_root_v.anchor_right = 1.0
	_root_v.anchor_top = 0.0
	_root_v.anchor_bottom = 1.0
	_root_v.offset_left = 14
	_root_v.offset_right = -14
	_root_v.offset_top = 12
	_root_v.offset_bottom = -12

func load_day() -> void:
	if RunState.todays_movies == null or RunState.todays_movies.size() == 0:
		RunState.todays_movies = MovieDB.todays_movies(movies_per_day)

	RunState.player_tags_by_movie = {}
	for m in RunState.todays_movies:
		var mid := String(m.get("id",""))
		RunState.player_tags_by_movie[mid] = []

	for c in _row.get_children():
		c.queue_free()

	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(10, 1)
	_row.add_child(left_spacer)

	for m in RunState.todays_movies:
		_row.add_child(_make_movie_card(m))

	var right_spacer := Control.new()
	right_spacer.custom_minimum_size = Vector2(10, 1)
	_row.add_child(right_spacer)

func _on_start_pressed() -> void:
	hide()
	emit_signal("day_setup_done")

func _make_movie_card(m: Dictionary) -> Control:
	var movie_id := String(m.get("id",""))
	var poster_path := String(m.get("poster",""))
	var pace := String(m.get("pace",""))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 560)
	card.add_theme_stylebox_override("panel", UITheme.card_style())

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var poster_layer := Control.new()
	poster_layer.custom_minimum_size = Vector2(CARD_W, POSTER_H)
	vb.add_child(poster_layer)

	var poster := TextureRect.new()
	poster.anchor_left = 0.0
	poster.anchor_right = 1.0
	poster.anchor_top = 0.0
	poster.anchor_bottom = 1.0
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if poster_path != "" and ResourceLoader.exists(poster_path):
		var tex = load(poster_path)
		if tex is Texture2D:
			poster.texture = tex
	poster_layer.add_child(poster)

	if pace != "":
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UITheme.badge_style())
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.anchor_top = 0.0
		badge.anchor_bottom = 0.0
		badge.offset_left = -110
		badge.offset_right = -10
		badge.offset_top = 10
		badge.offset_bottom = 44
		poster_layer.add_child(badge)

		var btxt := Label.new()
		btxt.text = "RÁPIDA" if pace == "fast" else "LENTA"
		btxt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btxt.add_theme_color_override("font_color", Color(1,1,1))
		btxt.add_theme_font_size_override("font_size", 12)
		badge.add_child(btxt)

	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", C_CREAM)
	title.text = _t(String(m.get("title_key","")))
	vb.add_child(title)

	var underline := Panel.new()
	underline.custom_minimum_size = Vector2(0, 1)
	var ul_style := StyleBoxFlat.new()
	ul_style.bg_color = C_GOLD_DIM
	underline.add_theme_stylebox_override("panel", ul_style)
	vb.add_child(underline)

	var syn := Label.new()
	syn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	syn.add_theme_font_size_override("font_size", SYN_SIZE)
	syn.text = _t(String(m.get("syn_key","")))
	syn.add_theme_color_override("font_color", C_CREAM_D)
	vb.add_child(syn)

	var tags_title := Label.new()
	tags_title.text = "Marca tags:"
	tags_title.add_theme_font_size_override("font_size", 12)
	tags_title.add_theme_color_override("font_color", C_GOLD)
	vb.add_child(tags_title)

	var flow := FlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	vb.add_child(flow)

	for tag_id in TAGS:
		var chip := Button.new()
		chip.toggle_mode = true
		chip.text = _pretty_tag(tag_id)
		chip.add_theme_font_size_override("font_size", CHIP_SIZE)
		chip.add_theme_color_override("font_color", C_CREAM)
		chip.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		chip.add_theme_color_override("font_hover_color", C_CREAM)

		var arr: Array = RunState.player_tags_by_movie[movie_id]
		chip.button_pressed = arr.has(tag_id)

		chip.add_theme_stylebox_override("normal", _chip_style(tag_id, false))
		chip.add_theme_stylebox_override("pressed", _chip_style(tag_id, true))
		chip.add_theme_stylebox_override("hover", _chip_style(tag_id, false))

		chip.pressed.connect(func():
			_toggle_tag(movie_id, tag_id, chip.button_pressed)
		)

		flow.add_child(chip)

	return card

func _toggle_tag(movie_id: String, tag_id: String, on: bool) -> void:
	var arr: Array = RunState.player_tags_by_movie.get(movie_id, [])
	if on:
		if not arr.has(tag_id):
			arr.append(tag_id)
	else:
		if arr.has(tag_id):
			arr.erase(tag_id)
	RunState.player_tags_by_movie[movie_id] = arr

func _badge_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.05, 0.05, 0.92)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = C_GOLD
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _chip_style(tag_id: String, pressed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var base := _tag_color(tag_id)

	if pressed:
		sb.bg_color = base
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(1.0, 1.0, 1.0, 0.25)
	else:
		# OFF: visible sobre fondo oscuro, pero claramente apagado
		var dim := base.lerp(Color(0.15, 0.10, 0.10), 0.58)
		dim.a = 0.72
		sb.bg_color = dim

	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = CHIP_PAD_X
	sb.content_margin_right = CHIP_PAD_X
	sb.content_margin_top = CHIP_PAD_Y
	sb.content_margin_bottom = CHIP_PAD_Y
	return sb

func _tag_color(tag_id: String) -> Color:
	match tag_id:
		"accion":   return Color(0.80, 0.20, 0.20)
		"comedia":  return Color(0.20, 0.75, 0.30)
		"terror":   return Color(0.22, 0.05, 0.08) # ✅ un pelín más legible que negro puro
		"thriller": return Color(0.60, 0.20, 0.70)
		"misterio": return Color(0.20, 0.55, 0.75)
		"scifi":    return Color(0.10, 0.70, 0.70)
		"drama":    return Color(0.80, 0.55, 0.15)
		"crimen":   return Color(0.35, 0.35, 0.35)
		"fantasia": return Color(0.45, 0.35, 0.85)
		"aventura": return Color(0.85, 0.40, 0.10)
		"oscura":   return Color(0.22, 0.22, 0.26) # ✅ antes era demasiado negro
		"ligera":   return Color(0.72, 0.72, 0.72)
		_:          return Color(0.25, 0.25, 0.28)

func _t(key: String) -> String:
	if key == "":
		return ""
	if _textdb != null and _textdb.has_method("t"):
		return String(_textdb.call("t", key))
	return "[" + key + "]"

func _pretty_tag(tag_id: String) -> String:
	match tag_id:
		"accion": return "Acción"
		"drama": return "Drama"
		"comedia": return "Comedia"
		"terror": return "Terror"
		"thriller": return "Thriller"
		"misterio": return "Misterio"
		"scifi": return "Sci-Fi"
		"crimen": return "Crimen"
		"fantasia": return "Fantasía"
		"aventura": return "Aventura"
		"oscura": return "Oscura"
		"ligera": return "Ligera"
		_: return tag_id.capitalize()

# Estilos: ver UITheme.gd
