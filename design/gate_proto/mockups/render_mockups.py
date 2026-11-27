"""Positioned-gate proposal: board mockups for the three prototype levels in three visual
directions. Design artwork only (Pillow), not game code. Reads ../levels/*.json.

Usage: python render_mockups.py            (writes all PNGs next to this script)
       python render_mockups.py compare    (only art_direction_comparison.png)
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

HERE = Path(__file__).resolve().parent
LEVELS = HERE.parent / "levels"
SS = 3  # supersampling factor

PIECE = {
    "red": (238, 82, 92), "blue": (58, 156, 240), "green": (96, 196, 92),
    "yellow": (255, 196, 52), "orange": (255, 142, 60), "purple": (156, 104, 230),
}

STYLES = {
    "pearl": {
        "title": "1  Carved Pearl (recommended)",
        "page": (255, 246, 236), "frame": (232, 222, 210), "frame_hi": (252, 247, 240), "frame_lo": (196, 182, 166),
        "well": (64, 78, 110), "cell": (78, 93, 128), "cell_hi": (92, 108, 146),
        "hole": (24, 30, 46), "text": (40, 52, 80), "sub": (120, 110, 100), "gloss": 0.55, "radius": 0.22,
    },
    "glass": {
        "title": "2  Midnight Glass",
        "page": (16, 20, 36), "frame": (34, 42, 70), "frame_hi": (66, 80, 124), "frame_lo": (14, 17, 30),
        "well": (22, 28, 50), "cell": (30, 38, 66), "cell_hi": (40, 50, 84),
        "hole": (4, 5, 10), "text": (226, 232, 255), "sub": (150, 160, 200), "gloss": 0.8, "radius": 0.18, "glow": True,
    },
    "wood": {
        "title": "3  Toy Workshop",
        "page": (244, 236, 222), "frame": (196, 138, 84), "frame_hi": (226, 176, 120), "frame_lo": (142, 92, 50),
        "well": (236, 214, 176), "cell": (226, 200, 158), "cell_hi": (240, 220, 186),
        "hole": (70, 44, 24), "text": (80, 52, 30), "sub": (130, 100, 70), "gloss": 0.25, "radius": 0.12, "matte": True,
    },
}


def font(size, bold=False):
    names = ("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")
    for n in names + ("DejaVuSans.ttf",):
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            continue
    return ImageFont.load_default()


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def load(name):
    return json.loads((LEVELS / name).read_text(encoding="utf-8"))


class Board:
    def __init__(self, level, cell, style, origin=(0, 0), pulse=()):
        self.lv, self.s, self.st = level, cell, STYLES[style]
        self.pulse, self.holes = set(pulse), []
        self.cols, self.rows = level["board"]["cols"], level["board"]["rows"]
        self.frame = int(cell * 0.42)
        self.ox, self.oy = origin[0] + self.frame, origin[1] + self.frame
        self.w = self.cols * cell + self.frame * 2
        self.h = self.rows * cell + self.frame * 2

    def cell_rect(self, x, y, inset=0):
        s = self.s
        return (self.ox + x * s + inset, self.oy + y * s + inset, self.ox + (x + 1) * s - inset, self.oy + (y + 1) * s - inset)

    def gate_rect(self, g):
        s, f = self.s, self.frame
        lo, hi = g["lo"], g["hi"]
        if g["side"] == "left":
            return (self.ox - f, self.oy + lo * s, self.ox, self.oy + (hi + 1) * s)
        if g["side"] == "right":
            x = self.ox + self.cols * s
            return (x, self.oy + lo * s, x + f, self.oy + (hi + 1) * s)
        if g["side"] == "top":
            return (self.ox + lo * s, self.oy - f, self.ox + (hi + 1) * s, self.oy)
        y = self.oy + self.rows * s
        return (self.ox + lo * s, y, self.ox + (hi + 1) * s, y + f)

    def draw(self, img, pieces_override=None, exiting=None):
        st, s, f = self.st, self.s, self.frame
        x0, y0 = self.ox - f, self.oy - f
        size = img.size
        # Drop shadow of the whole board.
        sh = Image.new("L", size, 0)
        ImageDraw.Draw(sh).rounded_rectangle((x0, y0 + s * 0.12, x0 + self.w, y0 + self.h + s * 0.12), radius=int(f * 1.2), fill=120)
        img.paste((0, 0, 0), mask=sh.filter(ImageFilter.GaussianBlur(s * 0.18)))
        d = ImageDraw.Draw(img)
        # Solid frame with a top highlight and bottom shade (bevel).
        d.rounded_rectangle((x0, y0, x0 + self.w, y0 + self.h), radius=int(f * 1.2), fill=st["frame_lo"])
        d.rounded_rectangle((x0, y0, x0 + self.w, y0 + self.h - f * 0.18), radius=int(f * 1.2), fill=st["frame_hi"])
        d.rounded_rectangle((x0 + f * 0.1, y0 + f * 0.12, x0 + self.w - f * 0.1, y0 + self.h - f * 0.22), radius=int(f * 1.05), fill=st["frame"])
        if st.get("matte"):  # wood grain
            for i in range(0, self.h, max(2, int(s * 0.09))):
                d.line((x0 + f * 0.2, y0 + i, x0 + self.w - f * 0.2, y0 + i + s * 0.05), fill=mix(st["frame"], st["frame_lo"], 0.18), width=max(1, SS))
            d.rounded_rectangle((x0 + f * 0.1, y0 + f * 0.12, x0 + self.w - f * 0.1, y0 + self.h - f * 0.22), radius=int(f * 1.05), outline=st["frame_lo"], width=SS)
        # Recessed play well with an inner shadow along its top / left edges.
        well = (self.ox - 2, self.oy - 2, self.ox + self.cols * s + 2, self.oy + self.rows * s + 2)
        d.rounded_rectangle(well, radius=int(s * 0.16), fill=st["well"])
        inner = Image.new("L", size, 0)
        ImageDraw.Draw(inner).rounded_rectangle(well, radius=int(s * 0.16), fill=255)
        cut = ImageChops.offset(inner, int(s * 0.06), int(s * 0.08))
        edge = ImageChops.subtract(inner, cut).filter(ImageFilter.GaussianBlur(s * 0.05))
        img.paste((0, 0, 0), mask=edge.point(lambda v: int(v * 0.45)))
        for y in range(self.rows):
            for x in range(self.cols):
                r = self.cell_rect(x, y, s * 0.06)
                d.rounded_rectangle(r, radius=int(s * 0.14), fill=st["cell_hi"])
                d.rounded_rectangle((r[0], r[1] + (r[3] - r[1]) * 0.18, r[2], r[3]), radius=int(s * 0.14), fill=st["cell"])
        self.holes = [self.draw_gate(img, g, pulse=g["id"] in self.pulse) for g in self.lv["gates"]]
        pieces = pieces_override if pieces_override is not None else self.lv["pieces"]
        for p in pieces:
            self.draw_piece(img, p)
        if exiting:
            # The exiting block is visible only inside the well and the openings: it passes
            # under the frame lip.
            clip = Image.new("L", img.size, 0)
            cd = ImageDraw.Draw(clip)
            cd.rectangle(well, fill=255)
            for h in self.holes:
                cd.rounded_rectangle(h, radius=int(s * 0.1), fill=255)
            self.draw_piece(img, exiting[0], offset=exiting[1], trail=exiting[2], clip=clip)

    def draw_gate(self, img, g, pulse=False):
        st, s, f = self.st, self.s, self.frame
        col = PIECE[g["accept"][0]]
        d = ImageDraw.Draw(img)
        side = g["side"]
        hx0, hy0, hx1, hy1 = self.gate_rect(g)
        pad = s * 0.04
        # Cut right through the frame (rim included) over exactly lo..hi, inset a hair at each
        # end so the posts sit on the cell lines.
        if side == "left":
            hole = (hx0 - f * 0.2, hy0 + pad, hx1 + 2, hy1 - pad)
        elif side == "right":
            hole = (hx0 - 2, hy0 + pad, hx1 + f * 0.2, hy1 - pad)
        elif side == "top":
            hole = (hx0 + pad, hy0 - f * 0.2, hx1 - pad, hy1 + 2)
        else:
            hole = (hx0 + pad, hy0 - 2, hx1 - pad, hy1 + f * 0.2)
        if pulse:
            halo = Image.new("L", img.size, 0)
            ImageDraw.Draw(halo).rounded_rectangle(hole, radius=int(s * 0.1), fill=255)
            img.paste(col, mask=halo.filter(ImageFilter.GaussianBlur(s * 0.3)).point(lambda v: min(255, int(v * 1.6))))
        d.rounded_rectangle(hole, radius=int(s * 0.1), fill=mix(st["hole"], col, 0.22))
        # Depth: lighter floor toward the outside, so the recess reads as a tunnel.
        shade = Image.new("L", img.size, 0)
        sd = ImageDraw.Draw(shade)
        steps = 8
        for i in range(steps):
            t = i / steps
            if side == "left":
                box = (hole[0], hole[1], hole[0] + (hole[2] - hole[0]) * (1 - t), hole[3])
            elif side == "right":
                box = (hole[0] + (hole[2] - hole[0]) * t, hole[1], hole[2], hole[3])
            elif side == "top":
                box = (hole[0], hole[1], hole[2], hole[1] + (hole[3] - hole[1]) * (1 - t))
            else:
                box = (hole[0], hole[1] + (hole[3] - hole[1]) * t, hole[2], hole[3])
            sd.rectangle(box, fill=int(14 * (i + 1)))
        hm = Image.new("L", img.size, 0)
        ImageDraw.Draw(hm).rounded_rectangle(hole, radius=int(s * 0.1), fill=255)
        img.paste(mix(st["hole"], col, 0.75), mask=ImageChops.multiply(shade, hm))
        # Coloured threshold strip on the board edge of the opening.
        glow = Image.new("L", img.size, 0)
        gd = ImageDraw.Draw(glow)
        t = f * 0.22
        if side == "left":
            gd.rounded_rectangle((hx1 - t, hole[1] + s * 0.05, hx1 + 1, hole[3] - s * 0.05), radius=int(t / 2), fill=255)
        elif side == "right":
            gd.rounded_rectangle((hx0 - 1, hole[1] + s * 0.05, hx0 + t, hole[3] - s * 0.05), radius=int(t / 2), fill=255)
        elif side == "top":
            gd.rounded_rectangle((hole[0] + s * 0.05, hy1 - t, hole[2] - s * 0.05, hy1 + 1), radius=int(t / 2), fill=255)
        else:
            gd.rounded_rectangle((hole[0] + s * 0.05, hy0 - 1, hole[2] - s * 0.05, hy0 + t), radius=int(t / 2), fill=255)
        if st.get("glow"):
            img.paste(col, mask=glow.filter(ImageFilter.GaussianBlur(s * 0.25)).point(lambda v: min(255, int(v * 1.4))))
        img.paste(col, mask=glow)
        # Posts: bevelled jambs at both ends of the opening, on the cell lines.
        jamb = max(2, int(f * 0.2))
        post = mix(st["frame_hi"], (255, 255, 255), 0.25)
        if side in ("left", "right"):
            for yy in (hole[1], hole[3]):
                d.rounded_rectangle((hole[0], yy - jamb / 2, hole[2], yy + jamb / 2), radius=jamb // 2, fill=post)
        else:
            for xx in (hole[0], hole[2]):
                d.rounded_rectangle((xx - jamb / 2, hole[1], xx + jamb / 2, hole[3]), radius=jamb // 2, fill=post)
        # One chevron per opening in the tunnel, pointing out, in the gate colour.
        cx, cy = (hole[0] + hole[2]) / 2, (hole[1] + hole[3]) / 2
        k = f * 0.26
        if side == "left":
            ax = hole[0] + (hole[2] - hole[0]) * 0.45
            pts = [(ax - k, cy), (ax + k * 0.7, cy - k), (ax + k * 0.7, cy + k)]
        elif side == "right":
            ax = hole[0] + (hole[2] - hole[0]) * 0.55
            pts = [(ax + k, cy), (ax - k * 0.7, cy - k), (ax - k * 0.7, cy + k)]
        elif side == "top":
            ay = hole[1] + (hole[3] - hole[1]) * 0.45
            pts = [(cx, ay - k), (cx - k, ay + k * 0.7), (cx + k, ay + k * 0.7)]
        else:
            ay = hole[1] + (hole[3] - hole[1]) * 0.55
            pts = [(cx, ay + k), (cx - k, ay - k * 0.7), (cx + k, ay - k * 0.7)]
        d.polygon(pts, fill=mix(col, (255, 255, 255), 0.55))
        return hole

    def draw_piece(self, img, p, offset=(0, 0), trail=False, clip=None):
        st, s = self.st, self.s
        col = PIECE[p["color"]]
        px, py = p["pos"]
        g = s * 0.07
        rects = []
        cells = {(c[0], c[1]) for c in p["cells"]}
        for (cx, cy) in cells:
            # Inset only on sides with no neighbour, so joins are seamless (no waist).
            r = self.cell_rect(px + cx, py + cy)
            r = (r[0] + (0 if (cx - 1, cy) in cells else g) + offset[0], r[1] + (0 if (cx, cy - 1) in cells else g) + offset[1],
                 r[2] - (0 if (cx + 1, cy) in cells else g) + offset[0], r[3] - (0 if (cx, cy + 1) in cells else g) + offset[1])
            rects.append(r)
        mask = Image.new("L", img.size, 0)
        md = ImageDraw.Draw(mask)
        for r in rects:
            md.rectangle(r, fill=255)
        rad = s * st["radius"]
        mask = mask.filter(ImageFilter.GaussianBlur(rad * 0.6)).point(lambda v: 255 if v > 128 else 0)
        if clip is not None:
            mask = ImageChops.multiply(mask, clip)
        if trail:
            for i, a in enumerate((0.1, 0.18, 0.28)):
                f = 0.25 * (3 - i)
                tm = ImageChops.offset(mask, int(-offset[0] * f), int(-offset[1] * f))
                img.paste(col, mask=tm.point(lambda v, a=a: int(v * a)))
        # Contact shadow, then the block's side (darker band = thickness), top face and gloss.
        shadow = ImageChops.offset(mask, int(s * 0.04), int(s * 0.1)).filter(ImageFilter.GaussianBlur(s * 0.08))
        img.paste((0, 0, 0), mask=shadow.point(lambda v: int(v * 0.35)))
        img.paste(mix(col, (0, 0, 0), 0.3), mask=mask)
        top = ImageChops.multiply(ImageChops.offset(mask, 0, -int(s * 0.08)), mask)
        img.paste(col, mask=top)
        if st.get("matte"):
            inner = top.filter(ImageFilter.MinFilter(int(s * 0.12) | 1))
            img.paste(mix(col, (255, 255, 255), 0.12), mask=inner)
            return
        # Gloss along every upward-facing edge (works for any shape), plus a soft top-left sheen.
        inner = top.filter(ImageFilter.MinFilter(int(s * 0.1) | 1))
        lip = ImageChops.subtract(inner, ImageChops.offset(inner, 0, int(s * 0.2))).filter(ImageFilter.GaussianBlur(s * 0.05))
        img.paste((255, 255, 255), mask=lip.point(lambda v: int(v * st["gloss"] * 0.75)))
        sheen = ImageChops.subtract(inner, ImageChops.offset(inner, int(s * 0.35), int(s * 0.35))).filter(ImageFilter.GaussianBlur(s * 0.12))
        img.paste((255, 255, 255), mask=sheen.point(lambda v: int(v * st["gloss"] * 0.18)))
        rim = ImageChops.subtract(top, top.filter(ImageFilter.MinFilter(max(3, int(s * 0.03)) | 1)))
        img.paste(mix(col, (255, 255, 255), 0.5), mask=rim.point(lambda v: int(v * 0.6)))


def render_board(level, style, cell=90, margin=40, exiting=None, pieces=None, pulse=()):
    cell = int(cell * SS)
    margin = int(margin * SS)
    b = Board(level, cell, style, (margin, margin), pulse)
    img = Image.new("RGB", (b.w + margin * 2, b.h + margin * 2), STYLES[style]["page"])
    b.draw(img, pieces, exiting)
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS)


def phone(level, style, moves_text):
    """Mobile composition at 390x844 points, drawn at 2x: HUD, board, bottom actions."""
    W, H = 390 * 2, 844 * 2
    st = STYLES[style]
    img = Image.new("RGB", (W, H), st["page"])
    d = ImageDraw.Draw(img)
    on_frame = st["text"] if style != "wood" else (255, 248, 236)
    board = render_board(level, style, cell=(W - 2 * 30) / (level["board"]["cols"] + 0.84 + 0.25), margin=12)
    d.text((W / 2, 150), level["name"], fill=st["text"], font=font(44, True), anchor="mm")
    d.text((W / 2, 205), moves_text, fill=st["sub"], font=font(30), anchor="mm")
    for x, label in ((80, "II"), (W - 80, "?")):
        d.rounded_rectangle((x - 46, 128, x + 46, 220), radius=28, fill=st["frame"])
        d.text((x, 174), label, fill=on_frame, font=font(34, True), anchor="mm")
    img.paste(board, ((W - board.width) // 2, int(H * 0.5 - board.height / 2)))
    for x, label in ((W / 2 - 150, "Undo"), (W / 2 + 150, "Restart")):
        d.rounded_rectangle((x - 130, H - 250, x + 130, H - 150), radius=40, fill=st["frame"])
        d.text((x, H - 200), label, fill=on_frame, font=font(34, True), anchor="mm")
    return img.resize((W // 2, H // 2), Image.LANCZOS)


def sheet(tiles, title, subtitle, out, page=(255, 246, 236), cap=(40, 52, 80)):
    pad, head = 36, 150
    w = sum(t.width for t, _ in tiles) + pad * (len(tiles) + 1)
    h = max(t.height for t, _ in tiles) + head + 70
    img = Image.new("RGB", (w, h), page)
    d = ImageDraw.Draw(img)
    d.text((pad, 30), title, fill=cap, font=font(40, True))
    d.text((pad, 88), subtitle, fill=cap, font=font(24))
    x = pad
    for t, label in tiles:
        d.text((x, head - 6), label, fill=cap, font=font(26, True))
        img.paste(t, (x, head + 34))
        x += t.width + pad
    img.save(out, optimize=True)
    print(out.name, img.size)


def comparison(level, out):
    """One row per direction, same level, same cell size (84 pt) for every board and crop.
    Columns: full board, door close-up x2, block close-up x2, phone screen."""
    cell, margin = 84, 40
    f = int(cell * SS * 0.42) / SS
    o = margin + f  # board origin in output pixels
    door = (int(o - f - 6), int(o + cell * 1.6), int(o + cell * 1.4), int(o + cell * 4.4))   # blue left door
    block = (int(o + cell * 0.8), int(o + cell * 3.8), int(o + cell * 6) + 6, int(o + cell * 6) + int(f) + 8)  # T, I3, red door
    rows = []
    for s in ("pearl", "glass", "wood"):
        board = render_board(level, s, cell=cell, margin=margin)
        d = board.crop(door)
        b = board.crop(block)
        rows.append((STYLES[s]["title"], [board, d.resize((d.width * 2, d.height * 2), Image.LANCZOS),
                                          b.resize((b.width * 2, b.height * 2), Image.LANCZOS), phone(level, s, "Moves 0  /  Par 9")]))
    pad, head, cap_h = 30, 190, 46
    heads = ["Board (84 pt cells)", "Door close-up x2", "Blocks + door x2", "Phone 390x844 pt"]
    col_w = [max(r[1][i].width for r in rows) for i in range(4)]
    row_h = [max(t.height for t in r[1]) for r in rows]
    W = sum(col_w) + pad * 5
    H = head + sum(h + cap_h + pad for h in row_h) + pad
    img = Image.new("RGB", (W, H), (255, 246, 236))
    d = ImageDraw.Draw(img)
    cap = (40, 52, 80)
    d.text((pad, 24), "Art directions side by side - Level C, same scale", fill=cap, font=font(40, True))
    d.text((pad, 80), "Every board and crop is the same level at the same cell size; close-ups are 2x crops of that board.", fill=cap, font=font(24))
    y = head
    for (title, tiles), h in zip(rows, row_h):
        d.text((pad, y), title, fill=cap, font=font(28, True))
        x = pad
        for i, t in enumerate(tiles):
            img.paste(t, (x, y + cap_h))
            x += col_w[i] + pad
        y += h + cap_h + pad
    x = pad
    for i, label in enumerate(heads):
        d.text((x, 130), label, fill=cap, font=font(24, True))
        x += col_w[i] + pad
    img.save(out, optimize=True)
    print(out.name, img.size)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "compare":
        comparison(load("proto_c.json"), HERE / "art_direction_comparison.png")
        return
    a, b, c = load("proto_a.json"), load("proto_b.json"), load("proto_c.json")
    sheet([(render_board(lv, "pearl", cell=80), f"Level {tag}  {lv['name']}  (par {lv['authored_metrics']['par']})")
           for lv, tag in ((a, "A"), (b, "B"), (c, "C"))],
          "Prototype levels - board mockups (Carved Pearl)",
          "Start positions. One opening per gate, exactly over its lo..hi cells; frame solid everywhere else.",
          HERE / "levels_board_mockups.png")
    for lv, tag in ((a, "a"), (b, "b"), (c, "c")):
        render_board(lv, "pearl").save(HERE / f"level_{tag}_board.png", optimize=True)
    sheet([(render_board(c, s, cell=84), STYLES[s]["title"]) for s in ("pearl", "glass", "wood")],
          "Visual directions - Level C 'Turn the Corner'",
          "Same level, same gate data. Recessed openings cut only where a gate is; solid frame elsewhere.",
          HERE / "visual_directions.png")
    sheet([(phone(c, s, "Moves 0  /  Par 9"), STYLES[s]["title"]) for s in ("pearl", "glass", "wood")],
          "Mobile composition (390x844 pt)", "HUD on top, board centred in the thumb-safe middle, two large actions at the bottom.",
          HERE / "mobile_composition.png")
    red = a["pieces"][0]
    aligned = dict(red, pos=[1, 2])
    s = 90
    frames = [
        (render_board(a, "pearl", cell=s), "1  start"),
        (render_board(a, "pearl", cell=s, pieces=[aligned]), "2  lined up with the door"),
        (render_board(a, "pearl", cell=s, pieces=[], exiting=(dict(aligned, pos=[4, 2]), (int(s * SS * 0.3), 0), True)), "3  entering the recess"),
        (render_board(a, "pearl", cell=s, pieces=[], pulse=["red_right"]), "4  cleared: door pulses"),
    ]
    sheet(frames, "Exit animation storyboard - Level A", "Slide to the frame, pass through the recess under the frame lip, short colour pulse on the door.", HERE / "exit_storyboard.png")


if __name__ == "__main__":
    main()
