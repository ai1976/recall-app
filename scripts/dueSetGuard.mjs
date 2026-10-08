// scripts/dueSetGuard.mjs
//
// T-001 brief C v6, C-6.4: the fail-closed guard behind the "due set" refresh signal.
//
// What it guarantees (and what it does not):
//  - It reads every source file in src/ with a real JavaScript parser (espree, the parser ESLint uses) and finds every call that can change data through
//    a RECOGNISED transport: a Supabase client `.rpc(...)`, a Supabase client `.from(table).insert / update / upsert / delete(...)`, a Supabase storage
//    write, an Edge Function call (`.functions.invoke`), a `fetch(...)`, and the creation of a Supabase client.
//  - Each such call must have exactly one entry in scripts/dueSetManifest.json, identified by a syntax-derived identity (file, enclosing symbol, kind and
//    target, with an ordinal for repeats), never by a line number. A call without an entry, an entry without a call, and a duplicate entry all fail.
//  - A call classified "due-changing" may only live in src/lib/dueSet.js (the wrapper module); everywhere else only "not-due-changing" entries are accepted,
//    with a reason, AND a call to any name or column on the due-mutating lists is refused outside the module whatever the manifest says.
//  - It is binding-aware: the Supabase client is whatever `@/lib/supabase` exports (and aliases of it); a `.rpc` or write on anything else is reported as
//    unbound and fails. An unresolved table name, a variable-held RPC name or a profile payload whose keys cannot be read from literals fails outside the
//    wrapper module (fail-closed).
//  - A NEW backend mutation transport (a new Edge Function route, a raw HTTP database endpoint, a new persistence client) is only seen if it uses one of the
//    recognised shapes above; a genuinely new shape needs an update of THIS file and its tests, which is why the transports are listed explicitly.
//  - It is a guard against omission and a syntax check; it does not prove runtime behaviour (the wrapper tests do), and the "not-due-changing" reasons are
//    review work that the manifest records and a reviewer owns.

import fs from 'node:fs';
import path from 'node:path';
import * as espree from 'espree';

export const WRAPPER_MODULE = 'src/lib/dueSet.js';
export const WRITE_METHODS = new Set(['insert', 'update', 'upsert', 'delete']);

// The RPC names and table writes that change what is due for the signed-in user (brief C v6 P6-E5). A call to any of them outside the wrapper module fails.
export const DUE_MUTATING_RPCS = new Set([
  'apply_review', 'skip_card', 'suspend_card', 'unsuspend_card', 'reset_card', 'skip_topic_cards', 'suspend_topic_cards',
  'add_to_my_cards', 'remove_from_my_cards', 'bulk_pause_my_cards', 'bulk_resume_my_cards', 'bulk_remove_from_my_cards',
]);
export const DUE_PROFILE_COLUMNS = new Set(['course_level', 'timezone']);
// Flashcard columns that can change what is due (the course rule, concept cards, visibility): an update of any of them, or of a payload whose keys cannot be read, must live in the wrapper module.
export const DUE_FLASHCARD_COLUMNS = new Set(['target_course', 'question_type', 'visibility', 'subject_id', 'discipline_id']);

// Per-name classification of every RPC the frontend calls, built from the accepted live-body evidence (T-001 diagnostics 11 v4 and 12): { names: { <rpc>: { classification, ... } } }.
export function loadRpcClassification(file) {
  const j = JSON.parse(fs.readFileSync(file, 'utf8'));
  return new Map(Object.entries(j.names));
}

const MANIFEST_BASIS = new Set([
  'saved live function body', 'live catalogue analysis (diagnostic 11 v4 W1 and diagnostic 12 W2)', 'repository SQL (may have drifted)', 'function name and call site only', 'table write read in code', 'infrastructure',
]);

function isClientImportSource(source) {
  return /(^|\/)lib\/supabase(\.js)?$/.test(source) || source === '@/lib/supabase';
}

function rootOf(node) {
  let n = node;
  for (;;) {
    if (!n) return null;
    if (n.type === 'MemberExpression') n = n.object;
    else if (n.type === 'CallExpression') n = n.callee;
    else if (n.type === 'AwaitExpression') n = n.argument;
    else if (n.type === 'ChainExpression') n = n.expression;
    else return n;
  }
}

function propName(member) {
  if (member.type !== 'MemberExpression') return null;
  if (!member.computed && member.property.type === 'Identifier') return member.property.name;
  if (member.computed && member.property.type === 'Literal' && typeof member.property.value === 'string') return member.property.value;
  return null;
}

