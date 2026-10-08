// D-05_writer-matrix_v4.mjs - T-002 deterministic writer matrix and sink/allowlist comparison (v4).
//
// v4 answers QA Round 24, which returned v3 (`1087cb8f7907`) as REVISION REQUIRED (v3 was never used for evidence):
//  1. The P1 `study_sessions` foreign-key sink key is exact: `foreign_key:<ancestor>:<event>-><result>|path=<example_path>|depth=<n>`; a P1 lead from `auth.users` must be the
//     direct cascade key (`study_sessions_user_id_fkey`, depth 1) or the named stop `fk_lead_not_bound_to_cascade_key` is raised (the key itself is bound by the P7 key).
//  2. The P6 frontier edges are validated (caller and callee schema, name, args). P5 must carry `auth_users_trigger_count` and `chain_function_count` equal to its lists, and
//     its trigger names must equal the P7 trigger names (otherwise bad input).
//  3. The cascade proof binds the COMPLETE referential-integrity trigger set: the parent side `RI_FKey_cascade_del` and the update-action trigger for the update action,
//     the child side `RI_FKey_check_ins` and `RI_FKey_check_upd`, nothing more, nothing less, every one enabled (`O`); anything else is `cascade_foreign_key_not_proven`.
//  4. Extension rows need a non-empty version and a non-negative INTEGER count (also in the clearance key). The foreign-key OID must be a non-negative integer.
//  5. P7 `visibility_unresolved` must be false (a boolean in the input schema) or the stop `p7_visibility_unresolved` is raised.
// v3 answered QA Round 22, which returned v2 (`d39292ddc66d`) as REVISION REQUIRED (v2 was never used for evidence):
//  1. RECURSIVE schema validation. Every nested element that the matrix reads is checked for presence and type (identity fields, flag booleans, hash formats,
//     counts that must agree with their lists). `p2.routines = [{}]`, `p4.jobs = [{}]`, `d4.entries = [{}]` and a `p5.chain_functions` that does not cover every
//     trigger function of P5 are BAD INPUT (exit 1), never an empty result.
//  2. EXACT keys. Every allowlisted object is identified by all the fields that define it:
//       routine          `routine:<schema>.<name>(<args>)|<src_md5>`
//       foreign_key lead `foreign_key:<ancestor>:<event>-><result>` (the P1 lead id; the foreign key itself is bound by the P7 key below)
//       writable_view    `writable_view:<schema>.<view>|<definition_md5>`
//       rule             `rule:<schema>.<relation>#<rule>|<definition_md5>`
//       scheduled_job    `scheduled_job:job <id> <name>|<command_md5>|active=<b>|schedule=<s>|database=<d>|username=<u>`
//       auth.users FK    `<child>.<constraint>|<definition_md5>|delete=<c>|update=<c>|validated=<b>|oid=<n>`
//       auth.users trigger `<name>|<definition_md5>|enabled=<c>`
//     and the cascade foreign key must also be VALIDATED, have at least one referential-integrity system trigger and every one of them enabled (`O`), and
//     `orphan_study_sessions_count` must be 0; otherwise the named stop `cascade_foreign_key_not_proven` is raised.
//  3. Clearances must carry a reason of at least 10 characters; extension clearance keys bind name, version, routine COUNT and a SHA-256 identity-set hash:
//     `extension_dynamic:<name>@<version>#<count>|<sha256>` / `extension_compiled:...`.
//  4. UNUSED allowlist or clearance entries are a stop (`allowlist_entry_unused`, `clearance_unused`) unless the entry is listed in the allowlist file's
//     `reviewed_unused` array (a reviewed, recorded exception), so stale or over-broad evidence cannot pass silently.
// v2 answered QA Round 20 (extension stops, hashed inputs, allowlist comparison, result_sha256). P6 stays advisory.
//
// It reads files and runs no database statement. Cells: leads / none_found / unresolved / leads_and_unresolved; `none_found` is possible only when no global
// unresolved item exists anywhere.
//
// Allowlist file (JSON object; every section is a required array of strings, empty means "none, deliberately"):
//   study_sessions_sinks, auth_users_roles, auth_users_routines (`<schema>.<name>(<args>)|<src_md5>`), auth_users_wrappers (same shape),
//   auth_users_foreign_keys, auth_users_triggers, auth_users_rules (`<rule>|<definition_md5>`), auth_users_chain_functions (`<schema>.<name>(<args>)|<definition_md5>`),
//   reviewed_unused (entries written as `<section>|<entry>`).
// Clearances file (JSON object key -> reason): `<schema>.<name>(<args>)|<src_md5>` for a dynamic-SQL routine, `<schema>.<name>(<args>)` for an unreadable or
// compiled routine, and the extension key shapes above.
//
// Usage:
//   node docs/database/t002/D-05_writer-matrix_v4.mjs --self-test
//   node docs/database/t002/D-05_writer-matrix_v4.mjs --p1 P1.json ... --p7 P7.json --d4 d4.json --allowlist allow.json [--clearances c.json] --out matrix.json [--md matrix.md]
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
export const D3_VERSION = 'D3-v6';
export const D4_TOOL = 'D-04_code-inventory_v6.mjs';
export const ALLOWLIST_KEYS = ['study_sessions_sinks', 'auth_users_roles', 'auth_users_routines', 'auth_users_wrappers', 'auth_users_foreign_keys', 'auth_users_triggers', 'auth_users_rules', 'auth_users_chain_functions', 'reviewed_unused'];
const CASCADE_FK = 'study_sessions_user_id_fkey';

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
const H64 = (v) => typeof v === 'string' && /^[0-9a-f]{64}$/.test(v);
const ANY = () => true;
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
const EXT_ROW = obj({ extension: SN, extversion: S, routines: NI, identity_set_sha256: H64 });
const D3_BASE = (run) => obj({ run: (v) => v === run, tool_version: (v) => v === D3_VERSION });
const SPECS = {
  p1: obj({ run: (v) => v === 'D3-P1', tool_version: (v) => v === D3_VERSION, targets_found: N,
    mutation_reachability: arr(obj({ target: S, ancestor: S, ancestor_event: S, target_result: S, min_depth: N, example_path: S0 })),
    frontier_cut_at_depth_cap: arr(obj({ target: S, ancestor: S })) }),
  p2: obj({ run: (v) => v === 'D3-P2', tool_version: (v) => v === D3_VERSION,
    routines: arr(obj({ ...ident, mentions: arr(S), src_md5: H32, security_definer: B, execute_grantees: arr(S), flags: flagsOf(ROUTINE_FLAGS) })),
    dynamic_sql_routines_not_in_extensions: obj({ count: N, identities: arr(obj({ ...ident, src_md5: H32 })) }),
    dynamic_sql_routines_in_extensions_by_extension: arr(EXT_ROW),
    unreadable_language_routines: obj({ count: N, identities: arr(obj(ident)) }),
    compiled_routines: obj({ not_in_extensions_count: N, not_in_extensions_identities: arr(obj(ident)), in_extensions_by_extension: arr(EXT_ROW) }) }),
  p3: obj({ run: (v) => v === 'D3-P3', tool_version: (v) => v === D3_VERSION,
    dependent_views: arr(obj({ schema: S, view: S, depends_transitively_on: arr(S), definition_md5: H32, accepts_update: B, accepts_insert: B, accepts_delete: B })),
    rewrite_rules_on_targets_and_dependents: arr(obj({ schema: S, relation: S, rule: S, event: S, instead: B, definition_md5: H32 })),
    frontier_cut_at_depth_cap: arr(S0) }),
  p4: obj({ run: (v) => v === 'D3-P4', tool_version: (v) => v === D3_VERSION, visibility_unresolved: B,
    jobs: arr(obj({ jobid: N, jobname: SN, schedule: S, active: B, database: S, username: S, command_md5: H32, flags: flagsOf(JOB_FLAGS) })) }),
  p5: obj({ run: (v) => v === 'D3-P5', tool_version: (v) => v === D3_VERSION, auth_users_trigger_count: NI, chain_function_count: NI,
    auth_users_triggers: arr(obj({ name: S, function_schema: S, function: S, function_args: S0 })),
    chain_functions: arr(obj({ ...ident, definition_md5: H32 })) }),
  p6: obj({ run: (v) => v === 'D3-P6', tool_version: (v) => v === D3_VERSION, closure_size: N,
    relevant_routines: arr(obj(ident)), frontier_edges_outside_closure: arr(obj({ caller_schema: S, caller_name: S, caller_args: S0, callee_schema: S, callee_name: S, callee_args: S0 })) }),
  p7: obj({ run: (v) => v === 'D3-P7', tool_version: (v) => v === D3_VERSION, auth_users_found: (v) => v === 1, orphan_study_sessions_count: NI, visibility_unresolved: B,
    effective_privileges_of_roles_holding_any_of_delete_truncate_update: arr(obj({ role: S, delete: B, truncate: B, update: B })),
    public_pseudo_role_privileges_from_acl: arr(S),
    foreign_keys_referencing_auth_users: arr(obj({ child: S, constraint: S, constraint_oid: NI, delete_action: S, update_action: S, definition_md5: H32, validated: B,
      system_triggers: arr(obj({ table: S, name: S, enabled: S, function: S })) })),
    rewrite_rules_on_auth_users: arr(obj({ rule: S, definition_md5: H32 })),
    triggers_on_auth_users: arr(obj({ name: S, enabled: S, definition_md5: H32 })),
    indirect_wrappers_of_those_routines: arr(obj({ ...ident, src_md5: H32 })),
    wrapper_frontier_beyond_depth_3: arr(obj(ident)),
    routines_naming_auth_users_with_delete_truncate_or_dynamic_sql: arr(obj({ ...ident, src_md5: H32 })) }),
  d4: obj({ tool: (v) => v === D4_TOOL, undisposed: arr(obj({ id: S })), unparsed_files: arr(obj({ file: S })),
    entries: arr((e) => e && typeof e === 'object' && S(e.kind) && S(e.file) && N(e.line) && (e.kind !== 'write' || (S(e.table) && S(e.op) && OP_TO_KIND[e.op] !== undefined))) }),
  allowlist: obj(Object.fromEntries(ALLOWLIST_KEYS.map((k) => [k, arr(S)]))),
};

