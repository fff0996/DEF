#!/usr/bin/env python3
"""Module summary cards (principle / input -> tool -> output / example result)
in the KOBIC portal style. Redraws the vendor cards for GTDB-Tk, Prokka, and
Prodigal with corrected content.

Run: python3 docs/Metagenome/figures/module_cards/make_module_cards.py, then for each SVG
rsvg-convert -w 2000 <name>.svg -o <name>.png
(needs the Pretendard and GmarketSans fonts).
"""
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent
W, H = 2000, 580
BODY = "Pretendard, sans-serif"
TITLE = "'Gmarket Sans TTF', 'GmarketSans', Pretendard, sans-serif"

POINT, MAIN, SUB = "#32549C", "#222222", "#3A3A3A"     # portal colors, used in rotation
ROTATE = [POINT, SUB, MAIN]
PANEL, TINT, LINE = "#F4F5F7", "#EAF0FA", "#D5DAE3"


def t(x, y, s, size=20, weight=400, color=MAIN, anchor="start", font=BODY):
    return (f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" font-weight="{weight}" '
            f'fill="{color}" text-anchor="{anchor}" dominant-baseline="middle">{escape(s)}</text>')


def arrow(x0, x1, y):
    return (f'<line x1="{x0}" y1="{y}" x2="{x1 - 14}" y2="{y}" stroke="{SUB}" stroke-width="4"/>'
            f'<path d="M{x1 - 16},{y - 10} L{x1},{y} L{x1 - 16},{y + 10} Z" fill="{SUB}"/>')


def file_chip(x, y, w, label, color):
    return (f'<rect x="{x}" y="{y - 19}" width="{w}" height="38" rx="8" fill="#fff" stroke="{color}" stroke-width="2.5"/>'
            f'<path d="M{x + 14},{y - 11} h12 l6,6 v16 h-18 Z" fill="{color}"/>'
            + t(x + 42, y + 1, label, min(17, (w - 52) / (len(label) * 0.56)), 600, color))


