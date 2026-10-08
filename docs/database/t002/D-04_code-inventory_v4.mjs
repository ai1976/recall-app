// D-04_code-inventory_v4.mjs - T-002 diagnostic D4 (v4): TypeScript-capable inventory of every backend call in the frontend and the edge functions.
//
// v4 answers QA Round 20, which returned v3 (`f480bcd05e5c`) as REVISION REQUIRED (v3 was never used for evidence):
//  a. EVERY `export * from '<any path>'` is handled, not only a path containing "supabase". The source is added to the import graph (so an invoke closure and the
//     graph follow it) and a lead `export_all_reexport` is raised for each one (disposition with a reason required). If the source does not resolve to a scanned
//     local file, the lead is `export_all_unresolved`, which is UNDISPOSABLE (like the two invoke kinds).
//  b. `export { x } from './h'` is also an import-graph edge now (v3 followed only `import`).
//  c. The self-test has 44 expectations: 31 fixtures plus 13 unit checks.
// v3 answered QA Round 18, which returned v2 (`58865e55b1c6`) as REVISION REQUIRED (v2 was never used for evidence):
//  a. An ALIASED re-export is detected: `export { db as supabase } from './client'` (the exported name is checked as well as the local name and the source path),
//     `export * from '<path containing supabase>'`, and `export { db as handle }` where db is a client.
//  b. `functions.invoke` binds the writes found in the invoked function's WHOLE import closure (its index.ts and every local module it imports, transitively,
//     including `_shared` helpers), not only the files under its own directory. The closure file list is output. If the target file is missing, or the closure
//     contains an unresolved local import or an unparsed file, an `invoke_closure_incomplete` / `invoke_target_not_in_repository` lead is raised and these two kinds
//     are UNDISPOSABLE: a disposition entry for them is ignored, so a run with one of them can never reach exit status 0.
//  c. (v3) The self-test had 39 expectations: 27 fixtures plus 12 unit checks.
// v2 answered QA Round 16, which returned v1 (`de019cd639fb`) as REVISION REQUIRED (v1 was never used for evidence). Changes:
//  1. Aliases of a query builder are followed to a fixed point (`const a = q`, `a = q`); a write-shaped call on a receiver that cannot be resolved (a builder passed
//     in as a parameter, an awaited or filter-chained insert/update/upsert/delete) is an UNRESOLVED lead, never silence.
//  2. New leads: a client or builder passed as an argument to another call (`client_passed_to_callee`), a client exported or re-exported (`client_exported`,
//     `client_reexported`), a `functions.invoke` (always a transport lead, bound to the function's file in the repository and to the writes found in it), a relative
//     import that does not resolve to a scanned file (`import_not_in_scanned_roots`).
//  3. An import graph (file -> resolved local imports) is part of the output, so every imported helper is either a scanned file or a stated lead.
//  4. Fail closed in the PROCESS EXIT STATUS: exit 2 when a file is unparsed, exit 3 when any unresolved lead has no recorded disposition. A disposition is an entry
//     in a JSON file given with --dispositions (`{ "<file>:<line>:<kind>": "<reason>" }`); the exit status is 0 only when every lead is disposed. Dispositions are
//     reviewed work and are part of the audited evidence; the script never invents one.
//  5. (v2) The self-test had 34 expectations: 24 fixtures plus 10 unit checks.
//
// Purpose (docs/database/t002/00_DIAGNOSTIC-BATCH_proposal_v1.md, D4): list, for every `.from(t).select/insert/update/upsert/delete`, every `.rpc(name, args)`, every
// `.functions.invoke(name)`, every `fetch(...)` and every other transport lead in the source roots, the table or name, the operation, the PARSED payload keys, and
// whether anything could not be resolved. READS are inventoried as well as writes.
//
// What it is and is not:
//  - It parses with @babel/parser and its `typescript` plugin (present in node_modules as a transitive dependency; making it an explicit devDependency is a separate
//    package.json change that this file does NOT make).
//  - It is deliberately CONSERVATIVE and does not depend on knowing which identifier is the Supabase client: any `.from(x).<op>(...)` chain is reported, with the root
//    identifier recorded and whether it is a known client binding.
//  - It does NOT do whole-program data-flow analysis. A client passed into a helper is reported as a lead at the call site, and the helper's own body is scanned as an
//    ordinary file (its calls appear with `root_is_known_client: false`); the link between the two is the lead, not a proof.
//  - It reads source files only. It makes no network call, writes nothing except the optional --out file, and runs no database statement.
//  - It is a code-side inventory at ONE commit (recorded in the output with the dirty state of the source roots). It is not evidence about the database.
//
// Usage:
//   node docs/database/t002/D-04_code-inventory_v4.mjs --self-test
//   node docs/database/t002/D-04_code-inventory_v4.mjs --label pre-F0 [--dispositions path.json] --out docs/discussions/evidence/T-002_D4-pre-F0_<dd-mm-yyyy>.json
// Roots: src and supabase/functions. Extensions: .js .jsx .mjs .cjs .ts .tsx. Excluded: node_modules, dist, build, __tests__, *.test.*, *.spec.* (listed in the output).

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { parse } from '@babel/parser';

export const ROOTS = ['src', 'supabase/functions'];
export const EXTENSIONS = new Set(['.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx']);
export const TARGET_TABLES = ['profiles', 'study_sessions', 'flashcards', 'notes', 'access_requests', 'disciplines', 'subjects', 'topics'];
const WRITE_OPS = new Set(['insert', 'update', 'upsert', 'delete']);
const OPS = new Set(['select', 'insert', 'update', 'upsert', 'delete']);
const KNOWN_CLIENT_NAMES = new Set(['supabase', 'supabaseAdmin', 'adminClient', 'serviceClient']);
const FOLLOW = new Set(['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'like', 'ilike', 'is', 'in', 'contains', 'containedBy', 'overlaps', 'match', 'not', 'or', 'filter',
  'order', 'limit', 'range', 'single', 'maybeSingle', 'select', 'returns', 'csv', 'throwOnError', 'abortSignal', 'explain', 'textSearch']);
