// McCabe gate (spec §18). One fixed analyzer. Counts per function:
// if/else-if/for/for-in/for-of/while/do/case/catch/ternary/??/&&/||.
// Limits: default max 8; service files max 10; QML handlers max 5 (heuristic:
// .qml `function` + `on*:` handlers); UI helpers (theme/, components/) max 6.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';

const ROOTS = ['models', 'services', 'components', 'theme'];
const DECISION = /\b(if|else\s+if|for|while|do|case|catch)\b|\?\.|\?\?|\?[^?:\n]*: |&&|\|\|/g;

function files(dir, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) files(p, out);
    else if (['.js', '.mjs', '.qml'].includes(extname(p))) out.push(p);
  }
  return out;
}

function limitsFor(path) {
  if (path.endsWith('.qml')) {
    if (path.startsWith('components/') || path.startsWith('theme/')) return 6;
    return 5; // QML event handler default; services/models QML capped low on purpose
  }
  if (path.startsWith('services/')) return 10;
  return 8;
}

// Naive function splitter: `function name(` in JS, `function name(` + `onX:` in QML.
function functionsOf(src, ext) {
  const out = [];
  const re = ext === '.qml'
    ? /(function\s+[A-Za-z_$][\w$]*\s*\([^)]*\)|on[A-Z][\w]*\s*:)/g
    : /function\s+[A-Za-z_$][\w$]*\s*\([^)]*\)|(?:const|let|var)\s+[A-Za-z_$][\w$]*\s*=\s*(?:async\s*)?\([^)]*\)\s*=>|(?:async\s+)?[A-Za-z_$][\w$]*\s*\([^)]*\)\s*\{/g;
  let m;
  const starts = [];
  while ((m = re.exec(src))) starts.push([m[0], m.index]);
  for (let i = 0; i < starts.length; i++) {
    const body = src.slice(starts[i][1], starts[i + 1]?.[1] ?? src.length);
    out.push({ name: starts[i][0].slice(0, 60), body });
  }
  return out;
}

let failures = 0;
for (const root of ROOTS) {
  let list = [];
  try {
    if (statSync(root).isDirectory()) list = files(root);
  } catch { continue; }
  for (const f of list) {
    const src = readFileSync(f, 'utf8');
    const max = limitsFor(f);
    for (const fn of functionsOf(src, extname(f))) {
      const c = 1 + (fn.body.match(DECISION)?.length ?? 0);
      if (c > max) {
        console.error(`FAIL ${f} :: ${fn.name} :: C=${c} > max=${max}`);
        failures++;
      }
    }
  }
}
if (failures > 0) {
  console.error(`\ncomplexity gate: ${failures} violation(s)`);
  process.exit(1);
}
console.log('complexity gate: OK');
