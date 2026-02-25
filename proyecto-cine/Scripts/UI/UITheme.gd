class_name UITheme
# ============================================================
# UITheme.gd  —  Paleta y estilos compartidos de toda la UI
# ============================================================
# Clase estática: úsalo como UITheme.cinema_panel_style() etc.
# No necesita ser autoload ni instanciarse.

# ── Paleta 80s cine de pueblo USA ────────────────────────────
const C_BG       := Color(0.10, 0.04, 0.04, 0.96)  # burdeos oscuro
const C_CARD     := Color(0.07, 0.02, 0.02, 0.99)  # más oscuro para cards
const C_GOLD     := Color(0.95, 0.76, 0.15)         # dorado marquesina
const C_GOLD_DIM := Color(0.95, 0.76, 0.15, 0.45)  # dorado suave (separadores)
const C_RED      := Color(0.70, 0.06, 0.06)         # rojo telón
const C_CREAM    := Color(0.97, 0.93, 0.80)         # crema cálida (texto principal)
const C_CREAM_D  := Color(0.80, 0.75, 0.60)         # crema atenuada (texto secundario)

# ── Estilos ──────────────────────────────────────────────────

static func cinema_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.border_width_left   = 3
	sb.border_width_right  = 3
	sb.border_width_top    = 3
	sb.border_width_bottom = 3
	sb.border_color = C_GOLD
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size  = 8
	return sb

static func card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.border_width_left   = 2
	sb.border_width_right  = 2
	sb.border_width_top    = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.76, 0.15, 0.50)
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	return sb

static func btn_style(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.10, 0.10) if hover else C_RED
	sb.border_width_left   = 2
	sb.border_width_right  = 2
	sb.border_width_top    = 2
	sb.border_width_bottom = 2
	sb.border_color = C_GOLD
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left   = 14
	sb.content_margin_right  = 14
	sb.content_margin_top    = 7
	sb.content_margin_bottom = 7
	return sb

static func gold_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color     = C_GOLD_DIM
	sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sb)
	return sep

static func badge_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.05, 0.05, 0.92)
	sb.border_width_left   = 1
	sb.border_width_right  = 1
	sb.border_width_top    = 1
	sb.border_width_bottom = 1
	sb.border_color = C_GOLD
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left   = 8
	sb.content_margin_right  = 8
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	return sb