def card(c):
    g = [f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>']
    # header
    g.append(f'<text x="40" y="54" dominant-baseline="middle">'
             f'<tspan font-family="{TITLE}" font-size="40" font-weight="700" fill="{POINT}">{escape(c["tool"])}</tspan>'
             f'<tspan dx="22" font-family="{BODY}" font-size="28" font-weight="700" fill="{MAIN}">{escape(c["ko"])}</tspan>'
             f'<tspan dx="12" font-family="{BODY}" font-size="22" font-weight="500" fill="{SUB}">({escape(c["en"])})</tspan></text>')
    g.append(f'<line x1="40" y1="92" x2="{W - 40}" y2="92" stroke="{POINT}" stroke-width="3"/>')

    # principle panel
    g.append(f'<rect x="40" y="118" width="360" height="{H - 158}" rx="14" fill="{PANEL}"/>'
             f'<rect x="64" y="140" width="88" height="38" rx="19" fill="{POINT}"/>'
             + t(108, 160, "원리", 20, 700, "#fff", "middle"))
    for i, line in enumerate(c["principle"]):
        g.append(t(62, 214 + i * 34, line, 17.5, 500, MAIN))

    # input -> tool -> output
    cy = 330
    g.append(t(520, 150, "Input", 22, 700, SUB, "middle") + t(520, 178, c["input_label"], 17, 500, SUB, "middle"))
    n_in = len(c["inputs"])
    for i, f in enumerate(c["inputs"]):
        g.append(file_chip(418, cy - (n_in - 1) * 28 + i * 56, 205, f, ROTATE[i % 3]))
    g.append(arrow(630, 674, cy))
    eng = 30 if c.get("engine") else 0
    tool_h = 110 + 52 * len(c["steps"]) + eng
    ty = cy - tool_h / 2
    title_size = min(26, 270 / (len(c["tool"]) * 0.72))     # long module names shrink
    g.append(f'<rect x="682" y="{ty}" width="300" height="{tool_h}" rx="16" fill="#fff" stroke="{POINT}" stroke-width="3"/>'
             f'<rect x="682" y="{ty}" width="300" height="62" rx="16" fill="{POINT}"/>'
             f'<rect x="682" y="{ty + 40}" width="300" height="22" fill="{POINT}"/>'
             + t(832, ty + 32, c["tool"], title_size, 700, "#fff", "middle", TITLE))
    if eng:
        g.append(t(832, ty + 82, c["engine"], 15.5, 600, POINT, "middle"))
    for i, s in enumerate(c["steps"]):
        y = ty + 92 + eng + i * 52
        col = ROTATE[i % 3]
        g.append(f'<rect x="696" y="{y - 21}" width="272" height="42" rx="8" fill="{TINT if col == POINT else PANEL}" '
                 f'stroke="{col}" stroke-width="2"/>'
                 f'<circle cx="718" cy="{y}" r="13" fill="{col}"/>' + t(718, y + 1, str(i + 1), 15, 700, "#fff", "middle")
                 + t(740, y + 1, s, 15.5, 600, MAIN))
    if c.get("option"):
        g.append(t(832, ty + tool_h - 24, c["option"], 16, 600, POINT, "middle"))
    g.append(arrow(988, 1030, cy))
    g.append(t(1166, 150, "Output", 22, 700, SUB, "middle") + t(1166, 178, c["output_label"], 17, 500, SUB, "middle"))
    n = len(c["outputs"])
    for i, f in enumerate(c["outputs"]):
        g.append(file_chip(1036, cy - (n - 1) * 28 + i * 56, 260, f, ROTATE[i % 3]))

    # example result
    x0, y0, tw_ = 1310, 118, W - 40 - 1310
    g.append(f'<rect x="{x0}" y="{y0}" width="{tw_}" height="{H - 158}" rx="14" fill="#fff" stroke="{LINE}" stroke-width="2"/>'
             + t(x0 + 22, y0 + 34, c["result_title"], 18, 700, POINT))
    cols, widths = c["columns"], c["widths"]
    ry = y0 + 70
    xs = [x0 + 14]
    for w in widths[:-1]:
        xs.append(xs[-1] + w)
    g.append(f'<rect x="{x0 + 10}" y="{ry - 18}" width="{tw_ - 20}" height="36" fill="{POINT}"/>')
    for x, h in zip(xs, cols):
        g.append(t(x + 4, ry, h, 12.5, 700, "#fff"))
    for r, row in enumerate(c["rows"]):
        yy = ry + 40 + r * 38
        if r % 2:
            g.append(f'<rect x="{x0 + 10}" y="{yy - 19}" width="{tw_ - 20}" height="38" fill="{PANEL}"/>')
        for x, v in zip(xs, row):
            g.append(t(x + 4, yy, v, 12.5, 500, MAIN))
    for i, note in enumerate(c.get("notes", [])):
        g.append(t(x0 + 22, H - 40 - (len(c.get("notes", [])) - i) * 22, note, 12.5, 500, SUB))
    if c.get("gene_map"):
        g.append(gene_map(x0 + 22, H - 110))
    if c.get("mini"):
        top = ry + 40 + len(c["rows"]) * 38 + 6
        g.append(MINIS[c["mini"]](x0 + 30, top + 6, tw_ - 60, H - 92 - len(c.get("notes", [])) * 22 - top))
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "".join(g) + "</svg>"


def gene_map(x, y):
    """Small CDS map: forward and reverse genes only (Prodigal predicts CDS)."""
    s = [f'<line x1="{x}" y1="{y}" x2="{x + 300}" y2="{y}" stroke="{SUB}" stroke-width="2"/>']
    genes = [(0, 60, 1), (72, 125, 1), (137, 180, -1), (192, 285, 1)]
    for a, b, d in genes:
        col = POINT if d > 0 else SUB
        if d > 0:
            s.append(f'<path d="M{x + a},{y - 10} H{x + b - 12} L{x + b},{y} L{x + b - 12},{y + 10} H{x + a} Z" fill="{col}"/>')
        else:
            s.append(f'<path d="M{x + b},{y - 10} H{x + a + 12} L{x + a},{y} L{x + a + 12},{y + 10} H{x + b} Z" fill="{col}"/>')
    s.append(f'<rect x="{x + 320}" y="{y - 8}" width="22" height="16" fill="{POINT}"/>' + t(x + 348, y, "CDS (+)", 13, 600, SUB))
    s.append(f'<rect x="{x + 415}" y="{y - 8}" width="22" height="16" fill="{SUB}"/>' + t(x + 443, y, "CDS (−)", 13, 600, SUB))
    return "".join(s)


def _axes(x, y, w, h, xlab, ylab):
    return (f'<path d="M{x},{y} V{y + h} H{x + w}" fill="none" stroke="{SUB}" stroke-width="2"/>'
            + t(x + w, y + h + 16, xlab, 12, 600, SUB, "end") + t(x - 4, y - 10, ylab, 12, 600, SUB))


def mini_frag(x, y, w, h):
    """Fragment size distribution: NFR peak, then nucleosome periodicity."""
    import math
    pts = []
    for i in range(201):
        L = 30 + i * 4.5                       # 30-930 bp
        v = (1.0 * math.exp(-((L - 60) / 35) ** 2) + 0.45 * math.exp(-((L - 200) / 40) ** 2)
             + 0.16 * math.exp(-((L - 390) / 50) ** 2) + 0.06 * math.exp(-((L - 590) / 60) ** 2))
        pts.append(f"{x + i / 200 * w:.1f},{y + h - v * (h - 10):.1f}")
    s = _axes(x, y, w, h, "fragment length (bp)", "count")
    s += f'<polyline points="{" ".join(pts)}" fill="none" stroke="{POINT}" stroke-width="3"/>'
    for L, lab in [(60, "NFR"), (200, "mono"), (390, "di"), (590, "tri")]:
        s += t(x + (L - 30) / 900 * w + (34 if lab == "NFR" else 0), y + 14 if lab == "NFR" else y + h * 0.45 + (0 if lab == "mono" else h * 0.25), lab, 12, 700, MAIN, "middle")
    return s


def mini_profile(x, y, w, h):
    """Average signal around the TSS: NFR peaks at the TSS, mononucleosome flanks it."""
    import math
    def curve(f):
        return " ".join(f"{x + i / 200 * w:.1f},{y + h - f((i - 100) / 100) * (h - 12):.1f}" for i in range(201))
    nfr = lambda d: 0.08 + 0.92 * math.exp(-(d / 0.12) ** 2)
    mono = lambda d: 0.1 + 0.45 * (math.exp(-((d - 0.32) / 0.13) ** 2) + math.exp(-((d + 0.32) / 0.13) ** 2)) - 0.05 * math.exp(-(d / 0.1) ** 2)
    s = _axes(x, y, w, h, "distance to TSS", "signal")
    s += f'<line x1="{x + w / 2}" y1="{y}" x2="{x + w / 2}" y2="{y + h}" stroke="{LINE}" stroke-width="2" stroke-dasharray="6,5"/>'
    s += t(x + w / 2, y + h + 16, "TSS", 12, 700, SUB, "middle")
    s += f'<polyline points="{curve(nfr)}" fill="none" stroke="{POINT}" stroke-width="3"/>'
    s += f'<polyline points="{curve(mono)}" fill="none" stroke="{SUB}" stroke-width="3" stroke-dasharray="8,5"/>'
    s += (f'<line x1="{x + w - 150}" y1="{y + 8}" x2="{x + w - 126}" y2="{y + 8}" stroke="{POINT}" stroke-width="3"/>'
          + t(x + w - 120, y + 8, "NFR", 12, 600, SUB)
          + f'<line x1="{x + w - 150}" y1="{y + 26}" x2="{x + w - 126}" y2="{y + 26}" stroke="{SUB}" stroke-width="3" stroke-dasharray="8,5"/>'
          + t(x + w - 120, y + 26, "mononucleosome", 12, 600, SUB))
    return s


def mini_footprint(x, y, w, h):
    """Corrected Tn5 signal around a motif: dip where the factor is bound."""
    import math
    def curve(depth):
        out = []
        for i in range(201):
            d = (i - 100) / 100
            v = 0.25 + 0.7 * math.exp(-(d / 0.55) ** 2) - depth * math.exp(-(d / 0.09) ** 2)
            out.append(f"{x + i / 200 * w:.1f},{y + h - v * (h - 12):.1f}")
        return " ".join(out)
    s = _axes(x, y, w, h, "position around motif", "Tn5 signal")
    s += f'<rect x="{x + w * 0.455}" y="{y}" width="{w * 0.09}" height="{h}" fill="{TINT}"/>'
    s += t(x + w / 2, y + h + 16, "motif", 12, 700, POINT, "middle")
    s += f'<polyline points="{curve(0.15)}" fill="none" stroke="{SUB}" stroke-width="3" stroke-dasharray="8,5"/>'
    s += f'<polyline points="{curve(0.55)}" fill="none" stroke="{POINT}" stroke-width="3"/>'
    s += (f'<line x1="{x + w - 170}" y1="{y + 8}" x2="{x + w - 146}" y2="{y + 8}" stroke="{POINT}" stroke-width="3"/>'
          + t(x + w - 140, y + 8, "treated (bound)", 12, 600, SUB)
          + f'<line x1="{x + w - 170}" y1="{y + 26}" x2="{x + w - 146}" y2="{y + 26}" stroke="{SUB}" stroke-width="3" stroke-dasharray="8,5"/>'
          + t(x + w - 140, y + 26, "control", 12, 600, SUB))
    return s


MINIS = {"frag": mini_frag, "profile": mini_profile, "footprint": mini_footprint}


CARDS = {
    "GTDB-Tk": dict(
        tool="GTDB-Tk", ko="계통학적 분류", en="Taxonomic classification",
        principle=["MAG에서 보존된 단일 사본 마커 유전자",
                   "(세균 120개, 고세균 53개)를 찾아 정렬하고",
                   "GTDB 참조 계통수에 배치(pplacer)합니다.",
                   "계통수상 위치와 참조 유전체와의 ANI를",
                   "함께 이용해 도메인부터 종까지",
                   "MAG의 분류를 결정합니다."],
        input_label="(MAGs, .fna)", inputs=["MAG_1.fna", "MAG_2.fna", "MAG_3.fna"],
        steps=["Marker gene identification", "Multiple sequence alignment",
               "Phylogenetic placement", "Taxonomic classification"],
        output_label="(classification table)",
        outputs=["gtdbtk.bac120.summary.tsv", "gtdbtk.ar53.summary.tsv"],
        result_title="결과 예시 (gtdbtk.bac120.summary.tsv)",
        columns=["user_genome", "classification", "closest_genome_reference", "ANI", "AF"],
        widths=[90, 230, 200, 55, 47],
        rows=[["MAG_1", "d__Bacteria;p__Bacillota;…", "GCF_000009045.1", "98.7", "0.91"],
              ["MAG_2", "d__Bacteria;p__Pseudomonadota;…", "GCF_000005845.2", "99.1", "0.88"],
              ["MAG_3", "d__Bacteria;p__Bacteroidota;…", "N/A", "N/A", "N/A"]],
        notes=["classification: d__도메인; p__문; c__강; o__목; f__과; g__속; s__종",
               "ANI·AF: 가장 가까운 참조 유전체와의 값(closest_genome_ani/af)", "값은 형식 설명용 예시"],
    ),
    "Prokka": dict(
        tool="Prokka", ko="유전체 주석", en="Genome annotation",
        principle=["Prodigal(단백질 암호화 유전자),",
                   "Aragorn(tRNA), Barrnap(rRNA) 등으로",
                   "MAG의 유전자 위치를 찾고, 단백질",
                   "데이터베이스 검색으로 유전자명, EC 번호,",
                   "COG, 기능 설명(product)을 붙여",
                   "표준 형식(GFF, GenBank)으로 저장합니다."],
        input_label="(MAG, .fna)", inputs=["MAG_1.fna"],
        steps=["CDS·tRNA·rRNA prediction", "Functional annotation", "Output formatting"],
        output_label="(annotation files)", outputs=[".gff", ".gbk", ".faa", ".ffn", ".tsv"],
        result_title="결과 예시 (PROKKA.tsv)",
        columns=["locus_tag", "ftype", "length_bp", "gene", "EC_number", "COG", "product"],
        widths=[92, 46, 72, 46, 84, 72, 210],
        rows=[["MAG1_00001", "CDS", "1356", "dnaA", "", "COG0593", "Replication initiator DnaA"],
              ["MAG1_00002", "CDS", "1101", "dnaN", "2.7.7.7", "COG0592", "DNA polymerase III beta"],
              ["MAG1_00031", "tRNA", "76", "", "", "", "tRNA-Leu(cag)"],
              ["MAG1_00042", "rRNA", "1537", "", "", "", "16S ribosomal RNA"]],
        notes=["ftype: CDS(단백질 암호화 유전자), tRNA, rRNA 등 유전자 종류", "값은 형식 설명용 예시"],
    ),
    "Prodigal": dict(
        tool="Prodigal", ko="유전자 예측", en="Gene prediction",
        principle=["원핵생물 유전체에서 시작·종결 코돈,",
                   "리보솜 결합 부위(RBS), GC 편향을 이용해",
                   "단백질 암호화 유전자(CDS)를 예측합니다.",
                   "여러 생물이 섞이거나 짧은 서열(MAG)은",
                   "메타게놈 모드(-p meta)로 분석합니다.",
                   "tRNA·rRNA는 예측하지 않습니다."],
        input_label="(MAG, .fna)", inputs=["MAG_1.fna"],
        steps=["Coding potential scoring", "Start codon and RBS selection", "Gene calling"],
        option="mode: -p meta",
        output_label="(gene prediction files)", outputs=[".gff (gene coordinates)", ".faa (proteins)", ".fna (genes)"],
        result_title="결과 예시 (GFF, 유전자 위치 정보)",
        columns=["seqid", "source", "type", "start", "end", "strand", "attributes"],
        widths=[70, 112, 42, 52, 52, 52, 242],
        rows=[["contig_1", "Prodigal_v2.6.3", "CDS", "3", "1205", "+", "ID=1_1;partial=10;start_type=Edge"],
              ["contig_1", "Prodigal_v2.6.3", "CDS", "1290", "2045", "−", "ID=1_2;partial=00;start_type=ATG"],
              ["contig_1", "Prodigal_v2.6.3", "CDS", "2101", "3330", "+", "ID=1_3;partial=00;start_type=GTG"]],
        notes=["값은 형식 설명용 예시"],
        gene_map=True,
    ),
}


if __name__ == "__main__":
    for name, c in CARDS.items():
        p = OUT / f"{name}_card.svg"
        p.write_text(card(c))
        print(p)
