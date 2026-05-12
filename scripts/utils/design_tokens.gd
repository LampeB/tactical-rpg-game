class_name DesignTokens
extends RefCounted
## Single source of truth for the warm-paper design system.
## Reference these constants from scripts and component scenes; the matching
## `assets/ui/theme/inventory_paper.tres` Theme resource carries the same
## values for declarative styling.

# === Surfaces ===
const PAPER := Color(0.953, 0.910, 0.838)
const PAPER_2 := Color(0.910, 0.866, 0.790)
const PAPER_3 := Color(0.870, 0.821, 0.741)
const PAPER_EDGE := Color(0.820, 0.769, 0.690)

# === Ink (text + borders) ===
const INK := Color(0.184, 0.157, 0.122)
const INK_2 := Color(0.318, 0.286, 0.247)
const INK_3 := Color(0.471, 0.435, 0.388)
const INK_4 := Color(0.620, 0.580, 0.510)
const HAIRLINE := Color(0.682, 0.624, 0.557)

# === Accents ===
const BRASS := Color(0.690, 0.529, 0.275)
const BRASS_SOFT := Color(0.870, 0.788, 0.624)
const BRASS_BRIGHT := Color(0.850, 0.660, 0.340)
const EMBER := Color(0.780, 0.353, 0.247)
const MOSS := Color(0.376, 0.561, 0.376)
const INDIGO := Color(0.290, 0.353, 0.561)

# === Stage / vignette ===
const STAGE_DARK := Color(0.10, 0.08, 0.05)

# === Rarity (paper-friendly desaturated palette) ===
const R_COMMON := Color(0.55, 0.54, 0.52)
const R_UNCOMMON := Color(0.376, 0.561, 0.376)
const R_RARE := Color(0.31, 0.49, 0.62)
const R_ELITE := Color(0.51, 0.40, 0.62)
const R_LEGENDARY := Color(0.78, 0.61, 0.32)
const R_UNIQUE := Color(0.78, 0.40, 0.30)

# === Gem / element hues ===
const G_FIRE := Color(0.69, 0.43, 0.27)
const G_FROST := Color(0.51, 0.69, 0.78)
const G_EARTH := Color(0.55, 0.51, 0.31)
const G_BOLT := Color(0.78, 0.71, 0.31)
const G_VOID := Color(0.39, 0.27, 0.49)

# === Spacing scale (px) ===
const GAP_XS := 4
const GAP_S := 8
const GAP_M := 12
const GAP_L := 16
const GAP_XL := 24
const GAP_XXL := 32

# === Font sizes (px) ===
const FONT_TINY := 9
const FONT_SMALL := 11
const FONT_BASE := 13
const FONT_MEDIUM := 15
const FONT_LARGE := 18
const FONT_XL := 22
const FONT_TITLE := 26
const FONT_HERO := 36

# === Corner bracket geometry ===
const BRACKET_SIZE := 10
const BRACKET_THICKNESS := 1


## Build a paper-bg + ink-border StyleBoxFlat with optional content padding.
## Centralized so panel styling stays consistent across scenes.
static func make_paper_panel(content_margin: int = 16, border: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.border_width_left = border
	sb.border_width_top = border
	sb.border_width_right = border
	sb.border_width_bottom = border
	sb.content_margin_left = content_margin
	sb.content_margin_top = content_margin
	sb.content_margin_right = content_margin
	sb.content_margin_bottom = content_margin
	return sb


## Build a paper-2 panel without border (for soft sections).
static func make_paper_soft(content_margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_2
	sb.content_margin_left = content_margin
	sb.content_margin_top = content_margin
	sb.content_margin_right = content_margin
	sb.content_margin_bottom = content_margin
	return sb


## Build a hairline separator stylebox (1px tall).
static func make_hairline() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HAIRLINE
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb
