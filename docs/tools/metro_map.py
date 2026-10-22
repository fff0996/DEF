#!/usr/bin/env python3
"""Drawing helpers for CLOSHA metro-style pipeline maps (SVG).

Taken from docs/ATAC-seq/pipeline/figures/make_pipeline_map.py so that other
pipelines draw their maps with the same look (docs/CLOSHA_Figure_Guide_v1.md 2).
Call reset() before each map, draw with route/node/tag/outputs/refs, then write
the file with save(path, title, legend_stages).
"""
from pathlib import Path

FONT = "Montserrat, 'DejaVu Sans', Arial, sans-serif"
LW = 15

svg = []
lines, overlay = [], []
segments = []     # straight parts of routes, for direction arrows
blocks = []       # boxes that arrows must not sit under: (x0, y0, x1, y1)


def reset():
    for x in (lines, overlay, segments, blocks):
        x.clear()


PURPLE, BLUE, GREEN, YELLOW = "#A8509C", "#1269FF", "#7CC744", "#FFB400"
ORANGE, DARK, GRAY_BG, TEXT = "#F07800", "#3D3D3D", "#EEEEEE", "#2B2B2B"
LW = 15

svg = []
lines, overlay = [], []
segments = []     # straight parts of routes, for direction arrows
blocks = []       # boxes that arrows must not sit under: (x0, y0, x1, y1)


def route(points, color, r=42, arrows=(), halo=False):
    """Orthogonal polyline with rounded corners; arrows = segment indexes."""
    d = f"M{points[0][0]},{points[0][1]}"
    for i in range(1, len(points) - 1):
        (x0, y0), (x1, y1), (x2, y2) = points[i - 1], points[i], points[i + 1]
        rr = min(r, abs(x1 - x0 + y1 - y0) / 2, abs(x2 - x1 + y2 - y1) / 2)
        sx = (x1 - x0 > 0) - (x1 - x0 < 0)
        sy = (y1 - y0 > 0) - (y1 - y0 < 0)
        tx = (x2 - x1 > 0) - (x2 - x1 < 0)
        ty = (y2 - y1 > 0) - (y2 - y1 < 0)
        d += f" L{x1 - sx * rr},{y1 - sy * rr} Q{x1},{y1} {x1 + tx * rr},{y1 + ty * rr}"
    d += f" L{points[-1][0]},{points[-1][1]}"
    if halo:   # white outline so a crossing line reads as passing over, not joining
        lines.append(f'<path d="{d}" fill="none" stroke="#fff" stroke-width="{LW + 12}" '
                     f'stroke-linecap="butt" stroke-linejoin="round"/>')
    lines.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{LW}" '
                 f'stroke-linecap="round" stroke-linejoin="round"/>')
    for i in range(len(points) - 1):
        (x0, y0), (x1, y1) = points[i], points[i + 1]
        # trim the rounded corners off both ends
        a = r if i > 0 else 0
        b = r if i < len(points) - 2 else 0
        segments.append((x0, y0, x1, y1, a, b))


def chevron(x, y, dx, dy):
    """White double arrowhead pointing along (dx, dy), drawn inside the line."""
    import math
    ang = math.degrees(math.atan2(dy, dx))
    tri = "M-5,-6 L4,0 L-5,6 Z"
    return (f'<g transform="translate({x},{y}) rotate({ang})" fill="#fff">'
            f'<path d="{tri}" transform="translate(-6,0)"/><path d="{tri}" transform="translate(5,0)"/></g>')


