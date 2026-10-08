// D-05_writer-matrix_v2.mjs - T-002 deterministic writer matrix and sink/allowlist comparison (v2).
//
// v2 answers QA Round 20, which returned v1 (`38b08065a470`) as REVISION REQUIRED (v1 was never used for evidence):
//  1. EXTENSION routines are no longer ignored. D3 v4 P2 returns, per extension, the version, the routine count and an identity-set hash for (a) extension-owned
//     dynamic-SQL routines and (b) extension-owned compiled routines. Each is a global unresolved stop unless a clearance bound to the exact key
//     `extension_dynamic:<name>@<version>|<identity_set_md5>` / `extension_compiled:<name>@<version>|<identity_set_md5>` is supplied.
//  2. EVERY input is validated against the exact D3 v4 / D4 v4 shape and hashed: P1 to P7, D4, the clearances and the allowlist. A missing field, a wrong type, a
//     wrong `run`, a wrong `tool_version`, or a count that disagrees with its list is a bad input (exit status 1), never an empty default.
//  3. An ALLOWLIST file (hashed) is compared by exact identity and body or definition hash. The comparison is implemented here, not by hand:
//       - every routine, foreign key, writable view, rule and scheduled job that can write study_sessions (P1, P2, P3, P4) must be in `study_sessions_sinks`;
//       - on auth.users (P5, P7): every role holding DELETE, TRUNCATE or UPDATE, every flagged routine, every indirect wrapper, every foreign key that references
//         it, every trigger, every rewrite rule and every trigger function must be in its allowlist section; PUBLIC holding any of those privileges, a non-empty
//         wrapper frontier, or a missing / changed `study_sessions_user_id_fkey` (delete action `c`) is a named stop.
//     Anything not allowlisted is a named item in `global_unresolved`; the exit status is then 3.
//  4. The output carries `result_sha256`, the hash of the locked comparison (cells + global_unresolved), next to the hashes of all inputs.
//  P6 (the callee closure) is an advisory over-approximation: its hash and its frontier are reported but it never clears or blocks anything.
//
// It reads files and runs no database statement. Cells: leads / none_found / unresolved / leads_and_unresolved, exactly as in v1; `none_found` is possible only
// when no global unresolved item exists anywhere.
//
// Allowlist file (JSON object of arrays of strings; every key must be present, an empty array is a deliberate statement):
//   study_sessions_sinks     `routine:<schema>.<name>(<args>)|<src_md5>`, `foreign_key:<id>`, `writable_view:<id>`, `rule:<id>|<definition_md5>`, `scheduled_job:<id>|<command_md5>`
//   auth_users_roles         role names allowed to hold DELETE, TRUNCATE or UPDATE on auth.users
//   auth_users_routines      `<schema>.<name>(<args>)|<src_md5>` for P7 routines that name auth.users with a write or EXECUTE word
//   auth_users_wrappers      same shape, for P7 indirect wrappers
//   auth_users_foreign_keys  `<child>.<constraint>|<definition_md5>`
//   auth_users_triggers      `<trigger name>|<definition_md5>`
//   auth_users_rules         `<rule name>|<definition_md5>`
//   auth_users_chain_functions `<schema>.<name>(<args>)|<definition_md5>` for the P5 trigger-chain functions
// Clearances file (JSON object key -> reason): `<schema>.<name>(<args>)|<src_md5>` for a dynamic-SQL routine, `<schema>.<name>(<args>)` for an unreadable or
// compiled routine, and the two extension key shapes above. A clearance is reviewed work and part of the audited evidence; the script never invents one.
//
// Usage:
//   node docs/database/t002/D-05_writer-matrix_v2.mjs --self-test
//   node docs/database/t002/D-05_writer-matrix_v2.mjs --p1 P1.json ... --p7 P7.json --d4 d4.json --allowlist allow.json [--clearances c.json] --out matrix.json [--md matrix.md]
// Exit status: 0 only when nothing is unresolved; 3 when any cell or global item is unresolved (fail closed); 1 on a bad input.

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
export const D3_VERSION = 'D3-v4';
export const D4_TOOL = 'D-04_code-inventory_v4.mjs';
export const ALLOWLIST_KEYS = ['study_sessions_sinks', 'auth_users_roles', 'auth_users_routines', 'auth_users_wrappers', 'auth_users_foreign_keys', 'auth_users_triggers', 'auth_users_rules', 'auth_users_chain_functions'];
const CASCADE_FK = 'study_sessions_user_id_fkey';

function stable(v) {
  if (Array.isArray(v)) return v.map(stable);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, stable(v[k])]));
  return v;
}
export const stableStringify = (v) => JSON.stringify(stable(v), null, 1);
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

