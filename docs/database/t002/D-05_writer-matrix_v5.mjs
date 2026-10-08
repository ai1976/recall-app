// D-05_writer-matrix_v5.mjs - T-002 deterministic writer matrix and sink/allowlist comparison (v5).
//
// v5 answers QA Round 26 and the Founder's DEC-4 decision of 08/10/2026 (the account-deletion provenance proof is dropped; the final check only requires that the
// set of unclassified manual study logs never GROWS). The `auth.users` caller closure (old D3 P7), the cascade key proof and the extension of the ledger are gone, so
// this script now takes P1 to P6, D4, an allowlist and clearances. What it does:
//  1. RECURSIVE schema validation of every input; every count that D3 returns must equal the length of its list (P1 foreign keys and paths, P2 routines, P3 views and
//     rules, P4 jobs, P5 triggers and chain functions); P1 must report the eight target relations. A truncated or edited cell is a BAD INPUT (exit 1).
//  2. SINKS for `study_sessions`. Only the operations that can ADD or RELABEL a row are gated: INSERT, UPDATE, UPSERT, MERGE, COPY. Every routine, foreign-key path
//     (SET NULL / SET DEFAULT results are UPDATE), writable view, rewrite rule and scheduled job that can do one of these to `study_sessions` must be in the hashed
//     allowlist by its exact key, otherwise it is a named stop. DELETE and TRUNCATE leads are recorded in the cells and are informational (they can only remove rows).
//  3. DIRECT CODE WRITERS (D4). Every D4 `write` entry for `study_sessions` with a gated operation must be in the allowlist section `code_writers`
//     (`<file>|<table>|<op>|<enclosing function>`), and its payload must be resolved; otherwise `code_writer_not_allowlisted` / `code_writer_payload_unresolved`.
//     D4 must come from a CLEAN commit: `git.commit` is 40 hex and `git.source_roots_dirty` is false, otherwise `d4_not_at_clean_commit`. The D4 file hash and commit are in the output.
//  4. EXTENSION routines (dynamic-SQL and compiled) are stops unless cleared by `extension_<dynamic|compiled>:<name>@<version>#<count>|<sha256>`; dynamic-SQL, unreadable and
//     compiled non-extension routines need clearances; a clearance needs a reason of at least 10 characters; unused allowlist or clearance entries are a stop unless listed in
//     `reviewed_unused`.
//  P6 stays advisory. The output carries `result_sha256` of the locked comparison and the hash of every input.
//
// Cells: leads / none_found / unresolved / leads_and_unresolved; `none_found` is possible only when no global unresolved item exists anywhere.
// Allowlist file (JSON, every section a required array of strings): study_sessions_sinks, code_writers, reviewed_unused.
//   sink keys: `routine:<schema>.<name>(<args>)|<src_md5>`; `foreign_key:<ancestor>:<event>-><result>|path=<path>|depth=<n>`; `writable_view:<id>|<definition_md5>`;
//   `rule:<id>|<definition_md5>`; `scheduled_job:job <id> <name>|<command_md5>|active=<b>|schedule=<s>|database=<d>|username=<u>`.
// Usage:
//   node docs/database/t002/D-05_writer-matrix_v5.mjs --self-test
//   node docs/database/t002/D-05_writer-matrix_v5.mjs --p1 P1.json ... --p6 P6.json --d4 d4.json --allowlist allow.json [--clearances c.json] --out matrix.json [--md matrix.md]
// Exit status: 0 only when nothing is unresolved; 3 when any cell or global item is unresolved (fail closed); 1 on a bad input.

import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const TARGETS = ['profiles', 'study_sessions', 'flashcards', 'notes', 'access_requests', 'disciplines', 'subjects', 'topics'];
export const KINDS = ['INSERT', 'UPDATE', 'UPSERT', 'MERGE', 'COPY', 'DELETE', 'TRUNCATE'];
export const GATED = new Set(['INSERT', 'UPDATE', 'UPSERT', 'MERGE', 'COPY']);
const FLAG_TO_KIND = { insert: 'INSERT', update: 'UPDATE', on_conflict_do_update: 'UPSERT', merge: 'MERGE', copy: 'COPY', delete: 'DELETE', truncate: 'TRUNCATE' };
const RULE_EVENT_TO_KIND = { '2': 'UPDATE', '3': 'INSERT', '4': 'DELETE' };
const OP_TO_KIND = { insert: 'INSERT', update: 'UPDATE', upsert: 'UPSERT', delete: 'DELETE' };
const routineId = (r) => `${r.schema}.${r.name}(${r.args})`;
export const D3_VERSION = 'D3-v7';
export const D4_TOOL = 'D-04_code-inventory_v7.mjs';
export const ALLOWLIST_KEYS = ['study_sessions_sinks', 'code_writers', 'reviewed_unused'];

function stable(v) {
  if (Array.isArray(v)) return v.map(stable);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, stable(v[k])]));
  return v;
}
export const stableStringify = (v) => JSON.stringify(stable(v), null, 1);
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

