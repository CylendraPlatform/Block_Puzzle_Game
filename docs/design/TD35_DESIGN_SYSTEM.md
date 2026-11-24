# TD-3.5 Visual Design System — v1
## Principle
The puzzle BOARD is hero. Premium Playful **2.5D** (layered vector shading and gradients, not a new 3D renderer). Warm, readable, friendly, marketable; not casino chrome or a glossy screenshot pasted behind gameplay. All shapes dynamically follow the actual `PuzzleEngine` footprint. Preserve visual truth: each one-cell gate physically accepts one projected cell, and every piece clearly fits/not-fits.

## Colors (sRGB; implementation JSON is authoritative for exact hex)
| Role | Hex | Usage |
|---|---|---|
| Pearl canvas | `#FFF3E5` | full-screen background |
| Canvas highlight | `#FFF9F1` | upper gradient |
| Navy primary | `#19345B` | labels/icons |
| Indigo tray | `#324B78` | outer board bezel |
| Board recessed | `#263B62` | inner board |
| Cell | `#38517B` | recessed grid |
| Aqua | `#1DDCC4` | green/aqua block |
| Azure | `#24BBF2` | blue block |
| Coral | `#FF6178` | red/coral block |
| Lemon | `#FFD143` | yellow block |
| Violet | `#A95CF5` | purple block |
| Leaf | `#88D83A` | green block |
| Tangerine | `#FFA83A` | orange block |
| Confirm green | `#31C548` | Play/Continue |
| Soft shadow | `#1C2540` at 18–32% | elevation |
| Metallic border | `#F7D27A` | small gold accent only |

NOTE: logical puzzle colors remain exactly `red, blue, green, yellow, orange, purple`. Art colors are presentation mappings; do not rename logical enums. Aqua/leaf usage must map unambiguously to existing green; do not introduce seventh gameplay color.

## Geometry tokens at reference viewport 390x844 logical dp
- Safe area: use actual Godot SafeArea/Android insets; background edge-to-edge; controls inside inset + 12dp.
- Header row: target 56dp, icon hit areas >=48dp, 12dp spacing; title 20–24sp, body 15–17sp; debug labels only in developer mode.
- Board hero: max width min(available width - 28dp, 520dp), centered in *available content area*; square board remains square, non-square uses grid aspect ratio; visible grid cell target 42–66dp; never stretch cells unevenly.
- HUD + board + footer are vertically stacked inside safe rect; dynamically distribute **remaining** free space above/below board; avoid giant blank upper half, overlong single-column boards and vertical crowding.
- Board frame 12dp outside pad, 16–24dp radius; cells 2–3dp gaps with subtle bevel; visible gate aperture sits in the border with geometric span `(hi-lo+1) * cell_size`.
- Piece silhouette one connected region; corners 6–12dp rounding where feasible with no holes or cracks, edge 2–3dp, upper bevel 5–8% of cell, drop shadow 3–5dp. Color recognition must not depend solely on glossy highlight.
- Primary CTA min height 56dp; secondary controls >=48x48dp; all touch targets >=48dp with labels/icon contrast.
- Avoid fixed-size image assets for dynamic board, shapes, gate locations or portrait sizes. Geometry derives entirely from grid dimensions, rules and current board.

## Typography
Use project-licensed fonts only. Prefer `Nunito Sans`, `Baloo 2`, or system sans if appropriate *after licensing, embedding and Android checks*. Do not commit fonts without license. Weight: bold 700 headlines, medium 600 labels, regular 400 body. UI copy in English only. Localize later.

## Shadows and lighting
One top-left soft highlight, subtle downward navy shadow; 2–3 elevation tiers max. Shaderless 2.5D first, optimize on physical device before adding shaders; do not create per-frame StyleBox objects in render loops.

## Input feedback
Touch down: scale 1.025 for active piece; legal landing preview 0.15 opacity, tiny spring on settle; bump 110–150ms; exit 250–350ms easing through the CORRECT gate; haptics optional and togglable. All logic committed by `PuzzleSessionV2` via `PuzzleEngine`, not by animation.

## Accessibility
Minimum contrast ratio 4.5:1 for small essential text where feasible, 3:1 large text/icons. Color-blind redundant information: shape/contour plus matched-gate pattern or icon. No instructions hidden behind color alone. Reduce-motion setting must suppress shake/flash. No fast strobe. Do not place vital interactive controls inside cutouts, navigation bars or gesture zones.

## Exclusions
No redesign of 100 v1 levels without explicit authorization; no TD-4 mechanics; no paid economy. Concept art may show decorative stars, coins or crowns; **do not expose these as live mechanics**.
