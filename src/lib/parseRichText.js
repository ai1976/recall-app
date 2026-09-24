/**
 * Sprint 8.7.9 (D-31) — pure parser for the locked corpus rich-content
 * contract used by front_text / back_text / scenario:
 *
 *   [[TABLE]]
 *   Header A | Header B
 *   Value A | Value B
 *   [[/TABLE]]
 *
 * Table markers are recognized only on a trimmed line that is exactly
 * "[[TABLE]]" or "[[/TABLE]]" — never as a substring inside prose. Any
 * malformed marker sequence (unclosed open, orphan close, nested open)
 * fails closed: the whole original string comes back as one paragraph
 * block, so a study card never blanks or crashes on bad input.
 */

const OPEN_MARKER = '[[TABLE]]';
const CLOSE_MARKER = '[[/TABLE]]';

function parseTableRow(line) {
  const cells = [];
  let current = '';
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '\\' && line[i + 1] === '|') {
      current += '|';
      i++;
    } else if (ch === '|') {
      cells.push(current.trim());
      current = '';
    } else {
      current += ch;
    }
  }
  cells.push(current.trim());
  return cells;
}

export function parseRichText(text) {
  const original = text == null ? '' : String(text);
  const fallback = [{ type: 'paragraph', text: original }];

  if (!original) return fallback;

  const lines = original.split(/\r\n|\n/);
  const markers = [];
  lines.forEach((line, idx) => {
    const trimmed = line.trim();
    if (trimmed === OPEN_MARKER) markers.push({ type: 'open', idx });
    else if (trimmed === CLOSE_MARKER) markers.push({ type: 'close', idx });
  });

  if (markers.length === 0) return fallback;

  // Markers must alternate open/close in strict pairs, in order.
  let expectOpen = true;
  for (const marker of markers) {
    if (expectOpen) {
      if (marker.type !== 'open') return fallback; // orphan close
      expectOpen = false;
    } else {
      if (marker.type !== 'close') return fallback; // nested open
      expectOpen = true;
    }
  }
  if (!expectOpen) return fallback; // trailing unclosed open

  const blocks = [];
  let cursor = 0;

  const pushParagraph = (fromLine, toLine) => {
    if (toLine <= fromLine) return;
    const segment = lines.slice(fromLine, toLine).join('\n');
    if (segment.trim().length > 0) {
      blocks.push({ type: 'paragraph', text: segment });
    }
  };

  for (let i = 0; i < markers.length; i += 2) {
    const openIdx = markers[i].idx;
    const closeIdx = markers[i + 1].idx;

    pushParagraph(cursor, openIdx);

    const rowLines = lines
      .slice(openIdx + 1, closeIdx)
      .filter((line) => line.trim().length > 0);
    const rows = rowLines.map(parseTableRow);

    if (rows.length > 0) {
      blocks.push({ type: 'table', headers: rows[0], rows: rows.slice(1) });
    }

    cursor = closeIdx + 1;
  }

  pushParagraph(cursor, lines.length);

  return blocks.length > 0 ? blocks : fallback;
}