// ---------------------------------------------------------------- recursive validation
const S = (v) => typeof v === 'string' && v.length > 0;
const S0 = (v) => typeof v === 'string';
const SN = (v) => v === null || typeof v === 'string';
const N = (v) => typeof v === 'number' && Number.isFinite(v);
const NI = (v) => Number.isInteger(v) && v >= 0;
const B = (v) => typeof v === 'boolean';
const H32 = (v) => typeof v === 'string' && /^[0-9a-f]{32}$/.test(v);
const H40 = (v) => typeof v === 'string' && /^[0-9a-f]{40}$/.test(v);
const H64 = (v) => typeof v === 'string' && /^[0-9a-f]{64}$/.test(v);
const arr = (of) => ({ arr: of });
const obj = (fields) => ({ obj: fields });
function chk(v, spec, p, errs) {
  if (typeof spec === 'function') { if (!spec(v)) errs.push(`${p}: invalid value ${JSON.stringify(v)}`.slice(0, 160)); return; }
  if (spec.arr) { if (!Array.isArray(v)) { errs.push(`${p}: not an array`); return; } v.forEach((x, i) => chk(x, spec.arr, `${p}[${i}]`, errs)); return; }
  if (spec.obj) {
    if (!v || typeof v !== 'object' || Array.isArray(v)) { errs.push(`${p}: not an object`); return; }
    for (const [k, s] of Object.entries(spec.obj)) { if (!(k in v)) errs.push(`${p}.${k}: missing`); else chk(v[k], s, `${p}.${k}`, errs); }
  }
}
const ident = { schema: S, name: S, args: S0 };
const flagsOf = (names) => obj(Object.fromEntries(names.map((n) => [n, B])));
const ROUTINE_FLAGS = ['insert', 'update', 'delete', 'truncate', 'merge', 'copy', 'on_conflict_do_update', 'dynamic_sql_execute', 'ddl_word'];
const JOB_FLAGS = [...TARGETS.map((t) => `names_${t}`), 'insert', 'update', 'delete', 'truncate', 'merge', 'copy', 'execute_word', 'net_http_post', 'names_cron_schema'];
const EXT_ROW = obj({ extension: S, extversion: S, routines: NI, identity_set_sha256: H64 });
const SPECS = {
  p1: obj({ run: (v) => v === 'D3-P1', tool_version: (v) => v === D3_VERSION, targets_found: (v) => v === TARGETS.length, depth_cap: (v) => v === 12,
    direct_foreign_key_count: NI, mutation_reachability_count: NI,
    direct_foreign_keys: arr(obj({ constraint: S, child: S, parent: S, definition_md5: H32 })),
    mutation_reachability: arr(obj({ target: S, ancestor: S, ancestor_event: S, target_result: S, min_depth: NI, example_path: S })),
    frontier_cut_at_depth_cap: arr(obj({ target: S, ancestor: S })) }),
  p2: obj({ run: (v) => v === 'D3-P2', tool_version: (v) => v === D3_VERSION, routines_scanned: NI, routines_naming_a_target: NI,
    routines: arr(obj({ ...ident, mentions: arr(S), src_md5: H32, security_definer: B, execute_grantees: arr(S), flags: flagsOf(ROUTINE_FLAGS) })),
    dynamic_sql_routines_not_in_extensions: obj({ count: NI, identities: arr(obj({ ...ident, src_md5: H32 })) }),
    dynamic_sql_routines_in_extensions_by_extension: arr(EXT_ROW),
    unreadable_language_routines: obj({ count: NI, identities: arr(obj(ident)) }),
    compiled_routines: obj({ not_in_extensions_count: NI, not_in_extensions_identities: arr(obj(ident)), in_extensions_by_extension: arr(EXT_ROW) }) }),
  p3: obj({ run: (v) => v === 'D3-P3', tool_version: (v) => v === D3_VERSION, depth_cap: (v) => v === 8, dependent_views_count: NI, rewrite_rules_count: NI,
    dependent_views: arr(obj({ schema: S, view: S, depends_transitively_on: arr(S), definition_md5: H32, accepts_update: B, accepts_insert: B, accepts_delete: B })),
    rewrite_rules_on_targets_and_dependents: arr(obj({ schema: S, relation: S, rule: S, event: S, instead: B, definition_md5: H32 })),
    frontier_cut_at_depth_cap: arr(S0) }),
  p4: obj({ run: (v) => v === 'D3-P4', tool_version: (v) => v === D3_VERSION, visibility_unresolved: B, visible_job_rows: NI,
    jobs: arr(obj({ jobid: NI, jobname: SN, schedule: S, active: B, database: S, username: S, command_md5: H32, flags: flagsOf(JOB_FLAGS) })) }),
  p5: obj({ run: (v) => v === 'D3-P5', tool_version: (v) => v === D3_VERSION, auth_users_trigger_count: NI, chain_function_count: NI,
    auth_users_triggers: arr(obj({ name: S, function_schema: S, function: S, function_args: S0 })),
    chain_functions: arr(obj({ ...ident, definition_md5: H32 })) }),
  p6: obj({ run: (v) => v === 'D3-P6', tool_version: (v) => v === D3_VERSION, closure_size: NI,
    relevant_routines: arr(obj(ident)),
    frontier_edges_outside_closure: arr(obj({ caller_schema: S, caller_name: S, caller_args: S0, callee_schema: S, callee_name: S, callee_args: S0 })) }),
  d4: obj({ tool: (v) => v === D4_TOOL, files_scanned: (v) => NI(v) && v > 0, unresolved_count: NI, disposed_count: NI, undisposed_count: NI,
    git: obj({ commit: H40, source_roots_dirty: B }),
    undisposed: arr(obj({ id: S })), disposed: arr(obj({ id: S })), unparsed_files: arr(obj({ file: S })),
    entries: arr((e) => e && typeof e === 'object' && S(e.kind) && S(e.file) && NI(e.line) && S0(e.in)
      && (e.kind !== 'write' || (S(e.table) && S(e.op) && OP_TO_KIND[e.op] !== undefined && B(e.payload_resolved))) ) }),
  allowlist: obj(Object.fromEntries(ALLOWLIST_KEYS.map((k) => [k, arr(S)]))),
};

