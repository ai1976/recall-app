// D-04_code-inventory.mjs - T-002 diagnostic D4 (v1): TypeScript-capable inventory of every backend call in the frontend and the edge functions.
//
// Purpose (docs/database/t002/00_DIAGNOSTIC-BATCH_proposal_v1.md, D4; QA Round 14 PASS WITH CONDITIONS, authoring only; condition 1 is built in):
// list, for every `.from(t).select/insert/update/upsert/delete`, every `.rpc(name, args)`, every `.functions.invoke(name)`, every `fetch(...)` and every
// other transport lead in the source roots, the table or name, the operation, the PARSED payload keys, and whether anything could not be resolved.
// READS are inventoried as well as writes (the privilege ceilings of plan v6 section 10B depend on who reads a relation).
//
// What it is and is not:
//  - It parses with @babel/parser and its `typescript` plugin (present in node_modules as a transitive dependency; making it an explicit devDependency is a
//    separate package.json change that this file does NOT make). The existing guard scripts/dueSetGuard.mjs uses espree, which cannot read the edge functions.
//  - It is deliberately CONSERVATIVE and does not depend on knowing which identifier is the Supabase client: any `.from(x).<op>(...)` chain is reported, with the
//    root identifier recorded and whether it is a known client binding. A client passed as an argument, an alias, an import with `as`, optional calls and a
//    builder held in a variable are all handled (see --self-test).
//  - FAIL CLOSED: a file that cannot be parsed, a `.from()` whose table is not a literal, a payload whose keys cannot be read, an op on a builder variable of
//    unknown table, an RPC or invoke whose name is not a literal, and any `fetch` / other transport are listed as UNRESOLVED or as leads; the run exits with a
//    non-zero status when any file is unparsed, and the self-test must pass before an inventory run is meaningful.
//  - It reads source files only. It makes no network call, writes nothing except the optional --out file, and runs no database statement.
//  - It is a code-side inventory at ONE commit. It is not evidence about the database, and it does not see code that is not in the roots.
//
// Usage:
//   node docs/database/t002/D-04_code-inventory.mjs --self-test
//   node docs/database/t002/D-04_code-inventory.mjs --label pre-F0 --out docs/discussions/evidence/T-002_D4-pre-F0_<dd-mm-yyyy>.json
// Roots: src and supabase/functions. Extensions: .js .jsx .mjs .cjs .ts .tsx. Excluded: node_modules, dist, build, *.test.*, *.spec.*, __tests__.
// Test files are excluded because they are not deployed code; their list is still reported so the exclusion is auditable.

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

// Flatten `a.b(c).d(e)` into { root, links: [{t:'member',name}, {t:'call',node}, ...] } from the root outward.
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

// Keys of an object-shaped payload. resolved=false when anything cannot be read (spread, computed key, identifier not defined as a unique literal in the file).
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
  const clientNames = new Set(KNOWN_CLIENT_NAMES);
  const fileObjects = new Map();
  const builders = new Map(); // variable name -> { tables:Set, ambiguous }

  // Pass 1: imports of clients, local object literals, builder variables.
  walk(ast, (n) => {
    if (n.type === 'ImportDeclaration') {
      const src = n.source.value;
      if (/supabase/i.test(src)) n.specifiers.forEach((s) => { if (s.local) clientNames.add(s.local.name); });
    }
    if (n.type === 'VariableDeclarator' && n.id.type === 'Identifier' && n.init) {
      const init = unwrap(n.init);
      if (init && init.type === 'ObjectExpression') {
        const list = fileObjects.get(n.id.name) || []; list.push(init); fileObjects.set(n.id.name, list);
      }
      if (isCall(init) && unwrap(init.callee) && unwrap(init.callee).type === 'Identifier' && unwrap(init.callee).name === 'createClient') clientNames.add(n.id.name);
      const f = flatten(init);
      if (f.links.some((l) => l.t === 'member' && l.name === 'from') && !f.links.some((l) => l.t === 'member' && OPS.has(l.name)) && !f.links.some((l) => l.t === 'member' && l.name === 'storage')) {
        const fi = f.links.findIndex((l) => l.t === 'member' && l.name === 'from');
        const call = f.links[fi + 1];
        const lit = call && call.t === 'call' ? literalString(call.node.arguments[0]) : { ok: false };
        const b = builders.get(n.id.name) || { tables: new Set(), ambiguous: false };
        if (lit.ok) b.tables.add(lit.value); else b.ambiguous = true;
        builders.set(n.id.name, b);
      }
      if (init && init.type === 'Identifier' && clientNames.has(init.name)) clientNames.add(n.id.name);
    }
  });

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

    // .from(non-literal) anywhere (not storage)
    if (prev && prev.t === 'member' && prev.name === 'from') {
      const isStorage = links.slice(0, -2).some((l) => l.t === 'member' && l.name === 'storage');
      if (!isStorage) {
        const lit = literalString(n.arguments[0]);
        if (!lit.ok) unresolved.push({ ...base, kind: 'from_non_literal_table', detail: 'table argument is not a string literal' });
      }
    }

    // operation on a chain: last is a call whose member name is an op
    if (last && last.t === 'call' && prev && prev.t === 'member' && OPS.has(prev.name)) {
      const op = prev.name;
      const before = links.slice(0, links.length - 2);
      if (before.some((l) => l.t === 'member' && l.name === 'storage')) return;
      // a select after a write is a returning modifier, not a read
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
      } else if (rn && clientNames.has(rn) && !before.some((l) => l.t === 'member' && l.name === 'from')) {
        return; // e.g. supabase.auth.update... not a table chain; storage handled above
      } else {
        return; // an unrelated .select/.update/.delete (arrays, maps, sets, query libraries)
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
      return;
    }

    // fetch(...) / globalThis.fetch(...) / window.fetch(...)
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
      return;
    }
  });

  // new XMLHttpRequest / axios / got / ky as other transport leads
  walk(ast, (n, anc) => {
    const line = n.loc ? n.loc.start.line : null;
    if (n.type === 'NewExpression' && n.callee.type === 'Identifier' && (n.callee.name === 'XMLHttpRequest' || n.callee.name === 'WebSocket' || n.callee.name === 'EventSource')) {
      unresolved.push({ file: filename, line, in: enclosingName(anc), kind: 'other_transport_lead', detail: n.callee.name });
    }
    if (n.type === 'ImportDeclaration' && /^(axios|got|ky|superagent|node-fetch|undici)$/.test(n.source.value)) {
      unresolved.push({ file: filename, line, in: '(module)', kind: 'other_transport_lead', detail: `import ${n.source.value}` });
    }
  });
  return { entries, unresolved };
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