const CODE_EXT = ['.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx'];

const isCall = (n) => n && (n.type === 'CallExpression' || n.type === 'OptionalCallExpression');
const isMember = (n) => n && (n.type === 'MemberExpression' || n.type === 'OptionalMemberExpression');

function unwrap(n) {
  let cur = n;
  while (cur && (cur.type === 'TSAsExpression' || cur.type === 'TSNonNullExpression' || cur.type === 'TSTypeAssertion' || cur.type === 'TSSatisfiesExpression'
                 || cur.type === 'ParenthesizedExpression' || cur.type === 'AwaitExpression')) cur = cur.expression || cur.argument;
  return cur;
}

function propName(m) {
  if (!m.computed) return m.property.type === 'Identifier' ? m.property.name : null;
  if (m.property.type === 'StringLiteral') return m.property.value;
  return null;
}

function flatten(node) {
  const n = unwrap(node);
  if (isCall(n)) { const f = flatten(n.callee); f.links.push({ t: 'call', node: n }); return f; }
  if (isMember(n)) { const f = flatten(n.object); f.links.push({ t: 'member', name: propName(n), node: n }); return f; }
  return { root: n, links: [] };
}

function literalString(n) {
  const x = unwrap(n);
  if (!x) return { ok: false };
  if (x.type === 'StringLiteral') return { ok: true, value: x.value };
  if (x.type === 'TemplateLiteral' && x.expressions.length === 0) return { ok: true, value: x.quasis.map((q) => q.value.cooked).join('') };
  return { ok: false };
}

function templateText(n) {
  const x = unwrap(n);
  if (!x) return null;
  if (x.type === 'StringLiteral') return x.value;
  if (x.type === 'TemplateLiteral') {
    let s = '';
    x.quasis.forEach((q, i) => { s += q.value.cooked; if (i < x.expressions.length) s += '${...}'; });
    return s;
  }
  return null;
}

function rootName(root) {
  const r = unwrap(root);
  if (!r) return null;
  if (r.type === 'Identifier') return r.name;
  if (r.type === 'ThisExpression') return 'this';
  return `(${r.type})`;
}

function describeCallee(c) {
  const f = flatten(c);
  const parts = [rootName(f.root) || '?'];
  for (const l of f.links) if (l.t === 'member') parts.push(l.name || '[computed]');
  return parts.join('.');
}

function walk(node, visit, ancestors = []) {
  if (!node || typeof node.type !== 'string') return;
  visit(node, ancestors);
  const next = ancestors.concat(node);
  for (const key of Object.keys(node)) {
    if (key === 'loc' || key === 'start' || key === 'end' || key === 'extra' || key === 'leadingComments' || key === 'trailingComments' || key === 'innerComments') continue;
    const v = node[key];
    if (Array.isArray(v)) v.forEach((c) => c && typeof c.type === 'string' && walk(c, visit, next));
    else if (v && typeof v.type === 'string') walk(v, visit, next);
  }
}

function enclosingName(ancestors) {
  for (let i = ancestors.length - 1; i >= 0; i--) {
    const a = ancestors[i];
    if (a.type === 'FunctionDeclaration' && a.id) return a.id.name;
    if ((a.type === 'ArrowFunctionExpression' || a.type === 'FunctionExpression') && ancestors[i - 1]) {
      const p = ancestors[i - 1];
      if (p.type === 'VariableDeclarator' && p.id.type === 'Identifier') return p.id.name;
      if (p.type === 'ObjectProperty' && p.key.type === 'Identifier') return p.key.name;
      if (p.type === 'ClassMethod' || p.type === 'ObjectMethod') return p.key && p.key.name;
    }
    if (a.type === 'ClassMethod' || a.type === 'ObjectMethod') return a.key && a.key.name;
  }
  return '(module)';
}

function payloadKeys(arg, fileObjects) {
  const x = unwrap(arg);
  if (!x) return { keys: [], resolved: true, note: 'no argument' };
  if (x.type === 'ObjectExpression') {
    const keys = []; let resolved = true; const notes = [];
    for (const p of x.properties) {
      if (p.type === 'SpreadElement') { resolved = false; notes.push('spread'); continue; }
      if (p.computed) { resolved = false; notes.push('computed key'); continue; }
      if (p.key.type === 'Identifier') keys.push(p.key.name);
      else if (p.key.type === 'StringLiteral') keys.push(p.key.value);
      else { resolved = false; notes.push('unreadable key'); }
    }
    return { keys, resolved, note: notes.join(', ') };
  }
  if (x.type === 'ArrayExpression') {
    const keys = new Set(); let resolved = true; const notes = [];
    for (const el of x.elements) {
      if (!el) continue;
      const r = payloadKeys(el, fileObjects);
      r.keys.forEach((k) => keys.add(k));
      if (!r.resolved) { resolved = false; if (r.note) notes.push(r.note); }
    }
    return { keys: [...keys].sort(), resolved, note: notes.join(', ') };
  }
  if (x.type === 'Identifier') {
    const defs = fileObjects.get(x.name);
    if (defs && defs.length === 1) { const r = payloadKeys(defs[0], new Map()); return { ...r, note: `via local const ${x.name}${r.note ? '; ' + r.note : ''}` }; }
    return { keys: [], resolved: false, note: `identifier ${x.name} not a unique local object literal` };
  }
  return { keys: [], resolved: false, note: `unreadable payload (${x.type})` };
}

// A write-shaped call whose receiver cannot be resolved is a lead when it is awaited or continues with a query-builder method.
function looksLikeQueryCall(anc, node) {
  const parent = anc[anc.length - 1];
  if (!parent) return false;
  if (parent.type === 'AwaitExpression') return true;
  if (isMember(parent) && parent.object === node) { const nm = propName(parent); return nm !== null && FOLLOW.has(nm); }
  return false;
}