// ---------------------------------------------------------------- input validation (a bad shape is an error, never an empty default)
export function validateInputs({ p1, p2, p3, p4, p5, p6, p7, d4, allowlist, clearances }) {
  const errors = [];
  const isArr = Array.isArray;
  const need = (cond, msg) => { if (!cond) errors.push(msg); };
  const obj = (v) => v && typeof v === 'object' && !isArr(v);
  const runs = { p1, p2, p3, p4, p5, p6, p7 };
  for (const [k, v] of Object.entries(runs)) {
    if (!obj(v)) { errors.push(`${k}: not a JSON object`); continue; }
    need(v.run === `D3-${k.toUpperCase()}`, `${k}: run is ${JSON.stringify(v.run)}, expected D3-${k.toUpperCase()}`);
    need(v.tool_version === D3_VERSION, `${k}: tool_version is ${JSON.stringify(v.tool_version)}, expected ${D3_VERSION}`);
  }
  if (obj(p1)) { need(isArr(p1.mutation_reachability), 'p1.mutation_reachability must be an array'); need(isArr(p1.frontier_cut_at_depth_cap), 'p1.frontier_cut_at_depth_cap must be an array'); need(typeof p1.targets_found === 'number', 'p1.targets_found must be a number'); }
  if (obj(p2)) {
    need(isArr(p2.routines), 'p2.routines must be an array');
    const dyn = p2.dynamic_sql_routines_not_in_extensions;
    need(obj(dyn) && isArr(dyn.identities) && typeof dyn.count === 'number' && dyn.count === dyn.identities.length, 'p2.dynamic_sql_routines_not_in_extensions: identities missing or count disagrees');
    need(isArr(p2.dynamic_sql_routines_in_extensions_by_extension), 'p2.dynamic_sql_routines_in_extensions_by_extension must be an array');
    const un = p2.unreadable_language_routines;
    need(obj(un) && isArr(un.identities) && un.count === un.identities.length, 'p2.unreadable_language_routines: identities missing or count disagrees');
    const cr = p2.compiled_routines;
    need(obj(cr) && isArr(cr.not_in_extensions_identities) && cr.not_in_extensions_count === cr.not_in_extensions_identities.length && isArr(cr.in_extensions_by_extension), 'p2.compiled_routines: lists missing or count disagrees');
    for (const e of [...(p2.dynamic_sql_routines_in_extensions_by_extension || []), ...((cr || {}).in_extensions_by_extension || [])]) {
      need(obj(e) && 'extension' in e && 'extversion' in e && typeof e.routines === 'number' && typeof e.identity_set_md5 === 'string', 'p2 extension row lacks extension / extversion / routines / identity_set_md5');
    }
  }
  if (obj(p3)) { need(isArr(p3.dependent_views), 'p3.dependent_views must be an array'); need(isArr(p3.rewrite_rules_on_targets_and_dependents), 'p3.rewrite_rules_on_targets_and_dependents must be an array'); need(isArr(p3.frontier_cut_at_depth_cap), 'p3.frontier_cut_at_depth_cap must be an array'); }
  if (obj(p4)) { need(typeof p4.visibility_unresolved === 'boolean', 'p4.visibility_unresolved must be a boolean'); need(isArr(p4.jobs), 'p4.jobs must be an array'); }
  if (obj(p5)) { need(isArr(p5.auth_users_triggers), 'p5.auth_users_triggers must be an array'); need(isArr(p5.chain_functions), 'p5.chain_functions must be an array'); }
  if (obj(p6)) { need(isArr(p6.relevant_routines), 'p6.relevant_routines must be an array'); need(isArr(p6.frontier_edges_outside_closure), 'p6.frontier_edges_outside_closure must be an array'); }
  if (obj(p7)) {
    need(p7.auth_users_found === 1, `p7.auth_users_found must be 1 (got ${JSON.stringify(p7.auth_users_found)})`);
    for (const k of ['effective_privileges_of_roles_holding_any_of_delete_truncate_update', 'public_pseudo_role_privileges_from_acl', 'foreign_keys_referencing_auth_users', 'rewrite_rules_on_auth_users', 'triggers_on_auth_users', 'indirect_wrappers_of_those_routines', 'wrapper_frontier_beyond_depth_3', 'routines_naming_auth_users_with_delete_truncate_or_dynamic_sql']) need(isArr(p7[k]), `p7.${k} must be an array`);
  }
  if (!obj(d4)) errors.push('d4: not a JSON object');
  else {
    need(d4.tool === D4_TOOL, `d4.tool is ${JSON.stringify(d4.tool)}, expected ${D4_TOOL}`);
    need(isArr(d4.entries) && isArr(d4.undisposed) && isArr(d4.unparsed_files), 'd4.entries, d4.undisposed and d4.unparsed_files must be arrays');
  }
  if (!obj(allowlist)) errors.push('allowlist: not a JSON object');
  else for (const k of ALLOWLIST_KEYS) need(isArr(allowlist[k]) && allowlist[k].every((x) => typeof x === 'string'), `allowlist.${k} must be present and an array of strings`);
  need(obj(clearances), 'clearances: not a JSON object (use {} for none)');
  return errors;
}

