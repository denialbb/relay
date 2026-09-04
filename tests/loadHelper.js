import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Load a `.pragma library` QML helper into Node without regex parsing.
// Top-level function/var declarations become sandbox properties after
// running the source in a fresh context — nested functions and comments
// can't break this, unlike the old matchAll(/function .../) approach.
export function loadHelper(filePath) {
  const raw = readFileSync(filePath, 'utf8').replace(/^\s*\.pragma\s+library\s*$/m, '');
  const sandbox = {};
  vm.createContext(sandbox);
  vm.runInContext(raw, sandbox, { filename: filePath });
  // Functions run in the vm realm, so their return values carry vm-realm
  // prototypes (deepStrictEqual-safe only within one realm). structuredClone
  // re-roots results into main-realm objects; helpers are pure data-in/out.
  const out = {};
  for (const key of Object.keys(sandbox)) {
    const v = sandbox[key];
    out[key] = typeof v === 'function'
      ? (...args) => structuredClone(v(...args))
      : structuredClone(v);
  }
  return out;
}
