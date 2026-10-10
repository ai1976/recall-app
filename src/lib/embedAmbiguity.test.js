import { describe, it, expect } from 'vitest';

// T-002 B-05 added a second link from notes and flashcards to subjects (the composite course/subject key). An embed that names the table only
// ("subjects(...)") is then ambiguous and the request fails (found live 10/10/2026: note pages said "Note not found"). Every embed of subjects
// must name its link by column: "subjects!subject_id(...)" or "subjects:subject_id (...)".
const files = import.meta.glob('/src/**/*.{js,jsx}', { query: '?raw', import: 'default', eager: true });

describe('embeds of subjects name their link', () => {
  it('has no embed of subjects without a link hint', () => {
    const offenders = [];
    for (const [path, text] of Object.entries(files)) {
      if (/\.test\.(js|jsx)$/.test(path)) continue;
      const lines = text.split(/\r?\n/);
      lines.forEach((line, i) => {
        if (/(^|[\s:,])subjects\s*\(/.test(line) && !/\.from\(|\.rpc\(/.test(line) && /select|id, name|name\)/.test(line)) offenders.push(path + ':' + (i + 1) + ' ' + line.trim());
      });
    }
    expect(offenders).toEqual([]);
  });
});
