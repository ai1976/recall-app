// Runs the due-set guard against the real tree (T-001 brief C v6 C-6.4). Exit 1 and print every failure when any call is unclassified or breaks a rule.
// Used by `npm run guard:due` and by `prebuild`, so a build cannot succeed with an unclassified database call.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scanTree, evaluateGuard, loadRpcClassification } from './dueSetGuard.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(here, 'dueSetManifest.json'), 'utf8')).entries;
const rpcClass = loadRpcClassification(path.join(here, 'dueSetRpcClassification.json'));
const calls = scanTree(root);
const failures = evaluateGuard(calls, manifest, rpcClass);
if (failures.length) {
  console.error(`due-set guard FAILED (${failures.length}):\n` + failures.map((f) => `  - ${f}`).join('\n'));
  process.exit(1);
}
console.log(`due-set guard passed: ${calls.length} database calls, all classified (${manifest.length} manifest entries).`);