export function inventory() {
  const files = []; const excluded = [];
  ROOTS.forEach((r) => listFiles(r, files, excluded));
  files.sort();
  const entries = []; const unresolved = []; const unparsed = [];
  for (const f of files) {
    let src;
    try { src = fs.readFileSync(f, 'utf8'); } catch (e) { unparsed.push({ file: f, error: `read failed: ${e.message}` }); continue; }
    try { const r = analyzeSource(src, f); entries.push(...r.entries); unresolved.push(...r.unresolved); }
    catch (e) { unparsed.push({ file: f, error: String(e.message || e).slice(0, 300) }); }
  }
  // per-table matrix
  const tables = {};
  for (const e of entries) {
    if (e.table === undefined) continue;
    const t = tables[e.table] || (tables[e.table] = { target: TARGET_TABLES.includes(e.table), read: [], write: {} });
    if (e.kind === 'read') t.read.push(`${e.file}:${e.line}`);
    else { const w = t.write[e.op] || (t.write[e.op] = { sites: [], payload_keys: new Set(), any_payload_unresolved: false }); w.sites.push(`${e.file}:${e.line}`); (e.payload_keys || []).forEach((k) => w.payload_keys.add(k)); if (e.payload_resolved === false) w.any_payload_unresolved = true; }
  }
  for (const t of Object.values(tables)) for (const w of Object.values(t.write)) w.payload_keys = [...w.payload_keys].sort();
  return { files, excluded, entries, unresolved, unparsed, tables };
}

