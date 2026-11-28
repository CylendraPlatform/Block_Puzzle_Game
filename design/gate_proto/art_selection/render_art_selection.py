"""Art-direction selection: concept mockups of prototype Level C in the two shortlisted
directions (Carved Pearl, Midnight Glass).

Design artwork only, drawn with Pillow. NOT game code and NOT gameplay screenshots. Every
board is built from ../levels/proto_c.json (board size, piece cells and positions, gate side
and lo..hi), so geometry matches the solver-verified level exactly. The script also checks
that each gate is exactly one opening over its lo..hi cells and that the frame is solid
everywhere else (see Board.check_geometry).

Usage: python design/gate_proto/art_selection/render_art_selection.py
Writes PNGs and metrics.json into renders/ next to this script.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
LEVEL_PATH = HERE.parent / "levels" / "proto_c.json"
V1_MOCKUPS = HERE.parent / "mockups"
OUT = HERE / "renders"
SS = 3  # supersampling factor for every render
WHITE, BLACK = (255, 255, 255), (0, 0, 0)

# Colour glyphs from GAME_DESIGN_SPEC section 6, in colour order.
GLYPH = {"red": "circle", "blue": "square", "green": "triangle", "yellow": "diamond",
         "orange": "star", "purple": "hexagon"}

TOKENS = {
    "pearl": {
        "name": "Carved Pearl", "label": "Direction A",
        "mood": "Warm porcelain tray, enamel blocks, deep blue well. Light from top-left.",
        "page_top": (255, 248, 239), "page_bot": (241, 227, 211), "page_glow": (255, 255, 255),
        "tray_top": (253, 248, 241), "tray_bot": (230, 218, 203), "tray_side": (188, 170, 150),
        "tray_hi": (255, 255, 255), "rim": None,
        "floor_top": (66, 80, 114), "floor_bot": (50, 62, 92),
        "cell_hi": (98, 114, 152), "cell": (80, 95, 132),
        "hole": (20, 24, 38), "shadow": (56, 38, 26),
        "text": (40, 52, 80), "sub": (118, 106, 94),
        "pieces": {"red": (238, 82, 92), "blue": (58, 156, 240), "green": (96, 196, 92),
                   "yellow": (255, 196, 52)},
        "radius": 0.22, "glass": False,
        "scrim": (44, 34, 28), "scrim_a": 0.40,
        "card_top": (255, 251, 246), "card_bot": (238, 228, 216),
        "primary": (58, 156, 240), "badge": (255, 196, 52),
    },
    "glass": {
        "name": "Midnight Glass", "label": "Direction B",
        "mood": "Smoked-glass slab on deep navy, translucent lit blocks, doors that emit light.",
        "page_top": (26, 32, 62), "page_bot": (7, 9, 20), "page_glow": (80, 92, 210),
        "tray_top": (54, 64, 108), "tray_bot": (27, 33, 62), "tray_side": (10, 12, 26),
        "tray_hi": (196, 214, 255), "rim": (120, 160, 255),
        "floor_top": (14, 18, 36), "floor_bot": (9, 12, 26),
        "cell_hi": (36, 44, 80), "cell": (25, 32, 60),
        "hole": (2, 3, 8), "shadow": (0, 0, 6),
        "text": (232, 238, 255), "sub": (152, 164, 208),
        "pieces": {"red": (255, 90, 112), "blue": (64, 168, 255), "green": (80, 220, 140),
                   "yellow": (255, 206, 72)},
        "radius": 0.18, "glass": True,
        "scrim": (4, 6, 14), "scrim_a": 0.55,
        "card_top": (48, 58, 100), "card_bot": (26, 32, 60),
        "primary": (64, 168, 255), "badge": (255, 206, 72),
    },
}


# ---------------------------------------------------------------- small helpers

def font(px, bold=False):
    names = ("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")
    for n in names + ("DejaVuSans.ttf",):
        try:
            return ImageFont.truetype(n, int(px))
        except OSError:
            continue
    return ImageFont.load_default()


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def blank(size):
    return Image.new("L", size, 0)


def full(size):
    return Image.new("L", size, 255)


def rr(size, box, r):
    m = blank(size)
    ImageDraw.Draw(m).rounded_rectangle(tuple(int(round(v)) for v in box), radius=max(0, int(r)), fill=255)
    return m


def rect(size, box):
    m = blank(size)
    ImageDraw.Draw(m).rectangle(tuple(int(round(v)) for v in box), fill=255)
    return m


def shift(m, dx, dy):
    """Translate without wrap-around (ImageChops.offset wraps)."""
    out = blank(m.size)
    out.paste(m, (int(round(dx)), int(round(dy))))
    return out


def blur(m, r):
    return m.filter(ImageFilter.GaussianBlur(max(0.3, r)))


def times(m, a):
    return m.point(lambda v: min(255, int(v * a)))


def shrink(m, r):
    """Approximate erosion by about r pixels (blur + high threshold); fast for large r."""
    return blur(m, r * 0.6).point(lambda v: 255 if v >= 250 else 0)


def mul(a, b):
    return ImageChops.multiply(a, b)


def sub(a, b):
    return ImageChops.subtract(a, b)


def union(a, b):
    return ImageChops.lighter(a, b)


def paint(img, color, mask, a=1.0):
    img.paste(color, mask=times(mask, a) if a != 1.0 else mask)


def clamp_box(box, size):
    x0, y0, x1, y1 = (int(round(v)) for v in box)
    return max(0, x0), max(0, y0), min(size[0], x1), min(size[1], y1)


def grad_mask(size, box, toward):
    """L mask over box: 0 at the inner end, 255 at the `toward` side (left/right/top/bottom)."""
    x0, y0, x1, y1 = clamp_box(box, size)
    m = blank(size)
    if x1 <= x0 or y1 <= y0:
        return m
    g = Image.linear_gradient("L")  # 0 at top, 255 at bottom
    if toward == "top":
        g = g.transpose(Image.FLIP_TOP_BOTTOM)
    elif toward == "left":
        g = g.transpose(Image.ROTATE_270)     # clockwise: bottom (255) ends up on the left
    elif toward == "right":
        g = g.transpose(Image.ROTATE_90)      # counter-clockwise: bottom ends up on the right
    m.paste(g.resize((x1 - x0, y1 - y0), Image.BILINEAR), (x0, y0))
    return m


def paint_grad(img, box, c0, c1, mask, a=1.0):
    """Vertical gradient c0 (top of box) to c1 (bottom), painted through mask."""
    x0, y0, x1, y1 = clamp_box(box, img.size)
    if x1 <= x0 or y1 <= y0:
        return
    col = Image.new("RGB", (1, 256))
    for i in range(256):
        col.putpixel((0, i), mix(c0, c1, i / 255))
    g = col.resize((x1 - x0, y1 - y0), Image.BILINEAR)
    region = mask.crop((x0, y0, x1, y1))
    if a != 1.0:
        region = times(region, a)
    img.paste(g, (x0, y0), region)


def bevel(img, m, b, soft, hi, lo, a_hi, a_lo):
    """Light from top-left: highlight band on top-left edges, shade band on bottom-right."""
    paint(img, hi, mul(blur(sub(m, shift(m, b, b)), soft), m), a_hi)
    paint(img, lo, mul(blur(sub(m, shift(m, -b, -b)), soft), m), a_lo)


def glyph_mask(size, kind, cx, cy, r):
    m = blank(size)
    d = ImageDraw.Draw(m)
    if kind == "circle":
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    elif kind == "square":
        d.rounded_rectangle((cx - r * 0.85, cy - r * 0.85, cx + r * 0.85, cy + r * 0.85), radius=int(r * 0.2), fill=255)
    elif kind == "triangle":
        d.polygon([(cx, cy - r), (cx + r * 1.05, cy + r * 0.8), (cx - r * 1.05, cy + r * 0.8)], fill=255)
    else:  # diamond (star / hexagon are not used in Level C)
        d.polygon([(cx, cy - r * 1.1), (cx + r, cy), (cx, cy + r * 1.1), (cx - r, cy)], fill=255)
    return m


def boost(m, a):
    return m.point(lambda v: min(255, int(v * a)))


# ---------------------------------------------------------------- the board

class Board:
    """One Level C board in one direction. `c` is the cell size in (supersampled) pixels.
    State overrides: pieces (list of piece dicts), exiting (piece, (dx, dy) px, trail),
    pulse (gate ids glowing after an exit), aligned (gate ids showing the 'lined up' cue)."""

    def __init__(self, lv, c, tok, pieces=None, exiting=None, pulse=(), aligned=()):
        self.lv, self.c, self.t = lv, c, tok
        self.cols, self.rows = lv["board"]["cols"], lv["board"]["rows"]
        self.f = round(c * 0.46)            # frame band
        self.m = round(c * 0.95)            # margin for shadows / glow
        self.d = round(c * 0.07)            # visible tray thickness
        self.W = self.cols * c + 2 * self.f + 2 * self.m
        self.H = self.rows * c + 2 * self.f + 2 * self.m + round(c * 0.2)
        self.ox, self.oy = self.m + self.f, self.m + self.f
        self.pieces = lv["pieces"] if pieces is None else pieces
        self.exiting, self.pulse, self.aligned = exiting, set(pulse), set(aligned)

    # geometry ------------------------------------------------------------
    def outer(self):
        m, c, f = self.m, self.c, self.f
        return (m, m, m + self.cols * c + 2 * f, m + self.rows * c + 2 * f)

    def well(self):
        p = self.c * 0.04
        return (self.ox - p, self.oy - p, self.ox + self.cols * self.c + p, self.oy + self.rows * self.c + p)

    def notch(self, g):
        """The opening through the frame: exactly over cells lo..hi (posts on the cell lines)."""
        c, ox, oy = self.c, self.ox, self.oy
        j = c * 0.045
        lo, hi = g["lo"], g["hi"]
        if g["side"] == "left":
            return (0, oy + lo * c + j, ox + c * 0.02, oy + (hi + 1) * c - j)
        if g["side"] == "right":
            x = ox + self.cols * c
            return (x - c * 0.02, oy + lo * c + j, self.W, oy + (hi + 1) * c - j)
        if g["side"] == "top":
            return (ox + lo * c + j, 0, ox + (hi + 1) * c - j, oy + c * 0.02)
        y = oy + self.rows * c
        return (ox + lo * c + j, y - c * 0.02, ox + (hi + 1) * c - j, self.H)

    def colour(self, name):
        return self.t["pieces"][name]

    # drawing -------------------------------------------------------------
    def render(self, base):
        t, c, size = self.t, self.c, base.size
        glass = t["glass"]
        O = rr(size, self.outer(), self.f * 0.95)
        Wm = rr(size, self.well(), c * 0.2)
        N = blank(size)
        nd = ImageDraw.Draw(N)
        gates = self.lv["gates"]
        notches = [self.notch(g) for g in gates]
        for n in notches:
            nd.rectangle(tuple(int(v) for v in n), fill=255)
        R = mul(union(Wm, N), O)           # recessed floor: well + one channel per gate
        T = sub(O, R)                      # raised tray (frame), solid except the openings
        self.T, self.R = T, R
        # 1. slab shadows on the page; in glass, light spills out of each opening
        paint(base, t["shadow"], blur(shift(O, c * 0.05, c * 0.26), c * 0.34), 0.55 if glass else 0.30)
        paint(base, t["shadow"], blur(shift(O, 0, self.d + c * 0.03), c * 0.06), 0.45 if glass else 0.35)
        if glass:
            outside = sub(full(size), O)
            for g, n in zip(gates, notches):
                paint(base, self.colour(g["accept"][0]), mul(blur(rect(size, self.spill(g, n)), c * 0.22), outside), 0.55)
        paint(base, t["tray_side"], shift(O, 0, self.d))
        # 2. recessed floor and cell dimples
        paint_grad(base, self.outer(), t["floor_top"], t["floor_bot"], R)
        cells = blank(size)
        cd = ImageDraw.Draw(cells)
        i = c * 0.05
        for y in range(self.rows):
            for x in range(self.cols):
                cd.rounded_rectangle((int(self.ox + x * c + i), int(self.oy + y * c + i), int(self.ox + (x + 1) * c - i), int(self.oy + (y + 1) * c - i)), radius=int(c * 0.16), fill=255)
        paint_grad(base, self.well(), t["cell_hi"], t["cell"], cells)
        b = c * 0.035
        paint(base, BLACK, mul(blur(sub(cells, shift(cells, b, b)), c * 0.02), cells), 0.30)
        paint(base, WHITE, mul(blur(sub(cells, shift(cells, -b, -b)), c * 0.02), cells), 0.06 if glass else 0.10)
        # 3. channels (openings)
        for g, n in zip(gates, notches):
            self.channel(base, g, n, R, Wm)
        # 4. shadow the tray casts into the recess (one light direction everywhere)
        paint(base, t["shadow"], mul(blur(T, c * 0.12), R), 0.35 if glass else 0.28)
        paint(base, t["shadow"], mul(blur(shift(T, c * 0.025, c * 0.08), c * 0.05), R), 0.60 if glass else 0.50)
        chans = sub(R, Wm)   # deeper occlusion on the channel floors: the jambs are close walls
        paint(base, t["shadow"], mul(blur(shift(T, c * 0.03, c * 0.10), c * 0.09), chans), 0.45)
        paint(base, t["tray_side"], mul(sub(shift(T, 0, self.d), T), R))  # south faces inside the recess
        # 5. tray top face with a double bevel
        paint_grad(base, self.outer(), t["tray_top"], t["tray_bot"], T)
        bevel(base, T, c * 0.05, c * 0.025, t["tray_hi"], t["tray_side"], 0.85, 0.55)
        bevel(base, T, c * 0.14, c * 0.09, t["tray_hi"], t["tray_side"], 0.22, 0.20)
        if glass:
            paint(base, t["rim"], blur(sub(T, shrink(T, c * 0.035)), c * 0.01), 0.55)
            sheen = blank(size)
            x0, y0, x1, y1 = self.outer()
            ImageDraw.Draw(sheen).polygon([(x0, y0 + (y1 - y0) * 0.30), (x0 + (x1 - x0) * 0.30, y0), (x0 + (x1 - x0) * 0.48, y0), (x0, y0 + (y1 - y0) * 0.48)], fill=255)
            paint(base, WHITE, mul(blur(sheen, c * 0.2), T), 0.07)
        self.clip = sub(R, shift(T, 0, self.d))
        # 6. blocks
        for p in self.pieces:
            self.piece(base, p)
        if self.exiting:
            p, delta, trail = self.exiting
            self.piece(base, p, delta, trail=trail, clip=self.clip)
        for g, n in zip(gates, notches):
            if g["id"] in self.pulse:
                col = self.colour(g["accept"][0])
                hole = mul(rect(size, n), O)
                paint(base, col, boost(blur(hole, c * 0.35), 1.8), 0.85)
                paint(base, mix(col, WHITE, 0.6), mul(hole, R), 0.55)

    def spill(self, g, n):
        c, (x0, y0, x1, y1) = self.c, self.outer()
        L_ = c * 0.5
        if g["side"] == "left":
            return (x0 - L_, n[1], x0, n[3])
        if g["side"] == "right":
            return (x1, n[1], x1 + L_, n[3])
        if g["side"] == "top":
            return (n[0], y0 - L_, n[2], y0)
        return (n[0], y1, n[2], y1 + L_)

    def channel(self, img, g, n, R, Wm):
        t, c, size = self.t, self.c, img.size
        col = self.colour(g["accept"][0])
        side = g["side"]
        ch = sub(mul(rect(size, n), R), Wm)
        paint(img, col, ch, 0.22 if t["glass"] else 0.30)
        depth = mul(grad_mask(size, n, side), ch)
        if t["glass"]:
            paint(img, col, depth, 0.95)            # light comes in through the door
        else:
            paint(img, t["hole"], depth, 0.80)      # tunnel falls away into shadow
        ox, oy, W, H = self.ox, self.oy, self.cols * c, self.rows * c
        th, e = c * 0.075, c * 0.07
        if side == "left":
            strip = (ox - th - c * 0.03, n[1] + e, ox - c * 0.03, n[3] - e)
        elif side == "right":
            strip = (ox + W + c * 0.03, n[1] + e, ox + W + th + c * 0.03, n[3] - e)
        elif side == "top":
            strip = (n[0] + e, oy - th - c * 0.03, n[2] - e, oy - c * 0.03)
        else:
            strip = (n[0] + e, oy + H + c * 0.03, n[2] - e, oy + H + th + c * 0.03)
        sm = rr(size, strip, th / 2)
        lit = g["id"] in self.aligned
        if t["glass"] or lit:
            paint(img, col, boost(blur(sm, c * 0.16), 2.2), 0.9 if lit else 0.7)
        paint(img, col, sm)
        if lit:
            paint(img, WHITE, sm, 0.45)
        # chevron (pointing out) and the colour glyph on the channel floor
        x0, y0, x1, y1 = n
        k = c * 0.10
        if side in ("left", "right"):
            inner = ox if side == "left" else ox + W
            outer = self.outer()[0] if side == "left" else self.outer()[2]
            cy = (y0 + y1) / 2
            sgn = -1 if side == "left" else 1
            gpos = (inner + sgn * abs(outer - inner) * 0.30, cy)
            ax = inner + sgn * abs(outer - inner) * 0.70
            chev = [(ax + sgn * k, cy), (ax - sgn * k * 0.6, cy - k), (ax - sgn * k * 0.6, cy + k)]
        else:
            inner = oy if side == "top" else oy + H
            outer = self.outer()[1] if side == "top" else self.outer()[3]
            cx = (x0 + x1) / 2
            sgn = -1 if side == "top" else 1
            gpos = (cx, inner + sgn * abs(outer - inner) * 0.30)
            ay = inner + sgn * abs(outer - inner) * 0.70
            chev = [(cx, ay + sgn * k), (cx - k, ay - sgn * k * 0.6), (cx + k, ay - sgn * k * 0.6)]
        cm = blank(size)
        ImageDraw.Draw(cm).polygon(chev, fill=255)
        paint(img, mix(col, WHITE, 0.65), cm, 0.95)
        paint(img, mix(col, WHITE, 0.75), glyph_mask(size, GLYPH[g["accept"][0]], gpos[0], gpos[1], c * 0.075), 0.85)

    def piece(self, img, p, delta=(0, 0), trail=False, clip=None):
        t, c, size = self.t, self.c, img.size
        work = img.copy() if clip is not None else img
        col = self.colour(p["color"])
        glass = t["glass"]
        px, py = p["pos"]
        cells = {(q[0], q[1]) for q in p["cells"]}
        g = c * 0.075
        m = blank(size)
        md = ImageDraw.Draw(m)
        for (cx, cy) in cells:
            # inset only on sides without a neighbour, so joins are seamless
            x0 = self.ox + (px + cx) * c + (0 if (cx - 1, cy) in cells else g) + delta[0]
            y0 = self.oy + (py + cy) * c + (0 if (cx, cy - 1) in cells else g) + delta[1]
            x1 = self.ox + (px + cx + 1) * c - (0 if (cx + 1, cy) in cells else g) + delta[0]
            y1 = self.oy + (py + cy + 1) * c - (0 if (cx, cy + 1) in cells else g) + delta[1]
            md.rectangle((int(x0), int(y0), int(x1), int(y1)), fill=255)
        M = blur(m, c * t["radius"] * 0.6).point(lambda v: 255 if v > 128 else 0)
        h = c * 0.11
        if trail:
            for i, a in enumerate((0.10, 0.16, 0.24)):
                k = 0.22 * (3 - i)
                paint(work, col, shift(M, -delta[0] * k, -delta[1] * k), a)
        if glass:
            paint(work, col, blur(M, c * 0.28), 0.40)
        paint(work, t["shadow"], blur(shift(M, c * 0.05, h + c * 0.14), c * 0.18), 0.40 if glass else 0.28)
        paint(work, t["shadow"], blur(shift(M, c * 0.02, h + c * 0.03), c * 0.05), 0.60 if glass else 0.50)
        S = blank(size)
        steps = max(2, int(h / 2))
        for k in range(1, steps + 1):
            S = union(S, shift(M, 0, h * k / steps))
        paint(work, mix(col, BLACK, 0.48 if glass else 0.36), S, 0.92 if glass else 1.0)
        paint(work, BLACK, mul(S, sub(shift(M, 0, h), shift(M, 0, h * 0.5))), 0.12)
        box = M.getbbox() or (0, 0, 1, 1)
        paint_grad(work, box, mix(col, WHITE, 0.30 if glass else 0.20), mix(col, BLACK, 0.10 if glass else 0.05), M, 0.62 if glass else 1.0)
        if glass:
            # translucent body: lit inner edge, darker core, sharp diagonal specular streak
            paint(work, mix(col, WHITE, 0.55), mul(blur(sub(M, shrink(M, c * 0.12)), c * 0.05), M), 0.85)
            paint(work, mix(col, BLACK, 0.25), mul(blur(shrink(M, c * 0.22), c * 0.12), M), 0.30)
            x0, y0, x1, y1 = box
            streak = blank(size)
            w_ = c * 0.16
            ImageDraw.Draw(streak).polygon([(x0, y0 + c * 0.55), (x0 + c * 0.55, y0), (x0 + c * 0.55 + w_, y0), (x0, y0 + c * 0.55 + w_)], fill=255)
            paint(work, WHITE, mul(blur(streak, c * 0.03), shrink(M, c * 0.06)), 0.35)
        else:
            inner = shrink(M, c * 0.12)
            paint(work, WHITE, mul(blur(sub(inner, shift(inner, c * 0.5, c * 0.5)), c * 0.14), M), 0.32)
        bevel(work, M, c * 0.05, c * 0.022, WHITE, mix(col, BLACK, 0.45), 0.70 if glass else 0.60, 0.45)
        lip_src = shrink(M, c * 0.035)
        paint(work, WHITE, blur(sub(lip_src, shift(lip_src, 0, c * 0.035)), c * 0.012), 0.85 if glass else 0.55)

        # embossed colour glyph on the anchor cell (the cell with most neighbours)
        def nbrs(q):
            return sum((q[0] + dx, q[1] + dy) in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        ax, ay = max(sorted(cells), key=nbrs)
        gx = self.ox + (px + ax + 0.5) * c + delta[0]
        gy = self.oy + (py + ay + 0.5) * c + delta[1]
        r, e = c * 0.13, max(2, c * 0.012)
        gk = GLYPH[p["color"]]
        paint(work, mix(col, BLACK, 0.35), glyph_mask(size, gk, gx + e, gy + e, r), 0.45)
        paint(work, mix(col, WHITE, 0.45), glyph_mask(size, gk, gx - e * 0.5, gy - e * 0.5, r), 0.55)
        if clip is not None:
            img.paste(work, (0, 0), clip)

    def check_geometry(self):
        """Sample the tray at the middle of the frame band beside every edge cell: it must be
        open exactly on the gate cells and solid everywhere else. Returns (ok, lines)."""
        c, f, m, T = self.c, self.f, self.m, self.T
        expected = {}
        for g in self.lv["gates"]:
            for i in range(g["lo"], g["hi"] + 1):
                expected[(g["side"], i)] = g["id"]
        lines, ok = [], True
        for side, n in (("left", self.rows), ("right", self.rows), ("top", self.cols), ("bottom", self.cols)):
            opened = []
            for i in range(n):
                if side == "left":
                    pt = (m + f * 0.5, self.oy + (i + 0.5) * c)
                elif side == "right":
                    pt = (self.ox + self.cols * c + f * 0.5, self.oy + (i + 0.5) * c)
                elif side == "top":
                    pt = (self.ox + (i + 0.5) * c, m + f * 0.5)
                else:
                    pt = (self.ox + (i + 0.5) * c, self.oy + self.rows * c + f * 0.5)
                is_open = T.getpixel((int(pt[0]), int(pt[1]))) < 128
                if is_open:
                    opened.append(i)
                if is_open != ((side, i) in expected):
                    ok = False
                    lines.append(f"MISMATCH {side} cell {i}: open={is_open}")
            lines.append(f"{side} edge: open cells {opened} of {n}")
        for g in self.lv["gates"]:
            edge_len = self.rows if g["side"] in ("left", "right") else self.cols
            if g["hi"] - g["lo"] + 1 >= edge_len:
                ok = False
                lines.append(f"FULL-EDGE gate {g['id']}")
        return ok, lines


def paint_page(img, t, glow_center=(0.5, 0.42)):
    size = img.size
    paint_grad(img, (0, 0, size[0], size[1]), t["page_top"], t["page_bot"], full(size))
    g = blank(size)
    cx, cy = size[0] * glow_center[0], size[1] * glow_center[1]
    rx, ry = size[0] * 0.55, size[1] * 0.32
    ImageDraw.Draw(g).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    paint(img, t["page_glow"], blur(g, size[0] * 0.18), 0.35 if t["glass"] else 0.45)


def board_image(lv, cell_pt, style, **state):
    """Render a board alone on its page. cell_pt = output pixels per cell."""
    c = cell_pt * SS
    b = Board(lv, c, TOKENS[style], **state)
    img = Image.new("RGB", (int(b.W), int(b.H)), TOKENS[style]["page_top"])
    paint_page(img, TOKENS[style])
    b.render(img)
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS), b


# ---------------------------------------------------------------- UI pieces

def tactile(img, box, r, t, top=None, bot=None, depth=6, glass=False, sh_a=0.35):
    """A raised, bevelled control or card with its own shadow, drawn in a local crop."""
    top, bot = top or t["tray_top"], bot or t["tray_bot"]
    pad = int(depth * 8 + r)
    rb = clamp_box((box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad + depth * 4), img.size)
    sub_img = img.crop(rb)
    bx = (box[0] - rb[0], box[1] - rb[1], box[2] - rb[0], box[3] - rb[1])
    M = rr(sub_img.size, bx, r)
    side = t["tray_side"] if top == t["tray_top"] else mix(top, BLACK, 0.35)
    paint(sub_img, t["shadow"], blur(shift(M, 0, depth * 2.2), depth * 2.4), sh_a)
    paint(sub_img, side, shift(M, 0, depth))
    paint_grad(sub_img, bx, top, bot, M)
    bevel(sub_img, M, depth * 0.7, depth * 0.35, WHITE, side, 0.75, 0.35)
    if glass:
        paint(sub_img, t["rim"], blur(sub(M, shrink(M, depth * 0.5)), depth * 0.15), 0.55)
    img.paste(sub_img, rb[:2])


def text(d, xy, s, px, colour, bold=False, anchor="mm"):
    d.text(xy, s, fill=colour, font=font(px, bold), anchor=anchor)


CELL_PT = 51.7  # 358 pt board width on a 390 pt phone: 6 c + 2 x 0.46 c = 6.92 c


def phone(lv, style, state, win=False):
    """Full gameplay screen at 390x844 pt, returned at 2x (780x1688)."""
    t = TOKENS[style]
    k = 2 * SS                                     # px per pt in the working canvas
    W, H = 390 * k, 844 * k
    img = Image.new("RGB", (W, H), t["page_top"])
    paint_page(img, t, (0.5, 0.45))
    b = Board(lv, CELL_PT * k, t, **state)
    bx, by = int(16 * k - b.m), int(262 * k - b.m)   # board centred between HUD and actions
    region = img.crop((bx, by, bx + int(b.W), by + int(b.H)))
    b.render(region)
    img.paste(region, (bx, by))
    d = ImageDraw.Draw(img)
    # generic status bar and the concept tag
    text(d, (34 * k, 24 * k), "9:41", 15 * k, t["text"], True, "lm")
    d.rounded_rectangle((W - 48 * k, 18 * k, W - 24 * k, 30 * k), radius=3 * k, outline=t["text"], width=int(1.2 * k))
    d.rectangle((W - 46 * k, 20 * k, W - 30 * k, 28 * k), fill=t["text"])
    for i in range(4):
        d.rectangle((W - (84 - i * 7) * k, (29 - 3 * i) * k, W - (80 - i * 7) * k, 30 * k), fill=t["text"])
    d.rounded_rectangle((W / 2 - 70 * k, 15 * k, W / 2 + 70 * k, 33 * k), radius=9 * k, outline=t["sub"], width=int(1 * k))
    text(d, (W / 2, 24 * k), "CONCEPT MOCKUP", 10 * k, t["sub"], True)
    # HUD: pause, title, hint, moves pill
    for x in (16, 328):
        tactile(img, (x * k, 60 * k, (x + 46) * k, 106 * k), 15 * k, t, depth=2.2 * k, glass=t["glass"])
    d = ImageDraw.Draw(img)
    for dx in (-5, 5):
        d.rounded_rectangle(((39 + dx - 2.5) * k, 74 * k, (39 + dx + 2.5) * k, 90 * k), radius=int(1.5 * k), fill=t["text"])
    text(d, (351 * k, 82 * k), "?", 22 * k, t["text"], True)
    text(d, (W / 2, 76 * k), "Turn the Corner", 21 * k, t["text"], True)
    text(d, (W / 2, 99 * k), "Prototype level C", 13 * k, t["sub"])
    tactile(img, (115 * k, 128 * k, 275 * k, 160 * k), 16 * k, t, depth=1.6 * k, glass=t["glass"])
    d = ImageDraw.Draw(img)
    text(d, (W / 2, 144 * k), "Moves 9  ·  Par 9" if win else "Moves 0  ·  Par 9", 15 * k, t["text"], True)
    # bottom actions
    for x0, label in ((24, "Undo"), (206, "Restart")):
        tactile(img, (x0 * k, 732 * k, (x0 + 160) * k, 784 * k), 18 * k, t, depth=2.4 * k, glass=t["glass"])
        d = ImageDraw.Draw(img)
        text(d, ((x0 + 80) * k, 758 * k), label, 17 * k, t["text"], True)
    d.rounded_rectangle((W / 2 - 67 * k, 829 * k, W / 2 + 67 * k, 834 * k), radius=3 * k, fill=t["sub"])
    if win:
        win_dialog(img, t, k)
    return img.resize((W // SS, H // SS), Image.LANCZOS), b


def win_dialog(img, t, k):
    """Bottom-sheet result card: the cleared board stays readable above it."""
    W, _ = img.size
    img.paste(img.filter(ImageFilter.GaussianBlur(0.8 * k)))
    img.paste(t["scrim"], mask=Image.new("L", img.size, int(255 * t["scrim_a"] * 0.6)))
    tactile(img, (16 * k, 600 * k, 374 * k, 824 * k), 28 * k, t, top=t["card_top"], bot=t["card_bot"], depth=3.2 * k, glass=t["glass"], sh_a=0.5)
    d = ImageDraw.Draw(img)
    text(d, (W / 2, 638 * k), "Solved!", 28 * k, t["text"], True)
    text(d, (W / 2, 672 * k), "Turn the Corner  ·  9 moves  ·  best 9", 14 * k, t["sub"])
    tactile(img, (120 * k, 692 * k, 270 * k, 724 * k), 16 * k, t, top=mix(t["badge"], WHITE, 0.25), bot=t["badge"], depth=1.6 * k)
    d = ImageDraw.Draw(img)
    text(d, (W / 2, 708 * k), "Perfect: par 9", 14 * k, (60, 40, 10), True)
    tactile(img, (36 * k, 744 * k, 186 * k, 794 * k), 18 * k, t, depth=2.4 * k, glass=t["glass"])
    tactile(img, (204 * k, 744 * k, 354 * k, 794 * k), 18 * k, t, top=mix(t["primary"], WHITE, 0.18), bot=mix(t["primary"], BLACK, 0.08), depth=2.4 * k)
    d = ImageDraw.Draw(img)
    text(d, (111 * k, 769 * k), "Replay", 17 * k, t["text"], True)
    text(d, (279 * k, 769 * k), "Next level", 17 * k, WHITE, True)


# ---------------------------------------------------------------- deliverables

def piece_by_id(lv, pid):
    return next(p for p in lv["pieces"] if p["id"] == pid)


def at(p, pos):
    return dict(p, pos=list(pos))


CLOSE_CELL = 130  # output px per cell for every close-up, both directions


def closeups(lv, style):
    """Gate close-up (blue_left, rows 2-3) and L / T block close-ups from one 130 px board."""
    img, b = board_image(lv, CLOSE_CELL, style)
    c, f, m = CLOSE_CELL, b.f / SS, b.m / SS
    ox, oy = m + f, m + f
    top = oy + c * 1.35
    gate = img.crop((int(m - c * 0.35), int(top), int(ox + c * 1.55), int(oy + c * 4.65)))
    gd = ImageDraw.Draw(gate)
    guide = (255, 64, 160)
    for line in (2, 4):
        y = oy + c * line - top
        for x in range(0, gate.width, 16):
            gd.line((x, y, x + 8, y), fill=guide, width=2)
    gd.text((8, 8), "blue_left: side left, lo 2, hi 3", fill=guide, font=font(18, True))
    gd.text((8, gate.height - 26), "dashed: cell lines y=2 and y=4", fill=guide, font=font(16))
    lpiece = img.crop((int(m - c * 0.15), int(m - c * 0.15), int(ox + c * 2.35), int(oy + c * 2.45)))
    tpiece = img.crop((int(ox + c * 0.7), int(oy + c * 3.7), int(ox + c * 4.3), int(oy + c * 6.0 + f * 0.7)))
    return gate, lpiece, tpiece, b


def storyboard(lv, style):
    """Blue T leaves through the left door (solution moves 2-3), four frames, 48 px cells."""
    tpc = piece_by_id(lv, "blue_t")
    # positions after solution move 1 (yellow parked right at (4,2))
    others = [at(piece_by_id(lv, "red_l"), (0, 0)), at(piece_by_id(lv, "green_i"), (4, 3)),
              at(piece_by_id(lv, "yellow_bar"), (4, 2))]
    c = 48 * SS
    frames = [
        (dict(pieces=others + [at(tpc, (1, 2))], aligned=["blue_left"]), "1  Lined up with rows 2-3: threshold brightens"),
        (dict(pieces=others, exiting=(at(tpc, (1, 2)), (-c * 0.9, 0), True)), "2  Slide out: one move"),
        (dict(pieces=others, exiting=(at(tpc, (1, 2)), (-c * 2.55, 0), False)), "3  Through the opening, under the lip"),
        (dict(pieces=others, pulse=["blue_left"]), "4  Gone: the door pulses once"),
    ]
    return [(board_image(lv, 48, style, **st)[0], cap) for st, cap in frames]


def contrast(a, b):
    def lum(col):
        def ch(v):
            v = v / 255
            return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
        r, g, bb = (ch(x) for x in col)
        return 0.2126 * r + 0.7152 * g + 0.0722 * bb
    la, lb = lum(a), lum(b)
    return round((max(la, lb) + 0.05) / (min(la, lb) + 0.05), 2)


def metrics(style):
    t = TOKENS[style]
    mid_cell = mix(t["cell_hi"], t["cell"], 0.5)
    mid_tray = mix(t["tray_top"], t["tray_bot"], 0.5)
    rows = {
        "title text on page": contrast(t["text"], t["page_top"]),
        "secondary text on page": contrast(t["sub"], t["page_top"]),
        "button label on button": contrast(t["text"], mid_tray),
        "cell vs tray (board edge)": contrast(mid_cell, mid_tray),
        "opening floor vs tray": contrast(t["floor_bot"], mid_tray),
    }
    for name, col in t["pieces"].items():
        rows[f"{name} block vs cell"] = contrast(col, mid_cell)
    for name, col in t["pieces"].items():
        rows[f"{name} door strip vs tray"] = contrast(col, mid_tray)
    return rows


def compose(tiles, gap, page, ink):
    """Tiles in one row with captions underneath."""
    cap_h = 30
    w = sum(t.width for t, _ in tiles) + gap * (len(tiles) - 1)
    h = max(t.height for t, _ in tiles) + cap_h
    out = Image.new("RGB", (w, h), page)
    d = ImageDraw.Draw(out)
    x = 0
    for t, cap in tiles:
        out.paste(t, (x, 0))
        d.text((x + 4, t.height + 4), cap, fill=ink, font=font(15))
        x += t.width + gap
    return out


def label_strip(img, s, page, ink, h=30):
    out = Image.new("RGB", (img.width, img.height + h), page)
    out.paste(img, (0, h))
    ImageDraw.Draw(out).text((0, h / 2), s, fill=ink, font=font(17, True), anchor="lm")
    return out


def swatches(style, width):
    t = TOKENS[style]
    items = [("page", t["page_top"]), ("tray", t["tray_top"]), ("tray side", t["tray_side"]),
             ("well", t["floor_top"]), ("cell", t["cell"]), ("text", t["text"]), ("sub", t["sub"])]
    items += list(t["pieces"].items())
    sw = width // len(items)
    out = Image.new("RGB", (width, 96), (250, 248, 245))
    d = ImageDraw.Draw(out)
    for i, (n, col) in enumerate(items):
        d.rounded_rectangle((i * sw + 4, 4, (i + 1) * sw - 4, 52), radius=8, fill=col, outline=(200, 200, 200))
        d.text((i * sw + sw / 2, 64), n, fill=(40, 40, 40), font=font(13, True), anchor="mm")
        d.text((i * sw + sw / 2, 82), "#%02X%02X%02X" % col, fill=(90, 90, 90), font=font(12), anchor="mm")
    return out


def fit(img, w):
    return img.resize((w, int(img.height * w / img.width)), Image.LANCZOS)


def comparison_sheet(cols, report):
    pad, colw = 40, 900
    page, ink = (250, 248, 245), (34, 38, 52)
    columns = []
    for style in ("pearl", "glass"):
        t, c = TOKENS[style], cols[style]
        parts = []
        head = Image.new("RGB", (colw, 90), page)
        hd = ImageDraw.Draw(head)
        hd.text((0, 4), f"{t['label']}: {t['name']}  (new concept)", fill=ink, font=font(30, True))
        hd.text((0, 50), t["mood"], fill=(90, 90, 100), font=font(18))
        parts.append(head)
        row = Image.new("RGB", (colw, 844 + 36), page)
        rd = ImageDraw.Draw(row)
        row.paste(c["game"], (0, 0))
        row.paste(c["win"], (450, 0))
        rd.text((0, 852), "Gameplay, start position (390x844 pt, 1x)", fill=ink, font=font(16, True))
        rd.text((450, 852), "Win screen, board behind the dialog", fill=ink, font=font(16, True))
        parts.append(row)
        g = c["gate"].resize((c["gate"].width // 2, c["gate"].height // 2), Image.LANCZOS)
        bl = c["blocks"].resize((c["blocks"].width // 2, c["blocks"].height // 2), Image.LANCZOS)
        cr = Image.new("RGB", (colw, max(g.height, bl.height) + 34), page)
        cr.paste(g, (0, 0))
        cr.paste(bl, (g.width + 30, 0))
        cd = ImageDraw.Draw(cr)
        cd.text((0, cr.height - 26), "Gate close-up", fill=ink, font=font(16, True))
        cd.text((g.width + 30, cr.height - 26), "L and T blocks (both close-ups at half size)", fill=ink, font=font(16, True))
        parts.append(cr)
        parts.append(label_strip(fit(c["sb"], colw), "Exit storyboard: blue T leaves through its door", page, ink))
        parts.append(label_strip(swatches(style, colw), "Design tokens", page, ink))
        cm = report["contrast"][style]
        tb = Image.new("RGB", (colw, 34 + 22 * len(cm)), page)
        td = ImageDraw.Draw(tb)
        td.text((0, 0), "Contrast (WCAG ratio, flat token colours)", fill=ink, font=font(16, True))
        for i, (name, v) in enumerate(cm.items()):
            td.text((0, 30 + i * 22), name, fill=(70, 70, 80), font=font(15))
            td.text((360, 30 + i * 22), f"{v}:1", fill=ink, font=font(15, True))
        parts.append(tb)
        colimg = Image.new("RGB", (colw, sum(p.height for p in parts) + 16 * len(parts)), page)
        y = 0
        for p in parts:
            colimg.paste(p, (0, y))
            y += p.height + 16
        columns.append(colimg)
    ref_path = V1_MOCKUPS / "visual_directions.png"
    ref = fit(Image.open(ref_path).convert("RGB"), colw * 2 + pad) if ref_path.exists() else None
    body = max(col.height for col in columns)
    W = colw * 2 + pad * 3
    H = 150 + body + (ref.height + 90 if ref else 0) + pad
    sheet = Image.new("RGB", (W, H), page)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 28), "Art direction selection: Level C 'Turn the Corner', identical geometry and framing", fill=ink, font=font(36, True))
    d.text((pad, 84), "All images are CONCEPT MOCKUPS rendered offline with Pillow from levels/proto_c.json. They are not gameplay screenshots.", fill=(160, 40, 40), font=font(20, True))
    d.text((pad, 114), "Same cell size, crops and states in both columns. One opening per gate, over exactly its lo..hi cells.", fill=(90, 90, 100), font=font(18))
    x = pad
    for col in columns:
        sheet.paste(col, (x, 150))
        x += colw + pad
    if ref:
        y = 150 + body + 30
        d.text((pad, y), "Reference: original PR #28 mockups (v1, flat), including Toy Workshop. Not shortlisted.", fill=ink, font=font(22, True))
        sheet.paste(ref, (pad, y + 44))
    sheet.save(OUT / "comparison_sheet.png", optimize=True)
    print("comparison_sheet.png", sheet.size)


def main():
    OUT.mkdir(exist_ok=True)
    lv = json.loads(LEVEL_PATH.read_text(encoding="utf-8"))
    report = {"level": lv["id"], "geometry": {}, "contrast": {}}
    cols, all_ok = {}, True
    for style in ("pearl", "glass"):
        t = TOKENS[style]
        game2x, b = phone(lv, style, {})
        ok, lines = b.check_geometry()
        game2x.save(OUT / f"{style}_game_390x844@2x.png", optimize=True)
        game1x = game2x.resize((390, 844), Image.LANCZOS)
        game1x.save(OUT / f"{style}_game_390x844.png", optimize=True)
        # win: every block has left; the red L was the last one out, so its door pulses
        win2x, _ = phone(lv, style, dict(pieces=[], pulse=["red_bottom"]), win=True)
        win2x.save(OUT / f"{style}_win_390x844@2x.png", optimize=True)
        win1x = win2x.resize((390, 844), Image.LANCZOS)
        win1x.save(OUT / f"{style}_win_390x844.png", optimize=True)
        gate, lp, tp, cb = closeups(lv, style)
        ok2, lines2 = cb.check_geometry()
        gate.save(OUT / f"{style}_gate_closeup.png", optimize=True)
        blocks = compose([(lp, "red L (3 cells)"), (tp, "blue T (4 cells)")], 20, t["page_top"], t["text"])
        blocks.save(OUT / f"{style}_blocks_closeup.png", optimize=True)
        sb = compose(storyboard(lv, style), 18, t["page_top"], t["text"])
        sb.save(OUT / f"{style}_exit_storyboard.png", optimize=True)
        report["geometry"][style] = {"ok": ok and ok2, "phone_board": lines, "closeup_board": lines2}
        report["contrast"][style] = metrics(style)
        cols[style] = dict(game=game1x, win=win1x, gate=gate, blocks=blocks, sb=sb)
        all_ok &= ok and ok2
        print(style, "geometry", "PASS" if ok and ok2 else "FAIL")
        for ln in lines:
            print("   ", ln)
    comparison_sheet(cols, report)
    (OUT / "metrics.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("all geometry checks:", "PASS" if all_ok else "FAIL")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