export function analyzeSource(source, filename) {
  const isTsOnly = /\.(ts|mts|cts)$/.test(filename);
  const ast = parse(source, {
    sourceType: 'module',
    errorRecovery: false,
    allowReturnOutsideFunction: true,
    plugins: isTsOnly ? ['typescript'] : ['jsx', 'typescript'],
  });
  const entries = [];
  const unresolved = [];
  const imports = [];
  const clientNames = new Set(KNOWN_CLIENT_NAMES);
  const fileObjects = new Map();
  const builders = new Map(); // name -> { tables:Set, ambiguous }
  const aliasEdges = [];      // [alias, source] from `const a = b` and `a = b`

  // Pass 1: imports, exports are handled in pass 3; clients, local object literals, builder variables and alias edges.
  walk(ast, (n) => {
    if (n.type === 'ImportDeclaration') {
      const spec = n.source.value;
      imports.push({ specifier: spec, line: n.loc ? n.loc.start.line : null });
      if (/supabase/i.test(spec)) n.specifiers.forEach((s) => { if (s.local) clientNames.add(s.local.name); });
    }
    if ((n.type === 'ExportAllDeclaration' || (n.type === 'ExportNamedDeclaration' && n.source)) && n.source) {
      imports.push({ specifier: n.source.value, line: n.loc ? n.loc.start.line : null, reexport_all: n.type === 'ExportAllDeclaration' });
    }
    if (n.type === 'VariableDeclarator' && n.id.type === 'Identifier' && n.init) {
      const init = unwrap(n.init);
      if (init && init.type === 'ObjectExpression') {
        const list = fileObjects.get(n.id.name) || []; list.push(init); fileObjects.set(n.id.name, list);
      }
      if (isCall(init) && unwrap(init.callee) && unwrap(init.callee).type === 'Identifier' && unwrap(init.callee).name === 'createClient') clientNames.add(n.id.name);
      const f = flatten(init);
      const hasFrom = f.links.some((l) => l.t === 'member' && l.name === 'from');
      const hasOp = f.links.some((l) => l.t === 'member' && OPS.has(l.name));
      const isStorage = f.links.some((l) => l.t === 'member' && l.name === 'storage');
      if (hasFrom && !hasOp && !isStorage) {
        const fi = f.links.findIndex((l) => l.t === 'member' && l.name === 'from');
        const call = f.links[fi + 1];
        const lit = call && call.t === 'call' ? literalString(call.node.arguments[0]) : { ok: false };
        const b = builders.get(n.id.name) || { tables: new Set(), ambiguous: false };
        if (lit.ok) b.tables.add(lit.value); else b.ambiguous = true;
        builders.set(n.id.name, b);
      }
      if (init && init.type === 'Identifier') aliasEdges.push([n.id.name, init.name]);
    }
    if (n.type === 'AssignmentExpression' && n.operator === '=' && n.left.type === 'Identifier') {
      const right = unwrap(n.right);
      if (right && right.type === 'Identifier') aliasEdges.push([n.left.name, right.name]);
      const f = flatten(right);
      const hasFrom = f.links.some((l) => l.t === 'member' && l.name === 'from');
      const hasOp = f.links.some((l) => l.t === 'member' && OPS.has(l.name));
      if (hasFrom && !hasOp && !f.links.some((l) => l.t === 'member' && l.name === 'storage')) {
        const fi = f.links.findIndex((l) => l.t === 'member' && l.name === 'from');
        const call = f.links[fi + 1];
        const lit = call && call.t === 'call' ? literalString(call.node.arguments[0]) : { ok: false };
        const b = builders.get(n.left.name) || { tables: new Set(), ambiguous: false };
        if (lit.ok) b.tables.add(lit.value); else b.ambiguous = true;
        builders.set(n.left.name, b);
      }
    }
  });
  // alias fixed point
  for (let changed = true; changed;) {
    changed = false;
    for (const [alias, src] of aliasEdges) {
      if (clientNames.has(src) && !clientNames.has(alias)) { clientNames.add(alias); changed = true; }
      if (builders.has(src)) {
        const s = builders.get(src); const cur = builders.get(alias) || { tables: new Set(), ambiguous: false };
        const before = cur.tables.size + (cur.ambiguous ? 1 : 0);
        s.tables.forEach((x) => cur.tables.add(x)); if (s.ambiguous) cur.ambiguous = true;
        builders.set(alias, cur);
        if (cur.tables.size + (cur.ambiguous ? 1 : 0) !== before) changed = true;
      }
    }
  }

  // Pass 2: calls.
  walk(ast, (n, anc) => {
    if (!isCall(n)) return;
    const f = flatten(n);
    const links = f.links;
    const last = links[links.length - 1];
    const prev = links[links.length - 2];
    const line = n.loc ? n.loc.start.line : null;
    const where = enclosingName(anc);
    const rn = rootName(f.root);
    const base = { file: filename, line, in: where, root: rn, root_is_known_client: rn ? clientNames.has(rn) : false };

    // a client or builder passed as an argument to another call
    const isSupabaseApi = last && last.t === 'call' && prev && prev.t === 'member' && (OPS.has(prev.name) || prev.name === 'from' || prev.name === 'rpc' || prev.name === 'invoke');
    if (!isSupabaseApi) {
      for (const a of n.arguments) {
        const ax = unwrap(a);
        if (ax && ax.type === 'Identifier' && (clientNames.has(ax.name) || builders.has(ax.name))) {
          unresolved.push({ ...base, kind: 'client_passed_to_callee', callee: describeCallee(n.callee), argument: ax.name,
            detail: 'a client or query builder is handed to another function; that function body is scanned as an ordinary file but is not linked by data flow' });
        }
      }
    }

    // .from(non-literal) anywhere (not storage)
    if (prev && prev.t === 'member' && prev.name === 'from') {
      const isStorage = links.slice(0, -2).some((l) => l.t === 'member' && l.name === 'storage');
      if (!isStorage) {
        const lit = literalString(n.arguments[0]);
        if (!lit.ok) unresolved.push({ ...base, kind: 'from_non_literal_table', detail: 'table argument is not a string literal' });
      }
    }

    // operation on a chain
    if (last && last.t === 'call' && prev && prev.t === 'member' && OPS.has(prev.name)) {
      const op = prev.name;
      const before = links.slice(0, links.length - 2);
      if (before.some((l) => l.t === 'member' && l.name === 'storage')) return;
      if (op === 'select' && before.some((l) => l.t === 'member' && WRITE_OPS.has(l.name))) return;
      let tables = null; let via = 'chain';
      const fi = before.findIndex((l) => l.t === 'member' && l.name === 'from');
      if (fi >= 0) {
        const call = before[fi + 1];
        const lit = call && call.t === 'call' ? literalString(call.node.arguments[0]) : { ok: false };
        if (lit.ok) tables = [lit.value]; else { tables = null; via = 'chain_non_literal'; }
      } else if (f.root && f.root.type === 'Identifier' && builders.has(f.root.name) && before.length === 0) {
        const b = builders.get(f.root.name);
        via = 'builder_variable';
        tables = (!b.ambiguous && b.tables.size > 0) ? [...b.tables] : null;
      } else {
        // unrelated .select/.update/.delete (arrays, maps, sets, other libraries) unless it looks like a query call on an unresolved receiver
        if (WRITE_OPS.has(op) && looksLikeQueryCall(anc, n)) {
          unresolved.push({ ...base, kind: 'write_shaped_call_unknown_receiver', op,
            detail: 'a write-shaped call that is awaited or continues with a query-builder method, on a receiver that is not a known client chain or builder variable (for example a builder passed in as a parameter)' });
        }
        return;
      }
      const arg0 = last.node.arguments[0];
      const pk = WRITE_OPS.has(op) && op !== 'delete' ? payloadKeys(arg0, fileObjects) : null;
      const select_cols = op === 'select' ? (literalString(arg0).ok ? literalString(arg0).value : (arg0 ? '(non-literal)' : '*')) : undefined;
      if (!tables) {
        unresolved.push({ ...base, kind: 'operation_on_unresolved_table', op, via, detail: 'table could not be resolved to one literal' });
        return;
      }
      for (const table of tables) {
        entries.push({ ...base, kind: WRITE_OPS.has(op) ? 'write' : 'read', op, table, via,
          payload_keys: pk ? pk.keys : undefined, payload_resolved: pk ? pk.resolved : undefined, payload_note: pk && pk.note ? pk.note : undefined, select_columns: select_cols });
        if (pk && !pk.resolved) unresolved.push({ ...base, kind: 'payload_keys_unresolved', op, table, detail: pk.note });
      }
      return;
    }

    // .rpc(name, args)
    if (last && last.t === 'call' && prev && prev.t === 'member' && prev.name === 'rpc') {
      const lit = literalString(n.arguments[0]);
      const pk = payloadKeys(n.arguments[1], fileObjects);
      if (!lit.ok) unresolved.push({ ...base, kind: 'rpc_name_non_literal', detail: 'rpc name is not a string literal' });
      entries.push({ ...base, kind: 'rpc', name: lit.ok ? lit.value : null, arg_keys: pk.keys, args_resolved: pk.resolved, args_note: pk.note || undefined });
      if (!pk.resolved && lit.ok) unresolved.push({ ...base, kind: 'rpc_args_unresolved', name: lit.value, detail: pk.note });
      return;
    }

    // .functions.invoke(name, ...)
    if (last && last.t === 'call' && prev && prev.t === 'member' && prev.name === 'invoke' && links.slice(0, -2).some((l) => l.t === 'member' && l.name === 'functions')) {
      const lit = literalString(n.arguments[0]);
      if (!lit.ok) unresolved.push({ ...base, kind: 'invoke_name_non_literal', detail: 'function name is not a string literal' });
      entries.push({ ...base, kind: 'functions_invoke', name: lit.ok ? lit.value : null });
      unresolved.push({ ...base, kind: 'invoke_transport_lead', name: lit.ok ? lit.value : null,
        detail: 'an edge function is invoked; its source (supabase/functions/<name>/index.ts) and the writes found in it are cross-referenced by the inventory' });
      return;
    }

    // fetch(...)
    const isFetch = (links.length === 1 && last.t === 'call' && f.root && f.root.type === 'Identifier' && f.root.name === 'fetch')
      || (links.length === 2 && prev.t === 'member' && prev.name === 'fetch' && last.t === 'call' && (rn === 'globalThis' || rn === 'window' || rn === 'self'));
    if (isFetch) {
      const url = templateText(n.arguments[0]);
      let method = null;
      const opt = unwrap(n.arguments[1]);
      if (opt && opt.type === 'ObjectExpression') {
        const mp = opt.properties.find((p) => p.type === 'ObjectProperty' && !p.computed && p.key.type === 'Identifier' && p.key.name === 'method');
        if (mp) { const m = literalString(mp.value); method = m.ok ? m.value : '(non-literal)'; }
      }
      entries.push({ ...base, kind: 'fetch', url_text: url, method });
      unresolved.push({ ...base, kind: 'fetch_transport_lead', detail: url === null ? 'non-literal url' : `url ${url}` });
    }
  });

  // Pass 3: other transports, exports of a client.
  walk(ast, (n, anc) => {
    const line = n.loc ? n.loc.start.line : null;
    if (n.type === 'NewExpression' && n.callee.type === 'Identifier' && (n.callee.name === 'XMLHttpRequest' || n.callee.name === 'WebSocket' || n.callee.name === 'EventSource')) {
      unresolved.push({ file: filename, line, in: enclosingName(anc), kind: 'other_transport_lead', detail: n.callee.name });
    }
    if (n.type === 'ImportDeclaration' && /^(axios|got|ky|superagent|node-fetch|undici)$/.test(n.source.value)) {
      unresolved.push({ file: filename, line, in: '(module)', kind: 'other_transport_lead', detail: `import ${n.source.value}` });
    }
    if (n.type === 'ExportNamedDeclaration') {
      if (n.source) {
        const names = n.specifiers.flatMap((s) => [s.local && s.local.name, s.exported && (s.exported.name || s.exported.value)]).filter(Boolean);
        if (names.some((x) => /supabase/i.test(x)) || /supabase/i.test(n.source.value)) {
          unresolved.push({ file: filename, line, in: '(module)', kind: 'client_reexported', detail: `re-export from ${n.source.value}: ${names.join(', ')}` });
        }
      } else if (n.declaration && n.declaration.type === 'VariableDeclaration') {
        for (const d of n.declaration.declarations) {
          const init = d.init ? unwrap(d.init) : null;
          if (init && init.type === 'Identifier' && (clientNames.has(init.name) || builders.has(init.name))) {
            unresolved.push({ file: filename, line, in: '(module)', kind: 'client_exported', detail: `export of ${init.name}` });
          }
        }
      } else if (n.specifiers.length) {
        for (const s of n.specifiers) {
          const exportedAs = s.exported && (s.exported.name || s.exported.value);
          if ((s.local && (clientNames.has(s.local.name) || builders.has(s.local.name))) || (exportedAs && /supabase/i.test(exportedAs))) {
            unresolved.push({ file: filename, line, in: '(module)', kind: 'client_exported', detail: `export of ${s.local ? s.local.name : '?'} as ${exportedAs}` });
          }
        }
      }
    }
    if (n.type === 'ExportAllDeclaration') {
      if (/supabase/i.test(n.source.value)) unresolved.push({ file: filename, line, in: '(module)', kind: 'client_reexported', detail: `export * from ${n.source.value}` });
      unresolved.push({ file: filename, line, in: '(module)', kind: 'export_all_reexport', detail: `export * from ${n.source.value}` });
    }
    if (n.type === 'ExportDefaultDeclaration') {
      const d = unwrap(n.declaration);
      if (d && d.type === 'Identifier' && (clientNames.has(d.name) || builders.has(d.name))) {
        unresolved.push({ file: filename, line, in: '(module)', kind: 'client_exported', detail: `default export of ${d.name}` });
      }
    }
  });
  return { entries, unresolved, imports };
}