// ---------------------------------------------------------------- the matrix and the comparison
export function buildMatrix({ p1, p2, p3, p4, p5, p6, p7, d4, allowlist, clearances }) {
  const cells = {};
  for (const r of TARGETS) { cells[r] = {}; for (const k of KINDS) cells[r][k] = { leads: [] }; }
  const add = (rel, kind, lead) => { if (cells[rel] && cells[rel][kind]) cells[rel][kind].leads.push(lead); };
  const global = [];
  const sinkKeys = new Set(allowlist.study_sessions_sinks);
  const used = { study_sessions_sinks: new Set() };
  const sink = (key, lead) => { // a lead that can write study_sessions must be allowlisted by exact key
    if (sinkKeys.has(key)) { used.study_sessions_sinks.add(key); lead.allowlisted = true; }
    else global.push({ kind: 'study_sessions_sink_not_allowlisted', id: key });
  };

  for (const r of p2.routines) {
    for (const rel of r.mentions || []) for (const [flag, kind] of Object.entries(FLAG_TO_KIND)) {
      if (r.flags && r.flags[flag]) {
        const lead = { source: 'routine', id: routineId(r), src_md5: r.src_md5, security_definer: r.security_definer, grantees: r.execute_grantees };
        add(rel, kind, lead);
        if (rel === 'study_sessions') sink(`routine:${routineId(r)}|${r.src_md5}`, lead);
      }
    }
  }
  const seenSinkKeys = new Set();
  const sinkOnce = (key, lead) => { if (!seenSinkKeys.has(key)) { seenSinkKeys.add(key); sink(key, lead); } else if (sinkKeys.has(key)) lead.allowlisted = true; };
  // foreign-key actions (indirect writes)
  for (const m of p1.mutation_reachability) {
    const kind = m.target_result === 'DELETE' ? 'DELETE' : 'UPDATE';
    const lead = { source: 'foreign_key', id: `${m.ancestor}:${m.ancestor_event}->${m.target_result}`, min_depth: m.min_depth, example_path: m.example_path };
    add(m.target, kind, lead);
    if (m.target === 'study_sessions') sinkOnce(`foreign_key:${lead.id}`, lead);
  }
  // writable views and rules
  const viewRoots = new Map();
  for (const v of p3.dependent_views) {
    const vid = `${v.schema}.${v.view}`; viewRoots.set(vid, v.depends_transitively_on || []);
    for (const root of v.depends_transitively_on || []) {
      for (const [flag, kind] of [['accepts_insert', 'INSERT'], ['accepts_update', 'UPDATE'], ['accepts_delete', 'DELETE']]) {
        if (!v[flag]) continue;
        const lead = { source: 'writable_view', id: vid };
        add(root, kind, lead);
        if (root === 'study_sessions') sinkOnce(`writable_view:${vid}`, lead);
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
      add(root, kind, lead);
      if (root === 'study_sessions') sinkOnce(`rule:${rid}|${ru.definition_md5}`, lead);
    }
  }
  // scheduled jobs
  for (const j of p4.jobs) {
    for (const rel of TARGETS) {
      if (!j.flags || !j.flags[`names_${rel}`]) continue;
      for (const [flag, kind] of [['insert', 'INSERT'], ['update', 'UPDATE'], ['delete', 'DELETE'], ['truncate', 'TRUNCATE'], ['merge', 'MERGE'], ['copy', 'COPY']]) {
        if (!j.flags[flag]) continue;
        const lead = { source: 'scheduled_job', id: `job ${j.jobid} ${j.jobname}`, command_md5: j.command_md5 };
        add(rel, kind, lead);
        if (rel === 'study_sessions') sinkOnce(`scheduled_job:${lead.id}|${j.command_md5}`, lead);
      }
    }
  }
  // code call sites (D4); the code side is governed by the D4 dispositions
  for (const e of d4.entries) {
    if (e.kind !== 'write' || !cells[e.table]) continue;
    add(e.table, OP_TO_KIND[e.op], { source: 'code', id: `${e.file}:${e.line}`, payload_keys: e.payload_keys, payload_resolved: e.payload_resolved });
  }

  // ---- global unresolved items
  for (const r of p2.dynamic_sql_routines_not_in_extensions.identities) { const key = `${routineId(r)}|${r.src_md5}`; if (!clearances[key]) global.push({ kind: 'dynamic_sql_routine_uncleared', id: key }); }
  for (const r of p2.unreadable_language_routines.identities) { const key = routineId(r); if (!clearances[key]) global.push({ kind: 'unreadable_language_routine_uncleared', id: key }); }
  for (const r of p2.compiled_routines.not_in_extensions_identities) { const key = routineId(r); if (!clearances[key]) global.push({ kind: 'compiled_routine_not_in_extension_uncleared', id: key }); }
  for (const e of p2.dynamic_sql_routines_in_extensions_by_extension) { const key = `extension_dynamic:${e.extension}@${e.extversion}|${e.identity_set_md5}`; if (!clearances[key]) global.push({ kind: 'extension_dynamic_sql_uncleared', id: key }); }
  for (const e of p2.compiled_routines.in_extensions_by_extension) { const key = `extension_compiled:${e.extension}@${e.extversion}|${e.identity_set_md5}`; if (!clearances[key]) global.push({ kind: 'extension_compiled_uncleared', id: key }); }
  if (p4.visibility_unresolved) global.push({ kind: 'cron_visibility_unresolved', id: 'cron.job rows may be hidden from the running role' });
  for (const f of p1.frontier_cut_at_depth_cap) global.push({ kind: 'fk_frontier_cut', id: `${f.target}<-${f.ancestor}` });
  for (const f of p3.frontier_cut_at_depth_cap) global.push({ kind: 'view_frontier_cut', id: String(typeof f === 'object' ? JSON.stringify(f) : f) });
  for (const u of d4.undisposed) global.push({ kind: 'code_lead_undisposed', id: u.id });
  for (const u of d4.unparsed_files) global.push({ kind: 'code_file_unparsed', id: u.file });

  // ---- the auth.users caller closure (P5, P7), compared with the allowlist by exact identity and hash
  const A = (k) => new Set(allowlist[k]);
  const roles = A('auth_users_roles'), routines = A('auth_users_routines'), wrappers = A('auth_users_wrappers'), fks = A('auth_users_foreign_keys');
  const triggers = A('auth_users_triggers'), rules = A('auth_users_rules'), chain = A('auth_users_chain_functions');
  for (const r of p7.effective_privileges_of_roles_holding_any_of_delete_truncate_update) if (!roles.has(r.role)) global.push({ kind: 'auth_users_role_not_allowlisted', id: r.role });
  for (const priv of p7.public_pseudo_role_privileges_from_acl) if (['DELETE', 'TRUNCATE', 'UPDATE'].includes(priv)) global.push({ kind: 'auth_users_public_holds_privilege', id: priv });
  for (const r of p7.routines_naming_auth_users_with_delete_truncate_or_dynamic_sql) { const k = `${routineId(r)}|${r.src_md5}`; if (!routines.has(k)) global.push({ kind: 'auth_users_routine_not_allowlisted', id: k }); }
  for (const w of p7.indirect_wrappers_of_those_routines) { const k = `${routineId(w)}|${w.src_md5}`; if (!wrappers.has(k)) global.push({ kind: 'auth_users_wrapper_not_allowlisted', id: k }); }
  for (const f of p7.wrapper_frontier_beyond_depth_3) global.push({ kind: 'auth_users_wrapper_frontier_cut', id: routineId(f) });
  for (const f of p7.foreign_keys_referencing_auth_users) { const k = `${f.child}.${f.constraint}|${f.definition_md5}`; if (!fks.has(k)) global.push({ kind: 'auth_users_foreign_key_not_allowlisted', id: k }); }
  for (const g of p7.triggers_on_auth_users) { const k = `${g.name}|${g.definition_md5}`; if (!triggers.has(k)) global.push({ kind: 'auth_users_trigger_not_allowlisted', id: k }); }
  for (const g of p7.rewrite_rules_on_auth_users) { const k = `${g.rule}|${g.definition_md5}`; if (!rules.has(k)) global.push({ kind: 'auth_users_rule_not_allowlisted', id: k }); }
  for (const c of p5.chain_functions) { const k = `${routineId(c)}|${c.definition_md5}`; if (!chain.has(k)) global.push({ kind: 'auth_users_chain_function_not_allowlisted', id: k }); }
  const cascade = p7.foreign_keys_referencing_auth_users.filter((f) => f.constraint === CASCADE_FK && /(^|\.)study_sessions$/.test(f.child));
  if (cascade.length !== 1 || cascade[0].delete_action !== 'c') global.push({ kind: 'cascade_foreign_key_missing_or_changed', id: `${CASCADE_FK} must exist exactly once with delete action c` });

  for (const r of TARGETS) for (const k of KINDS) {
    const c = cells[r][k];
    c.leads.sort((a, b) => (a.source + a.id).localeCompare(b.source + b.id));
    c.status = c.leads.length ? (global.length ? 'leads_and_unresolved' : 'leads') : (global.length ? 'unresolved' : 'none_found');
  }
  const seen = new Set();
  const uniq = global.filter((g) => { const k = g.kind + '\u0000' + g.id; if (seen.has(k)) return false; seen.add(k); return true; });
  uniq.sort((a, b) => (a.kind + a.id).localeCompare(b.kind + b.id));
  const allowlist_unused = [...allowlist.study_sessions_sinks].filter((k) => !used.study_sessions_sinks.has(k) && !seenSinkKeys.has(k)).sort();
  const advisory = { p6_closure_size: p6.closure_size, p6_frontier_edges: p6.frontier_edges_outside_closure.length, note: 'P6 is an advisory over-approximation; it neither clears nor blocks' };
  const locked = { cells, global_unresolved: uniq };
  return { ...locked, allowlist_unused_study_sessions_sinks: allowlist_unused, advisory, result_sha256: sha256(stableStringify(locked)) };
}

export function renderMarkdown(m) {
  const lines = ['| relation | ' + KINDS.join(' | ') + ' |', '|---|' + KINDS.map(() => '---').join('|') + '|'];
  for (const r of TARGETS) lines.push(`| ${r} | ` + KINDS.map((k) => { const c = m.cells[r][k]; return `${c.status}${c.leads.length ? ` (${c.leads.length})` : ''}`; }).join(' | ') + ' |');
  lines.push('', `Global unresolved items: ${m.global_unresolved.length}`);
  for (const g of m.global_unresolved) lines.push(`- ${g.kind}: ${g.id}`);
  lines.push('', `result_sha256: ${m.result_sha256}`);
  return lines.join('\n') + '\n';
}

export function exitCodeFor(m) {
  if (m.global_unresolved.length) return 3;
  for (const r of TARGETS) for (const k of KINDS) if (m.cells[r][k].status.includes('unresolved')) return 3;
  return 0;
}

// ---------------------------------------------------------------- self-test (synthetic inputs only)
const clone = (o) => JSON.parse(JSON.stringify(o));
export function synthetic() {
  const p1 = { run: 'D3-P1', tool_version: D3_VERSION, targets_found: 8, mutation_reachability: [{ target: 'study_sessions', ancestor: 'auth.users', ancestor_event: 'DELETE', target_result: 'DELETE', min_depth: 1, example_path: CASCADE_FK }], frontier_cut_at_depth_cap: [] };
  const p2 = {
    run: 'D3-P2', tool_version: D3_VERSION,
    routines: [{ schema: 'public', name: 'purge_notes', args: '', mentions: ['notes'], src_md5: 'aa', security_definer: true, execute_grantees: ['postgres'], flags: { delete: true } },
               { schema: 'public', name: 'upsert_profile', args: 'p uuid', mentions: ['profiles'], src_md5: 'bb', security_definer: true, execute_grantees: [], flags: { on_conflict_do_update: true, insert: true } },
               { schema: 'public', name: 'log_session', args: '', mentions: ['study_sessions'], src_md5: 'ss', security_definer: false, execute_grantees: [], flags: { insert: true } }],
    dynamic_sql_routines_not_in_extensions: { count: 1, identities: [{ schema: 'public', name: 'dyn', args: '', src_md5: 'cc' }] },
    dynamic_sql_routines_in_extensions_by_extension: [{ extension: 'pg_net', extversion: '0.14', routines: 2, identity_set_md5: 'x1' }],
    unreadable_language_routines: { count: 0, identities: [] },
    compiled_routines: { not_in_extensions_count: 0, not_in_extensions_identities: [], in_extensions_by_extension: [{ extension: 'pgcrypto', extversion: '1.3', routines: 40, identity_set_md5: 'x2' }] },
  };
  const p3 = { run: 'D3-P3', tool_version: D3_VERSION, dependent_views: [{ schema: 'public', view: 'v_notes', depends_transitively_on: ['notes'], accepts_update: true, accepts_insert: false, accepts_delete: false }],
               rewrite_rules_on_targets_and_dependents: [{ schema: 'public', relation: 'v_notes', rule: 'r1', event: '4', instead: true, definition_md5: 'dd' }], frontier_cut_at_depth_cap: [] };
  const p4 = { run: 'D3-P4', tool_version: D3_VERSION, visibility_unresolved: false, jobs: [{ jobid: 4, jobname: 'j', command_md5: 'ee', flags: { names_flashcards: true, delete: true } }] };
  const p5 = { run: 'D3-P5', tool_version: D3_VERSION, auth_users_triggers: [], chain_functions: [{ schema: 'public', name: 'on_signup', args: '', definition_md5: 'f1' }] };
  const p6 = { run: 'D3-P6', tool_version: D3_VERSION, closure_size: 3, relevant_routines: [], frontier_edges_outside_closure: [] };
  const p7 = { run: 'D3-P7', tool_version: D3_VERSION, auth_users_found: 1,
    effective_privileges_of_roles_holding_any_of_delete_truncate_update: [{ role: 'postgres', delete: true, truncate: true, update: true }, { role: 'supabase_auth_admin', delete: true, truncate: false, update: true }],
    public_pseudo_role_privileges_from_acl: [],
    foreign_keys_referencing_auth_users: [{ child: 'study_sessions', constraint: CASCADE_FK, delete_action: 'c', update_action: 'a', definition_md5: 'k1' }, { child: 'profiles', constraint: 'profiles_id_fkey', delete_action: 'c', update_action: 'a', definition_md5: 'k2' }],
    rewrite_rules_on_auth_users: [], triggers_on_auth_users: [{ name: 'on_auth_user_created', definition_md5: 't1' }],
    indirect_wrappers_of_those_routines: [{ schema: 'public', name: 'wrap', args: '', src_md5: 'w1' }], wrapper_frontier_beyond_depth_3: [],
    routines_naming_auth_users_with_delete_truncate_or_dynamic_sql: [{ schema: 'public', name: 'admin_delete_user_data', args: 'p uuid', src_md5: 'a1' }] };
  const d4 = { tool: D4_TOOL, entries: [{ kind: 'write', table: 'study_sessions', op: 'insert', file: 'src/a.js', line: 3, payload_keys: ['user_id'], payload_resolved: true }, { kind: 'read', table: 'notes', op: 'select', file: 'src/b.js', line: 1 }], undisposed: [], unparsed_files: [] };
  const allowlist = {
    study_sessions_sinks: ['routine:public.log_session()|ss', 'foreign_key:auth.users:DELETE->DELETE'],
    auth_users_roles: ['postgres', 'supabase_auth_admin'], auth_users_routines: ['public.admin_delete_user_data(p uuid)|a1'], auth_users_wrappers: ['public.wrap()|w1'],
    auth_users_foreign_keys: [`study_sessions.${CASCADE_FK}|k1`, 'profiles.profiles_id_fkey|k2'], auth_users_triggers: ['on_auth_user_created|t1'], auth_users_rules: [],
    auth_users_chain_functions: ['public.on_signup()|f1'],
  };
  const clearances = { 'public.dyn()|cc': 'read: no DML on target relations', 'extension_dynamic:pg_net@0.14|x1': 'reviewed', 'extension_compiled:pgcrypto@1.3|x2': 'reviewed' };
  return { p1, p2, p3, p4, p5, p6, p7, d4, allowlist, clearances };
}

export function selfTest() {
  const failures = []; let total = 0;
  const check = (name, ok) => { total += 1; if (!ok) failures.push(name); };
  const S = synthetic();
  const build = (mut) => { const x = clone(S); if (mut) mut(x); return { x, errors: validateInputs(x), m: buildMatrix(x) }; };
  let r = build();
  check('the synthetic baseline validates', r.errors.length === 0);
  check('a fully allowlisted and cleared baseline has no global unresolved item and exits 0', r.m.global_unresolved.length === 0 && exitCodeFor(r.m) === 0);
  check('an empty cell is none_found only when nothing is unresolved', r.m.cells.topics.TRUNCATE.status === 'none_found');
  check('a foreign-key cascade is a DELETE lead on the target', r.m.cells.study_sessions.DELETE.leads.some((l) => l.source === 'foreign_key' && l.allowlisted));
  check('a code insert is a lead; a code read is not', r.m.cells.study_sessions.INSERT.leads.some((l) => l.source === 'code') && r.m.cells.notes.INSERT.leads.length === 0);
  check('ON CONFLICT DO UPDATE is an UPSERT lead', r.m.cells.profiles.UPSERT.leads.some((l) => l.id === 'public.upsert_profile(p uuid)'));
  check('a writable view and an INSTEAD rule reach the base relation', r.m.cells.notes.UPDATE.leads.some((l) => l.source === 'writable_view') && r.m.cells.notes.DELETE.leads.some((l) => l.source === 'rule'));
  check('a scheduled job naming a relation and DELETE is a DELETE lead', r.m.cells.flashcards.DELETE.leads.some((l) => l.source === 'scheduled_job'));
  r = build((x) => { x.clearances = {}; });
  check('uncleared dynamic routine AND uncleared extensions each make cells unresolved', r.m.cells.topics.TRUNCATE.status === 'unresolved' && r.m.global_unresolved.some((g) => g.kind === 'dynamic_sql_routine_uncleared') && r.m.global_unresolved.some((g) => g.kind === 'extension_dynamic_sql_uncleared') && r.m.global_unresolved.some((g) => g.kind === 'extension_compiled_uncleared') && exitCodeFor(r.m) === 3);
  r = build((x) => { x.clearances['extension_compiled:pgcrypto@1.3|x2'] = ''; delete x.clearances['extension_compiled:pgcrypto@1.3|x2']; x.p2.compiled_routines.in_extensions_by_extension[0].identity_set_md5 = 'CHANGED'; });
  check('an extension clearance for a different identity-set hash does not clear it (synthetic extension case no longer yields a clean cell)', r.m.cells.study_sessions.DELETE.status === 'leads_and_unresolved' && exitCodeFor(r.m) === 3);
  r = build((x) => { x.clearances = { 'public.dyn()|ZZ': 'wrong hash', 'extension_dynamic:pg_net@0.14|x1': 'r', 'extension_compiled:pgcrypto@1.3|x2': 'r' }; });
  check('a clearance for a different body hash does not clear a routine', r.m.global_unresolved.some((g) => g.kind === 'dynamic_sql_routine_uncleared'));
  r = build((x) => { x.p2.routines.push({ schema: 'public', name: 'sneak', args: '', mentions: ['study_sessions'], src_md5: 'zz', security_definer: true, execute_grantees: [], flags: { update: true } }); });
  check('a study_sessions writer routine that is not allowlisted is a named stop', r.m.global_unresolved.some((g) => g.kind === 'study_sessions_sink_not_allowlisted' && g.id === 'routine:public.sneak()|zz') && exitCodeFor(r.m) === 3);
  r = build((x) => { x.p2.routines[2].src_md5 = 'changed'; });
  check('an allowlisted routine whose body hash changed is not allowlisted any more', r.m.global_unresolved.some((g) => g.kind === 'study_sessions_sink_not_allowlisted'));
  r = build((x) => { x.p7.effective_privileges_of_roles_holding_any_of_delete_truncate_update.push({ role: 'rogue', delete: true }); });
  check('a role with DELETE on auth.users outside the allowlist is a named stop', r.m.global_unresolved.some((g) => g.kind === 'auth_users_role_not_allowlisted' && g.id === 'rogue'));
  r = build((x) => { x.p7.public_pseudo_role_privileges_from_acl = ['UPDATE']; });
  check('PUBLIC holding UPDATE on auth.users is a named stop', r.m.global_unresolved.some((g) => g.kind === 'auth_users_public_holds_privilege'));
  r = build((x) => { x.p7.indirect_wrappers_of_those_routines.push({ schema: 'public', name: 'wrap2', args: '', src_md5: 'w2' }); });
  check('an indirect wrapper that is not allowlisted is a named stop', r.m.global_unresolved.some((g) => g.kind === 'auth_users_wrapper_not_allowlisted'));
  r = build((x) => { x.p7.wrapper_frontier_beyond_depth_3.push({ schema: 'public', name: 'deep', args: '' }); });
  check('a cut wrapper frontier is a named stop', r.m.global_unresolved.some((g) => g.kind === 'auth_users_wrapper_frontier_cut'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].delete_action = 'a'; });
  check('a changed cascade action stops (foreign key identity/hash and action)', r.m.global_unresolved.some((g) => g.kind === 'cascade_foreign_key_missing_or_changed'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users.push({ child: 'notes', constraint: 'notes_x_fkey', delete_action: 'c', definition_md5: 'k9' }); });
  check('another foreign key referencing auth.users that is not allowlisted is a named stop', r.m.global_unresolved.some((g) => g.kind === 'auth_users_foreign_key_not_allowlisted'));
  r = build((x) => { x.p7.routines_naming_auth_users_with_delete_truncate_or_dynamic_sql[0].src_md5 = 'a2'; });
  check('an auth.users routine whose body hash changed is a named stop', r.m.global_unresolved.some((g) => g.kind === 'auth_users_routine_not_allowlisted'));
  r = build((x) => { x.p5.chain_functions[0].definition_md5 = 'f2'; });
  check('a changed signup-chain function is a named stop', r.m.global_unresolved.some((g) => g.kind === 'auth_users_chain_function_not_allowlisted'));
  r = build((x) => { x.p7.triggers_on_auth_users.push({ name: 'extra', definition_md5: 't9' }); });
  check('a trigger on auth.users that is not allowlisted is a named stop', r.m.global_unresolved.some((g) => g.kind === 'auth_users_trigger_not_allowlisted'));
  r = build((x) => { x.p4.visibility_unresolved = true; });
  check('cron visibility unresolved makes the matrix unresolved', exitCodeFor(r.m) === 3);
  r = build((x) => { x.d4.undisposed = [{ id: 'src/x.js:9:from_non_literal_table' }]; });
  check('an undisposed code lead keeps the matrix unresolved', r.m.global_unresolved.some((g) => g.kind === 'code_lead_undisposed'));
  // validation
  check('a missing P6 input is a bad input', validateInputs((() => { const x = clone(S); delete x.p6; return x; })()).length > 0);
  check('a wrong tool_version is a bad input', validateInputs((() => { const x = clone(S); x.p3.tool_version = 'D3-v3'; return x; })()).length > 0);
  check('a missing P5 / P6 / P7 input is a bad input, not an empty default', validateInputs((() => { const x = clone(S); x.p7 = {}; return x; })()).length > 0);
  check('a count that disagrees with its identity list is a bad input', validateInputs((() => { const x = clone(S); x.p2.dynamic_sql_routines_not_in_extensions.count = 5; return x; })()).length > 0);
  check('an allowlist missing a key is a bad input', validateInputs((() => { const x = clone(S); delete x.allowlist.auth_users_rules; return x; })()).length > 0);
  check('a D4 file from another tool version is a bad input', validateInputs((() => { const x = clone(S); x.d4.tool = 'D-04_code-inventory_v3.mjs'; return x; })()).length > 0);
  check('an extension row without an identity-set hash is a bad input', validateInputs((() => { const x = clone(S); delete x.p2.compiled_routines.in_extensions_by_extension[0].identity_set_md5; return x; })()).length > 0);
  const a = buildMatrix(clone(S)), b = buildMatrix(clone(S));
  check('the output and its result_sha256 are deterministic', stableStringify(a) === stableStringify(b) && /^[0-9a-f]{64}$/.test(a.result_sha256));
  check('a changed allowlist changes the locked comparison hash only through its effect (baseline hash stable under reordering of the allowlist)', (() => { const x = clone(S); x.allowlist.study_sessions_sinks.reverse(); return buildMatrix(x).result_sha256 === a.result_sha256; })());
  return { total, failures };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
if (isMain) {
  const args = process.argv.slice(2);
  const get = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
  const st = selfTest();
  if (args.includes('--self-test')) { console.log(JSON.stringify(st, null, 2)); process.exit(st.failures.length ? 1 : 0); }
  if (st.failures.length) { console.error('self-test failed'); console.error(JSON.stringify(st, null, 2)); process.exit(1); }
  const need = ['--p1', '--p2', '--p3', '--p4', '--p5', '--p6', '--p7', '--d4', '--allowlist'];
  if (need.some((k) => !get(k))) { console.error('missing input: ' + need.filter((k) => !get(k)).join(', ')); process.exit(1); }
  const read = (p) => { const buf = fs.readFileSync(p); return { obj: JSON.parse(buf.toString('utf8')), sha256: crypto.createHash('sha256').update(buf).digest('hex') }; };
  const inputs = {}; const loaded = {};
  try {
    for (const k of ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'd4', 'allowlist']) { const r = read(get('--' + k)); loaded[k] = r.obj; inputs[k] = { file: get('--' + k), sha256: r.sha256 }; }
    if (get('--clearances')) { const r = read(get('--clearances')); loaded.clearances = r.obj; inputs.clearances = { file: get('--clearances'), sha256: r.sha256 }; } else { loaded.clearances = {}; inputs.clearances = { file: null, sha256: sha256('{}') }; }
  } catch (e) { console.error('cannot read an input: ' + e.message); process.exit(1); }
  const errors = validateInputs(loaded);
  if (errors.length) { console.error('BAD INPUT (nothing computed):\n- ' + errors.join('\n- ')); process.exit(1); }
  const m = buildMatrix(loaded);
  const out = { tool: 'D-05_writer-matrix_v2.mjs', inputs, ...m };
  const text = stableStringify(out);
  if (get('--out')) fs.writeFileSync(get('--out'), text, 'utf8'); else console.log(text);
  if (get('--md')) fs.writeFileSync(get('--md'), renderMarkdown(m), 'utf8');
  process.exit(exitCodeFor(m));
}
