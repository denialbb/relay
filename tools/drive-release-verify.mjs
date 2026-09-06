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

    // Capture collapsed
    const s1 = join(outDir, '01_drawer_collapsed.png');
    captureScreenshot(s1);
    console.log('Captured:', s1);

    // 2. Toggle '?' expanded
    text('?');
    await sleep(250);
    const s2 = join(outDir, '02_drawer_expanded.png');
    captureScreenshot(s2);
    console.log('Captured:', s2);

    // Toggle '?' back
    text('?');
    await sleep(200);

    // 3. Toggle 'h' (hide pinned)
    text('h');
    await sleep(250);
    const s3 = join(outDir, '03_drawer_hidden_pins.png');
    captureScreenshot(s3);
    console.log('Captured:', s3);

    // Toggle 'h' back
    text('h');
    await sleep(200);

    // 4. Test quick reply expansion
    text('i');
    await sleep(250);
    text('Testing multiline quick reply expansion inside compact Relay drawer. Typing a long response that spans across multiple lines to verify auto-growth behavior.');
    await sleep(350);
    const s4 = join(outDir, '04_drawer_quick_reply.png');
    captureScreenshot(s4);
    console.log('Captured:', s4);

    // Cancel quick reply
    key('Escape');
    await sleep(200);

    // 5. Open conversation view with Enter / o
    key('Return');
    await sleep(350);
    const s5 = join(outDir, '05_drawer_conversation.png');
    captureScreenshot(s5);
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
