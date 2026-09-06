#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { captureScreenshot } from './drive-relay.mjs';

const outDir = '/tmp/omarchy-relay-verify';
mkdirSync(outDir, { recursive: true });

function run(bin, args) {
  return execFileSync(bin, args, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

function key(k) {
  try {
    run('wtype', ['-k', k]);
  } catch(e) {
    console.error('wtype key error:', e.message);
  }
}

function ctrlKey(k) {
  try {
    run('wtype', ['-M', 'ctrl', '-k', k, '-m', 'ctrl']);
  } catch(e) {
    console.error('wtype ctrlKey error:', e.message);
  }
}

function text(str) {
  try {
    run('wtype', [str]);
  } catch(e) {
    console.error('wtype text error:', e.message);
  }
}

async function main() {
  console.log('Driving UI verification fast...');
  try {
    // 1. Toggle open
    run('omarchy-shell', ['shell', 'summon', 'denial.beeper-relay', '{}']);
    await sleep(500);

    // Capture standard height
    const s1 = join(outDir, '01_drawer_standard.png');
    captureScreenshot(s1, { cardHeight: 500 });
    console.log('Captured:', s1);

    // 2. Test growing height with Ctrl+j (press twice, +100px)
    ctrlKey('j');
    await sleep(150);
    ctrlKey('j');
    await sleep(350); // allow animation to finish
    const sGrown = join(outDir, '06_drawer_grown.png');
    captureScreenshot(sGrown, { cardHeight: 550 });
    console.log('Captured:', sGrown);

    // 3. Test shrinking height with Ctrl+k (press 3 times, -150px)
    ctrlKey('k');
    await sleep(150);
    ctrlKey('k');
    await sleep(150);
    ctrlKey('k');
    await sleep(350); // allow animation to finish
    const sShrunk = join(outDir, '07_drawer_shrunk.png');
    captureScreenshot(sShrunk, { cardHeight: 500 });
    console.log('Captured:', sShrunk);

    // Restore standard height (Ctrl+j once)
    ctrlKey('j');
    await sleep(250);

    // 4. Toggle '?' expanded (with C-j/k hint)
    text('?');
    await sleep(250);
    const s2 = join(outDir, '02_drawer_expanded.png');
    captureScreenshot(s2, { cardHeight: 500 });
    console.log('Captured:', s2);

    // Toggle '?' back
    text('?');
    await sleep(200);

    // 5. Open conversation view with Enter / o
    key('Return');
    await sleep(350);

    // Test grow inside conversation
    ctrlKey('j');
    await sleep(300);
    const s5 = join(outDir, '05_drawer_conversation.png');
    captureScreenshot(s5, { cardHeight: 550 });
    console.log('Captured:', s5);

    // Close conversation and close drawer
    key('Escape');
    await sleep(200);
    key('Escape');
    await sleep(200);
  } finally {
    try {
      run('omarchy-shell', ['shell', 'hide', 'denial.beeper-relay', '{}']);
    } catch {}
  }
  console.log('Done driving UI verification.');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