// ---- import resolution (pure; tested)
export function resolveImport(fromFile, spec, fileSet) {
  let base;
  if (spec.startsWith('@/')) base = path.posix.join('src', spec.slice(2));
  else if (spec.startsWith('./') || spec.startsWith('../')) base = path.posix.normalize(path.posix.join(path.posix.dirname(fromFile), spec));
  else return { kind: 'external' };
  if (/\.(css|scss|svg|png|jpe?g|gif|webp|ico|json|woff2?|ttf|md|txt|csv)$/i.test(base)) return { kind: 'asset' };
  const cands = [base, ...CODE_EXT.map((e) => base + e), ...CODE_EXT.map((e) => path.posix.join(base, 'index' + e))];
  const hit = cands.find((c) => fileSet.has(c));
  return hit ? { kind: 'local', file: hit } : { kind: 'unresolved', tried: base };
}

// ---- dispositions and exit status (pure; tested)
export function leadId(u) { return `${u.file}:${u.line}:${u.kind}`; }
export const UNDISPOSABLE = new Set(['invoke_target_not_in_repository', 'invoke_closure_incomplete', 'export_all_unresolved']);
export function applyDispositions(unresolved, dispositions) {
  const d = Array.isArray(dispositions) ? Object.fromEntries(dispositions.map((x) => [x.id, x.reason])) : (dispositions || {});
  const disposed = []; const undisposed = [];
  for (const u of unresolved) {
    const id = leadId(u);
    if (!UNDISPOSABLE.has(u.kind) && d[id] && String(d[id]).trim()) disposed.push({ id, reason: d[id] });
    else undisposed.push({ id, ...u });
  }
  return { disposed, undisposed };
}
export function reachable(graph, start) {
  const seen = new Set(); const stack = [start];
  while (stack.length) { const f = stack.pop(); if (seen.has(f)) continue; seen.add(f); for (const g of (graph[f] || [])) stack.push(g); }
  return seen;
}
export function exitCodeFor(unparsedCount, undisposedCount) {
  if (unparsedCount > 0) return 2;
  if (undisposedCount > 0) return 3;
  return 0;
}