function literalString(node) {
  if (!node) return null;
  if (node.type === 'Literal' && typeof node.value === 'string') return node.value;
  if (node.type === 'TemplateLiteral' && node.expressions.length === 0 && node.quasis.length === 1) return node.quasis[0].value.cooked;
  return null;
}

// Collect the names that stand for the Supabase client in one file: imports from the client module, `createClient(...)` results, and aliases of those.
function clientNames(ast) {
  const names = new Set();
  for (const node of ast.body) {
    if (node.type === 'ImportDeclaration' && isClientImportSource(String(node.source.value))) {
      for (const s of node.specifiers) names.add(s.local.name);
    }
  }
  const declarators = [];
  (function walk(n) {
    if (!n || typeof n.type !== 'string') return;
    if (n.type === 'VariableDeclarator' && n.id.type === 'Identifier' && n.init) declarators.push(n);
    for (const k of Object.keys(n)) {
      if (k === 'loc' || k === 'range') continue;
      const v = n[k];
      if (Array.isArray(v)) v.forEach(walk); else if (v && typeof v.type === 'string') walk(v);
    }
  })(ast);
  for (let pass = 0; pass < 3; pass++) {
    for (const d of declarators) {
      const init = d.init.type === 'AwaitExpression' ? d.init.argument : d.init;
      if (init.type === 'Identifier' && names.has(init.name)) names.add(d.id.name);
      if (init.type === 'CallExpression' && init.callee.type === 'Identifier' && init.callee.name === 'createClient') names.add(d.id.name);
    }
  }
  return names;
}

function payloadKeys(arg) {
  if (!arg) return { keys: [], resolved: true };
  if (arg.type === 'ArrayExpression') {
    const all = new Set();
    let resolved = true;
    for (const el of arg.elements) {
      const r = payloadKeys(el);
      r.keys.forEach(k => all.add(k));
      resolved = resolved && r.resolved;
    }
    return { keys: [...all].sort(), resolved };
  }
  if (arg.type !== 'ObjectExpression') return { keys: [], resolved: false };
  const keys = [];
  let resolved = true;
  for (const p of arg.properties) {
    if (p.type !== 'Property' || p.computed) { resolved = false; continue; }
    if (p.key.type === 'Identifier') keys.push(p.key.name);
    else if (p.key.type === 'Literal') keys.push(String(p.key.value));
    else resolved = false;
  }
  return { keys: keys.sort(), resolved };
}

