// D-05_writer-matrix.mjs - T-002 deterministic writer matrix (v1).
//
// Purpose (QA Round 18, D-03 finding 2): the relation-by-DML-kind writer matrix of docs/database/t002/00_DIAGNOSTIC-BATCH_proposal_v1.md must be reproducible from
// exact artifacts, not assembled by hand. This script reads the SAVED, decoded JSON results of D3 (runs P1, P2, P3, P4) and of D4, and an optional clearances file,
// and writes the matrix. It reads files only and runs no database statement. Its inputs are hashed into the output, so the matrix can be recomputed and compared.
//
// Cells: for each target relation and each DML kind (INSERT, UPDATE, UPSERT [ON CONFLICT DO UPDATE], MERGE, COPY, DELETE, TRUNCATE) the status is:
//   - `leads`                    one or more discovered writers (routine, foreign-key action, writable view, rule, scheduled job, code call site);
//   - `none_found`               no lead AND no global unresolved item anywhere (the only state that may be read as "no writer found");
//   - `unresolved`               no lead, but a global unresolved item exists (an uncleared dynamic-SQL routine, an unreadable or compiled routine, a cut frontier, a
//                                cron visibility problem, an undisposed code lead): the cell cannot be called clean;
//   - `leads_and_unresolved`     leads exist and a global unresolved item exists too.
// Global unresolved items are never converted to clean by this script. They are cleared only by a `--clearances` file: a JSON object whose keys are
// `<schema>.<name>(<args>)|<src_md5>` for a dynamic-SQL routine (the hash binds the clearance to the exact body that was read) and `<schema>.<name>(<args>)` for an
// unreadable or compiled routine, and whose values are the reason. A clearance is reviewed work and is part of the audited evidence; the script never invents one.
//
// Usage:
//   node docs/database/t002/D-05_writer-matrix.mjs --self-test
//   node docs/database/t002/D-05_writer-matrix.mjs --p1 P1.json --p2 P2.json --p3 P3.json --p4 P4.json --d4 d4.json [--clearances c.json] --out matrix.json [--md matrix.md]
// Exit status: 0 when no cell is unresolved; 3 when at least one cell is `unresolved` or `leads_and_unresolved` (fail closed); 1 on a bad input.

import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const TARGETS = ['profiles', 'study_sessions', 'flashcards', 'notes', 'access_requests', 'disciplines', 'subjects', 'topics'];
export const KINDS = ['INSERT', 'UPDATE', 'UPSERT', 'MERGE', 'COPY', 'DELETE', 'TRUNCATE'];
const FLAG_TO_KIND = { insert: 'INSERT', update: 'UPDATE', on_conflict_do_update: 'UPSERT', merge: 'MERGE', copy: 'COPY', delete: 'DELETE', truncate: 'TRUNCATE' };
const RULE_EVENT_TO_KIND = { '2': 'UPDATE', '3': 'INSERT', '4': 'DELETE' };
const OP_TO_KIND = { insert: 'INSERT', update: 'UPDATE', upsert: 'UPSERT', delete: 'DELETE' };
const routineId = (r) => `${r.schema}.${r.name}(${r.args})`;

function stable(v) {
  if (Array.isArray(v)) return v.map(stable);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, stable(v[k])]));
  return v;
}
export const stableStringify = (v) => JSON.stringify(stable(v), null, 1);