function listFiles(root, acc, excluded) {
  if (!fs.existsSync(root)) return;
  for (const d of fs.readdirSync(root, { withFileTypes: true })) {
    const p = path.posix.join(root.replace(/\\/g, '/'), d.name);
    if (d.isDirectory()) { if (/^(node_modules|dist|build|\.git|__tests__)$/.test(d.name)) { excluded.push(p + '/ (directory)'); continue; } listFiles(p, acc, excluded); continue; }
    if (!EXTENSIONS.has(path.extname(d.name))) continue;
    if (/\.(test|spec)\.[^.]+$/.test(d.name)) { excluded.push(p); continue; }
    acc.push(p);
  }
}

export function inventory(dispositions) {
  const files = []; const excluded = [];
  ROOTS.forEach((r) => listFiles(r, files, excluded));
  files.sort();
  const fileSet = new Set(files);
  const entries = []; const unresolved = []; const unparsed = []; const importGraph = {};
  for (const f of files) {
    let src;
    try { src = fs.readFileSync(f, 'utf8'); } catch (e) { unparsed.push({ file: f, error: `read failed: ${e.message}` }); continue; }
    try {
      const r = analyzeSource(src, f);
      entries.push(...r.entries); unresolved.push(...r.unresolved);
      const edges = [];
      for (const im of r.imports) {
        const res = resolveImport(f, im.specifier, fileSet);
        if (res.kind === 'local') edges.push(res.file);
        else if (im.reexport_all) unresolved.push({ file: f, line: im.line, in: '(module)', kind: 'export_all_unresolved', detail: `${im.specifier} (${res.kind}${res.tried ? ', tried ' + res.tried : ''})` });
        if (res.kind === 'unresolved' ) unresolved.push({ file: f, line: im.line, in: '(module)', kind: 'import_not_in_scanned_roots', detail: `${im.specifier} (tried ${res.tried})` });
      }
      importGraph[f] = [...new Set(edges)].sort();
    } catch (e) { unparsed.push({ file: f, error: String(e.message || e).slice(0, 300) }); }
  }
  // bind each invoke to the edge function's file and to the writes found in its WHOLE import closure
  const unparsedFiles = new Set(unparsed.map((x) => x.file));
  for (const e of entries.filter((x) => x.kind === 'functions_invoke' && x.name)) {
    const target = `supabase/functions/${e.name}/index.ts`;
    e.edge_function_file = fileSet.has(target) ? target : null;
    if (!e.edge_function_file) {
      e.writes_in_that_function = null; e.closure_files = [];
      unresolved.push({ file: e.file, line: e.line, in: e.in, kind: 'invoke_target_not_in_repository', name: e.name, detail: `${target} is not among the scanned files` });
      continue;
    }
    const closure = reachable(importGraph, target);
    e.closure_files = [...closure].sort();
    e.writes_in_that_function = entries.filter((x) => closure.has(x.file) && x.kind === 'write').map((x) => `${x.table}:${x.op}@${x.file}:${x.line}`);
    const broken = unresolved.filter((u) => closure.has(u.file) && u.kind === 'import_not_in_scanned_roots');
    if (broken.length || unparsedFiles.has(target) || [...closure].some((f) => unparsedFiles.has(f))) {
      unresolved.push({ file: e.file, line: e.line, in: e.in, kind: 'invoke_closure_incomplete', name: e.name,
        detail: `the import closure of ${target} contains ${broken.length} unresolved import(s) or an unparsed file` });
    }
  }
  const tables = {};
  for (const e of entries) {
    if (e.table === undefined) continue;
    const t = tables[e.table] || (tables[e.table] = { target: TARGET_TABLES.includes(e.table), read: [], write: {} });
    if (e.kind === 'read') t.read.push(`${e.file}:${e.line}`);
    else { const w = t.write[e.op] || (t.write[e.op] = { sites: [], payload_keys: new Set(), any_payload_unresolved: false }); w.sites.push(`${e.file}:${e.line}`); (e.payload_keys || []).forEach((k) => w.payload_keys.add(k)); if (e.payload_resolved === false) w.any_payload_unresolved = true; }
  }
  for (const t of Object.values(tables)) for (const w of Object.values(t.write)) w.payload_keys = [...w.payload_keys].sort();
  const disp = applyDispositions(unresolved, dispositions);
  return { files, excluded, entries, unresolved, unparsed, tables, importGraph, disposed: disp.disposed, undisposed: disp.undisposed };
}

