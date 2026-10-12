// Build the KOBIC portal copy-paste document (Word) from
// docs/ATAC-seq_Portal_Content.md, in the portal style: Pretendard body
// #222222, GmarketSans headings #32549C, notes #3A3A3A. The portal has no
// editor and keeps Word formatting on paste, so each section is copied from
// this file.
// Run: node docs/portal/make_portal_docx.js   (needs the npm package "docx")
const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, ImageRun, AlignmentType, LevelFormat,
  BorderStyle,
} = require("docx");

const ROOT = path.resolve(__dirname, "..", "..");
const SRC = path.join(ROOT, "docs", "ATAC-seq_Portal_Content.md");
const OUT = path.join(ROOT, "docs", "portal", "ATAC-seq_Portal_Content.docx");

const BODY_FONT = "Pretendard", POINT_FONT = "GmarketSans";
const MAIN = "222222", SUB = "3A3A3A", POINT = "32549C";

// Internal notes: shown in gray with a "do not paste" marker.
const NOTE_PREFIXES = ["KOBIC 포탈의", "포탈 스타일", "포탈의 현재", "출처 확인 필요", "그림:"];

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
for (const raw of lines) {
  const line = raw.trimEnd();
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
