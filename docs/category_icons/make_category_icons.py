"""Generate category icons in the line style of the Shutterstock bioinformatics set
(dark outline, no fill, rounded caps)."""
import math
import os

INK = "#2B2B2B"
W = 14  # stroke width on a 512 canvas
OUT = os.path.dirname(os.path.abspath(__file__))


def gene_regulation():
    """Epigenomics-like layout: vertical DNA, an info box and an ON switch."""
    # Same DNA as the set: one full turn, open ends flared to full width, dense rungs.
    cx, y0, y1, amp = 140, 64, 448, 62
    period = y1 - y0
    def vhelix(sign):
        pts = []
        for i in range(201):
            y = y0 + (y1 - y0) * i / 200
            x = cx + sign * amp * math.cos(2 * math.pi * (y - y0) / period)
            pts.append(f"{x:.1f},{y:.1f}")
        return "M" + " L".join(pts)
    def edge(y):
        return cx + abs(amp * math.cos(2 * math.pi * (y - y0) / period))
    rungs = []
    for i in range(14):
        y = y0 + 18 + i * (period - 36) / 13
        a = amp * math.cos(2 * math.pi * (y - y0) / period)
        if abs(a) > 18:
            k = math.copysign(6, a)
            rungs.append(f'<line x1="{cx - a + k:.1f}" y1="{y:.1f}" x2="{cx + a - k:.1f}" y2="{y:.1f}"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <!-- DNA double helix -->
  <g fill="none" stroke="{INK}" stroke-linecap="round" stroke-width="{W}">
    <g stroke-width="{W - 2}" stroke-linecap="butt">{''.join(rungs)}</g>
    <path d="{vhelix(1)}"/>
    <path d="{vhelix(-1)}"/>
  </g>
  <g fill="none" stroke="{INK}" stroke-width="{W}" stroke-linecap="round" stroke-linejoin="round">
    <!-- Regulatory information on a DNA region -->
    <path d="M{edge(88):.1f},88 H368 V124"/>
    <rect x="276" y="124" width="184" height="104" rx="16"/>
    <path d="M306,160 H430 M306,194 H396"/>
    <!-- Gene switched on -->
    <path d="M{edge(272):.1f},272 H368 V312"/>
    <rect x="276" y="312" width="184" height="96" rx="48"/>
  </g>
  <circle cx="412" cy="360" r="30" fill="{INK}"/>
</svg>
'''


if __name__ == "__main__":
    with open(os.path.join(OUT, "gene_regulation.svg"), "w") as f:
        f.write(gene_regulation())