// ---------------------------------------------------------------- self-test
const has = (r, pred) => r.entries.some(pred);
const lead = (r, kind) => r.unresolved.some((u) => u.kind === kind);
const FIXTURES = [
  { name: 'ts imported admin alias, double quotes, annotation', file: 'f1.ts',
    src: `import { supabaseAdmin as db } from '../_shared/supabaseAdmin.ts';\ninterface X { a: string }\nexport async function g(x: X): Promise<void> { const { data } = await db.from("study_sessions").select("id, user_id").eq("a", 1); }`,
    expect: (r) => has(r, (e) => e.kind === 'read' && e.table === 'study_sessions' && e.root_is_known_client === true) },
  { name: 'client passed as an argument, update with literal keys', file: 'f2.ts',
    src: `export async function f(client: any) { await client.from('profiles').update({ course_level: a, timezone: b }).eq('id', id); }`,
    expect: (r) => has(r, (e) => e.kind === 'write' && e.op === 'update' && e.table === 'profiles' && e.root_is_known_client === false && e.payload_keys.join() === 'course_level,timezone' && e.payload_resolved === true) },
  { name: 'split builder held in a variable, payload identifier unresolved', file: 'f3.jsx',
    src: `async function h(updates) { const q = supabase.from('flashcards'); const r = await q.update(updates); return r; }`,
    expect: (r) => has(r, (e) => e.kind === 'write' && e.op === 'update' && e.table === 'flashcards' && e.via === 'builder_variable' && e.payload_resolved === false) && lead(r, 'payload_keys_unresolved') },
  { name: 'optional call', file: 'f4.ts',
    src: `async function d() { await supabase?.from('notes')?.delete().eq('id', 1); }`,
    expect: (r) => has(r, (e) => e.kind === 'write' && e.op === 'delete' && e.table === 'notes') },
  { name: 'computed table name is unresolved', file: 'f5.js',
    src: `async function i(tbl) { await supabase.from(tbl).insert({ a: 1 }); }`,
    expect: (r) => lead(r, 'from_non_literal_table') && lead(r, 'operation_on_unresolved_table') },
  { name: 'rpc with a spread argument', file: 'f6.js',
    src: `async function r(rest) { await supabase.rpc('submit_access_request', { p_course: c, ...rest }); }`,
    expect: (r) => has(r, (e) => e.kind === 'rpc' && e.name === 'submit_access_request' && e.arg_keys.join() === 'p_course' && e.args_resolved === false) },
  { name: 'functions.invoke is a transport lead', file: 'f7.ts',
    src: `async function n() { await supabase.functions.invoke('notify-content-created', { body: {} }); }`,
    expect: (r) => has(r, (e) => e.kind === 'functions_invoke' && e.name === 'notify-content-created') && lead(r, 'invoke_transport_lead') },
  { name: 'raw fetch with a template url', file: 'f8.js',
    src: "async function p() { await fetch(`${url}/rest/v1/access_requests`, { method: 'POST' }); }",
    expect: (r) => has(r, (e) => e.kind === 'fetch' && e.method === 'POST' && e.url_text === '${...}/rest/v1/access_requests') && lead(r, 'fetch_transport_lead') },
  { name: 'insert then select is one write, not an extra read', file: 'f9.ts',
    src: `async function s() { await supabase.from('study_sessions').insert({ source: 'manual', category: c }).select(); }`,
    expect: (r) => r.entries.filter((e) => e.table === 'study_sessions').length === 1 && r.entries[0].kind === 'write' },
  { name: 'storage .from is not a table', file: 'f10.js',
    src: `async function t() { await supabase.storage.from('notes').remove([p]); }`,
    expect: (r) => r.entries.length === 0 && r.unresolved.length === 0 },
  { name: 'upsert with a spread', file: 'f11.js',
    src: `async function u() { await supabase.from('notes').upsert({ ...base, subject_id: s }); }`,
    expect: (r) => has(r, (e) => e.op === 'upsert' && e.table === 'notes' && e.payload_keys.join() === 'subject_id' && e.payload_resolved === false) },
  { name: 'insert of an array of objects unions the keys', file: 'f12.js',
    src: `async function a() { await supabase.from('flashcards').insert([{ a: 1 }, { b: 2 }]); }`,
    expect: (r) => has(r, (e) => e.op === 'insert' && e.payload_keys.join() === 'a,b' && e.payload_resolved === true) },
  { name: 'unrelated array methods are ignored', file: 'f13.js',
    src: `function z(list) { list.delete(1); const m = new Map(); m.update(2); return list.select(); }`,
    expect: (r) => r.entries.length === 0 && r.unresolved.length === 0 },
  { name: 'payload via a unique local const object', file: 'f14.js',
    src: `async function c() { const row = { user_id: u, source: 'manual' }; await supabase.from('study_sessions').insert(row); }`,
    expect: (r) => has(r, (e) => e.op === 'insert' && e.payload_keys.join() === 'user_id,source' && e.payload_resolved === true) },
  { name: 'tsx generics parse', file: 'f15.tsx',
    src: `const x = <T,>(a: T) => a; export const C = () => <div>{x<number>(1)}</div>;`,
    expect: (r) => r.entries.length === 0 },
  { name: 'alias of a builder (const alias = q) is followed', file: 'f16.js',
    src: `async function a() { const q = supabase.from("study_sessions"); const alias = q; await alias.update({ a: 1 }); }`,
    expect: (r) => has(r, (e) => e.kind === 'write' && e.op === 'update' && e.table === 'study_sessions' && e.via === 'builder_variable') },
  { name: 'alias by assignment is followed', file: 'f17.js',
    src: `async function a() { const q = supabase.from('notes'); let alias; alias = q; await alias.delete().eq('id', 1); }`,
    expect: (r) => has(r, (e) => e.kind === 'write' && e.op === 'delete' && e.table === 'notes') },
  { name: 'alias of the client itself is a known client', file: 'f18.js',
    src: `async function a() { const db = supabase; await db.from('profiles').update({ timezone: z }).eq('id', 1); }`,
    expect: (r) => has(r, (e) => e.op === 'update' && e.table === 'profiles' && e.root_is_known_client === true) },
  { name: 'builder passed in as a parameter is a lead', file: 'f19.js',
    src: `async function f(q) { await q.update({ a: 1 }).eq('id', 1); }`,
    expect: (r) => lead(r, 'write_shaped_call_unknown_receiver') },
  { name: 'awaited cache.delete is a lead (documented false-positive class, to be disposed)', file: 'f20.js',
    src: `async function f(cache) { await cache.delete('k'); }`,
    expect: (r) => lead(r, 'write_shaped_call_unknown_receiver') },
  { name: 'computed member calls resolve', file: 'f21.js',
    src: `async function f() { await supabase['from']('notes')['delete']().eq('id', 1); }`,
    expect: (r) => has(r, (e) => e.kind === 'write' && e.op === 'delete' && e.table === 'notes') },
  { name: 'non-literal rpc name is a lead', file: 'f22.js',
    src: `async function f(name) { await supabase.rpc(name, { a: 1 }); }`,
    expect: (r) => lead(r, 'rpc_name_non_literal') },
  { name: 'client passed to another function is a lead', file: 'f23.js',
    src: `async function f() { await doThing(supabase, 5); }`,
    expect: (r) => r.unresolved.some((u) => u.kind === 'client_passed_to_callee' && u.callee === 'doThing' && u.argument === 'supabase') },
  { name: 'aliased re-export (export { db as supabase } from ...) is a lead', file: 'f25.js',
    src: `export { db as supabase } from './client';`,
    expect: (r) => lead(r, 'client_reexported') },
  { name: 'export * from a supabase module is a lead', file: 'f26.js',
    src: `export * from './lib/supabase';`,
    expect: (r) => lead(r, 'client_reexported') },
  { name: 'client exported under another name is a lead', file: 'f27.js',
    src: `const db = supabase; export { db as handle };`,
    expect: (r) => lead(r, 'client_exported') },
  { name: 'generic local export * is a lead', file: 'f28.js',
    src: `export * from './client';`,
    expect: (r) => lead(r, 'export_all_reexport') },
  { name: 'export * records an import edge', file: 'f29.js',
    src: `export * from './client';`,
    expect: (r) => r.imports.some((i) => i.specifier === './client' && i.reexport_all === true) },
  { name: 'named re-export records an import edge', file: 'f30.js',
    src: `export { x } from './helper';`,
    expect: (r) => r.imports.some((i) => i.specifier === './helper') },
  { name: 'export * from a bare package is a lead', file: 'f31.js',
    src: `export * from 'some-package';`,
    expect: (r) => lead(r, 'export_all_reexport') },
  { name: 'client re-exported and exported', file: 'f24.js',
    src: `export { supabase } from './lib/supabase';\nexport const db = supabase;`,
    expect: (r) => lead(r, 'client_reexported') && lead(r, 'client_exported') },
];

