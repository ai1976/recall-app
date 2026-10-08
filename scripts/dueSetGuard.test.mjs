// Tests for the due-set guard (T-001 brief C v6, C-6.5 item 5): the guard must pass on the real tree with the reviewed manifest and must FAIL on planted
// cases: an unclassified literal-named RPC, an unclassified table write, a variable-held RPC name, a spread-payload profile update, an aliased client
// (which must be recognised, not ignored), a variable table name, a client that is not the Supabase binding, a due-mutating RPC outside the wrapper module,
// a course_level or timezone write outside it, a friendship delete outside it, a stale and a duplicate manifest entry, and a due-changing entry outside it.
import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scanSource, scanTree, evaluateGuard, loadRpcClassification, WRAPPER_MODULE } from './dueSetGuard.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');

const IMPORT = "import { supabase } from '@/lib/supabase';\n";
const entry = (id, classification = 'not-due-changing') => ({
  id, classification, reason: 'planted test entry with a reason of sufficient length', basis: 'table write read in code',
});
// Evaluate a planted snippet with a manifest that classifies exactly the calls it contains as not-due-changing (so only the structural rules can fail).
function failuresFor(file, code, extraManifest = []) {
  const calls = scanSource(file, code);
  const manifest = [...calls.map((c) => entry(c.id)), ...extraManifest];
  return { calls, failures: evaluateGuard(calls, manifest) };
}
function failuresWithEmptyManifest(file, code) {
  const calls = scanSource(file, code);
  return { calls, failures: evaluateGuard(calls, []) };
}

describe('the real tree', () => {
  it('has a reviewed manifest entry for every call, none stale, none duplicated, and passes every structural rule', () => {
    const calls = scanTree(root);
    const manifest = JSON.parse(fs.readFileSync(path.join(here, 'dueSetManifest.json'), 'utf8')).entries;
    const rpcClass = loadRpcClassification(path.join(here, 'dueSetRpcClassification.json'));
    expect(evaluateGuard(calls, manifest, rpcClass)).toEqual([]);
  });

  it('keeps every due-changing call inside the wrapper module', () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(here, 'dueSetManifest.json'), 'utf8')).entries;
    const outside = manifest.filter((e) => e.classification === 'due-changing' && !e.id.startsWith(`${WRAPPER_MODULE}::`));
    expect(outside).toEqual([]);
  });
});

