# RPG2 — Design System Colors
# Auto-generated from styles.css. Hex values are resolved via sRGB.
# Source-of-truth is styles.css (OKLCH); this file is regenerated, do not hand-edit.

class_name RPG2Colors
extends RefCounted


# ── SURFACE / PAPER ──
const PAPER = Color8(242, 237, 229, 255)  # #F2EDE5  source: oklch(0.945 0.012 75)
const PAPER_2 = Color8(234, 227, 218, 255)  # #EAE3DA  source: oklch(0.918 0.014 72)
const PAPER_3 = Color8(225, 217, 206, 255)  # #E1D9CE  source: oklch(0.885 0.016 70)
const PAPER_EDGE = Color8(212, 201, 188, 255)  # #D4C9BC  source: oklch(0.84  0.02  68)

# ── TEXT / INK ──
const INK = Color8(35, 25, 17, 255)  # #231911  source: oklch(0.22  0.02  60)
const INK_2 = Color8(62, 54, 46, 255)  # #3E362E  source: oklch(0.34  0.018 60)
const INK_3 = Color8(105, 99, 90, 255)  # #69635A  source: oklch(0.50  0.014 60)
const INK_4 = Color8(152, 144, 138, 255)  # #98908A  source: oklch(0.66  0.012 60)
const HAIRLINE = Color8(192, 180, 173, 255)  # #C0B4AD  source: oklch(0.78  0.018 65)

# ── ACCENT ──
const BRASS = Color8(178, 120, 3, 255)  # #B27803  source: oklch(0.62  0.13  75)
const BRASS_SOFT = Color8(230, 204, 165, 255)  # #E6CCA5  source: oklch(0.86  0.06  78)
const EMBER = Color8(199, 79, 49, 255)  # #C74F31  source: oklch(0.58  0.16  35)
const MOSS = Color8(67, 131, 82, 255)  # #438352  source: oklch(0.55  0.10  150)
const INDIGO = Color8(59, 83, 140, 255)  # #3B538C  source: oklch(0.45  0.10  265)

# ── RARITY ──
const R_COMMON = Color8(98, 149, 101, 255)  # #629565  source: oklch(0.62  0.09  145)
const R_UNCOMMON = Color8(23, 133, 175, 255)  # #1785AF  source: oklch(0.58  0.11  230)
const R_RARE = Color8(120, 96, 181, 255)  # #7860B5  source: oklch(0.55  0.13  295)
const R_ELITE = Color8(196, 109, 33, 255)  # #C46D21  source: oklch(0.62  0.14   55)
const R_LEGENDARY = Color8(184, 70, 67, 255)  # #B84643  source: oklch(0.55  0.15   25)
const R_UNIQUE = Color8(171, 172, 48, 255)  # #ABAC30  source: oklch(0.72  0.14  110)

# ── RARITY / DIM ──
const R_COMMON_DIM = Color8(50, 80, 51, 255)  # #325033  source: oklch(0.40  0.06  145)
const R_UNCOMMON_DIM = Color8(13, 73, 97, 255)  # #0D4961  source: oklch(0.38  0.07  230)
const R_RARE_DIM = Color8(65, 51, 98, 255)  # #413362  source: oklch(0.36  0.08  295)
const R_ELITE_DIM = Color8(108, 56, 13, 255)  # #6C380D  source: oklch(0.40  0.09   55)
const R_LEGENDARY_DIM = Color8(100, 38, 37, 255)  # #642625  source: oklch(0.36  0.09   25)
const R_UNIQUE_DIM = Color8(97, 99, 29, 255)  # #61631D  source: oklch(0.48  0.09  110)

# ── GEM ──
const G_FIRE = Color8(213, 88, 73, 255)  # #D55849  source: oklch(0.62  0.16  30)
const G_FROST = Color8(66, 167, 195, 255)  # #42A7C3  source: oklch(0.68  0.10  220)
const G_EARTH = Color8(124, 115, 56, 255)  # #7C7338  source: oklch(0.55  0.08  100)
const G_BOLT = Color8(198, 160, 31, 255)  # #C6A01F  source: oklch(0.72  0.14  90)
const G_VOID = Color8(78, 61, 108, 255)  # #4E3D6C  source: oklch(0.40  0.08  300)

# ── STATUS ──
const SUCCESS = Color8(51, 132, 75, 255)  # #33844B  source: oklch(0.55  0.12  150)
const SUCCESS_BRIGHT = Color8(0, 138, 57, 255)  # #008A39  source: oklch(0.55  0.16  150)

# ── STAGE ──
const STAGE_DEEP = Color8(14, 11, 6, 255)  # #0E0B06  source: #0e0a07
const STAGE_WARM = Color8(43, 34, 27, 255)  # #2B221B  source: #2a221a

# ── SPECIAL ──
const GLYPH_INK = Color8(25, 15, 8, 255)  # #190F08  source: oklch(0.18  0.02  60)
const MODAL_VEIL = Color8(0, 0, 0, 115)  # #000000  source: rgba(0, 0, 0, 0.45)

# ── BACKDROP ──
const BACKDROP = Color8(67, 38, 23, 255)  # #432617  source: oklch(0.30  0.05   50)
const BACKDROP_DEEP = Color8(40, 20, 8, 255)  # #281408  source: oklch(0.22  0.04   50)

# Lookup by rarity tier name → Color
static func rarity(tier: String) -> Color:
	match tier:
		"common": return R_COMMON
		"magic", "uncommon": return R_UNCOMMON
		"rare": return R_RARE
		"mythic", "elite": return R_ELITE
		"legendary": return R_LEGENDARY
		"unique": return R_UNIQUE
		_: return R_COMMON