export function selfTest() {
  const failures = [];
  for (const fx of FIXTURES) {
    try { const r = analyzeSource(fx.src, fx.file); if (!fx.expect(r)) failures.push(`${fx.name}: expectation not met; got ${JSON.stringify(r)}`); }
    catch (e) { failures.push(`${fx.name}: threw ${e.message}`); }
  }
  let total = FIXTURES.length;
  const check = (name, ok) => { total += 1; if (!ok) failures.push(name); };
  try { analyzeSource('const = ;', 'bad.js'); check('unparsable source did not throw', false); } catch { check('unparsable source throws', true); }
  const fs1 = new Set(['src/lib/a.js', 'src/lib/b/index.ts', 'supabase/functions/_shared/x.ts']);
  check('relative import resolves with an extension added', resolveImport('src/lib/c.js', './a', fs1).file === 'src/lib/a.js');
  check('alias import resolves to an index file', resolveImport('src/pages/p.jsx', '@/lib/b', fs1).file === 'src/lib/b/index.ts');
  check('explicit extension resolves (edge function style)', resolveImport('supabase/functions/f/index.ts', '../_shared/x.ts', fs1).file === 'supabase/functions/_shared/x.ts');
  check('missing local import is unresolved', resolveImport('src/lib/c.js', './missing', fs1).kind === 'unresolved');
  check('bare specifier is external, css is an asset', resolveImport('src/a.js', 'react', fs1).kind === 'external' && resolveImport('src/a.js', './s.css', fs1).kind === 'asset');
  check('exit status 2 when a file is unparsed', exitCodeFor(1, 5) === 2);
  check('exit status 3 when leads are undisposed', exitCodeFor(0, 1) === 3);
  check('exit status 0 only when nothing is unparsed or undisposed', exitCodeFor(0, 0) === 0);
  const leads = [{ file: 'a.js', line: 1, kind: 'x' }, { file: 'b.js', line: 2, kind: 'y' }];
  check('export * that resolves to nothing is an undisposable lead', (() => {
    const u = [{ file: 'x.js', line: 1, kind: 'export_all_unresolved' }];
    return applyDispositions(u, { 'x.js:1:export_all_unresolved': 'fine' }).undisposed.length === 1;
  })());
  check('reachable follows imports transitively and survives a cycle', (() => { const g = { a: ['b'], b: ['c'], c: ['a'] }; const s = reachable(g, 'a'); return s.size === 3 && s.has('c'); })());
  check('a disposition cannot dispose an undisposable invoke lead', (() => {
    const u = [{ file: 'x.js', line: 3, kind: 'invoke_closure_incomplete' }];
    return applyDispositions(u, { 'x.js:3:invoke_closure_incomplete': 'looks fine' }).undisposed.length === 1;
  })());
  const ap = applyDispositions(leads, { 'a.js:1:x': 'reviewed: array method', 'b.js:2:y': '   ' });
  check('a disposition with a reason disposes the lead, a blank one does not', ap.disposed.length === 1 && ap.undisposed.length === 1 && ap.undisposed[0].id === 'b.js:2:y');
  return { total, failures };
}

