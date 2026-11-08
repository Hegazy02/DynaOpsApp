// Renders one language of docs/install-and-permissions-guide.ar.md to a print-ready
// HTML page (Chrome then prints it to PDF — see build.sh).
//
// Usage: node md2html.js <guide.md> <out.html> <ar|en>
// Prints the guide version (first cell of the first table's first row) to stdout.
//
// Supports only what the guide uses: headings, paragraphs, bold, (nested) lists,
// blockquotes, tables, `---`, and lines made only of images. `![logo](...)` is the
// page logo; `<!-- lang:en -->` splits the Arabic part from the English part.
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

const [, , input, output, lang] = process.argv;
if (!input || !output || !['ar', 'en'].includes(lang)) {
  console.error('Usage: node md2html.js <guide.md> <out.html> <ar|en>');
  process.exit(2);
}

const all = fs.readFileSync(input, 'utf8').replace(/\r/g, '').split('\n');
const split = all.findIndex((l) => /^<!--\s*lang:en\s*-->$/.test(l.trim()));
if (split < 0) throw new Error('Missing <!-- lang:en --> separator');
const lines = lang === 'ar' ? all.slice(0, split) : all.slice(split + 1);

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const inline = (s) => esc(s).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
const cells = (r) => r.trim().replace(/^\||\|$/g, '').split('|').map((c) => c.trim());

// Headings of the company "Document Control" block, styled with a short underline.
const CONTROL_HEADINGS = ['ضبط الوثيقة', 'سجل التغييرات', 'Document Control', 'Change Record'];

