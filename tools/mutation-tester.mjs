import { readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const target = 'models/TriageModel.js';
const original = readFileSync(target, 'utf8');

const mutations = [
  { match: /===/g, replace: '!==' },
  { match: /!==/g, replace: '===' },
  { match: /&&/g, replace: '||' },
  { match: /\|\|/g, replace: '&&' },
  { match: /\+ /g, replace: '- ' },
  { match: / > 0/g, replace: ' >= 0' },
  { match: / > 0/g, replace: ' < 0' },
  { match: /return true/g, replace: 'return false' },
  { match: /return false/g, replace: 'return true' }
];

let total = 0;
let killed = 0;
let survived = 0;

console.log(`Running mutation tests on ${target}...`);

for (const mut of mutations) {
  let matchCount = (original.match(mut.match) || []).length;
  if (matchCount === 0) continue;

  for (let i = 0; i < matchCount; i++) {
    let index = 0;
    const mutated = original.replace(mut.match, (m) => {
      if (index++ === i) return mut.replace;
      return m;
    });

    writeFileSync(target, mutated);
    total++;
    
    try {
      execSync('node --test tests/triage-model.test.js tests/message-classification.test.js', { stdio: 'ignore' });
      console.log(`SURVIVED: replaced ${mut.match} with ${mut.replace} (instance ${i+1})`);
      survived++;
    } catch (err) {
      killed++;
    }
  }
}

writeFileSync(target, original);

console.log(`\nMutation results: ${killed}/${total} mutants killed.`);
if (survived > 0) {
  console.log(`WARNING: ${survived} mutants survived.`);
  process.exit(1);
} else {
  console.log('SUCCESS: All mutants killed.');
}