function gitInfo() {
  const sha = spawnSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' });
  const dirty = spawnSync('git', ['status', '--porcelain', '--', ...ROOTS], { encoding: 'utf8' });
  return { commit: (sha.stdout || '').trim(), source_roots_dirty: (dirty.stdout || '').trim().length > 0, dirty_files: (dirty.stdout || '').trim().split('\n').filter(Boolean) };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
if (isMain) {
  const args = process.argv.slice(2);
  const get = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
  const st = selfTest();
  if (args.includes('--self-test')) {
    console.log(JSON.stringify(st, null, 2));
    process.exit(st.failures.length ? 1 : 0);
  }
  if (st.failures.length) { console.error('self-test failed; no inventory produced'); console.error(JSON.stringify(st, null, 2)); process.exit(1); }
  const dispositions = get('--dispositions') ? JSON.parse(fs.readFileSync(get('--dispositions'), 'utf8')) : {};
  const inv = inventory(dispositions);
  const code = exitCodeFor(inv.unparsed.length, inv.undisposed.length);
  const out = {
    tool: 'D-04_code-inventory_v4.mjs', label: get('--label'), generated_by_node: process.version, parser: 'node_modules/@babel/parser (typescript plugin)',
    git: gitInfo(), roots: ROOTS, extensions: [...EXTENSIONS], target_tables: TARGET_TABLES,
    files_scanned: inv.files.length, excluded: inv.excluded, unparsed_files: inv.unparsed,
    verdict: inv.unparsed.length ? 'FAILED: unparsed files present (fail closed)'
      : inv.undisposed.length ? `INCOMPLETE: ${inv.undisposed.length} unresolved lead(s) without a recorded disposition (fail closed)`
      : 'COMPLETE: every lead has a recorded disposition',
    exit_status: code,
    unresolved_count: inv.unresolved.length, disposed_count: inv.disposed.length, undisposed_count: inv.undisposed.length,
    tables: inv.tables, import_graph: inv.importGraph, undisposed: inv.undisposed, disposed: inv.disposed, entries: inv.entries,
  };
  const text = JSON.stringify(out, null, 2);
  if (get('--out')) fs.writeFileSync(get('--out'), text, 'utf8'); else console.log(text);
  process.exit(code);
}