const blocks = [];
let version = null;
let i = 0;
while (i < lines.length) {
  const line = lines[i];
  if (!line.trim()) { i++; continue; }
  let m;

  if ((m = line.match(/^(#{1,3})\s+(.*)$/))) {
    const n = m[1].length;
    const dc = CONTROL_HEADINGS.includes(m[2].trim()) ? ' class="dc"' : '';
    blocks.push(`<h${n}${dc}>${inline(m[2])}</h${n}>`); i++; continue;
  }
  if (/^---\s*$/.test(line)) { blocks.push('<hr>'); i++; continue; }

  if (/^(\s*!\[[^\]]*\]\([^)]+\))+\s*$/.test(line)) {
    const imgs = [...line.matchAll(/!\[([^\]]*)\]\(([^)]+)\)/g)];
    if (imgs.length === 1 && imgs[0][1] === 'logo') {
      blocks.push(`<div class="logo"><img src="${esc(imgs[0][2])}" alt=""></div>`);
    } else {
      blocks.push(`<div class="shots">${imgs.map((x) => `<img src="${esc(x[2])}" alt="">`).join('')}</div>`);
    }
    i++; continue;
  }

  if (line.startsWith('>')) {
    const buf = [];
    while (i < lines.length && lines[i].startsWith('>')) buf.push(lines[i++].replace(/^>\s?/, ''));
    blocks.push(`<blockquote>${buf.map((b) => `<p>${inline(b)}</p>`).join('')}</blockquote>`);
    continue;
  }

  if (line.startsWith('|')) {
    const rows = [];
    while (i < lines.length && lines[i].startsWith('|')) rows.push(lines[i++]);
    const body = rows.slice(2).map(cells);
    // The first table is the Change Record (Date | Version | Author | Change | Reference);
    // its last row is the current version.
    const isRecord = version === null;
    if (isRecord) version = body[body.length - 1][1];
    blocks.push(
      `<table${isRecord ? ' class="record"' : ''}><thead><tr>${cells(rows[0]).map((c) => `<th>${inline(c)}</th>`).join('')}</tr></thead>` +
      `<tbody>${body.map((r) => `<tr>${r.map((c) => `<td>${inline(c)}</td>`).join('')}</tr>`).join('')}</tbody></table>`,
    );
    continue;
  }

  if (/^\s*(-|\d+\.)\s/.test(line)) {
    const items = [];
    while (i < lines.length && /^\s*(-|\d+\.)\s/.test(lines[i])) {
      const mm = lines[i].match(/^(\s*)(-|\d+\.)\s+(.*)$/);
      items.push({ depth: Math.floor(mm[1].length / 2), ordered: mm[2] !== '-', text: mm[3] });
      i++;
    }
    let out = '';
    const stack = [];
    for (const it of items) {
      while (stack.length > it.depth + 1) out += `</li></${stack.pop()}>`;
      if (stack.length === it.depth + 1) out += '</li>';
      else { const t = it.ordered ? 'ol' : 'ul'; stack.push(t); out += `<${t}>`; }
      out += `<li>${inline(it.text)}`;
    }
    while (stack.length) out += `</li></${stack.pop()}>`;
    blocks.push(out);
    continue;
  }

  const buf = [];
  while (i < lines.length && lines[i].trim() && !/^(#|>|\||---|!\[|\s*(-|\d+\.)\s)/.test(lines[i])) buf.push(inline(lines[i++]));
  blocks.push(`<p>${buf.join('<br>')}</p>`);
}
if (!version) throw new Error(`No Change Record table (version) found in the ${lang} part`);

// The last block is the "prepared by" line.
blocks[blocks.length - 1] = blocks[blocks.length - 1].replace(/^<p>/, '<p class="signature">');

const t = lang === 'ar'
  ? { dir: 'rtl', title: 'دليل تثبيت DynaOps', footer: `DynaOps — دليل التثبيت والأذونات — الإصدار ${version}`, page: 'صفحة' }
  : { dir: 'ltr', title: 'DynaOps Installation Guide', footer: `DynaOps — Installation & Permissions Guide — Version ${version}`, page: 'Page' };
const cssString = (s) => `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
const base = pathToFileURL(path.dirname(path.resolve(input))).href + '/';

const page = `<!doctype html>
<html lang="${lang}" dir="${t.dir}"><head><meta charset="utf-8"><base href="${base}"><title>${t.title}</title>
<style>
  @page {
    size: A4; margin: 18mm 16mm 20mm;
    @bottom-left { content: ${cssString(t.footer)}; font: 8.5pt "Segoe UI", Tahoma, sans-serif; color: #7a8299; }
    @bottom-right { content: ${cssString(t.page + ' ')} counter(page) " / " counter(pages); font: 8.5pt "Segoe UI", Tahoma, sans-serif; color: #7a8299; }
  }
  body { font-family: "Segoe UI", Tahoma, Arial, sans-serif; font-size: ${lang === 'ar' ? '11.5pt; line-height: 1.75' : '11pt; line-height: 1.6'}; color: #1f2430; }
  .logo { text-align: center; margin: 0 0 14px; }
  .logo img { height: 64px; }
  h1 { font-size: 21pt; color: #192966; border-bottom: 3px solid #192966; padding-bottom: 8px; margin-top: 0; text-align: center; }
  h2 { font-size: 15.5pt; color: #192966; margin-top: 22px; break-after: avoid; }
  h3 { font-size: 12.5pt; color: #2b3f8f; margin: 16px 0 6px; break-after: avoid; }
  hr { border: 0; border-top: 1px solid #d5d9e4; margin: 18px 0; }
  blockquote { margin: 10px 0; padding: 8px 14px; background: #f1f4fb; border-inline-start: 4px solid #3b55b5; border-radius: 4px; break-inside: avoid; }
  blockquote p { margin: 2px 0; }
  ul, ol { padding-inline-start: 22px; padding-inline-end: 0; margin: 6px 0; }
  li { margin: 3px 0; }
  table { width: 100%; border-collapse: collapse; margin: 10px 0; font-size: 10.5pt; break-inside: avoid; }
  th, td { border: 1px solid #c9cfdd; padding: 6px 8px; text-align: start; vertical-align: top; }
  th { background: #192966; color: #fff; }
  tr:nth-child(even) td { background: #f7f8fc; }
  h2.dc, h3.dc { color: #111; font-weight: 600; border: 0; margin: 14px 0 10px; }
  h2.dc::after, h3.dc::after { content: ""; display: block; width: 70px; border-bottom: 2px solid #3b55b5; margin-top: 8px; }
  h3.dc { font-weight: 400; font-size: 13pt; }
  table.record { border-collapse: separate; border-spacing: 0; border: 1px solid #24388a; border-radius: 10px; overflow: hidden; margin: 12px 0 6px; }
  table.record th, table.record td { border: 0; text-align: center; vertical-align: middle; padding: 10px 8px; background: #fff; }
  table.record th { background: #24388a; color: #fff; }
  table.record th + th, table.record td + td { border-inline-start: 1px solid #c9cfdd; }
  table.record th + th { border-inline-start-color: #8090c8; }
  table.record tbody tr + tr td { border-top: 1px solid #24388a; }
  strong { color: #10183d; }
  .shots { display: flex; flex-wrap: wrap; justify-content: center; align-items: flex-start; gap: 14px; margin: 12px 0; break-inside: avoid; }
  .shots img { max-height: 400px; max-width: 46%; border: 1px solid #c9cfdd; border-radius: 10px; }
  .signature { text-align: center; font-size: 12pt; margin-top: 18px; }
</style></head><body>
${blocks.join('\n')}
</body></html>`;
fs.writeFileSync(output, page, 'utf8');
process.stdout.write(version);