export function buildMatrix({ p1, p2, p3, p4, d4, clearances = {} }) {
  const cells = {};
  for (const r of TARGETS) { cells[r] = {}; for (const k of KINDS) cells[r][k] = { leads: [] }; }
  const add = (rel, kind, lead) => { if (cells[rel] && cells[rel][kind]) cells[rel][kind].leads.push(lead); };

  // routines that spell a target relation and a DML word
  for (const r of p2.routines || []) {
    for (const rel of r.mentions || []) for (const [flag, kind] of Object.entries(FLAG_TO_KIND)) {
      if (r.flags && r.flags[flag]) add(rel, kind, { source: 'routine', id: routineId(r), src_md5: r.src_md5, security_definer: r.security_definer, grantees: r.execute_grantees });
    }
  }
  // foreign-key actions (indirect writes)
  for (const m of p1.mutation_reachability || []) {
    const kind = m.target_result === 'DELETE' ? 'DELETE' : 'UPDATE';
    add(m.target, kind, { source: 'foreign_key', id: `${m.ancestor}:${m.ancestor_event}->${m.target_result}`, min_depth: m.min_depth, example_path: m.example_path });
  }
  // writable views and rules
  const viewRoots = new Map();
  for (const v of p3.dependent_views || []) {
    const vid = `${v.schema}.${v.view}`; viewRoots.set(vid, v.depends_transitively_on || []);
    for (const root of v.depends_transitively_on || []) {
      if (v.accepts_insert) add(root, 'INSERT', { source: 'writable_view', id: vid });
      if (v.accepts_update) add(root, 'UPDATE', { source: 'writable_view', id: vid });
      if (v.accepts_delete) add(root, 'DELETE', { source: 'writable_view', id: vid });
    }
  }
  for (const ru of p3.rewrite_rules_on_targets_and_dependents || []) {
    const kind = RULE_EVENT_TO_KIND[String(ru.event)];
    if (!kind) continue;
    const rid = `${ru.schema}.${ru.relation}#${ru.rule}`;
    const roots = TARGETS.includes(ru.relation) ? [ru.relation] : (viewRoots.get(`${ru.schema}.${ru.relation}`) || []);
    for (const root of roots) add(root, kind, { source: 'rule', id: rid, instead: ru.instead, definition_md5: ru.definition_md5 });
  }
  // scheduled jobs
  for (const j of p4.jobs || []) {
    for (const rel of TARGETS) {
      if (!j.flags || !j.flags[`names_${rel}`]) continue;
      for (const [flag, kind] of [['insert', 'INSERT'], ['update', 'UPDATE'], ['delete', 'DELETE'], ['truncate', 'TRUNCATE'], ['merge', 'MERGE'], ['copy', 'COPY']]) {
        if (j.flags[flag]) add(rel, kind, { source: 'scheduled_job', id: `job ${j.jobid} ${j.jobname}`, command_md5: j.command_md5 });
      }
    }
  }
  // code call sites (D4)
  for (const e of d4.entries || []) {
    if (e.kind !== 'write' || !cells[e.table]) continue;
    add(e.table, OP_TO_KIND[e.op], { source: 'code', id: `${e.file}:${e.line}`, payload_keys: e.payload_keys, payload_resolved: e.payload_resolved });
  }

  // global unresolved items
  const global = [];
  const dyn = (p2.dynamic_sql_routines_not_in_extensions || {}).identities || [];
  for (const r of dyn) {
    const key = `${routineId(r)}|${r.src_md5}`;
    if (!clearances[key]) global.push({ kind: 'dynamic_sql_routine_uncleared', id: key });
  }
  for (const r of (p2.unreadable_language_routines || {}).identities || []) {
    const key = routineId(r);
    if (!clearances[key]) global.push({ kind: 'unreadable_language_routine_uncleared', id: key });
  }
  for (const r of (p2.compiled_routines || {}).not_in_extensions_identities || []) {
    const key = routineId(r);
    if (!clearances[key]) global.push({ kind: 'compiled_routine_not_in_extension_uncleared', id: key });
  }
  if (p4.visibility_unresolved) global.push({ kind: 'cron_visibility_unresolved', id: 'cron.job rows may be hidden from the running role' });
  for (const f of p1.frontier_cut_at_depth_cap || []) global.push({ kind: 'fk_frontier_cut', id: `${f.target}<-${f.ancestor}` });
  for (const f of p3.frontier_cut_at_depth_cap || []) global.push({ kind: 'view_frontier_cut', id: String(f) });
  for (const u of d4.undisposed || []) global.push({ kind: 'code_lead_undisposed', id: u.id });
  if ((d4.unparsed_files || []).length) for (const u of d4.unparsed_files) global.push({ kind: 'code_file_unparsed', id: u.file });

  for (const r of TARGETS) for (const k of KINDS) {
    const c = cells[r][k];
    c.leads.sort((a, b) => (a.source + a.id).localeCompare(b.source + b.id));
    c.status = c.leads.length ? (global.length ? 'leads_and_unresolved' : 'leads') : (global.length ? 'unresolved' : 'none_found');
  }
  global.sort((a, b) => (a.kind + a.id).localeCompare(b.kind + b.id));
  return { cells, global_unresolved: global };
}