export function validateInputs(inputs) {
  const errors = [];
  for (const [k, spec] of Object.entries(SPECS)) chk(inputs[k], spec, k, errors);
  const { p1, p2, p3, p4, p5, d4, clearances } = inputs;
  const eq = (label, a, b) => { if (a !== b) errors.push(`${label}: count ${a} disagrees with list length ${b}`); };
  if (p1 && Array.isArray(p1.direct_foreign_keys)) eq('p1.direct_foreign_key_count', p1.direct_foreign_key_count, p1.direct_foreign_keys.length);
  if (p1 && Array.isArray(p1.mutation_reachability)) eq('p1.mutation_reachability_count', p1.mutation_reachability_count, p1.mutation_reachability.length);
  if (p2 && Array.isArray(p2.routines)) eq('p2.routines_naming_a_target', p2.routines_naming_a_target, p2.routines.length);
  if (p2 && p2.dynamic_sql_routines_not_in_extensions) eq('p2 dynamic-SQL count', p2.dynamic_sql_routines_not_in_extensions.count, (p2.dynamic_sql_routines_not_in_extensions.identities || []).length);
  if (p2 && p2.unreadable_language_routines) eq('p2 unreadable-language count', p2.unreadable_language_routines.count, (p2.unreadable_language_routines.identities || []).length);
  if (p2 && p2.compiled_routines) eq('p2 compiled count', p2.compiled_routines.not_in_extensions_count, (p2.compiled_routines.not_in_extensions_identities || []).length);
  if (p3 && Array.isArray(p3.dependent_views)) eq('p3.dependent_views_count', p3.dependent_views_count, p3.dependent_views.length);
  if (p3 && Array.isArray(p3.rewrite_rules_on_targets_and_dependents)) eq('p3.rewrite_rules_count', p3.rewrite_rules_count, p3.rewrite_rules_on_targets_and_dependents.length);
  if (p4 && Array.isArray(p4.jobs)) eq('p4.visible_job_rows', p4.visible_job_rows, p4.jobs.length);
  if (p5 && Array.isArray(p5.auth_users_triggers)) eq('p5.auth_users_trigger_count', p5.auth_users_trigger_count, p5.auth_users_triggers.length);
  if (p5 && Array.isArray(p5.chain_functions)) eq('p5.chain_function_count', p5.chain_function_count, p5.chain_functions.length);
  if (p5 && Array.isArray(p5.auth_users_triggers) && Array.isArray(p5.chain_functions)) {
    const have = new Set(p5.chain_functions.map((c) => `${c.schema}.${c.name}(${c.args})`));
    for (const t of p5.auth_users_triggers) { const id = `${t.function_schema}.${t.function}(${t.function_args})`; if (!have.has(id)) errors.push(`p5: trigger function ${id} is not among chain_functions`); }
  }
  if (d4 && Array.isArray(d4.undisposed) && Array.isArray(d4.disposed)) {
    eq('d4.undisposed_count', d4.undisposed_count, d4.undisposed.length);
    eq('d4.disposed_count', d4.disposed_count, d4.disposed.length);
    if (d4.unresolved_count !== d4.undisposed_count + d4.disposed_count) errors.push('d4: unresolved_count is not disposed_count + undisposed_count');
  }
  if (!clearances || typeof clearances !== 'object' || Array.isArray(clearances)) errors.push('clearances: not a JSON object (use {} for none)');
  else for (const [k, v] of Object.entries(clearances)) {
    if (typeof v !== 'string' || v.trim().length < 10) errors.push(`clearances["${k}"]: a reason of at least 10 characters is required`);
    if (/^extension_(dynamic|compiled):/.test(k) && !/^extension_(dynamic|compiled):.+@.+#\d+\|[0-9a-f]{64}$/.test(k)) errors.push(`clearances["${k}"]: extension key must be extension_<dynamic|compiled>:<name>@<version>#<count>|<sha256 hex>`);
  }
  return errors;
}

// ---------------------------------------------------------------- the matrix and the comparison
export function buildMatrix({ p1, p2, p3, p4, p5, p6, d4, allowlist, clearances }) {
  const cells = {};
  for (const r of TARGETS) { cells[r] = {}; for (const k of KINDS) cells[r][k] = { leads: [] }; }
  const add = (rel, kind, lead) => { if (cells[rel] && cells[rel][kind]) cells[rel][kind].leads.push(lead); };
  const global = [];
  const sections = Object.fromEntries(ALLOWLIST_KEYS.map((k) => [k, new Set(allowlist[k])]));
  const usedAllow = new Set(); const usedClear = new Set();
  const allowed = (section, key) => { if (sections[section].has(key)) { usedAllow.add(`${section}|${key}`); return true; } return false; };
  const cleared = (key) => { if (Object.prototype.hasOwnProperty.call(clearances, key)) { usedClear.add(key); return true; } return false; };
  const sink = (rel, kind, key, lead) => {
    if (rel !== 'study_sessions' || !GATED.has(kind)) return;
    if (allowed('study_sessions_sinks', key)) lead.allowlisted = true; else global.push({ kind: 'study_sessions_sink_not_allowlisted', id: key });
  };

  for (const r of p2.routines) {
    for (const rel of r.mentions) for (const [flag, kind] of Object.entries(FLAG_TO_KIND)) {
      if (!r.flags[flag]) continue;
      const lead = { source: 'routine', id: routineId(r), src_md5: r.src_md5, security_definer: r.security_definer, grantees: r.execute_grantees };
      add(rel, kind, lead); sink(rel, kind, `routine:${routineId(r)}|${r.src_md5}`, lead);
    }
  }
  for (const m of p1.mutation_reachability) {
    const kind = m.target_result === 'DELETE' ? 'DELETE' : 'UPDATE';
    const lead = { source: 'foreign_key', id: `${m.ancestor}:${m.ancestor_event}->${m.target_result}`, min_depth: m.min_depth, example_path: m.example_path };
    add(m.target, kind, lead); sink(m.target, kind, `foreign_key:${lead.id}|path=${m.example_path}|depth=${m.min_depth}`, lead);
  }
  const viewRoots = new Map();
  for (const v of p3.dependent_views) {
    const vid = `${v.schema}.${v.view}`; viewRoots.set(vid, v.depends_transitively_on);
    for (const root of v.depends_transitively_on) {
      for (const [flag, kind] of [['accepts_insert', 'INSERT'], ['accepts_update', 'UPDATE'], ['accepts_delete', 'DELETE']]) {
        if (!v[flag]) continue;
        const lead = { source: 'writable_view', id: vid, definition_md5: v.definition_md5 };
        add(root, kind, lead); sink(root, kind, `writable_view:${vid}|${v.definition_md5}`, lead);
      }
    }
  }
  for (const ru of p3.rewrite_rules_on_targets_and_dependents) {
    const kind = RULE_EVENT_TO_KIND[String(ru.event)];
    if (!kind) continue;
    const rid = `${ru.schema}.${ru.relation}#${ru.rule}`;
    const roots = TARGETS.includes(ru.relation) ? [ru.relation] : (viewRoots.get(`${ru.schema}.${ru.relation}`) || []);
    for (const root of roots) {
      const lead = { source: 'rule', id: rid, instead: ru.instead, definition_md5: ru.definition_md5 };
      add(root, kind, lead); sink(root, kind, `rule:${rid}|${ru.definition_md5}`, lead);
    }
  }
  for (const j of p4.jobs) {
    for (const rel of TARGETS) {
      if (!j.flags[`names_${rel}`]) continue;
      for (const [flag, kind] of [['insert', 'INSERT'], ['update', 'UPDATE'], ['delete', 'DELETE'], ['truncate', 'TRUNCATE'], ['merge', 'MERGE'], ['copy', 'COPY']]) {
        if (!j.flags[flag]) continue;
        const lead = { source: 'scheduled_job', id: `job ${j.jobid} ${j.jobname}`, command_md5: j.command_md5 };
        add(rel, kind, lead);
        sink(rel, kind, `scheduled_job:${lead.id}|${j.command_md5}|active=${j.active}|schedule=${j.schedule}|database=${j.database}|username=${j.username}`, lead);
      }
    }
  }
  // direct code writers (D4)
  for (const e of d4.entries) {
    if (e.kind !== 'write' || !cells[e.table]) continue;
    const kind = OP_TO_KIND[e.op];
    const key = `${e.file}|${e.table}|${e.op}|${e.in}`;
    const lead = { source: 'code', id: `${e.file}:${e.line}`, key, payload_keys: e.payload_keys, payload_resolved: e.payload_resolved };
    add(e.table, kind, lead);
    if (e.table === 'study_sessions' && GATED.has(kind)) {
      if (allowed('code_writers', key)) lead.allowlisted = true; else global.push({ kind: 'code_writer_not_allowlisted', id: key });
      if (e.payload_resolved !== true) global.push({ kind: 'code_writer_payload_unresolved', id: key });
    }
  }
  if (d4.git.source_roots_dirty) global.push({ kind: 'd4_not_at_clean_commit', id: `commit ${d4.git.commit} with uncommitted changes in the source roots` });

  // ---- global unresolved items
  for (const r of p2.dynamic_sql_routines_not_in_extensions.identities) { const key = `${routineId(r)}|${r.src_md5}`; if (!cleared(key)) global.push({ kind: 'dynamic_sql_routine_uncleared', id: key }); }
  for (const r of p2.unreadable_language_routines.identities) { const key = routineId(r); if (!cleared(key)) global.push({ kind: 'unreadable_language_routine_uncleared', id: key }); }
  for (const r of p2.compiled_routines.not_in_extensions_identities) { const key = routineId(r); if (!cleared(key)) global.push({ kind: 'compiled_routine_not_in_extension_uncleared', id: key }); }
  for (const e of p2.dynamic_sql_routines_in_extensions_by_extension) { const key = `extension_dynamic:${e.extension}@${e.extversion}#${e.routines}|${e.identity_set_sha256}`; if (!cleared(key)) global.push({ kind: 'extension_dynamic_sql_uncleared', id: key }); }
  for (const e of p2.compiled_routines.in_extensions_by_extension) { const key = `extension_compiled:${e.extension}@${e.extversion}#${e.routines}|${e.identity_set_sha256}`; if (!cleared(key)) global.push({ kind: 'extension_compiled_uncleared', id: key }); }
  if (p4.visibility_unresolved) global.push({ kind: 'cron_visibility_unresolved', id: 'cron.job rows may be hidden from the running role' });
  for (const f of p1.frontier_cut_at_depth_cap) global.push({ kind: 'fk_frontier_cut', id: `${f.target}<-${f.ancestor}` });
  for (const f of p3.frontier_cut_at_depth_cap) global.push({ kind: 'view_frontier_cut', id: f });
  for (const u of d4.undisposed) global.push({ kind: 'code_lead_undisposed', id: u.id });
  for (const u of d4.unparsed_files) global.push({ kind: 'code_file_unparsed', id: u.file });

  // ---- unused entries are stale or over-broad evidence
  const reviewed = sections.reviewed_unused;
  for (const section of ['study_sessions_sinks', 'code_writers']) for (const entry of sections[section]) if (!usedAllow.has(`${section}|${entry}`) && !reviewed.has(`${section}|${entry}`)) global.push({ kind: 'allowlist_entry_unused', id: `${section}|${entry}` });
  for (const k of Object.keys(clearances)) if (!usedClear.has(k) && !reviewed.has(`clearances|${k}`)) global.push({ kind: 'clearance_unused', id: k });

  for (const r of TARGETS) for (const k of KINDS) {
    const c = cells[r][k];
    c.leads.sort((a, b) => (a.source + a.id).localeCompare(b.source + b.id));
    c.status = c.leads.length ? (global.length ? 'leads_and_unresolved' : 'leads') : (global.length ? 'unresolved' : 'none_found');
  }
  const seen = new Set();
  const uniq = global.filter((g) => { const k = g.kind + '\u0000' + g.id; if (seen.has(k)) return false; seen.add(k); return true; });
  uniq.sort((a, b) => (a.kind + a.id).localeCompare(b.kind + b.id));
  const advisory = { p6_closure_size: p6.closure_size, p6_frontier_edges: p6.frontier_edges_outside_closure.length, note: 'P6 is an advisory over-approximation; it neither clears nor blocks' };
  const locked = { cells, global_unresolved: uniq };
  return { ...locked, advisory, d4_commit: d4.git.commit, result_sha256: sha256(stableStringify(locked)) };
}

export function renderMarkdown(m) {
  const lines = ['| relation | ' + KINDS.join(' | ') + ' |', '|---|' + KINDS.map(() => '---').join('|') + '|'];
  for (const r of TARGETS) lines.push(`| ${r} | ` + KINDS.map((k) => { const c = m.cells[r][k]; return `${c.status}${c.leads.length ? ` (${c.leads.length})` : ''}`; }).join(' | ') + ' |');
  lines.push('', `Global unresolved items: ${m.global_unresolved.length}`);
  for (const g of m.global_unresolved) lines.push(`- ${g.kind}: ${g.id}`);
  lines.push('', `d4 commit: ${m.d4_commit}`, `result_sha256: ${m.result_sha256}`);
  return lines.join('\n') + '\n';
}

export function exitCodeFor(m) {
  if (m.global_unresolved.length) return 3;
  for (const r of TARGETS) for (const k of KINDS) if (m.cells[r][k].status.includes('unresolved')) return 3;
  return 0;
}

// ---------------------------------------------------------------- self-test (synthetic inputs only)
const clone = (o) => JSON.parse(JSON.stringify(o));
const h32 = (c) => c.repeat(32).slice(0, 32);
const h64 = (c) => c.repeat(64).slice(0, 64);
export function synthetic() {
  const jobFlags = Object.fromEntries(JOB_FLAGS.map((f) => [f, false]));
  const rflags = (o) => ({ ...Object.fromEntries(ROUTINE_FLAGS.map((f) => [f, false])), ...o });
  const p1 = { run: 'D3-P1', tool_version: D3_VERSION, targets_found: 8, depth_cap: 12, direct_foreign_key_count: 1, mutation_reachability_count: 1,
    direct_foreign_keys: [{ constraint: 'study_sessions_user_id_fkey', child: 'study_sessions', parent: 'auth.users', definition_md5: h32('1') }],
    mutation_reachability: [{ target: 'study_sessions', ancestor: 'auth.users', ancestor_event: 'DELETE', target_result: 'DELETE', min_depth: 1, example_path: 'study_sessions_user_id_fkey' }], frontier_cut_at_depth_cap: [] };
  const p2 = { run: 'D3-P2', tool_version: D3_VERSION, routines_scanned: 300, routines_naming_a_target: 3,
    routines: [{ schema: 'public', name: 'purge_notes', args: '', mentions: ['notes'], src_md5: h32('a'), security_definer: true, execute_grantees: ['postgres'], flags: rflags({ delete: true }) },
               { schema: 'public', name: 'upsert_profile', args: 'p uuid', mentions: ['profiles'], src_md5: h32('b'), security_definer: true, execute_grantees: [], flags: rflags({ on_conflict_do_update: true, insert: true }) },
               { schema: 'public', name: 'log_session', args: '', mentions: ['study_sessions'], src_md5: h32('c'), security_definer: false, execute_grantees: [], flags: rflags({ insert: true }) }],
    dynamic_sql_routines_not_in_extensions: { count: 1, identities: [{ schema: 'public', name: 'dyn', args: '', src_md5: h32('d') }] },
    dynamic_sql_routines_in_extensions_by_extension: [{ extension: 'pg_net', extversion: '0.14', routines: 2, identity_set_sha256: h64('1') }],
    unreadable_language_routines: { count: 0, identities: [] },
    compiled_routines: { not_in_extensions_count: 0, not_in_extensions_identities: [], in_extensions_by_extension: [{ extension: 'pgcrypto', extversion: '1.3', routines: 40, identity_set_sha256: h64('2') }] } };
  const p3 = { run: 'D3-P3', tool_version: D3_VERSION, depth_cap: 8, dependent_views_count: 1, rewrite_rules_count: 1,
    dependent_views: [{ schema: 'public', view: 'v_notes', depends_transitively_on: ['notes'], definition_md5: h32('e'), accepts_update: true, accepts_insert: false, accepts_delete: false }],
    rewrite_rules_on_targets_and_dependents: [{ schema: 'public', relation: 'v_notes', rule: 'r1', event: '4', instead: true, definition_md5: h32('f') }], frontier_cut_at_depth_cap: [] };
  const p4 = { run: 'D3-P4', tool_version: D3_VERSION, visibility_unresolved: false, visible_job_rows: 1,
    jobs: [{ jobid: 4, jobname: 'j', schedule: '*/15 * * * *', active: true, database: 'postgres', username: 'postgres', command_md5: h32('9'), flags: { ...jobFlags, names_flashcards: true, delete: true } }] };
  const p5 = { run: 'D3-P5', tool_version: D3_VERSION, auth_users_trigger_count: 1, chain_function_count: 1,
    auth_users_triggers: [{ name: 'on_auth_user_created', function_schema: 'public', function: 'on_signup', function_args: '' }], chain_functions: [{ schema: 'public', name: 'on_signup', args: '', definition_md5: h32('7') }] };
  const p6 = { run: 'D3-P6', tool_version: D3_VERSION, closure_size: 3, relevant_routines: [], frontier_edges_outside_closure: [] };
  const d4 = { tool: D4_TOOL, files_scanned: 178, unresolved_count: 0, disposed_count: 0, undisposed_count: 0, git: { commit: 'a'.repeat(40), source_roots_dirty: false },
    undisposed: [], disposed: [], unparsed_files: [],
    entries: [{ kind: 'write', table: 'study_sessions', op: 'insert', file: 'src/a.js', line: 3, in: 'saveSession', payload_keys: ['user_id'], payload_resolved: true }, { kind: 'read', table: 'notes', op: 'select', file: 'src/b.js', line: 1, in: 'load' }] };
  const allowlist = { study_sessions_sinks: [`routine:public.log_session()|${h32('c')}`], code_writers: ['src/a.js|study_sessions|insert|saveSession'], reviewed_unused: [] };
  const clearances = { [`public.dyn()|${h32('d')}`]: 'read: no DML on target relations', [`extension_dynamic:pg_net@0.14#2|${h64('1')}`]: 'reviewed extension content', [`extension_compiled:pgcrypto@1.3#40|${h64('2')}`]: 'reviewed extension content' };
  return { p1, p2, p3, p4, p5, p6, d4, allowlist, clearances };
}

export function selfTest() {
  const failures = []; let total = 0;
  const check = (name, ok) => { total += 1; if (!ok) failures.push(name); };
  const Z = synthetic();
  const build = (mut) => { const x = clone(Z); if (mut) mut(x); return { x, errors: validateInputs(x), m: buildMatrix(x) }; };
  const bad = (mut) => { const x = clone(Z); mut(x); return validateInputs(x).length > 0; };
  const stops = (r, kind) => r.m.global_unresolved.some((g) => g.kind === kind);
  const rf = (o) => ({ insert: false, update: false, delete: false, truncate: false, merge: false, copy: false, on_conflict_do_update: false, dynamic_sql_execute: false, ddl_word: false, ...o });
  let r = build();
  check('the synthetic baseline validates', r.errors.length === 0);
  check('a fully allowlisted, cleared and used baseline has no global unresolved item and exits 0', r.m.global_unresolved.length === 0 && exitCodeFor(r.m) === 0);
  check('an empty cell is none_found only when nothing is unresolved', r.m.cells.topics.TRUNCATE.status === 'none_found');
  check('a cascade foreign key is a DELETE lead and DELETE leads need no allowlist entry', r.m.cells.study_sessions.DELETE.leads.some((l) => l.source === 'foreign_key'));
  check('a code insert is a lead; a code read is not', r.m.cells.study_sessions.INSERT.leads.some((l) => l.source === 'code' && l.allowlisted) && r.m.cells.notes.INSERT.leads.length === 0);
  check('ON CONFLICT DO UPDATE is an UPSERT lead', r.m.cells.profiles.UPSERT.leads.some((l) => l.id === 'public.upsert_profile(p uuid)'));
  check('a writable view and an INSTEAD rule reach the base relation', r.m.cells.notes.UPDATE.leads.some((l) => l.source === 'writable_view') && r.m.cells.notes.DELETE.leads.some((l) => l.source === 'rule'));
  check('a scheduled job naming a relation and DELETE is a DELETE lead', r.m.cells.flashcards.DELETE.leads.some((l) => l.source === 'scheduled_job'));
  // simplified DEC-4: removal paths are informational, add/relabel paths are gated
  r = build((x) => { x.p2.routines.push({ schema: 'public', name: 'purge_sessions', args: '', mentions: ['study_sessions'], src_md5: h32('5'), security_definer: true, execute_grantees: [], flags: rf({ delete: true, truncate: true }) }); x.p2.routines_naming_a_target = 4; });
  check('a routine that only DELETES or TRUNCATES study_sessions is informational (no stop)', r.m.global_unresolved.length === 0 && r.m.cells.study_sessions.TRUNCATE.leads.length === 1);
  r = build((x) => { x.p2.routines.push({ schema: 'public', name: 'sneak', args: '', mentions: ['study_sessions'], src_md5: h32('6'), security_definer: true, execute_grantees: [], flags: rf({ update: true }) }); x.p2.routines_naming_a_target = 4; });
  check('a routine that UPDATES study_sessions and is not allowlisted is a named stop', stops(r, 'study_sessions_sink_not_allowlisted') && exitCodeFor(r.m) === 3);
  r = build((x) => { x.p2.routines[2].src_md5 = h32('0'); });
  check('an allowlisted routine whose body hash changed is not allowlisted any more', stops(r, 'study_sessions_sink_not_allowlisted') && stops(r, 'allowlist_entry_unused'));
  r = build((x) => { x.p1.mutation_reachability.push({ target: 'study_sessions', ancestor: 'other.parent', ancestor_event: 'DELETE', target_result: 'UPDATE', min_depth: 2, example_path: 'a > b' }); x.p1.mutation_reachability_count = 2; });
  check('a SET NULL / SET DEFAULT foreign-key path (an UPDATE result) is gated by its exact path key', stops(r, 'study_sessions_sink_not_allowlisted'));
  r = build((x) => { x.p1.mutation_reachability.push({ target: 'study_sessions', ancestor: 'auth.users', ancestor_event: 'DELETE', target_result: 'UPDATE', min_depth: 1, example_path: 'second_fkey' }); x.p1.mutation_reachability_count = 2; });
  check('a second path with the same ancestor and event is a separate gated key (no collision)', stops(r, 'study_sessions_sink_not_allowlisted'));
  r = build((x) => { x.p3.dependent_views.push({ schema: 'public', view: 'v_ss', depends_transitively_on: ['study_sessions'], definition_md5: h32('8'), accepts_update: true, accepts_insert: false, accepts_delete: false }); x.p3.dependent_views_count = 2; });
  check('a writable view over study_sessions is gated', stops(r, 'study_sessions_sink_not_allowlisted'));
  r = build((x) => { x.p4.jobs[0].flags.names_study_sessions = true; x.p4.jobs[0].flags.update = true; });
  check('a scheduled job that updates study_sessions is gated by its exact key', stops(r, 'study_sessions_sink_not_allowlisted'));
  // direct code writers
  r = build((x) => { x.d4.entries.push({ kind: 'write', table: 'study_sessions', op: 'delete', file: 'src/c.js', line: 9, in: 'wipe', payload_resolved: true }); });
  check('a direct code DELETE of study_sessions is informational', r.m.global_unresolved.length === 0 && r.m.cells.study_sessions.DELETE.leads.some((l) => l.source === 'code'));
  r = build((x) => { x.d4.entries.push({ kind: 'write', table: 'study_sessions', op: 'update', file: 'src/c.js', line: 9, in: 'relabel', payload_resolved: true }); });
  check('QA probe: a direct code UPDATE of study_sessions that is not allowlisted is a named stop (not exit 0)', stops(r, 'code_writer_not_allowlisted') && exitCodeFor(r.m) === 3);
  r = build((x) => { x.d4.entries[0].payload_resolved = false; });
  check('an allowlisted code writer with an unresolved payload is a stop', stops(r, 'code_writer_payload_unresolved'));
  r = build((x) => { x.d4.git.source_roots_dirty = true; });
  check('a D4 inventory taken on a dirty source tree is a stop', stops(r, 'd4_not_at_clean_commit'));
  r = build((x) => { x.d4.undisposed = [{ id: 'src/x.js:9:from_non_literal_table' }]; x.d4.undisposed_count = 1; x.d4.unresolved_count = 1; });
  check('an undisposed code lead keeps the matrix unresolved', stops(r, 'code_lead_undisposed'));
  // clearances, extensions, unused
  r = build((x) => { x.clearances = {}; });
  check('uncleared dynamic routine and extensions each make cells unresolved', r.m.cells.topics.TRUNCATE.status === 'unresolved' && stops(r, 'dynamic_sql_routine_uncleared') && stops(r, 'extension_dynamic_sql_uncleared') && stops(r, 'extension_compiled_uncleared'));
  r = build((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].identity_set_sha256 = h64('9'); });
  check('an extension whose identity-set hash changed is not cleared', stops(r, 'extension_compiled_uncleared') && stops(r, 'clearance_unused'));
  r = build((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].routines = 41; });
  check('an extension whose routine count changed is not cleared', stops(r, 'extension_compiled_uncleared'));
  r = build((x) => { x.p4.visibility_unresolved = true; });
  check('cron visibility unresolved makes the matrix unresolved', exitCodeFor(r.m) === 3);
  r = build((x) => { x.allowlist.code_writers.push('src/ghost.js|study_sessions|insert|g'); });
  check('an unused allowlist entry is a stop', stops(r, 'allowlist_entry_unused'));
  r = build((x) => { x.allowlist.code_writers.push('src/ghost.js|study_sessions|insert|g'); x.allowlist.reviewed_unused.push('code_writers|src/ghost.js|study_sessions|insert|g'); });
  check('an unused entry listed as reviewed_unused is accepted', r.m.global_unresolved.length === 0);
  r = build((x) => { x.clearances['public.never_used()'] = 'a reason that is long enough'; });
  check('an unused clearance is a stop', stops(r, 'clearance_unused'));
  // validation
  check('p2.routines = [{}] is a bad input', bad((x) => { x.p2.routines = [{}]; }));
  check('p4.jobs = [{}] is a bad input', bad((x) => { x.p4.jobs = [{}]; }));
  check('d4.entries = [{}] is a bad input', bad((x) => { x.d4.entries = [{}]; }));
  check('a truncated P2 routine list (count says 3, list has 2) is a bad input', bad((x) => { x.p2.routines.pop(); }));
  check('a truncated P1 path list is a bad input', bad((x) => { x.p1.mutation_reachability = []; }));
  check('a truncated P3 view or rule list is a bad input', bad((x) => { x.p3.dependent_views = []; }) && bad((x) => { x.p3.rewrite_rules_on_targets_and_dependents = []; }));
  check('a truncated P4 job list is a bad input', bad((x) => { x.p4.jobs = []; }));
  check('P1 reporting fewer than eight targets is a bad input', bad((x) => { x.p1.targets_found = 7; }));
  check('p5.chain_functions = [] while P5 lists a trigger function is a bad input', bad((x) => { x.p5.chain_functions = []; x.p5.chain_function_count = 0; }));
  check('a wrong tool_version or a missing P6 is a bad input', bad((x) => { x.p3.tool_version = 'D3-v6'; }) && bad((x) => { delete x.p6; }));
  check('a D4 file from another tool version, without a commit, or with inconsistent counts is a bad input', bad((x) => { x.d4.tool = 'D-04_code-inventory_v6.mjs'; }) && bad((x) => { x.d4.git.commit = 'abc'; }) && bad((x) => { x.d4.unresolved_count = 5; }));
  check('a write entry without a table, a boolean payload flag or an enclosing function is a bad input', bad((x) => { x.d4.entries.push({ kind: 'write', file: 'f', line: 1, in: 'g', op: 'insert', payload_resolved: true }); }) && bad((x) => { delete x.d4.entries[0].payload_resolved; }) && bad((x) => { delete x.d4.entries[0].in; }));
  check('an allowlist missing a section is a bad input', bad((x) => { delete x.allowlist.code_writers; }));
  check('an extension with a null name, empty version, fractional count or short hash is a bad input', bad((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].extension = null; }) && bad((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].extversion = ''; }) && bad((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].routines = 1.5; }) && bad((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].identity_set_sha256 = h32('a'); }));
  check('a clearance with a short reason or a malformed extension key is a bad input', bad((x) => { x.clearances[`public.dyn()|${h32('d')}`] = 'ok'; }) && bad((x) => { x.clearances['extension_dynamic:pg_net@0.14|short'] = 'a reason that is long enough'; }));
  check('a P6 frontier edge without callee fields is a bad input', bad((x) => { x.p6.frontier_edges_outside_closure = [{ caller_name: 'a' }]; }));
  const a = buildMatrix(clone(Z)), b = buildMatrix(clone(Z));
  check('the output and its result_sha256 are deterministic', stableStringify(a) === stableStringify(b) && /^[0-9a-f]{64}$/.test(a.result_sha256));
  check('reordering the allowlist does not change the result hash', (() => { const x = clone(Z); x.allowlist.study_sessions_sinks.reverse(); return buildMatrix(x).result_sha256 === a.result_sha256; })());
  return { total, failures };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