describe('planted cases the guard must refuse', () => {
  it('an unclassified literal-named RPC', () => {
    const { failures } = failuresWithEmptyManifest('src/pages/X.jsx', `${IMPORT}export function f(){ return supabase.rpc('some_new_rpc', {}); }`);
    expect(failures.join('\n')).toMatch(/unclassified call.*rpc:some_new_rpc/);
  });

  it('an unclassified table write', () => {
    const { failures } = failuresWithEmptyManifest('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('notes').update({ title: 'a' }).eq('id', 1); }`);
    expect(failures.join('\n')).toMatch(/unclassified call.*table-write:notes\.update/);
  });

  it('a variable-held RPC name outside the wrapper module', () => {
    const { failures } = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(name){ return supabase.rpc(name, {}); }`);
    expect(failures.join('\n')).toMatch(/unresolved target outside the wrapper module.*rpc:DYNAMIC/);
  });

  it('a variable-held RPC name chosen through a map', () => {
    const { failures } = failuresFor('src/pages/X.jsx', `${IMPORT}const MAP = { a: 'bulk_pause_my_cards' };\nexport async function f(k){ return supabase.rpc(MAP[k], {}); }`);
    expect(failures.join('\n')).toMatch(/unresolved target/);
  });

  it('a variable table name', () => {
    const { failures } = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(t){ await supabase.from(t).delete().eq('id', 1); }`);
    expect(failures.join('\n')).toMatch(/unresolved target outside the wrapper module.*table-write:DYNAMIC\.delete/);
  });

  it('a profile update whose payload is a spread or a variable', () => {
    const spread = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(extra){ await supabase.from('profiles').update({ ...extra }).eq('id', 1); }`);
    expect(spread.failures.join('\n')).toMatch(/cannot be read from literals/);
    const variable = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(p){ await supabase.from('profiles').update(p).eq('id', 1); }`);
    expect(variable.failures.join('\n')).toMatch(/cannot be read from literals/);
    const computed = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(k){ await supabase.from('profiles').update({ [k]: 1 }).eq('id', 1); }`);
    expect(computed.failures.join('\n')).toMatch(/cannot be read from literals/);
  });

  it('a profile update of course_level or timezone outside the wrapper module, including a multi-line object', () => {
    const code = `${IMPORT}export async function f(){\n  await supabase\n    .from('profiles')\n    .update({\n      full_name: 'A',\n      course_level: 'CA',\n    })\n    .eq('id', 1);\n}`;
    const { failures } = failuresFor('src/pages/X.jsx', code);
    expect(failures.join('\n')).toMatch(/course_level or timezone outside the wrapper module/);
    const tz = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('profiles').update({ timezone: 'UTC' }).eq('id', 1); }`);
    expect(tz.failures.join('\n')).toMatch(/course_level or timezone outside the wrapper module/);
  });

  it('a due-mutating RPC outside the wrapper module, even when the manifest says not-due-changing', () => {
    for (const name of ['apply_review', 'skip_card', 'suspend_card', 'unsuspend_card', 'reset_card', 'skip_topic_cards', 'suspend_topic_cards',
      'add_to_my_cards', 'remove_from_my_cards', 'bulk_pause_my_cards', 'bulk_resume_my_cards', 'bulk_remove_from_my_cards']) {
      const { failures } = failuresFor('src/pages/X.jsx', `${IMPORT}export function f(){ return supabase.rpc('${name}', {}); }`);
      expect(failures.join('\n')).toMatch(/due-mutating RPC outside the wrapper module/);
    }
  });

  it('any friendship write, and a card or note delete, outside the wrapper module', () => {
    const a = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('friendships').delete().eq('id', 1); }`);
    expect(a.failures.join('\n')).toMatch(/friendship write outside the wrapper module/);
    const b = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('friendships').update({ status: 'accepted' }).eq('id', 1); }`);
    expect(b.failures.join('\n')).toMatch(/friendship write outside the wrapper module/);
    const c = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('flashcards').delete().eq('id', 1); }`);
    expect(c.failures.join('\n')).toMatch(/card or note delete outside the wrapper module/);
    const d = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('notes').delete().in('id', [1]); }`);
    expect(d.failures.join('\n')).toMatch(/card or note delete outside the wrapper module/);
  });

  it('sending or creating a friendship is also a friendship write and belongs in the wrapper module (an upsert can replace an accepted row)', () => {
    const { failures } = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('friendships').insert({ user_id: 1, friend_id: 2 }); }`);
    expect(failures.join('\n')).toMatch(/friendship write outside the wrapper module/);
  });

  it('an ALIASED client is still recognised (so its calls need classification), not ignored', () => {
    const code = `${IMPORT}const sb = supabase;\nexport function f(){ return sb.rpc('aliased_rpc', {}); }`;
    const { calls, failures } = failuresWithEmptyManifest('src/pages/X.jsx', code);
    expect(calls).toHaveLength(1);
    expect(calls[0].bound).toBe(true);
    expect(failures.join('\n')).toMatch(/unclassified call.*rpc:aliased_rpc/);
    expect(failures.join('\n')).not.toMatch(/not the Supabase client binding/);
  });

  it('a call on something that is not the Supabase client binding', () => {
    const { failures } = failuresFor('src/pages/X.jsx', `import other from 'elsewhere';\nexport function f(){ return other.rpc('x', {}); }`);
    expect(failures.join('\n')).toMatch(/not the Supabase client binding/);
    const w = failuresFor('src/pages/X.jsx', `import other from 'elsewhere';\nexport async function f(){ await other.from('notes').update({ a: 1 }); }`);
    expect(w.failures.join('\n')).toMatch(/not the Supabase client binding/);
  });

  it('other backend transports are listed, not ignored: fetch, functions.invoke, storage writes and client creation', () => {
    const code = `${IMPORT}export async function f(){\n  await fetch('https://x.example/functions/v1/new-route', { method: 'POST' });\n  await supabase.functions.invoke('new-fn', {});\n  await supabase.storage.from('b').update('p', 1);\n}`;
    const calls = scanSource('src/pages/X.jsx', code);
    expect(calls.map((c) => c.kind).sort()).toEqual(['edge-function', 'http', 'storage-write']);
    const { failures } = failuresWithEmptyManifest('src/pages/X.jsx', code);
    expect(failures.filter((x) => x.startsWith('unclassified call'))).toHaveLength(3);
    const cc = scanSource('src/lib/other.js', `import { createClient } from '@supabase/supabase-js';\nexport const c = createClient('u', 'k');`);
    expect(cc.map((x) => x.kind)).toEqual(['client-creation']);
  });

  it('the client used as a value or destructured cannot hide a call', () => {
    const MSG = /client method used as a value or the client destructured/;
    const val = failuresFor('src/pages/X.jsx', `${IMPORT}const call = supabase.rpc;\nexport function f(){ return call('apply_review', {}); }`);
    expect(val.failures.join('\n')).toMatch(MSG);
    const bound = failuresFor('src/pages/X.jsx', `${IMPORT}export function f(){ return supabase.rpc.bind(supabase)('apply_review', {}); }`);
    expect(bound.failures.join('\n')).toMatch(MSG);
    const destr = failuresFor('src/pages/X.jsx', `${IMPORT}const { rpc, from } = supabase;\nexport function f(){ return rpc('apply_review', {}); }`);
    expect(destr.failures.join('\n')).toMatch(MSG);
    const fromVal = failuresFor('src/pages/X.jsx', `${IMPORT}const q = supabase.from;\nexport function f(){ return q('notes'); }`);
    expect(fromVal.failures.join('\n')).toMatch(MSG);
    // an ordinary read through a chain, and destructuring the RESULT of a call, are not escapes
    const ok = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ const { data, error } = await supabase.from('notes').select('id'); return [data, error]; }`);
    expect(ok.failures).toEqual([]);
  });

  it('does not confuse an ordinary Map or Set delete with a database write', () => {
    const { calls } = failuresWithEmptyManifest('src/pages/X.jsx', `${IMPORT}export function f(m, s){ m.delete(1); s.delete(2); return [1].update; }`);
    expect(calls).toEqual([]);
  });

  it('a stale manifest entry and a duplicate manifest entry', () => {
    const code = `${IMPORT}export function f(){ return supabase.rpc('a_rpc', {}); }`;
    const calls = scanSource('src/pages/X.jsx', code);
    const good = entry(calls[0].id);
    expect(evaluateGuard(calls, [good, entry('src/pages/X.jsx::gone::rpc:removed_rpc')]).join('\n')).toMatch(/stale manifest entry/);
    expect(evaluateGuard(calls, [good, good]).join('\n')).toMatch(/duplicate manifest entry/);
  });

  it('a due-changing classification anywhere but the wrapper module, and a not-due-changing one inside it', () => {
    const code = `${IMPORT}export function f(){ return supabase.rpc('a_rpc', {}); }`;
    const calls = scanSource('src/pages/X.jsx', code);
    expect(evaluateGuard(calls, [entry(calls[0].id, 'due-changing')]).join('\n')).toMatch(/due-changing call may only live in/);
    const inside = scanSource(WRAPPER_MODULE, `${IMPORT}export function f(){ return supabase.rpc('apply_review', {}); }`);
    expect(evaluateGuard(inside, [entry(inside[0].id, 'not-due-changing')]).join('\n')).toMatch(/inside the wrapper module must be due-changing/);
    expect(evaluateGuard(inside, [entry(inside[0].id, 'due-changing')])).toEqual([]);
  });

  it('a manifest entry without a real reason or an allowed basis', () => {
    const code = `${IMPORT}export function f(){ return supabase.rpc('a_rpc', {}); }`;
    const calls = scanSource('src/pages/X.jsx', code);
    expect(evaluateGuard(calls, [{ id: calls[0].id, classification: 'not-due-changing', reason: 'x', basis: 'table write read in code' }]).join('\n')).toMatch(/reason missing or too short/);
    expect(evaluateGuard(calls, [{ id: calls[0].id, classification: 'not-due-changing', reason: 'a reason that is long enough', basis: 'because' }]).join('\n')).toMatch(/basis missing or not allowed/);
  });

  it('call identities do not depend on line numbers: moving a call down keeps its identity, a repeat gets an ordinal', () => {
    const a = scanSource('src/pages/X.jsx', `${IMPORT}export function f(){ supabase.rpc('r1', {}); supabase.rpc('r1', {}); }`);
    const b = scanSource('src/pages/X.jsx', `${IMPORT}\n\n\n// moved down\nexport function f(){ supabase.rpc('r1', {}); supabase.rpc('r1', {}); }`);
    expect(a.map((c) => c.id)).toEqual(b.map((c) => c.id));
    expect(a[1].id.endsWith('#2')).toBe(true);
  });
});