def place_arrows():
    """Arrows in the middle of every part of a straight segment not covered
    by a node or station."""
    out = []
    for x0, y0, x1, y1, a, b in segments:
        horiz = y0 == y1
        lo, hi = (x0, x1) if horiz else (y0, y1)
        sign = 1 if hi >= lo else -1
        start, end = lo + sign * a, hi - sign * b
        s0, s1 = sorted((start, end))
        if s1 - s0 < 50:
            continue
        cut = []
        for bx0, by0, bx1, by1 in blocks:
            if horiz and by0 <= y0 <= by1:
                cut.append((bx0, bx1))
            if not horiz and bx0 <= x0 <= bx1:
                cut.append((by0, by1))
        free, cur = [], s0
        for c0, c1 in sorted(cut):
            if c1 <= cur or c0 >= s1:
                continue
            if c0 > cur:
                free.append((cur, c0))
            cur = max(cur, c1)
        if cur < s1:
            free.append((cur, s1))
        # one arrow in every visible gap long enough to hold it
        for f0, f1 in free:
            if f1 - f0 < 42:
                continue
            n = max(1, int((f1 - f0) // 300))   # long gaps get a repeated arrow
            for k in range(n):
                m = f0 + (f1 - f0) * (k + 0.5) / n
                x, y = (m, y0) if horiz else (x0, m)
                out.append(chevron(x, y, x1 - x0, y1 - y0))
    return "".join(out)


def node(x, y, label, w=None):
    rows = label.split("\n")
    w = w or max(len(t) for t in rows) * 15.5 + 120
    h = 80
    blocks.append((x - w / 2 - 8, y - h / 2, x + w / 2 + 8, y + h / 2))
    s = (f'<rect x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="{h / 2}" fill="{DARK}"/>'
         f'<rect x="{x - w / 2 + 30}" y="{y - 12}" width="24" height="22" rx="3" fill="#6B6B6B"/>'
         f'<text x="{x - w / 2 + 34}" y="{y + 4}" font-family="monospace" font-size="11" fill="#fff">&gt;_</text>')
    ty = y + 9 - (len(rows) - 1) * 13
    for i, t in enumerate(rows):
        s += (f'<text x="{x + 18}" y="{ty + i * 26}" text-anchor="middle" font-family="{FONT}" '
              f'font-size="24" font-weight="600" fill="#fff">{t}</text>')
    overlay.append(s)
    return w


def station(x, y, color=DARK, fill="#fff"):
    blocks.append((x - 26, y - 26, x + 26, y + 26))
    overlay.append(f'<circle cx="{x}" cy="{y}" r="13" fill="{fill}" stroke="{color}" stroke-width="7"/>')


ICON_DIR = Path(__file__).resolve().parents[1] / "ATAC-seq" / "pipeline" / "figures" / "icons"   # cropped from docs/workflow_ex maps
ICON_SCALE = 1.1


def icon(name, x, y):
    """Place an icon from icons/<name>.png centered at (x, y)."""
    import base64, struct
    data = (ICON_DIR / f"{name}.png").read_bytes()
    w, h = struct.unpack(">II", data[16:24])
    w, h = w * ICON_SCALE, h * ICON_SCALE
    b64 = base64.b64encode(data).decode()
    overlay.append(f'<image x="{x - w / 2:.1f}" y="{y - h / 2:.1f}" width="{w:.1f}" height="{h:.1f}" '
                   f'href="data:image/png;base64,{b64}"/>')


def label_box(x, y, text, kind):
    """kind: 'in' (gray input format) or 'out' (orange output)."""
    rows = text.split("\n")
    w = max(len(t) for t in rows) * 12.2 + 44
    h = 22 + 25 * len(rows)
    fill, fg = (GRAY_BG, TEXT) if kind == "in" else (ORANGE, "#fff")
    s = f'<rect x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="{min(h / 2, 24)}" fill="{fill}"/>'
    for i, t in enumerate(rows):
        s += (f'<text x="{x}" y="{y + 7 - (len(rows) - 1) * 12.5 + i * 25}" text-anchor="middle" '
              f'font-family="{FONT}" font-size="19" font-weight="{500 if kind == "in" else 600}" fill="{fg}">{t}</text>')
    overlay.append(s)
    return h


def tag(cx, cy, text, kind, above=True, gap=78, icon=True):
    """Station at (cx, cy) with a dashed connector to a label box."""
    color = DARK if kind == "in" else ORANGE
    rows = text.count("\n") + 1
    h = 22 + 25 * rows
    ly = cy - gap - h / 2 if above else cy + gap + h / 2
    edge = ly + h / 2 if above else ly - h / 2
    overlay.append(f'<line x1="{cx}" y1="{cy}" x2="{cx}" y2="{edge}" stroke="{color}" stroke-width="3" '
                   f'stroke-dasharray="7,6"/>')
    label_box(cx, ly, text, kind)
    if icon:
        iy = ly - h / 2 - 40 if above else ly + h / 2 + 40
        globals()["icon"]("doc" if icon is True else icon, cx, iy)
    station(cx, cy, color if kind == "out" else DARK)


def label_width(text):
    return max(len(t) for t in text.split("\n")) * 12.2 + 44


def outputs(cx, cy, labels, above=True, gap=60, dx=0):
    """Output station with several format labels side by side, joined to the
    station by a dashed bracket (as in the BIO-EXPRESS maps)."""
    h = 47
    ws = [label_width(t) for t in labels]
    total = sum(ws) + 12 * (len(ws) - 1)
    xs, x = [], cx + dx - total / 2     # dx moves the label group sideways
    for w in ws:
        xs.append(x + w / 2)
        x += w + 12
    ly = cy - gap - h / 2 if above else cy + gap + h / 2
    edge = ly + h / 2 if above else ly - h / 2
    by = (cy + edge) / 2
    dash = f'stroke="{ORANGE}" stroke-width="3" stroke-dasharray="7,6" fill="none"'
    overlay.append(f'<path d="M{cx},{cy} V{by}" {dash}/>')
    left, right = min(xs[0], cx), max(xs[-1], cx)
    if right > left:
        overlay.append(f'<path d="M{left:.1f},{by} H{right:.1f}" {dash}/>')
    for x, t in zip(xs, labels):
        overlay.append(f'<path d="M{x:.1f},{by} V{edge}" {dash}/>')
        label_box(x, ly, t, "out")
        icon("doc", x, ly - h / 2 - 40 if above else ly + h / 2 + 40)
    station(cx, cy, ORANGE)


def refs(x, ny, items):
    """Extra inputs of a node, shown above it as 'LABEL +' (as in the examples)."""
    ws = [label_width(t) for t, _ in items]
    total = sum(ws) + 12 * (len(ws) - 1)
    lx = x - total / 2
    for (t, ic), w in zip(items, ws):
        cx = lx + w / 2
        label_box(cx, ny - 76, t, "in")
        icon(ic, cx, ny - 140)
        lx += w + 12
    overlay.append(f'<text x="{x}" y="{ny - 42}" text-anchor="middle" font-family="{FONT}" font-size="22" '
                   f'font-weight="700" fill="{TEXT}">+</text>')


def save(path, width, height, title, stages, legend_y):
    """Write the SVG: BIO-EXPRESS title, routes, arrows, overlay and legend.
    stages: [(color, text)] of the line colours."""
    t = (f'<g transform="translate(60,62)">'
         f'<rect width="88" height="52" rx="8" fill="url(#bx)"/>'
         f'<text x="44" y="38" text-anchor="middle" font-family="{FONT}" font-size="34" font-weight="800" fill="#fff">BX</text>'
         f'<text x="108" y="42" font-family="{FONT}" font-size="46" font-weight="800" fill="#3A3A3A">BIO-EXPRESS</text></g>'
         f'<text x="60" y="172" font-family="{FONT}" font-size="38" font-weight="700" fill="{TEXT}">{title}</text>')
    lg = [f'<text x="60" y="{legend_y}" font-family="{FONT}" font-size="30" font-weight="700" fill="{TEXT}">Legend</text>']
    for i, (c, s) in enumerate(stages):
        y = legend_y + 42 + i * 42
        lg.append(f'<rect x="60" y="{y - 9}" width="80" height="17" fill="{c}"/>'
                  f'<text x="158" y="{y + 7}" font-family="{FONT}" font-size="22" font-weight="500" fill="{TEXT}">{s}</text>')
    for i, (c, s) in enumerate([(DARK, "Input format"), (ORANGE, "Output format")]):
        y = legend_y + 42 + i * 42
        lg.append(f'<circle cx="560" cy="{y}" r="10" fill="#fff" stroke="{c}" stroke-width="5"/>'
                  f'<line x1="574" y1="{y}" x2="620" y2="{y}" stroke="{c}" stroke-width="3" stroke-dasharray="7,6"/>'
                  f'<text x="635" y="{y + 7}" font-family="{FONT}" font-size="22" font-weight="500" fill="{TEXT}">{s}</text>')
    doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
           f'<defs><linearGradient id="bx" x1="0" x2="1" y1="0" y2="1">'
           f'<stop offset="0" stop-color="#C13BE0"/><stop offset="0.55" stop-color="#5B5BFF"/>'
           f'<stop offset="1" stop-color="#19D3E6"/></linearGradient></defs>'
           f'<rect width="{width}" height="{height}" fill="#fff"/>' + t + "".join(lines) + place_arrows()
           + "".join(overlay) + "".join(lg) + "</svg>")
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(doc)
    print(path)