if (isMain) {
  const args = process.argv.slice(2);
  const get = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
  const st = selfTest();
  if (args.includes('--self-test')) { console.log(JSON.stringify(st, null, 2)); process.exit(st.failures.length ? 1 : 0); }
  if (st.failures.length) { console.error('self-test failed'); console.error(JSON.stringify(st, null, 2)); process.exit(1); }
  const need = ['--p1', '--p2', '--p3', '--p4', '--p5', '--p6', '--d4', '--allowlist'];
  if (need.some((k) => !get(k))) { console.error('missing input: ' + need.filter((k) => !get(k)).join(', ')); process.exit(1); }
  const read = (p) => { const buf = fs.readFileSync(p); return { obj: JSON.parse(buf.toString('utf8')), sha256: crypto.createHash('sha256').update(buf).digest('hex') }; };
  const inputs = {}; const loaded = {};
  try {
    for (const k of ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'd4', 'allowlist']) { const r = read(get('--' + k)); loaded[k] = r.obj; inputs[k] = { file: get('--' + k), sha256: r.sha256 }; }
    if (get('--clearances')) { const r = read(get('--clearances')); loaded.clearances = r.obj; inputs.clearances = { file: get('--clearances'), sha256: r.sha256 }; } else { loaded.clearances = {}; inputs.clearances = { file: null, sha256: sha256('{}') }; }
  } catch (e) { console.error('cannot read an input: ' + e.message); process.exit(1); }
  const errors = validateInputs(loaded);
  if (errors.length) { console.error('BAD INPUT (nothing computed):\n- ' + errors.slice(0, 60).join('\n- ')); process.exit(1); }
  const m = buildMatrix(loaded);
  const out = { tool: 'D-05_writer-matrix_v5.mjs', inputs, ...m };
  const text = stableStringify(out);
  if (get('--out')) fs.writeFileSync(get('--out'), text, 'utf8'); else console.log(text);
  if (get('--md')) fs.writeFileSync(get('--md'), renderMarkdown(m), 'utf8');
  process.exit(exitCodeFor(m));
}