// ---------------------------------------------------------------- self-test fixtures
const FIXTURES = [
  { name: 'ts imported admin alias, double quotes, annotation', file: 'f1.ts',
    src: `import { supabaseAdmin as db } from '../_shared/supabaseAdmin.ts';\ninterface X { a: string }\nexport async function g(x: X): Promise<void> { const { data } = await db.from("study_sessions").select("id, user_id").eq("a", 1); }`,
    expect: (r) => r.entries.some((e) => e.kind === 'read' && e.table === 'study_sessions' && e.root_is_known_client === true) },
  { name: 'client passed as an argument, update with literal keys', file: 'f2.ts',
    src: `export async function f(client: any) { await client.from('profiles').update({ course_level: a, timezone: b }).eq('id', id); }`,
    expect: (r) => r.entries.some((e) => e.kind === 'write' && e.op === 'update' && e.table === 'profiles' && e.root_is_known_client === false && e.payload_keys.join() === 'course_level,timezone' && e.payload_resolved === true) },
  { name: 'split builder held in a variable, payload identifier unresolved', file: 'f3.jsx',
    src: `async function h(updates) { const q = supabase.from('flashcards'); const r = await q.update(updates); return r; }`,
    expect: (r) => r.entries.some((e) => e.kind === 'write' && e.op === 'update' && e.table === 'flashcards' && e.via === 'builder_variable' && e.payload_resolved === false) && r.unresolved.some((u) => u.kind === 'payload_keys_unresolved') },
  { name: 'optional call', file: 'f4.ts',
    src: `async function d() { await supabase?.from('notes')?.delete().eq('id', 1); }`,
    expect: (r) => r.entries.some((e) => e.kind === 'write' && e.op === 'delete' && e.table === 'notes') },
  { name: 'computed table name is unresolved', file: 'f5.js',
    src: `async function i(tbl) { await supabase.from(tbl).insert({ a: 1 }); }`,
    expect: (r) => r.unresolved.some((u) => u.kind === 'from_non_literal_table') && r.unresolved.some((u) => u.kind === 'operation_on_unresolved_table') },
  { name: 'rpc with a spread argument', file: 'f6.js',
    src: `async function r(rest) { await supabase.rpc('submit_access_request', { p_course: c, ...rest }); }`,
    expect: (r) => r.entries.some((e) => e.kind === 'rpc' && e.name === 'submit_access_request' && e.arg_keys.join() === 'p_course' && e.args_resolved === false) },
  { name: 'functions.invoke', file: 'f7.ts',
    src: `async function n() { await supabase.functions.invoke('notify-content-created', { body: {} }); }`,
    expect: (r) => r.entries.some((e) => e.kind === 'functions_invoke' && e.name === 'notify-content-created') },
  { name: 'raw fetch with a template url', file: 'f8.js',
    src: "async function p() { await fetch(`${url}/rest/v1/access_requests`, { method: 'POST' }); }",
    expect: (r) => r.entries.some((e) => e.kind === 'fetch' && e.method === 'POST' && e.url_text === '${...}/rest/v1/access_requests') && r.unresolved.some((u) => u.kind === 'fetch_transport_lead') },
  { name: 'insert then select is one write, not an extra read', file: 'f9.ts',
    src: `async function s() { await supabase.from('study_sessions').insert({ source: 'manual', category: c }).select(); }`,
    expect: (r) => r.entries.filter((e) => e.table === 'study_sessions').length === 1 && r.entries[0].kind === 'write' },
  { name: 'storage .from is not a table', file: 'f10.js',
    src: `async function t() { await supabase.storage.from('notes').remove([p]); }`,
    expect: (r) => r.entries.length === 0 && r.unresolved.length === 0 },
  { name: 'upsert with a spread', file: 'f11.js',
    src: `async function u() { await supabase.from('notes').upsert({ ...base, subject_id: s }); }`,
    expect: (r) => r.entries.some((e) => e.op === 'upsert' && e.table === 'notes' && e.payload_keys.join() === 'subject_id' && e.payload_resolved === false) },
  { name: 'insert of an array of objects unions the keys', file: 'f12.js',
    src: `async function a() { await supabase.from('flashcards').insert([{ a: 1 }, { b: 2 }]); }`,
    expect: (r) => r.entries.some((e) => e.op === 'insert' && e.payload_keys.join() === 'a,b' && e.payload_resolved === true) },
  { name: 'unrelated array methods are ignored', file: 'f13.js',
    src: `function z(list) { list.delete(1); const m = new Map(); m.update(2); return list.select(); }`,
    expect: (r) => r.entries.length === 0 && r.unresolved.length === 0 },
  { name: 'payload via a unique local const object', file: 'f14.js',
    src: `async function c() { const row = { user_id: u, source: 'manual' }; await supabase.from('study_sessions').insert(row); }`,
    expect: (r) => r.entries.some((e) => e.op === 'insert' && e.payload_keys.join() === 'user_id,source' && e.payload_resolved === true) },
  { name: 'tsx generics and satisfies parse', file: 'f15.tsx',
    src: `const x = <T,>(a: T) => a; export const C = () => <div>{x<number>(1)}</div>;`,
    expect: (r) => r.entries.length === 0 },
];

export function selfTest() {
  const failures = [];
  for (const fx of FIXTURES) {
    try { const r = analyzeSource(fx.src, fx.file); if (!fx.expect(r)) failures.push(`${fx.name}: expectation not met; got ${JSON.stringify(r)}`); }
    catch (e) { failures.push(`${fx.name}: threw ${e.message}`); }
  }
  // an unparsable file must throw (fail closed)
  try { analyzeSource('const = ;', 'bad.js'); failures.push('unparsable source did not throw'); } catch { /* expected */ }
  return { total: FIXTURES.length + 1, failures };
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
  const inv = inventory();
  const out = {
    tool: 'D-04_code-inventory.mjs v1', label: get('--label'), generated_by_node: process.version, parser: 'node_modules/@babel/parser (typescript plugin)',
    git: gitInfo(), roots: ROOTS, extensions: [...EXTENSIONS], target_tables: TARGET_TABLES,
    files_scanned: inv.files.length, excluded: inv.excluded, unparsed_files: inv.unparsed,
    verdict: inv.unparsed.length ? 'FAILED: unparsed files present (fail closed)' : 'parsed all files',
    unresolved_count: inv.unresolved.length, tables: inv.tables, unresolved: inv.unresolved, entries: inv.entries,
  };
  const text = JSON.stringify(out, null, 2);
  if (get('--out')) fs.writeFileSync(get('--out'), text, 'utf8'); else console.log(text);
  process.exit(inv.unparsed.length ? 2 : 0);
}