// Scan one source text. `file` is the repository-relative path with forward slashes.
export function scanSource(file, code) {
  const ast = espree.parse(code, { ecmaVersion: 'latest', sourceType: 'module', ecmaFeatures: { jsx: true }, loc: true });
  const clients = clientNames(ast);
  const calls = [];
  const stack = [];

  function symbolName() {
    const names = stack.filter(Boolean);
    return names.length ? names.join('>') : 'module';
  }

  function chainInfo(callee) {
    // walk down the chain collecting member names and the table passed to .from(...)
    let n = callee;
    const members = [];
    let fromArg;
    let fromSeen = false;
    for (;;) {
      if (!n) break;
      if (n.type === 'MemberExpression') { members.push(propName(n)); n = n.object; }
      else if (n.type === 'CallExpression') {
        if (n.callee.type === 'MemberExpression' && propName(n.callee) === 'from') { fromSeen = true; fromArg = n.arguments[0]; }
        n = n.callee;
      }
      else if (n.type === 'AwaitExpression') n = n.argument;
      else if (n.type === 'ChainExpression') n = n.expression;
      else break;
    }
    return { members, fromSeen, fromArg };
  }

  function visit(node, parent) {
    if (!node || typeof node.type !== 'string') return;
    let pushed = false;
    if (node.type === 'FunctionDeclaration' && node.id) { stack.push(node.id.name); pushed = true; }
    else if ((node.type === 'FunctionExpression' || node.type === 'ArrowFunctionExpression')) {
      let name = null;
      if (parent && parent.type === 'VariableDeclarator' && parent.id.type === 'Identifier') name = parent.id.name;
      else if (parent && parent.type === 'Property' && parent.key && parent.key.type === 'Identifier') name = parent.key.name;
      else if (parent && parent.type === 'MethodDefinition' && parent.key && parent.key.type === 'Identifier') name = parent.key.name;
      else if (node.id) name = node.id.name;
      stack.push(name); pushed = true;
    }

    // A client method used as a VALUE (`const call = supabase.rpc`, `.rpc.bind(...)`) or the client destructured (`const { rpc } = supabase`) would hide a
    // call from the shapes above, so it is reported as an escape and always fails.
    if (node.type === 'MemberExpression') {
      const m = propName(node);
      if (m === 'rpc' || m === 'from') {
        const root = rootOf(node);
        const isClient = !!(root && root.type === 'Identifier' && clients.has(root.name));
        const isCallee = !!(parent && parent.type === 'CallExpression' && parent.callee === node);
        if (isClient && !isCallee) {
          calls.push({ file, symbol: symbolName(), kind: 'escape', target: m, method: null, bound: true, line: node.loc.start.line, payload: null });
        }
      }
    }
    if (node.type === 'VariableDeclarator' && node.id.type === 'ObjectPattern' && node.init) {
      const init = node.init.type === 'AwaitExpression' ? node.init.argument : node.init;
      if (init.type === 'Identifier' && clients.has(init.name)) {
        calls.push({ file, symbol: symbolName(), kind: 'escape', target: 'destructured', method: null, bound: true, line: node.loc.start.line, payload: null });
      }
    }

    if (node.type === 'CallExpression') {
      const callee = node.callee;
      const line = node.loc.start.line;
      if (callee.type === 'MemberExpression') {
        const m = propName(callee);
        const root = rootOf(callee);
        const rootName = root && root.type === 'Identifier' ? root.name : null;
        const bound = !!(rootName && clients.has(rootName));
        const info = chainInfo(callee);
        if (m === 'rpc') {
          const name = literalString(node.arguments[0]);
          calls.push({ file, symbol: symbolName(), kind: 'rpc', target: name === null ? 'DYNAMIC' : name, method: null, bound, line, payload: null });
        } else if (WRITE_METHODS.has(m) && info.fromSeen) {
          const table = literalString(info.fromArg);
          const isStorage = info.members.includes('storage');
          const pk = payloadKeys(node.arguments[0]);
          calls.push({
            file, symbol: symbolName(), kind: isStorage ? 'storage-write' : 'table-write', target: table === null ? 'DYNAMIC' : table,
            method: m, bound, line, payload: m === 'delete' ? { keys: [], resolved: true } : pk,
          });
        } else if (m === 'invoke' && info.members.includes('functions')) {
          const name = literalString(node.arguments[0]);
          calls.push({ file, symbol: symbolName(), kind: 'edge-function', target: name === null ? 'DYNAMIC' : name, method: null, bound, line, payload: null });
        }
      } else if (callee.type === 'Identifier' && callee.name === 'fetch') {
        const a = node.arguments[0];
        let target = literalString(a);
        if (target === null && a && a.type === 'TemplateLiteral') {
          target = a.quasis.map(q => q.value.cooked).join('${}');
        }
        calls.push({ file, symbol: symbolName(), kind: 'http', target: target === null ? 'DYNAMIC' : target, method: null, bound: true, line, payload: null });
      } else if (callee.type === 'Identifier' && callee.name === 'createClient') {
        calls.push({ file, symbol: symbolName(), kind: 'client-creation', target: 'createClient', method: null, bound: true, line, payload: null });
      }
    }

    for (const k of Object.keys(node)) {
      if (k === 'loc' || k === 'range' || k === 'parent') continue;
      const v = node[k];
      if (Array.isArray(v)) v.forEach(c => visit(c, node)); else if (v && typeof v.type === 'string') visit(v, node);
    }
    if (pushed) stack.pop();
  }
  visit(ast, null);

  // identities: file::symbol::kind:target[.method]  with an ordinal for repeats within the same (file, symbol, kind, target, method)
  const seen = new Map();
  for (const c of calls) {
    const base = `${c.file}::${c.symbol}::${c.kind}:${c.target}${c.method ? '.' + c.method : ''}`;
    const n = (seen.get(base) || 0) + 1;
    seen.set(base, n);
    c.id = n === 1 ? base : `${base}#${n}`;
  }
  return calls;
}

export function listSourceFiles(root) {
  const out = [];
  (function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) { if (e.name === 'node_modules' || e.name === 'test') continue; walk(p); }
      else if (/\.(js|jsx)$/.test(e.name) && !/\.test\.(js|jsx)$/.test(e.name)) out.push(p);
    }
  })(path.join(root, 'src'));
  return out.sort();
}

export function scanTree(root) {
  const calls = [];
  for (const abs of listSourceFiles(root)) {
    const rel = path.relative(root, abs).split(path.sep).join('/');
    calls.push(...scanSource(rel, fs.readFileSync(abs, 'utf8')));
  }
  return calls;
}

