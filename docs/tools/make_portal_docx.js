// Build the KOBIC portal copy-paste document (Word) from
// docs/ATAC-seq/Portal_Content.md, in the portal style: Pretendard body
// #222222, GmarketSans headings #32549C, notes #3A3A3A. The portal has no
// editor and keeps Word formatting on paste, so each section is copied from
// this file.
// Run: node docs/tools/make_portal_docx.js   (needs the npm package "docx")
const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, ImageRun, AlignmentType, LevelFormat,
  BorderStyle, Table, TableRow, TableCell, WidthType, ShadingType,
} = require("docx");

const ROOT = path.resolve(__dirname, "..", "..");
// Optional arguments: source markdown and output docx (relative to the repo).
const SRC = path.join(ROOT, process.argv[2] || "docs/ATAC-seq/Portal_Content.md");
const OUT = path.join(ROOT, process.argv[3] || "docs/ATAC-seq/portal/Portal_Content.docx");

const BODY_FONT = "Pretendard", POINT_FONT = "GmarketSans";
const MAIN = "222222", SUB = "3A3A3A", POINT = "32549C";

// Internal notes: shown in gray with a "do not paste" marker.
const NOTE_PREFIXES = ["KOBIC 포탈의", "포탈 스타일", "포탈의 현재", "출처 확인 필요", "그림:",
  "등록 화면 공통 안내"];
const PAGE_W = 9506;   // A4 width minus 1200 DXA margins

function table(rows) {
  // rows: arrays of cell strings; the first row is the header
  const n = rows[0].length;
  // parameter tables get wide description columns; others share the width
  const preset = {
    7: [920, 950, 950, 1400, 1000, 2140, 2146],
    3: [1800, 3853, 3853],
  };
  const widths = preset[n] || Array(n).fill(Math.floor(PAGE_W / n));
  const total = widths.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: total, type: WidthType.DXA },
    columnWidths: widths,
    rows: rows.map((cells, r) => new TableRow({
      children: cells.map((c, i) => new TableCell({
        width: { size: widths[i], type: WidthType.DXA },
        shading: r === 0 ? { type: ShadingType.CLEAR, fill: "E8EDF6", color: "auto" } : undefined,
        margins: { top: 60, bottom: 60, left: 90, right: 90 },
        children: [new Paragraph({ children: runs(c, r === 0 ? { bold: true, size: 18, color: POINT } : { size: 18 }) })],
      })),
    })),
  });
}

function splitRow(line) {
  // split a markdown table row on unescaped pipes
  const cells = [];
  let cur = "";
  const body = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  for (let i = 0; i < body.length; i++) {
    if (body[i] === "\\" && body[i + 1] === "|") { cur += "|"; i++; }
    else if (body[i] === "|") { cells.push(cur.trim()); cur = ""; }
    else cur += body[i];
  }
  cells.push(cur.trim());
  return cells;
}

