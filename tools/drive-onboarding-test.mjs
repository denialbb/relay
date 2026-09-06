#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, statSync } from 'node:fs';
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
  const home = process.env.HOME || '/home/denial';
  const tokenFile = join(home, '.config/beeper-relay/token');
  const tokenBak = join(home, '.config/beeper-relay/token.bak');
  const tokenDisabled = join(home, '.config/beeper-relay/token.disabled_test');

  if (!existsSync(tokenBak)) {
    throw new Error('Backup token not found at ' + tokenBak);
  }

  const tokenValue = readFileSync(tokenBak, 'utf8').trim();
  if (!tokenValue) {
    throw new Error('Token in backup is empty');
  }

  console.log('Step 1: Moving active token away to trigger onboarding...');
  if (existsSync(tokenFile)) {
    run('mv', [tokenFile, tokenDisabled]);
  }

  console.log('Step 2: Restarting shell to reload Relay without token...');
  run('/usr/share/omarchy/bin/omarchy-restart-shell');
  await sleep(1500);

  console.log('Step 3: Summoning Relay drawer...');
  run('omarchy-shell', ['shell', 'summon', 'denial.beeper-relay', '{}']);
  await sleep(600);

  const sPrompt = join(outDir, 'onboarding_01_prompt.png');
  captureScreenshot(sPrompt, { cardHeight: 500 });
  console.log('Captured onboarding prompt screenshot:', sPrompt);

  console.log('Timer: Waiting 6 seconds so you can watch the OnboardingView on screen...');
  for (let i = 6; i > 0; i--) {
    console.log(`[Watch Screen] Onboarding prompt visible... ${i}s remaining`);
    await sleep(1000);
  }

  console.log('Step 4: Typing token into onboarding input...');
  text(tokenValue);
  await sleep(500);

  const sTyped = join(outDir, 'onboarding_02_typed.png');
  captureScreenshot(sTyped, { cardHeight: 500 });
  console.log('Captured typed token screenshot:', sTyped);

  await sleep(1000);

  console.log('Step 5: Submitting token (Enter)...');
  key('Return');
  await sleep(1000);

  console.log('Timer: Waiting 6 seconds so you can watch transition to connected inbox...');
  for (let i = 6; i > 0; i--) {
    console.log(`[Watch Screen] Connected inbox / chat list loading... ${i}s remaining`);
    await sleep(1000);
  }

  const sConnected = join(outDir, 'onboarding_03_connected.png');
  captureScreenshot(sConnected, { cardHeight: 500 });
  console.log('Captured connected view screenshot:', sConnected);

  console.log('Step 6: Verifying saved token file on disk...');
  if (!existsSync(tokenFile)) {
    throw new Error('Token file was not recreated at ' + tokenFile);
  }
  const savedToken = readFileSync(tokenFile, 'utf8').trim();
  if (savedToken !== tokenValue) {
    throw new Error('Saved token does not match backup token!');
  }
  const stat = statSync(tokenFile);
  const mode = (stat.mode & 0o777).toString(8);
  console.log('Token file recreated successfully! Mode:', mode);

  if (existsSync(tokenDisabled)) {
    run('rm', ['-f', tokenDisabled]);
  }

  console.log('Step 7: Closing drawer...');
  await sleep(1500);
  run('omarchy-shell', ['shell', 'hide', 'denial.beeper-relay']);

  console.log('Step 8: Restarting shell to ensure clean production state...');
  run('/usr/share/omarchy/bin/omarchy-restart-shell');
  await sleep(1500);

  console.log('Final verification: Confirming token file integrity...');
  const finalToken = readFileSync(tokenFile, 'utf8').trim();
  if (finalToken !== tokenValue) {
    throw new Error('Final token verification failed! Does not match backup.');
  }
  console.log('Test completed successfully and verified clean!');
}

main().catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