// Evaluate calls against a manifest (array of { id, classification, reason, basis }). Returns an array of failure strings; empty means the guard passes.
export function evaluateGuard(calls, manifest, rpcClass = null) {
  const failures = [];
  const byId = new Map();
  for (const e of manifest) {
    if (byId.has(e.id)) failures.push(`duplicate manifest entry: ${e.id}`);
    byId.set(e.id, e);
  }
  const callIds = new Set();
  for (const c of calls) {
    if (callIds.has(c.id)) failures.push(`duplicate call identity (internal): ${c.id}`);
    callIds.add(c.id);
    const inWrapper = c.file === WRAPPER_MODULE;
    if (c.kind === 'escape') failures.push(`client method used as a value or the client destructured (use a direct call so it can be classified): ${c.id} (line ${c.line})`);
    const entry = byId.get(c.id);
    if (!entry) failures.push(`unclassified call (add a reviewed manifest entry): ${c.id} (line ${c.line})`);
    if (!c.bound && (c.kind === 'rpc' || c.kind === 'table-write' || c.kind === 'storage-write' || c.kind === 'edge-function')) {
      failures.push(`call on a client that is not the Supabase client binding: ${c.id} (line ${c.line})`);
    }
    if (!inWrapper) {
      if (c.target === 'DYNAMIC') failures.push(`unresolved target outside the wrapper module: ${c.id} (line ${c.line})`);
      const dueRpc = rpcClass ? rpcClass.get(c.target)?.classification === 'due-changing' : DUE_MUTATING_RPCS.has(c.target);
      if (c.kind === 'rpc' && dueRpc) failures.push(`due-mutating RPC outside the wrapper module: ${c.id} (line ${c.line})`);
      if (c.kind === 'table-write' && c.target === 'profiles') {
        if (!c.payload || !c.payload.resolved) failures.push(`profiles write with a payload whose keys cannot be read from literals, outside the wrapper module: ${c.id} (line ${c.line})`);
        else if (c.payload.keys.some(k => DUE_PROFILE_COLUMNS.has(k))) failures.push(`profiles write of course_level or timezone outside the wrapper module: ${c.id} (line ${c.line})`);
      }
      if (c.kind === 'table-write' && c.target === 'flashcards' && c.method === 'update') {
        if (!c.payload || !c.payload.resolved) failures.push(`flashcards update with a payload whose keys cannot be read from literals, outside the wrapper module: ${c.id} (line ${c.line})`);
        else if (c.payload.keys.some(k => DUE_FLASHCARD_COLUMNS.has(k))) failures.push(`flashcards update of a due-relevant column (target_course, question_type, visibility, subject_id, discipline_id) outside the wrapper module: ${c.id} (line ${c.line})`);
      }
      if (c.kind === 'table-write' && c.target === 'flashcard_decks' && c.method === 'delete') {
        failures.push(`deck delete outside the wrapper module (it cascades to the deck's cards): ${c.id} (line ${c.line})`);
      }
      if (c.kind === 'table-write' && (c.target === 'friendships')) {
        // updates and deletes of friendships change who can see friends-only cards: must use the wrapper
        failures.push(`friendship write outside the wrapper module: ${c.id} (line ${c.line})`);
      }
      if (c.kind === 'table-write' && (c.target === 'flashcards' || c.target === 'notes') && c.method === 'delete') {
        failures.push(`card or note delete outside the wrapper module: ${c.id} (line ${c.line})`);
      }
      if (entry && entry.classification === 'due-changing') failures.push(`a due-changing call may only live in ${WRAPPER_MODULE}: ${c.id}`);
    } else if (entry && entry.classification !== 'due-changing' && entry.classification !== 'infrastructure') {
      failures.push(`every call inside the wrapper module must be due-changing or infrastructure: ${c.id}`);
    }
    if (rpcClass && c.kind === 'rpc' && c.target !== 'DYNAMIC') {
      const cls = rpcClass.get(c.target);
      if (!cls) failures.push(`RPC name not classified from the live-body evidence (add it to the RPC classification after a catalogue check): ${c.id} (line ${c.line})`);
      else {
        if (entry && entry.classification !== 'infrastructure' && entry.classification !== cls.classification) failures.push(`manifest classification differs from the RPC classification (${cls.classification}) for ${c.id}`);
        if (inWrapper && cls.classification !== 'due-changing') failures.push(`an RPC called inside the wrapper module must be classified due-changing: ${c.id}`);
      }
    }
    if (entry) {
      if (!['due-changing', 'not-due-changing', 'infrastructure'].includes(entry.classification)) failures.push(`bad classification on ${c.id}`);
      if (typeof entry.reason !== 'string' || entry.reason.trim().length < 20) failures.push(`manifest reason missing or too short: ${c.id}`);
      if (!MANIFEST_BASIS.has(entry.basis)) failures.push(`manifest basis missing or not allowed: ${c.id}`);
    }
  }
  for (const e of manifest) if (!callIds.has(e.id)) failures.push(`stale manifest entry (no such call in the tree): ${e.id}`);
  return failures;
}