function runs(text, base = {}) {
  // **bold**, *italic*, `code` -> TextRuns
  const out = [];
  const re = /(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)/g;
  let last = 0, m;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push(new TextRun({ text: text.slice(last, m.index), ...base }));
    const t = m[0];
    // Code marks are dropped: the portal shows plain text in the body font.
    if (t.startsWith("**")) out.push(new TextRun({ text: t.slice(2, -2).replace(/`/g, ""), ...base, bold: true }));
    else if (t.startsWith("*")) out.push(new TextRun({ text: t.slice(1, -1), ...base, italics: true }));
    else out.push(new TextRun({ text: t.slice(1, -1), ...base }));
    last = m.index + t.length;
  }
  if (last < text.length) out.push(new TextRun({ text: text.slice(last), ...base }));
  return out;
}

function note(text) {
  return new Paragraph({
    spacing: { after: 120 },
    children: [
      new TextRun({ text: "[내부 메모 · 붙여 넣지 마세요] ", bold: true, color: "B0B0B0", size: 18 }),
      ...runs(text, { color: "8A8F99", size: 18 }),
    ],
  });
}

function image(rel) {
  const file = path.join(ROOT, rel);
  if (!fs.existsSync(file)) return null;
  const buf = fs.readFileSync(file);
  // PNG width/height from the IHDR chunk
  const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20);
  const width = 600, height = Math.round((h / w) * width);
  return new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { before: 120, after: 120 },
    children: [new ImageRun({ type: "png", data: buf, transformation: { width, height } })],
  });
}

const children = [];
let listInstance = 0, inNumbered = false;   // restart numbering for each list
const lines = fs.readFileSync(SRC, "utf8").split("\n");
let tableRows = null, codeLines = null;
function flushTable() {
  if (tableRows) { children.push(table(tableRows)); children.push(new Paragraph({ children: [] })); }
  tableRows = null;
}
for (const raw of lines) {
  const line = raw.trimEnd();
  // fenced code block: copy lines as plain text in a gray box
  if (line.startsWith("```")) {
    if (codeLines === null) { codeLines = []; continue; }
    children.push(...codeLines.map((t) => new Paragraph({
      shading: { type: ShadingType.CLEAR, fill: "F3F4F6", color: "auto" },
      spacing: { after: 0 }, children: [new TextRun({ text: t || " ", size: 19, color: SUB })],
    })));
    children.push(new Paragraph({ children: [] }));
    codeLines = null;
    continue;
  }
  if (codeLines !== null) { codeLines.push(raw); continue; }
  if (line.startsWith("|")) {
    if (/^\|[\s|:-]+\|$/.test(line)) continue;   // separator row
    (tableRows = tableRows || []).push(splitRow(line));
    continue;
  }
  flushTable();
  if (!line.trim() || line.trim() === "---") continue;
  if (!/^\d+\. /.test(line)) inNumbered = false;
  if (line.startsWith("# ")) {
    children.push(new Paragraph({
      spacing: { after: 240 },
      children: [new TextRun({ text: line.slice(2), font: POINT_FONT, bold: true, size: 36, color: POINT })],
    }));
  } else if (line.startsWith("## ")) {
    children.push(new Paragraph({
      spacing: { before: 360, after: 160 },
      border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: POINT, space: 4 } },
      children: [new TextRun({ text: line.slice(3), font: POINT_FONT, bold: true, size: 30, color: POINT })],
    }));
  } else if (line.startsWith("### ")) {
    children.push(new Paragraph({
      spacing: { before: 200, after: 100 },
      children: [new TextRun({ text: line.slice(4), bold: true, size: 24, color: SUB })],
    }));
  } else if (NOTE_PREFIXES.some((p) => line.startsWith(p))) {
    children.push(note(line));
    const img = line.match(/`(docs\/figures\/[^`]+\.png)`/);
    if (img) { const p = image(img[1]); if (p) children.push(p); }
  } else if (/^\d+\. /.test(line)) {
    if (!inNumbered) { listInstance += 1; inNumbered = true; }
    children.push(new Paragraph({
      numbering: { reference: "num", level: 0, instance: listInstance }, spacing: { after: 100 },
      children: runs(line.replace(/^\d+\. /, "")),
    }));
  } else if (line.startsWith("- ")) {
    children.push(new Paragraph({
      numbering: { reference: "bullet", level: 0 }, spacing: { after: 80 },
      children: runs(line.slice(2)),
    }));
  } else {
    children.push(new Paragraph({ spacing: { after: 140 }, children: runs(line) }));
  }
}

flushTable();

const doc = new Document({
  styles: {
    default: { document: { run: { font: BODY_FONT, size: 21, color: MAIN } } },
  },
  numbering: {
    config: [
      { reference: "bullet", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•",
        alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 270 } } } }] },
      { reference: "num", levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.",
        alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 300 } } } }] },
    ],
  },
  sections: [{ properties: { page: { margin: { top: 1200, bottom: 1200, left: 1200, right: 1200 } } }, children }],
});

Packer.toBuffer(doc).then((b) => { fs.writeFileSync(OUT, b); console.log(OUT); });