export function renderMarkdown(m) {
  const lines = ['| relation | ' + KINDS.join(' | ') + ' |', '|---|' + KINDS.map(() => '---').join('|') + '|'];
  for (const r of TARGETS) lines.push(`| ${r} | ` + KINDS.map((k) => { const c = m.cells[r][k]; return `${c.status}${c.leads.length ? ` (${c.leads.length})` : ''}`; }).join(' | ') + ' |');
  lines.push('', `Global unresolved items: ${m.global_unresolved.length}`);
  for (const g of m.global_unresolved) lines.push(`- ${g.kind}: ${g.id}`);
  return lines.join('\n') + '\n';
}

export function exitCodeFor(m) {
  for (const r of TARGETS) for (const k of KINDS) if (m.cells[r][k].status.includes('unresolved')) return 3;
  return 0;
}

// ---------------------------------------------------------------- self-test (synthetic inputs only)
export function selfTest() {
  const failures = []; let total = 0;
  const check = (name, ok) => { total += 1; if (!ok) failures.push(name); };
  const p1 = { mutation_reachability: [{ target: 'study_sessions', ancestor: 'auth.users', ancestor_event: 'DELETE', target_result: 'DELETE', min_depth: 1, example_path: 'study_sessions_user_id_fkey' }], frontier_cut_at_depth_cap: [] };
  const p2 = {
    routines: [{ schema: 'public', name: 'purge_notes', args: '', mentions: ['notes'], src_md5: 'aa', security_definer: true, execute_grantees: ['postgres'], flags: { delete: true, insert: false, update: false, truncate: false, merge: false, copy: false, on_conflict_do_update: false } },
               { schema: 'public', name: 'upsert_profile', args: 'p uuid', mentions: ['profiles'], src_md5: 'bb', security_definer: true, execute_grantees: [], flags: { on_conflict_do_update: true, insert: true } }],
    dynamic_sql_routines_not_in_extensions: { identities: [{ schema: 'public', name: 'dyn', args: '', src_md5: 'cc' }] },
    unreadable_language_routines: { identities: [] }, compiled_routines: { not_in_extensions_identities: [] },
  };
  const p3 = { dependent_views: [{ schema: 'public', view: 'v_notes', depends_transitively_on: ['notes'], accepts_update: true, accepts_insert: false, accepts_delete: false }],
               rewrite_rules_on_targets_and_dependents: [{ schema: 'public', relation: 'v_notes', rule: 'r1', event: '4', instead: true, definition_md5: 'dd' }], frontier_cut_at_depth_cap: [] };
  const p4 = { visibility_unresolved: false, jobs: [{ jobid: 4, jobname: 'j', command_md5: 'ee', flags: { names_flashcards: true, delete: true } }] };
  const d4 = { entries: [{ kind: 'write', table: 'study_sessions', op: 'insert', file: 'src/a.js', line: 3, payload_keys: ['user_id'], payload_resolved: true }, { kind: 'read', table: 'notes', op: 'select', file: 'src/b.js', line: 1 }], undisposed: [], unparsed_files: [] };
  let m = buildMatrix({ p1, p2, p3, p4, d4, clearances: {} });
  check('an uncleared dynamic-SQL routine makes empty cells unresolved, not clean', m.cells.topics.TRUNCATE.status === 'unresolved' && m.global_unresolved.some((g) => g.kind === 'dynamic_sql_routine_uncleared'));
  check('a foreign-key cascade is a DELETE lead on the target', m.cells.study_sessions.DELETE.leads.some((l) => l.source === 'foreign_key'));
  check('a code insert is an INSERT lead; a code read is not a lead', m.cells.study_sessions.INSERT.leads.some((l) => l.source === 'code') && m.cells.notes.INSERT.leads.length === 0);
  check('a routine with ON CONFLICT DO UPDATE is an UPSERT lead for the relation it names', m.cells.profiles.UPSERT.leads.some((l) => l.id === 'public.upsert_profile(p uuid)'));
  check('a writable view and an INSTEAD rule on it reach the base relation', m.cells.notes.UPDATE.leads.some((l) => l.source === 'writable_view') && m.cells.notes.DELETE.leads.some((l) => l.source === 'rule'));
  check('a scheduled job that names a relation and a DELETE word is a DELETE lead', m.cells.flashcards.DELETE.leads.some((l) => l.source === 'scheduled_job'));
  check('fail closed: exit status 3 while any cell is unresolved', exitCodeFor(m) === 3);
  m = buildMatrix({ p1, p2, p3, p4, d4, clearances: { 'public.dyn()|cc': 'read: no DML on target relations' } });
  check('a clearance bound to the exact body hash clears the dynamic routine', m.global_unresolved.length === 0 && m.cells.topics.TRUNCATE.status === 'none_found');
  check('with nothing unresolved the status of a cell with leads is leads', m.cells.study_sessions.DELETE.status === 'leads' && exitCodeFor(m) === 0);
  m = buildMatrix({ p1, p2, p3, p4, d4, clearances: { 'public.dyn()|ZZ': 'wrong hash' } });
  check('a clearance for a different body hash does not clear it', m.global_unresolved.some((g) => g.kind === 'dynamic_sql_routine_uncleared'));
  m = buildMatrix({ p1, p2, p3, p4: { ...p4, visibility_unresolved: true }, d4, clearances: { 'public.dyn()|cc': 'ok' } });
  check('cron visibility unresolved makes the matrix unresolved', exitCodeFor(m) === 3);
  m = buildMatrix({ p1, p2, p3, p4, d4: { ...d4, undisposed: [{ id: 'src/x.js:9:from_non_literal_table' }] }, clearances: { 'public.dyn()|cc': 'ok' } });
  check('an undisposed code lead keeps the matrix unresolved', m.global_unresolved.some((g) => g.kind === 'code_lead_undisposed'));
  const a = stableStringify(buildMatrix({ p1, p2, p3, p4, d4, clearances: { 'public.dyn()|cc': 'ok' } }));
  const b = stableStringify(buildMatrix({ p1, p2, p3, p4, d4, clearances: { 'public.dyn()|cc': 'ok' } }));
  check('the output is deterministic', a === b);
  return { total, failures };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
if (isMain) {
  const args = process.argv.slice(2);
  const get = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
  const st = selfTest();
  if (args.includes('--self-test')) { console.log(JSON.stringify(st, null, 2)); process.exit(st.failures.length ? 1 : 0); }
  if (st.failures.length) { console.error('self-test failed'); console.error(JSON.stringify(st, null, 2)); process.exit(1); }
  const need = ['--p1', '--p2', '--p3', '--p4', '--d4'];
  if (need.some((k) => !get(k))) { console.error('missing input: ' + need.filter((k) => !get(k)).join(', ')); process.exit(1); }
  const read = (p) => { const buf = fs.readFileSync(p); return { obj: JSON.parse(buf.toString('utf8')), sha256: crypto.createHash('sha256').update(buf).digest('hex') }; };
  const inputs = {}; const loaded = {};
  for (const k of ['p1', 'p2', 'p3', 'p4', 'd4']) { const r = read(get('--' + k)); loaded[k] = r.obj; inputs[k] = { file: get('--' + k), sha256: r.sha256 }; }
  let clearances = {};
  if (get('--clearances')) { const r = read(get('--clearances')); clearances = r.obj; inputs.clearances = { file: get('--clearances'), sha256: r.sha256 }; }
  const m = buildMatrix({ ...loaded, clearances });
  const out = { tool: 'D-05_writer-matrix.mjs v1', inputs, ...m };
  const text = stableStringify(out);
  if (get('--out')) fs.writeFileSync(get('--out'), text, 'utf8'); else console.log(text);
  if (get('--md')) fs.writeFileSync(get('--md'), renderMarkdown(m), 'utf8');
  process.exit(exitCodeFor(m));
}