export function validateInputs(inputs) {
  const errors = [];
  for (const [k, spec] of Object.entries(SPECS)) chk(inputs[k], spec, k, errors);
  const { p2, p5, p7, clearances } = inputs;
  if (p2 && p2.dynamic_sql_routines_not_in_extensions && p2.dynamic_sql_routines_not_in_extensions.count !== (p2.dynamic_sql_routines_not_in_extensions.identities || []).length) errors.push('p2: dynamic-SQL count disagrees with its identity list');
  if (p2 && p2.unreadable_language_routines && p2.unreadable_language_routines.count !== (p2.unreadable_language_routines.identities || []).length) errors.push('p2: unreadable-language count disagrees with its identity list');
  if (p2 && p2.compiled_routines && p2.compiled_routines.not_in_extensions_count !== (p2.compiled_routines.not_in_extensions_identities || []).length) errors.push('p2: compiled count disagrees with its identity list');
  if (p5 && Array.isArray(p5.auth_users_triggers) && Array.isArray(p5.chain_functions)) {
    const have = new Set(p5.chain_functions.map((c) => `${c.schema}.${c.name}(${c.args})`));
    for (const t of p5.auth_users_triggers) { const id = `${t.function_schema}.${t.function}(${t.function_args})`; if (!have.has(id)) errors.push(`p5: trigger function ${id} is not among chain_functions`); }
  }
  if (p5 && Array.isArray(p5.auth_users_triggers) && p5.auth_users_trigger_count !== p5.auth_users_triggers.length) errors.push('p5: auth_users_trigger_count disagrees with the trigger list');
  if (p5 && Array.isArray(p5.chain_functions) && p5.chain_function_count !== p5.chain_functions.length) errors.push('p5: chain_function_count disagrees with the chain function list');
  if (p5 && p7 && Array.isArray(p5.auth_users_triggers) && Array.isArray(p7.triggers_on_auth_users)) {
    const a = p5.auth_users_triggers.map((t) => t.name).sort().join('|'), b = p7.triggers_on_auth_users.map((t) => t.name).sort().join('|');
    if (a !== b) errors.push('p5 and p7 disagree on the triggers on auth.users');
  }
  if (!clearances || typeof clearances !== 'object' || Array.isArray(clearances)) errors.push('clearances: not a JSON object (use {} for none)');
  else for (const [k, v] of Object.entries(clearances)) {
    if (typeof v !== 'string' || v.trim().length < 10) errors.push(`clearances["${k}"]: a reason of at least 10 characters is required`);
    if (/^extension_(dynamic|compiled):/.test(k) && !/^extension_(dynamic|compiled):.+@.+#\d+\|[0-9a-f]{64}$/.test(k)) errors.push(`clearances["${k}"]: extension key must be extension_<dynamic|compiled>:<name>@<version>#<count>|<sha256 hex>`);
  }
  return errors;
}

// the complete referential-integrity trigger set of one foreign key (PostgreSQL system triggers), every one enabled
const norm = (s) => String(s).replace(/"/g, '').split('.').pop().toLowerCase();
const UPDATE_FN = { a: 'ri_fkey_noaction_upd', r: 'ri_fkey_restrict_upd' };
export function riSetComplete(fk) {
  if (fk.delete_action !== 'c' || !UPDATE_FN[fk.update_action]) return false;
  const want = [`users:ri_fkey_cascade_del`, `users:${UPDATE_FN[fk.update_action]}`, `${norm(fk.child)}:ri_fkey_check_ins`, `${norm(fk.child)}:ri_fkey_check_upd`].sort();
  const have = fk.system_triggers.map((g) => `${norm(g.table)}:${norm(g.function)}`).sort();
  return have.length === want.length && want.every((w, i) => w === have[i]) && fk.system_triggers.every((g) => g.enabled === 'O');
}

// ---------------------------------------------------------------- the matrix and the comparison
export function buildMatrix({ p1, p2, p3, p4, p5, p6, p7, d4, allowlist, clearances }) {
  const cells = {};
  for (const r of TARGETS) { cells[r] = {}; for (const k of KINDS) cells[r][k] = { leads: [] }; }
  const add = (rel, kind, lead) => { if (cells[rel] && cells[rel][kind]) cells[rel][kind].leads.push(lead); };
  const global = [];
  const sections = Object.fromEntries(ALLOWLIST_KEYS.map((k) => [k, new Set(allowlist[k])]));
  const usedAllow = new Set(); const usedClear = new Set();
  const allowed = (section, key) => { if (sections[section].has(key)) { usedAllow.add(`${section}|${key}`); return true; } return false; };
  const cleared = (key) => { if (Object.prototype.hasOwnProperty.call(clearances, key)) { usedClear.add(key); return true; } return false; };
  const sink = (key, lead) => { if (allowed('study_sessions_sinks', key)) lead.allowlisted = true; else global.push({ kind: 'study_sessions_sink_not_allowlisted', id: key }); };

  for (const r of p2.routines) {
    for (const rel of r.mentions) for (const [flag, kind] of Object.entries(FLAG_TO_KIND)) {
      if (r.flags[flag]) {
        const lead = { source: 'routine', id: routineId(r), src_md5: r.src_md5, security_definer: r.security_definer, grantees: r.execute_grantees };
        add(rel, kind, lead);
        if (rel === 'study_sessions') sink(`routine:${routineId(r)}|${r.src_md5}`, lead);
      }
    }
  }
  for (const m of p1.mutation_reachability) {
    const kind = m.target_result === 'DELETE' ? 'DELETE' : 'UPDATE';
    const lead = { source: 'foreign_key', id: `${m.ancestor}:${m.ancestor_event}->${m.target_result}`, min_depth: m.min_depth, example_path: m.example_path };
    add(m.target, kind, lead);
    if (m.target === 'study_sessions') {
      sink(`foreign_key:${lead.id}|path=${m.example_path}|depth=${m.min_depth}`, lead);
      if (m.ancestor === 'auth.users' && (m.example_path !== CASCADE_FK || m.min_depth !== 1)) global.push({ kind: 'fk_lead_not_bound_to_cascade_key', id: `${lead.id}|path=${m.example_path}|depth=${m.min_depth}` });
    }
  }
  const viewRoots = new Map();
  for (const v of p3.dependent_views) {
    const vid = `${v.schema}.${v.view}`; viewRoots.set(vid, v.depends_transitively_on);
    for (const root of v.depends_transitively_on) {
      for (const [flag, kind] of [['accepts_insert', 'INSERT'], ['accepts_update', 'UPDATE'], ['accepts_delete', 'DELETE']]) {
        if (!v[flag]) continue;
        const lead = { source: 'writable_view', id: vid, definition_md5: v.definition_md5 };
        add(root, kind, lead);
        if (root === 'study_sessions') sink(`writable_view:${vid}|${v.definition_md5}`, lead);
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
      if (root === 'study_sessions') sink(`rule:${rid}|${ru.definition_md5}`, lead);
    }
  }
  for (const j of p4.jobs) {
    for (const rel of TARGETS) {
      if (!j.flags[`names_${rel}`]) continue;
      for (const [flag, kind] of [['insert', 'INSERT'], ['update', 'UPDATE'], ['delete', 'DELETE'], ['truncate', 'TRUNCATE'], ['merge', 'MERGE'], ['copy', 'COPY']]) {
        if (!j.flags[flag]) continue;
        const lead = { source: 'scheduled_job', id: `job ${j.jobid} ${j.jobname}`, command_md5: j.command_md5 };
        add(rel, kind, lead);
        if (rel === 'study_sessions') sink(`scheduled_job:${lead.id}|${j.command_md5}|active=${j.active}|schedule=${j.schedule}|database=${j.database}|username=${j.username}`, lead);
      }
    }
  }
  for (const e of d4.entries) {
    if (e.kind !== 'write' || !cells[e.table]) continue;
    add(e.table, OP_TO_KIND[e.op], { source: 'code', id: `${e.file}:${e.line}`, payload_keys: e.payload_keys, payload_resolved: e.payload_resolved });
  }

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

  // ---- the auth.users caller closure (P5, P7), compared with the allowlist by exact identity and hash
  for (const r of p7.effective_privileges_of_roles_holding_any_of_delete_truncate_update) if (!allowed('auth_users_roles', r.role)) global.push({ kind: 'auth_users_role_not_allowlisted', id: r.role });
  for (const priv of p7.public_pseudo_role_privileges_from_acl) if (['DELETE', 'TRUNCATE', 'UPDATE'].includes(priv)) global.push({ kind: 'auth_users_public_holds_privilege', id: priv });
  for (const r of p7.routines_naming_auth_users_with_delete_truncate_or_dynamic_sql) { const k = `${routineId(r)}|${r.src_md5}`; if (!allowed('auth_users_routines', k)) global.push({ kind: 'auth_users_routine_not_allowlisted', id: k }); }
  for (const w of p7.indirect_wrappers_of_those_routines) { const k = `${routineId(w)}|${w.src_md5}`; if (!allowed('auth_users_wrappers', k)) global.push({ kind: 'auth_users_wrapper_not_allowlisted', id: k }); }
  for (const f of p7.wrapper_frontier_beyond_depth_3) global.push({ kind: 'auth_users_wrapper_frontier_cut', id: routineId(f) });
  for (const f of p7.foreign_keys_referencing_auth_users) {
    const k = `${f.child}.${f.constraint}|${f.definition_md5}|delete=${f.delete_action}|update=${f.update_action}|validated=${f.validated}|oid=${f.constraint_oid}`;
    if (!allowed('auth_users_foreign_keys', k)) global.push({ kind: 'auth_users_foreign_key_not_allowlisted', id: k });
  }
  for (const g of p7.triggers_on_auth_users) { const k = `${g.name}|${g.definition_md5}|enabled=${g.enabled}`; if (!allowed('auth_users_triggers', k)) global.push({ kind: 'auth_users_trigger_not_allowlisted', id: k }); }
  for (const g of p7.rewrite_rules_on_auth_users) { const k = `${g.rule}|${g.definition_md5}`; if (!allowed('auth_users_rules', k)) global.push({ kind: 'auth_users_rule_not_allowlisted', id: k }); }
  for (const c of p5.chain_functions) { const k = `${routineId(c)}|${c.definition_md5}`; if (!allowed('auth_users_chain_functions', k)) global.push({ kind: 'auth_users_chain_function_not_allowlisted', id: k }); }
  if (p7.visibility_unresolved) global.push({ kind: 'p7_visibility_unresolved', id: 'the running role could not be shown to see every row of auth.users and study_sessions' });
  const cascade = p7.foreign_keys_referencing_auth_users.filter((f) => f.constraint === CASCADE_FK && /(^|\.)study_sessions$/.test(f.child));
  const proven = cascade.length === 1 && cascade[0].delete_action === 'c' && cascade[0].validated === true && riSetComplete(cascade[0]) && p7.orphan_study_sessions_count === 0;
  if (!proven) global.push({ kind: 'cascade_foreign_key_not_proven', id: `${CASCADE_FK} must exist exactly once, delete action c, validated, with enabled system triggers, and zero orphan study_sessions rows` });

  // ---- unused entries are stale or over-broad evidence
  const reviewed = sections.reviewed_unused;
  for (const [section, set] of Object.entries(sections)) {
    if (section === 'reviewed_unused') continue;
    for (const entry of set) if (!usedAllow.has(`${section}|${entry}`) && !reviewed.has(`${section}|${entry}`)) global.push({ kind: 'allowlist_entry_unused', id: `${section}|${entry}` });
  }
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
  return { ...locked, advisory, result_sha256: sha256(stableStringify(locked)) };
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
const h32 = (c) => c.repeat(32).slice(0, 32);
const h64 = (c) => c.repeat(64).slice(0, 64);
const FKKEY = (f) => `${f.child}.${f.constraint}|${f.definition_md5}|delete=${f.delete_action}|update=${f.update_action}|validated=${f.validated}|oid=${f.constraint_oid}`;
export function synthetic() {
  const jobFlags = Object.fromEntries(JOB_FLAGS.map((f) => [f, false]));
  const rflags = (o) => ({ ...Object.fromEntries(ROUTINE_FLAGS.map((f) => [f, false])), ...o });
  const p1 = { run: 'D3-P1', tool_version: D3_VERSION, targets_found: 8, mutation_reachability: [{ target: 'study_sessions', ancestor: 'auth.users', ancestor_event: 'DELETE', target_result: 'DELETE', min_depth: 1, example_path: CASCADE_FK }], frontier_cut_at_depth_cap: [] };
  const p2 = {
    run: 'D3-P2', tool_version: D3_VERSION,
    routines: [{ schema: 'public', name: 'purge_notes', args: '', mentions: ['notes'], src_md5: h32('a'), security_definer: true, execute_grantees: ['postgres'], flags: rflags({ delete: true }) },
               { schema: 'public', name: 'upsert_profile', args: 'p uuid', mentions: ['profiles'], src_md5: h32('b'), security_definer: true, execute_grantees: [], flags: rflags({ on_conflict_do_update: true, insert: true }) },
               { schema: 'public', name: 'log_session', args: '', mentions: ['study_sessions'], src_md5: h32('c'), security_definer: false, execute_grantees: [], flags: rflags({ insert: true }) }],
    dynamic_sql_routines_not_in_extensions: { count: 1, identities: [{ schema: 'public', name: 'dyn', args: '', src_md5: h32('d') }] },
    dynamic_sql_routines_in_extensions_by_extension: [{ extension: 'pg_net', extversion: '0.14', routines: 2, identity_set_sha256: h64('1') }],
    unreadable_language_routines: { count: 0, identities: [] },
    compiled_routines: { not_in_extensions_count: 0, not_in_extensions_identities: [], in_extensions_by_extension: [{ extension: 'pgcrypto', extversion: '1.3', routines: 40, identity_set_sha256: h64('2') }] },
  };
  const p3 = { run: 'D3-P3', tool_version: D3_VERSION, dependent_views: [{ schema: 'public', view: 'v_notes', depends_transitively_on: ['notes'], definition_md5: h32('e'), accepts_update: true, accepts_insert: false, accepts_delete: false }],
               rewrite_rules_on_targets_and_dependents: [{ schema: 'public', relation: 'v_notes', rule: 'r1', event: '4', instead: true, definition_md5: h32('f') }], frontier_cut_at_depth_cap: [] };
  const p4 = { run: 'D3-P4', tool_version: D3_VERSION, visibility_unresolved: false, jobs: [{ jobid: 4, jobname: 'j', schedule: '*/15 * * * *', active: true, database: 'postgres', username: 'postgres', command_md5: h32('9'), flags: { ...jobFlags, names_flashcards: true, delete: true } }] };
  const p5 = { run: 'D3-P5', tool_version: D3_VERSION, auth_users_trigger_count: 1, chain_function_count: 1, auth_users_triggers: [{ name: 'on_auth_user_created', function_schema: 'public', function: 'on_signup', function_args: '' }], chain_functions: [{ schema: 'public', name: 'on_signup', args: '', definition_md5: h32('7') }] };
  const p6 = { run: 'D3-P6', tool_version: D3_VERSION, closure_size: 3, relevant_routines: [], frontier_edges_outside_closure: [] };
  const fkS = { child: 'study_sessions', constraint: CASCADE_FK, constraint_oid: 16401, delete_action: 'c', update_action: 'a', definition_md5: h32('1'), validated: true, system_triggers: [{ table: 'auth.users', name: 'RI_ConstraintTrigger_a_1', enabled: 'O', function: '"RI_FKey_cascade_del"' }, { table: 'auth.users', name: 'RI_ConstraintTrigger_a_2', enabled: 'O', function: '"RI_FKey_noaction_upd"' }, { table: 'study_sessions', name: 'RI_ConstraintTrigger_c_3', enabled: 'O', function: '"RI_FKey_check_ins"' }, { table: 'study_sessions', name: 'RI_ConstraintTrigger_c_4', enabled: 'O', function: '"RI_FKey_check_upd"' }] };
  const fkP = { child: 'profiles', constraint: 'profiles_id_fkey', constraint_oid: 16402, delete_action: 'c', update_action: 'a', definition_md5: h32('2'), validated: true, system_triggers: [{ table: 'users', name: 'RI_ConstraintTrigger_a_3', enabled: 'O', function: 'RI_FKey_cascade_del' }] };
  const p7 = { run: 'D3-P7', tool_version: D3_VERSION, auth_users_found: 1, orphan_study_sessions_count: 0, visibility_unresolved: false,
    effective_privileges_of_roles_holding_any_of_delete_truncate_update: [{ role: 'postgres', delete: true, truncate: true, update: true }, { role: 'supabase_auth_admin', delete: true, truncate: false, update: true }],
    public_pseudo_role_privileges_from_acl: [], foreign_keys_referencing_auth_users: [fkS, fkP],
    rewrite_rules_on_auth_users: [], triggers_on_auth_users: [{ name: 'on_auth_user_created', enabled: 'O', definition_md5: h32('3') }],
    indirect_wrappers_of_those_routines: [{ schema: 'public', name: 'wrap', args: '', src_md5: h32('4') }], wrapper_frontier_beyond_depth_3: [],
    routines_naming_auth_users_with_delete_truncate_or_dynamic_sql: [{ schema: 'public', name: 'admin_delete_user_data', args: 'p uuid', src_md5: h32('5') }] };
  const d4 = { tool: D4_TOOL, entries: [{ kind: 'write', table: 'study_sessions', op: 'insert', file: 'src/a.js', line: 3, payload_keys: ['user_id'], payload_resolved: true }, { kind: 'read', table: 'notes', op: 'select', file: 'src/b.js', line: 1 }], undisposed: [], unparsed_files: [] };
  const allowlist = {
    study_sessions_sinks: [`routine:public.log_session()|${h32('c')}`, `foreign_key:auth.users:DELETE->DELETE|path=${CASCADE_FK}|depth=1`],
    auth_users_roles: ['postgres', 'supabase_auth_admin'], auth_users_routines: [`public.admin_delete_user_data(p uuid)|${h32('5')}`], auth_users_wrappers: [`public.wrap()|${h32('4')}`],
    auth_users_foreign_keys: [FKKEY(fkS), FKKEY(fkP)], auth_users_triggers: [`on_auth_user_created|${h32('3')}|enabled=O`], auth_users_rules: [],
    auth_users_chain_functions: [`public.on_signup()|${h32('7')}`], reviewed_unused: [],
  };
  const clearances = { [`public.dyn()|${h32('d')}`]: 'read: no DML on target relations', [`extension_dynamic:pg_net@0.14#2|${h64('1')}`]: 'reviewed extension content', [`extension_compiled:pgcrypto@1.3#40|${h64('2')}`]: 'reviewed extension content' };
  return { p1, p2, p3, p4, p5, p6, p7, d4, allowlist, clearances };
}

export function selfTest() {
  const failures = []; let total = 0;
  const check = (name, ok) => { total += 1; if (!ok) failures.push(name); };
  const S0x = synthetic();
  const build = (mut) => { const x = clone(S0x); if (mut) mut(x); return { x, errors: validateInputs(x), m: buildMatrix(x) }; };
  const bad = (mut) => { const x = clone(S0x); mut(x); return validateInputs(x).length > 0; };
  const stops = (r, kind) => r.m.global_unresolved.some((g) => g.kind === kind);
  let r = build();
  check('the synthetic baseline validates', r.errors.length === 0);
  check('a fully allowlisted, cleared and used baseline has no global unresolved item and exits 0', r.m.global_unresolved.length === 0 && exitCodeFor(r.m) === 0);
  check('an empty cell is none_found only when nothing is unresolved', r.m.cells.topics.TRUNCATE.status === 'none_found');
  check('a foreign-key cascade is a DELETE lead on the target', r.m.cells.study_sessions.DELETE.leads.some((l) => l.source === 'foreign_key' && l.allowlisted));
  check('a code insert is a lead; a code read is not', r.m.cells.study_sessions.INSERT.leads.some((l) => l.source === 'code') && r.m.cells.notes.INSERT.leads.length === 0);
  check('ON CONFLICT DO UPDATE is an UPSERT lead', r.m.cells.profiles.UPSERT.leads.some((l) => l.id === 'public.upsert_profile(p uuid)'));
  check('a writable view and an INSTEAD rule reach the base relation', r.m.cells.notes.UPDATE.leads.some((l) => l.source === 'writable_view') && r.m.cells.notes.DELETE.leads.some((l) => l.source === 'rule'));
  check('a scheduled job naming a relation and DELETE is a DELETE lead', r.m.cells.flashcards.DELETE.leads.some((l) => l.source === 'scheduled_job'));
  r = build((x) => { x.clearances = {}; });
  check('uncleared dynamic routine and uncleared extensions each make cells unresolved', r.m.cells.topics.TRUNCATE.status === 'unresolved' && stops(r, 'dynamic_sql_routine_uncleared') && stops(r, 'extension_dynamic_sql_uncleared') && stops(r, 'extension_compiled_uncleared') && exitCodeFor(r.m) === 3);
  r = build((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].identity_set_sha256 = h64('9'); });
  check('an extension whose identity-set hash changed is not cleared (and the old clearance is reported unused)', stops(r, 'extension_compiled_uncleared') && stops(r, 'clearance_unused') && r.m.cells.study_sessions.DELETE.status === 'leads_and_unresolved');
  r = build((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].routines = 41; });
  check('an extension whose routine count changed is not cleared', stops(r, 'extension_compiled_uncleared'));
  r = build((x) => { x.p2.routines.push({ schema: 'public', name: 'sneak', args: '', mentions: ['study_sessions'], src_md5: h32('z'.replace('z', '0')), security_definer: true, execute_grantees: [], flags: { insert: false, update: true, delete: false, truncate: false, merge: false, copy: false, on_conflict_do_update: false, dynamic_sql_execute: false, ddl_word: false } }); });
  check('a study_sessions writer routine that is not allowlisted is a named stop', stops(r, 'study_sessions_sink_not_allowlisted') && exitCodeFor(r.m) === 3);
  r = build((x) => { x.p2.routines[2].src_md5 = h32('0'); });
  check('an allowlisted routine whose body hash changed is not allowlisted any more', stops(r, 'study_sessions_sink_not_allowlisted') && stops(r, 'allowlist_entry_unused'));
  r = build((x) => { x.p3.dependent_views.push({ schema: 'public', view: 'v_ss', depends_transitively_on: ['study_sessions'], definition_md5: h32('8'), accepts_update: true, accepts_insert: false, accepts_delete: false }); x.allowlist.study_sessions_sinks.push('writable_view:public.v_ss|' + h32('1')); });
  check('a writable view over study_sessions whose definition hash differs from the allowlisted one is a stop', stops(r, 'study_sessions_sink_not_allowlisted'));
  r = build((x) => { x.p4.jobs[0].flags.names_study_sessions = true; x.p4.jobs[0].flags.update = true; x.allowlist.study_sessions_sinks.push(`scheduled_job:job 4 j|${h32('9')}|active=true|schedule=*/15 * * * *|database=postgres|username=postgres`); x.p4.jobs[0].username = 'other'; });
  check('a scheduled job whose username changed no longer matches the allowlisted exact job key', stops(r, 'study_sessions_sink_not_allowlisted'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].constraint_oid = 99999; });
  check('a cascade foreign key with a different OID is a stop (exact key)', stops(r, 'auth_users_foreign_key_not_allowlisted'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].definition_md5 = h32('0'); });
  check('a cascade foreign key with a different definition hash is a stop', stops(r, 'auth_users_foreign_key_not_allowlisted'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].validated = false; });
  check('an unvalidated cascade foreign key is not proven', stops(r, 'cascade_foreign_key_not_proven'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].system_triggers[0].enabled = 'D'; });
  check('a disabled referential-integrity system trigger is not proven', stops(r, 'cascade_foreign_key_not_proven'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].system_triggers = []; });
  check('a cascade foreign key with no system trigger is not proven', stops(r, 'cascade_foreign_key_not_proven'));
  r = build((x) => { x.p7.orphan_study_sessions_count = 3; });
  check('pre-existing orphan study_sessions rows stop the matrix', stops(r, 'cascade_foreign_key_not_proven'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].delete_action = 'a'; });
  check('a changed cascade action is a stop', stops(r, 'cascade_foreign_key_not_proven') && stops(r, 'auth_users_foreign_key_not_allowlisted'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users.push({ child: 'notes', constraint: 'notes_x_fkey', constraint_oid: 1, delete_action: 'c', update_action: 'a', definition_md5: h32('6'), validated: true, system_triggers: [] }); });
  check('another foreign key referencing auth.users that is not allowlisted is a stop', stops(r, 'auth_users_foreign_key_not_allowlisted'));
  r = build((x) => { x.p7.triggers_on_auth_users[0].enabled = 'D'; });
  check('a trigger on auth.users in a different enabled state is a stop', stops(r, 'auth_users_trigger_not_allowlisted'));
  r = build((x) => { x.p7.effective_privileges_of_roles_holding_any_of_delete_truncate_update.push({ role: 'rogue', delete: true, truncate: false, update: false }); });
  check('a role with a privilege on auth.users outside the allowlist is a stop', stops(r, 'auth_users_role_not_allowlisted'));
  r = build((x) => { x.p7.public_pseudo_role_privileges_from_acl = ['UPDATE']; });
  check('PUBLIC holding UPDATE on auth.users is a stop', stops(r, 'auth_users_public_holds_privilege'));
  r = build((x) => { x.p7.indirect_wrappers_of_those_routines.push({ schema: 'public', name: 'wrap2', args: '', src_md5: h32('0') }); });
  check('an indirect wrapper that is not allowlisted is a stop', stops(r, 'auth_users_wrapper_not_allowlisted'));
  r = build((x) => { x.p7.wrapper_frontier_beyond_depth_3.push({ schema: 'public', name: 'deep', args: '' }); });
  check('a cut wrapper frontier is a stop', stops(r, 'auth_users_wrapper_frontier_cut'));
  r = build((x) => { x.p7.routines_naming_auth_users_with_delete_truncate_or_dynamic_sql[0].src_md5 = h32('0'); });
  check('an auth.users routine whose body hash changed is a stop', stops(r, 'auth_users_routine_not_allowlisted'));
  r = build((x) => { x.p5.chain_functions[0].definition_md5 = h32('0'); });
  check('a changed signup-chain function is a stop', stops(r, 'auth_users_chain_function_not_allowlisted'));
  r = build((x) => { x.p4.visibility_unresolved = true; });
  check('cron visibility unresolved makes the matrix unresolved', exitCodeFor(r.m) === 3);
  r = build((x) => { x.d4.undisposed = [{ id: 'src/x.js:9:from_non_literal_table' }]; });
  check('an undisposed code lead keeps the matrix unresolved', stops(r, 'code_lead_undisposed'));
  r = build((x) => { x.allowlist.auth_users_roles.push('ghost'); });
  check('an unused allowlist entry is a stop', stops(r, 'allowlist_entry_unused'));
  r = build((x) => { x.allowlist.auth_users_roles.push('ghost'); x.allowlist.reviewed_unused.push('auth_users_roles|ghost'); });
  check('an unused allowlist entry listed as reviewed_unused is accepted', r.m.global_unresolved.length === 0);
  r = build((x) => { x.clearances['public.never_used()'] = 'a reason that is long enough'; });
  check('an unused clearance is a stop', stops(r, 'clearance_unused'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].system_triggers.pop(); });
  check('an incomplete referential-integrity trigger set is not proven', stops(r, 'cascade_foreign_key_not_proven'));
  r = build((x) => { x.p7.foreign_keys_referencing_auth_users[0].system_triggers[0].function = '"RI_FKey_cascade_upd"'; });
  check('a wrong referential-integrity trigger function is not proven', stops(r, 'cascade_foreign_key_not_proven'));
  r = build((x) => { x.p7.visibility_unresolved = true; });
  check('P7 visibility unresolved is a stop', stops(r, 'p7_visibility_unresolved') && exitCodeFor(r.m) === 3);
  r = build((x) => { x.p1.mutation_reachability[0].example_path = 'other_fkey'; });
  check('a P1 lead from auth.users that is not the direct cascade key is a stop, and the sink key no longer matches', stops(r, 'fk_lead_not_bound_to_cascade_key') && stops(r, 'study_sessions_sink_not_allowlisted'));
  r = build((x) => { x.p1.mutation_reachability.push({ target: 'study_sessions', ancestor: 'other.parent', ancestor_event: 'DELETE', target_result: 'DELETE', min_depth: 2, example_path: 'p_fkey' }); });
  check('a second foreign-key path to study_sessions is not cleared by the first path\'s allowlist entry', stops(r, 'study_sessions_sink_not_allowlisted'));
  // validation: the QA probes and more
  check('a P6 frontier edge without callee fields is a bad input', bad((x) => { x.p6.frontier_edges_outside_closure = [{ caller_name: 'a' }]; }));
  check('a P5 trigger count that disagrees with the list is a bad input', bad((x) => { x.p5.auth_users_trigger_count = 2; }));
  check('P5 and P7 disagreeing on the triggers of auth.users is a bad input', bad((x) => { x.p7.triggers_on_auth_users.push({ name: 'extra', enabled: 'O', definition_md5: h32('5') }); }));
  check('an extension with an empty version, a fractional or a negative count is a bad input', bad((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].extversion = ''; }) && bad((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].routines = 1.5; }) && bad((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].routines = -1; }));
  check('a missing visibility flag or a fractional OID is a bad input', bad((x) => { delete x.p7.visibility_unresolved; }) && bad((x) => { x.p7.foreign_keys_referencing_auth_users[0].constraint_oid = 1.5; }));
  check('p2.routines = [{}] is a bad input', bad((x) => { x.p2.routines = [{}]; }));
  check('p4.jobs = [{}] is a bad input', bad((x) => { x.p4.jobs = [{}]; }));
  check('d4.entries = [{}] is a bad input', bad((x) => { x.d4.entries = [{}]; }));
  check('p5.chain_functions = [] while P5 lists a trigger function is a bad input', bad((x) => { x.p5.chain_functions = []; }));
  check('a wrong tool_version is a bad input', bad((x) => { x.p3.tool_version = 'D3-v4'; }));
  check('a missing P6 or an empty P7 is a bad input', bad((x) => { delete x.p6; }) && bad((x) => { x.p7 = {}; }));
  check('a count that disagrees with its identity list is a bad input', bad((x) => { x.p2.dynamic_sql_routines_not_in_extensions.count = 5; }));
  check('an allowlist missing a section is a bad input', bad((x) => { delete x.allowlist.reviewed_unused; }));
  check('a D4 file from another tool version is a bad input', bad((x) => { x.d4.tool = 'D-04_code-inventory_v4.mjs'; }));
  check('an extension row with an MD5-length hash or no hash is a bad input', bad((x) => { x.p2.compiled_routines.in_extensions_by_extension[0].identity_set_sha256 = h32('a'); }));
  check('a routine hash that is not 32 hex characters is a bad input', bad((x) => { x.p2.routines[0].src_md5 = 'aa'; }));
  check('a clearance with a blank or short reason is a bad input', bad((x) => { x.clearances[`public.dyn()|${h32('d')}`] = 'ok'; }));
  check('a malformed extension clearance key is a bad input', bad((x) => { x.clearances['extension_dynamic:pg_net@0.14|short'] = 'a reason that is long enough'; }));
  check('a write entry without a table is a bad input', bad((x) => { x.d4.entries.push({ kind: 'write', file: 'f', line: 1, op: 'insert' }); }));
  const a = buildMatrix(clone(S0x)), b = buildMatrix(clone(S0x));
  check('the output and its result_sha256 are deterministic', stableStringify(a) === stableStringify(b) && /^[0-9a-f]{64}$/.test(a.result_sha256));
  check('reordering the allowlist does not change the result hash', (() => { const x = clone(S0x); x.allowlist.study_sessions_sinks.reverse(); return buildMatrix(x).result_sha256 === a.result_sha256; })());
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
  if (errors.length) { console.error('BAD INPUT (nothing computed):\n- ' + errors.slice(0, 60).join('\n- ')); process.exit(1); }
  const m = buildMatrix(loaded);
  const out = { tool: 'D-05_writer-matrix_v4.mjs', inputs, ...m };
  const text = stableStringify(out);
  if (get('--out')) fs.writeFileSync(get('--out'), text, 'utf8'); else console.log(text);
  if (get('--md')) fs.writeFileSync(get('--md'), renderMarkdown(m), 'utf8');
  process.exit(exitCodeFor(m));
}