describe('per-name RPC classification and the new table rules', () => {
  const rpcClass = new Map([
    ['read_only_rpc', { classification: 'not-due-changing' }],
    ['writes_reviews', { classification: 'due-changing' }],
  ]);
  const withClass = (file, code, ids) => {
    const calls = scanSource(file, code);
    return evaluateGuard(calls, calls.map((c) => entry(c.id, ids ? ids(c) : 'not-due-changing')), rpcClass).join('\n');
  };

  it('an RPC name that has no classification from the evidence', () => {
    expect(withClass('src/pages/X.jsx', `${IMPORT}export function f(){ return supabase.rpc('brand_new_rpc', {}); }`)).toMatch(/RPC name not classified from the live-body evidence/);
  });

  it('a due-changing RPC name called outside the wrapper module', () => {
    expect(withClass('src/pages/X.jsx', `${IMPORT}export function f(){ return supabase.rpc('writes_reviews', {}); }`)).toMatch(/due-mutating RPC outside the wrapper module/);
  });

  it('a manifest entry that disagrees with the RPC classification', () => {
    const calls = scanSource('src/pages/X.jsx', `${IMPORT}export function f(){ return supabase.rpc('read_only_rpc', {}); }`);
    expect(evaluateGuard(calls, [entry(calls[0].id, 'due-changing')], rpcClass).join('\n')).toMatch(/manifest classification differs from the RPC classification/);
  });

  it('an RPC called inside the wrapper module that is not classified due-changing', () => {
    const inside = scanSource(WRAPPER_MODULE, `${IMPORT}export function f(){ return supabase.rpc('read_only_rpc', {}); }`);
    expect(evaluateGuard(inside, [entry(inside[0].id, 'due-changing')], rpcClass).join('\n')).toMatch(/must be classified due-changing/);
  });

  it('a flashcards update of target_course, question_type, visibility, subject_id or discipline_id, or of an unreadable payload, outside the wrapper module', () => {
    for (const payload of ["{ target_course: 'CA Final' }", "{ question_type: 'concept_card' }", "{ visibility: 'public' }", "{ subject_id: 's1' }", "{ discipline_id: 'd1' }"]) {
      const { failures } = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('flashcards').update(${payload}).eq('id', 1); }`);
      expect(failures.join('\n')).toMatch(/flashcards update of a due-relevant column/);
    }
    const spread = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(u){ await supabase.from('flashcards').update(u).eq('batch_id', 1); }`);
    expect(spread.failures.join('\n')).toMatch(/flashcards update with a payload whose keys cannot be read/);
    const ok = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('flashcards').update({ front_text: 'a', back_text: 'b' }).eq('id', 1); }`);
    expect(ok.failures).toEqual([]);
  });

  it('a deck delete and any friendship write outside the wrapper module', () => {
    const deck = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('flashcard_decks').delete().eq('id', 1); }`);
    expect(deck.failures.join('\n')).toMatch(/deck delete outside the wrapper module/);
    const upsert = failuresFor('src/pages/X.jsx', `${IMPORT}export async function f(){ await supabase.from('friendships').upsert({ status: 'pending' }); }`);
    expect(upsert.failures.join('\n')).toMatch(/friendship write outside the wrapper module/);
  });
});
