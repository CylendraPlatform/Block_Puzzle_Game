class_name Style
extends RefCounted
## Centralized visual design tokens. Styling lives here, separate from puzzle rules.
## See docs/VISUAL_DESIGN_SYSTEM.md.

# ---- Palette: vivid block colors (logical name -> base color) ----
const BLOCK := {
	"red": Color("#ff5a6e"),
	"blue": Color("#4d7cff"),
	"green": Color("#2fd6a6"),
	"yellow": Color("#ffc442"),
	"orange": Color("#ff8f3c"),
	"purple": Color("#b36bff"),
}

# ---- Surfaces ----
const BG_TOP := Color("#2b3150")        # app background gradient (top)
const BG_BOTTOM := Color("#171a28")     # app background gradient (bottom)
const BOARD := Color("#30354f")         # play-area panel
const CELL := Color("#272b40")          # empty cell fill
const WALL := Color("#12141d")          # blocked cell
const PANEL := Color("#242a44")         # popups / bars
const PANEL_EDGE := Color("#4a5280")    # panel border

# ---- Text ----
const TEXT := Color("#f4f6ff")
const TEXT_DIM := Color("#aab0cc")
const TITLE := Color("#ffffff")

# ---- Dimensions ----
const RADIUS_BLOCK := 14
const RADIUS_PANEL := 20
const RADIUS_BUTTON := 16
const CELL_PAD := 0.10                   # fraction of a cell
const SHADOW := Color("#0b0d16")
const SHADOW_SIZE := 10
const BUTTON_H := 76
const BUTTON_MIN_W := 300

# ---- Typography (px) ----
const FS_TITLE := 64
const FS_HEADING := 30
const FS_BODY := 24
const FS_BUTTON := 26

# ---- Animation timing (seconds) ----
const EASE_SPEED := 22.0                 # block settle lerp speed
const EXIT_DUR := 0.22                   # exit pop
const GATE_PULSE := 1.6                  # gate idle pulse period
const SQUASH := 0.06                     # squash/stretch amount

static func block_color(name: String) -> Color:
	return BLOCK.get(name, Color.WHITE)

static func bg_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, BG_TOP)
	g.set_color(1, BG_BOTTOM)
	return g

## A full-rect vertical-gradient background node (ignores mouse).
static func make_bg() -> TextureRect:
	var tex := GradientTexture2D.new()
	tex.gradient = bg_gradient()
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(3)  # Control.PRESET_FULL_RECT
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
