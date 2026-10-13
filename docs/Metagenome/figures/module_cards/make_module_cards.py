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


SYN = "합성 시험 데이터로 실제 실행한 결과"
EX = "값은 형식 설명용 예시"

ATAC_CARDS = {
    "organellar_filter": dict(
        tool="organellar_filter", ko="세포소기관 read 제거", en="Organellar read removal", engine="samtools",
        principle=["ATAC-seq에서는 Tn5가 뉴클레오솜이 없는",
                   "미토콘드리아·엽록체 DNA를 많이 잘라",
                   "세포소기관 read 비율이 높게 나옵니다.",
                   "염색체 이름 규칙(organellar_pattern)으로",
                   "세포소기관 contig를 찾고, 그 read를",
                   "뺀 BAM을 만듭니다."],
        input_label="(sorted BAM)", inputs=["ctrl_1.bam", "trt_1.bam"],
        steps=["Contig listing (idxstats)", "Organellar contig matching", "Read filtering", "Index and flagstat"],
        output_label="(filtered BAM)", outputs=["03_filtered_bam/*.bam", "idxstats · flagstat", "organellar_filter_summary.tsv"],
        result_title="결과 예시 (idxstats, 필터 전)",
        columns=["contig", "length", "mapped", "unmapped", "filter"],
        widths=[110, 150, 150, 110, 102],
        rows=[["1", "30427671", "8210433", "0", "keep"], ["2", "19698289", "5102877", "0", "keep"],
              ["Mt", "366924", "3904112", "0", "remove"], ["Pt", "154478", "6881045", "0", "remove"]],
        notes=["Mt, Pt: organellar_pattern에 해당하는 세포소기관 contig", EX],
    ),
    "ATAC_QC": dict(
        tool="ATAC_QC", ko="품질 평가와 Tn5 보정", en="ATAC-seq QC and Tn5 shift", engine="ATACseqQC",
        principle=["Fragment 길이 분포에서 뉴클레오솜",
                   "주기(약 200 bp)를 확인하고, 중복·저품질",
                   "read를 거른 뒤 Tn5 삽입 위치를 보정",
                   "(+4/−5 bp)합니다. fragment를 NFR과",
                   "뉴클레오솜 종류로 나누고, TSS",
                   "enrichment 점수와 bigWig를 만듭니다."],
        input_label="(BAM, 샘플 정보, 참조)", inputs=["filtered BAM", "sample_data.csv", "txs.bed", "genome.fa"],
        steps=["Fragment size distribution", "bamQC (clean BAM)", "Tn5 shift (+4/−5 bp)", "Nucleosome split",
               "TSS enrichment · bigWig"],
        output_label="(QC and shifted BAM)",
        outputs=["03_shifted_bam", "04_split_bam", "07_tss_enrichment", "08_bigwig (bw)", "atac_qc_metrics.tsv"],
        result_title="결과 예시 (atac_qc_metrics.tsv)",
        columns=["SampleID", "CleanMappedReads", "ShiftedReads", "TSSEnrichment", "SplitStatus"],
        widths=[100, 160, 130, 130, 102],
        rows=[["ctrl_1", "500000", "500000", "22.407", "done"], ["ctrl_2", "500000", "500000", "21.891", "done"],
              ["trt_1", "500000", "500000", "21.758", "done"], ["trt_2", "500000", "500000", "21.976", "done"]],
        mini="frag",
        notes=["그림: fragment 길이 분포의 뉴클레오솜 주기(개념도)", SYN],
    ),
    "ATAC_QC_plot": dict(
        tool="ATAC_QC_plot", ko="TSS 주변 신호 시각화", en="TSS signal visualization", engine="ATACseqQC",
        principle=["NFR fragment는 TSS 바로 위에,",
                   "mononucleosome fragment는 TSS 양옆에",
                   "모이는 것이 정상적인 ATAC-seq 신호",
                   "입니다. fragment 종류별 TSS 주변",
                   "신호를 heatmap과 평균 profile로 그려",
                   "데이터 품질을 확인합니다."],
        input_label="(ATAC_QC 결과, TSS)", inputs=["ATAC_QC output_dir", "tss.bed"],
        steps=["Load split BAMs", "TSS-centered signal matrix", "Heatmap and profile"],
        output_label="(plots)", outputs=["01_tss_signal (pdf, tsv)", "02_signal_matrices (rds)", "03_summary"],
        result_title="결과 예시 (<sample>.plot_summary.tsv)",
        columns=["SampleID", "Status", "UsedClasses", "DroppedClasses"],
        widths=[80, 70, 340, 132],
        rows=[["ctrl_1", "done", "NucleosomeFree,mononucleosome,dinucleosome", "trinucleosome"],
              ["trt_1", "done", "NucleosomeFree,mononucleosome,dinucleosome", "trinucleosome"]],
        mini="profile",
        notes=["그림: TSS 주변 평균 신호의 모양(개념도)", EX],
    ),
    "MACS3_callpeak_ATAC": dict(
        tool="MACS3_callpeak_ATAC", ko="Peak 검출", en="Peak calling", engine="MACS3 callpeak (BAMPE)",
        principle=["Tn5 보정 BAM에서 paired-end fragment가",
                   "주변 배경보다 유의하게 많이 쌓인",
                   "위치를 열린 염색질 peak로 검출합니다.",
                   "peak 안에 들어간 read 비율(FRiP)로",
                   "신호 대 잡음을 평가합니다."],
        input_label="(ATAC_QC 03_shifted_bam)", inputs=["ctrl_1.shifted.bam", "trt_1.shifted.bam"],
        steps=["Fragment pileup (BAMPE)", "Local background (λ)", "Peak calling (q < 0.05)", "FRiP (samtools)"],
        output_label="(peaks)", outputs=["*_peaks.narrowPeak", "*_summits.bed", "*_peaks.xls", "frip_summary.tsv"],
        result_title="결과 예시 (frip_summary.tsv)",
        columns=["SampleID", "peaks", "total_reads", "reads_in_peaks", "FRiP"],
        widths=[110, 90, 150, 170, 102],
        rows=[["ctrl_1", "903", "500000", "369670", "0.7393"], ["ctrl_2", "908", "500000", "369543", "0.7391"],
              ["trt_1", "901", "500000", "366825", "0.7337"], ["trt_2", "905", "500000", "367750", "0.7355"]],
        notes=["FRiP: ENCODE 기준 0.3 초과 양호, 0.2 초과 허용", SYN],
    ),
    "peak_annotation": dict(
        tool="peak_annotation", ko="Peak 유전체 주석", en="Peak annotation", engine="ChIPseeker",
        principle=["peak가 유전자 구조의 어디에 있는지",
                   "(promoter, exon, intron, intergenic 등)",
                   "분류하고, 가장 가까운 유전자와 TSS",
                   "까지의 거리를 붙입니다. GFF/GTF로",
                   "TxDb를 만들어 다양한 종에 적용합니다."],
        input_label="(peaks, 유전자 주석)", inputs=["*_peaks.narrowPeak", "genes.gff3"],
        steps=["TxDb from GFF/GTF", "Feature annotation", "Nearest gene · TSS distance", "Gene lists"],
        output_label="(annotation)",
        outputs=["annotated_peaks.tsv", "annotation_summary.tsv", "plots (pdf)", "gene_lists (tsv)"],
        result_title="결과 예시 (<sample>.annotated_peaks.tsv)",
        columns=["seqnames", "start", "end", "annotation", "geneId", "distanceToTSS"],
        widths=[70, 80, 80, 180, 110, 102],
        rows=[["1", "19592", "20389", "Promoter (<=1kb)", "AT1G01050", "0"],
              ["1", "24120", "24960", "Promoter (1-2kb)", "AT1G01060", "-1530"],
              ["2", "40021", "40560", "Exon", "AT2G01110", "2311"],
              ["3", "88204", "88730", "Distal Intergenic", "AT3G01250", "8452"]],
        notes=[EX],
    ),
    "differential_accessibility": dict(
        tool="differential_accessibility", ko="차등 접근성 분석", en="Differential accessibility", engine="edgeR (TMM, QL F-test)",
        principle=["두 조건 샘플의 peak를 합쳐 공통",
                   "peak를 만들고 peak별 read 수를 셉니다.",
                   "TMM으로 정규화한 뒤 quasi-likelihood",
                   "검정으로 접근성이 증가·감소한 peak를",
                   "찾고, GC 편향·샘플 상관·PCA로",
                   "품질을 확인합니다."],
        input_label="(BAM, peaks, 샘플 정보)", inputs=["shifted BAM", "narrowPeak", "sample_data.csv", "genome.fa"],
        steps=["Consensus peaks", "Read counting", "TMM normalization", "QL F-test (edgeR)", "QC plots (GC, PCA)"],
        output_label="(differential peaks)",
        outputs=["diff_accessibility_TMM.csv", "up / down peaks (bed)", "04_plots (pdf)", "peak_count_matrix.tsv"],
        result_title="결과 예시 (diff_accessibility_TMM.csv)",
        columns=["peakID", "seqnames", "start", "end", "logFC", "FDR"],
        widths=[130, 80, 100, 100, 90, 122],
        rows=[["peak_0000546", "2", "1092411", "1093617", "2.36", "1.4e-30"],
              ["peak_0000517", "2", "959859", "961198", "2.32", "4.1e-30"],
              ["peak_0000590", "2", "1290406", "1291625", "-2.29", "1.1e-29"],
              ["peak_0000893", "3", "1270362", "1271664", "-2.24", "1.3e-28"]],
        notes=["logFC > 0: treated에서 더 열림(control 기준)", SYN],
    ),
    "atac_motif": dict(
        tool="atac_motif", ko="모티프 농축 분석", en="Motif enrichment", engine="monaLisa",
        principle=["peak를 접근성 변화량(logFC) 순서로",
                   "여러 구간(bin)으로 나누고, 구간마다",
                   "전사인자 모티프가 다른 구간보다 얼마나",
                   "많이 나타나는지 계산합니다. 접근성",
                   "변화와 함께 움직이는 전사인자 후보를",
                   "찾습니다."],
        input_label="(DA 결과, 참조, 모티프)", inputs=["diff_accessibility.csv", "genome.fa", "motifs.meme"],
        steps=["logFC binning", "Motif scanning", "Binned enrichment", "k-mer / regression"],
        output_label="(motif enrichment)",
        outputs=["binned_motif_enrichment.tsv", "heatmap · seqlogo (pdf)", "03_kmer", "04_regression"],
        result_title="결과 예시 (binned_motif_enrichment.tsv)",
        columns=["motif_id", "motif_name", "log2enr__bin1", "log2enr__bin5", "negLog10P__bin5"],
        widths=[110, 110, 130, 130, 142],
        rows=[["MOTIF_A", "TF_A", "-0.42", "1.35", "6.8"], ["MOTIF_B", "TF_B", "0.88", "-0.61", "0.4"],
              ["MOTIF_C", "TF_C", "0.05", "0.97", "4.9"]],
        notes=["bin1: 접근성이 가장 감소한 구간, bin5: 가장 증가한 구간", EX],
    ),
    "tf_footprinting": dict(
        tool="tf_footprinting", ko="전사인자 footprint 분석", en="TF footprinting", engine="TOBIAS",
        principle=["전사인자가 결합한 자리는 Tn5가",
                   "자르지 못해 신호가 움푹 패입니다",
                   "(footprint). 조건별로 BAM을 합쳐",
                   "Tn5 서열 편향을 보정하고 footprint",
                   "점수를 계산한 뒤, 모티프별 결합",
                   "변화를 조건 간에 비교합니다."],
        input_label="(BAM, peaks, 샘플 정보, 모티프)", inputs=["shifted BAM", "narrowPeak", "metadata.tsv", "motifs.meme"],
        steps=["Merge BAM by condition", "ATACorrect (bias)", "ScoreBigwig (footprint)", "BINDetect (compare)"],
        output_label="(footprints)", outputs=["03_tobias_tracks (bw)", "04_BINDetect", "bindetect_results.txt", "summary"],
        result_title="결과 예시 (bindetect_results.txt)",
        columns=["name", "total_tfbs", "control_treated_change", "control_treated_pvalue"],
        widths=[120, 110, 200, 192],
        rows=[["TF_A", "1842", "-0.152", "3.2e-05"], ["TF_B", "927", "0.084", "0.012"]],
        mini="footprint",
        notes=["그림: 모티프 주변 Tn5 신호의 footprint(개념도)", EX],
    ),
    "functional_enrichment": dict(
        tool="functional_enrichment", ko="GO 기능 농축 분석", en="GO enrichment", engine="clusterProfiler",
        principle=["peak(또는 접근성이 변한 peak)마다",
                   "가장 가까운 유전자를 찾고, 이 유전자들이",
                   "배경 유전자보다 어떤 GO 기능에 많이",
                   "모여 있는지 초기하분포 검정으로",
                   "분석합니다. 종별 OrgDb 파일을 사용해",
                   "인터넷 연결 없이 수행합니다."],
        input_label="(gene lists 또는 DA, 주석)", inputs=["gene_lists / DA csv", "genes.gff3", "OrgDb.sqlite"],
        steps=["Peak to nearest gene", "ID matching (OrgDb)", "GO over-representation", "Dot / bar plots"],
        output_label="(GO enrichment)",
        outputs=["01_gene_lists", "02_enrichment (tsv)", "03_plots (pdf)", "enrichment_summary.tsv"],
        result_title="결과 예시 (TMM.up.GO_BP.tsv)",
        columns=["ID", "Description", "GeneRatio", "FoldEnrichment", "p.adjust"],
        widths=[100, 250, 85, 110, 77],
        rows=[["GO:0015979", "photosynthesis", "60/77", "9.56", "1.2e-70"],
              ["GO:0019684", "photosynthesis, light reaction", "42/77", "9.56", "2.3e-45"],
              ["GO:0006091", "generation of precursor metabolites…", "44/77", "7.51", "1.2e-36"]],
        notes=["DA의 up 목록, 애기장대 OrgDb", SYN],
    ),
    "replicate_consistency": dict(
        tool="replicate_consistency", ko="반복 실험 재현성", en="Replicate consistency (IDR)", engine="IDR + MACS3",
        principle=["진짜 peak는 반복 실험에서 신호",
                   "순위가 비슷하게 나타납니다. 반복",
                   "실험마다 느슨한 기준으로 peak를 찾고,",
                   "두 반복의 peak 순위 일치도를 IDR로",
                   "평가해 재현성 있는 peak만 골라냅니다."],
        input_label="(shifted BAM, 샘플 정보)", inputs=["rep1.shifted.bam", "rep2.shifted.bam", "sample_data.csv"],
        steps=["Relaxed peaks (p < 0.01)", "Pooled peaks", "IDR per replicate pair", "Conservative peak set"],
        output_label="(reproducible peaks)",
        outputs=["01_relaxed_peaks", "02_idr (txt, png)", "conservative_peaks.narrowPeak", "idr_summary.tsv"],
        result_title="결과 예시 (idr_summary.tsv)",
        columns=["condition", "replicate_a", "replicate_b", "pooled_peaks", "idr_passed"],
        widths=[110, 120, 120, 130, 142],
        rows=[["control", "ctrl_1", "ctrl_2", "918", "70"], ["treated", "trt_1", "trt_2", "917", "97"]],
        notes=[SYN],
    ),
}

if __name__ == "__main__":
    for name, c in CARDS.items():
        p = OUT / f"{name}_card.svg"
        p.write_text(card(c))
        print(p)
    for name, c in ATAC_CARDS.items():
        # ATAC-seq cards live with the ATAC-seq docs
        p = OUT.parents[2] / "ATAC-seq" / "figures" / "module_cards" / f"{name}_card.svg"
        p.parent.mkdir(exist_ok=True)
        p.write_text(card(c))
        print(p)
