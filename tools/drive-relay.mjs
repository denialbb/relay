#!/usr/bin/env node
import { execFileSync, spawnSync as spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { calculateCropGeometry } from './drive-geometry.mjs';

const PLUGIN_ID = 'denial.beeper-relay';
const BEEPER_URL = process.env.BEEPER_URL || 'http://127.0.0.1:23373';

function run(bin, args = [], opts = {}) {
  return execFileSync(bin, args, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], ...opts }).trim();
}

function tryRun(bin, args = []) {
  try {
    return run(bin, args);
  } catch (err) {
    return null;
  }
}

export function getStatus() {
  const pluginsRaw = tryRun('omarchy', ['plugin', 'list', '--json']);
  let plugin = null;
  if (pluginsRaw) {
    try {
      const list = JSON.parse(pluginsRaw);
      plugin = list.find(p => p.id === PLUGIN_ID);
    } catch {}
  }

  const geomRaw = tryRun('omarchy-shell', ['shell', 'debugBarGeometry']);
  let widget = null;
  if (geomRaw) {
    try {
      const list = JSON.parse(geomRaw);
      widget = list.find(w => w.id === PLUGIN_ID);
    } catch {}
  }

  return {
    pluginInstalled: !!plugin,
    pluginEnabled: plugin ? plugin.enabled : false,
    barWidgetPlaced: !!widget,
    widgetGeometry: widget
  };
}

export function locateGeometry(options = {}) {
  const monitorsRaw = tryRun('hyprctl', ['monitors', '-j']);
  const barGeomRaw = tryRun('omarchy-shell', ['shell', 'debugBarGeometry']);
  if (!monitorsRaw || !barGeomRaw) return null;

  try {
    const monitors = JSON.parse(monitorsRaw);
    const barGeom = JSON.parse(barGeomRaw);
    return calculateCropGeometry(monitors, barGeom, { widgetId: PLUGIN_ID, ...options });
  } catch (err) {
    return null;
  }
}

export function openRelay() {
  run('omarchy-shell', ['shell', 'summon', PLUGIN_ID]);
}

export function closeRelay() {
  run('omarchy-shell', ['shell', 'hide', PLUGIN_ID]);
}

export function toggleRelay() {
  run('omarchy-shell', ['shell', 'toggle', PLUGIN_ID]);
}

export function captureScreenshot(outFile, options = {}) {
  const geom = locateGeometry(options);
  if (!geom) throw new Error('Could not calculate crop geometry for ' + PLUGIN_ID);
  run('grim', ['-g', geom.geomString, outFile]);
  return { outFile, geom };
}

export function ocrScreenshot(imagePath) {
  if (!existsSync(imagePath)) throw new Error('Image not found: ' + imagePath);
  return tryRun('tesseract', [imagePath, 'stdout', '--oem', '1', '--psm', '6']) || '';
}

function fileHash(path) {
  if (!existsSync(path)) return '';
  return run('sha256sum', [path]).split(/\s+/)[0];
}

export async function preflight() {
  const results = { makeCheck: false, beeperPort: false, tokenConfigured: false, errors: [] };

  // 1. make check
  try {
    run('make', ['check']);
    results.makeCheck = true;
  } catch (e) {
    results.errors.push('make check failed: ' + (e.stderr || e.message));
  }

  // 2. probe beeper desktop port
  try {
    let token = '';
    try {
      token = readFileSync(process.env.HOME + '/.config/beeper-relay/token', 'utf8').trim();
    } catch(e) {}
    const headers = token ? { 'Authorization': 'Bearer ' + token } : {};
    const res = await fetch(`${BEEPER_URL}/v1/chats/search?unreadOnly=true&type=any`, {
      headers,
      signal: AbortSignal.timeout(3000)
    });
    // 200 or 401 proves Beeper Desktop is listening
    results.beeperPort = res.status === 200 || res.status === 401;
    results.tokenConfigured = res.status === 200;
  } catch (e) {
    results.errors.push(`Beeper Desktop not reachable at ${BEEPER_URL}: ${e.message}`);
  }

  return results;
}

export async function verifyLoop(outDir) {
  const targetDir = resolve(outDir || process.env.RELAY_VERIFY_DIR || '/tmp/omarchy-relay-verify');
  if (!existsSync(targetDir)) mkdirSync(targetDir, { recursive: true });

  console.log(`[1/5] Running preflight...`);
  const pf = await preflight();
  console.log(`  make check: ${pf.makeCheck ? 'OK' : 'FAIL'}`);
  console.log(`  beeper port: ${pf.beeperPort ? 'OK' : 'FAIL'} (token configured: ${pf.tokenConfigured})`);
  if (!pf.makeCheck) throw new Error('Preflight make check failed');

  console.log(`[2/5] Ensuring closed & capturing baseline...`);
  closeRelay();
  await new Promise(r => setTimeout(r, 1200));
  const beforeImg = join(targetDir, 'closed_before.png');
  captureScreenshot(beforeImg);
  const beforeHash = fileHash(beforeImg);
  console.log(`  Saved baseline: ${beforeImg} (${beforeHash.slice(0, 8)})`);

  console.log(`[3/5] Opening Relay drawer...`);
  openRelay();
  await new Promise(r => setTimeout(r, 1500));
  const openImg = join(targetDir, 'open.png');
  captureScreenshot(openImg);
  const openHash = fileHash(openImg);
  console.log(`  Saved open screenshot: ${openImg} (${openHash.slice(0, 8)})`);

  if (beforeHash === openHash) {
    throw new Error('Open assertion failed: screen did not change after openRelay()');
  }

  console.log(`[4/5] Running OCR verification...`);
  const text = ocrScreenshot(openImg);
  const foundKeywords = ['Connection Error', 'unauthorized', 'credentials', 'Retry', 'Beeper'].filter(k =>
    text.toLowerCase().includes(k.toLowerCase())
  );
  console.log(`  Detected keywords: ${foundKeywords.join(', ')}`);
  const hasDrawerContent = text.toLowerCase().includes('connection error') ||
                           text.toLowerCase().includes('credentials') ||
                           text.toLowerCase().includes('retry') ||
                           text.toLowerCase().includes('no unread');
  if (!hasDrawerContent) {
    throw new Error(`OCR verification failed: expected drawer content ('Connection Error' / 'credentials' / 'Retry') in ${openImg}. Raw OCR: ${JSON.stringify(text)}`);
  }

  console.log(`[5/5] Closing drawer & verifying clean dismiss...`);
  closeRelay();
  await new Promise(r => setTimeout(r, 1200));
  const afterImg = join(targetDir, 'closed_after.png');
  captureScreenshot(afterImg);
  const afterHash = fileHash(afterImg);
  console.log(`  Saved after dismiss: ${afterImg} (${afterHash.slice(0, 8)})`);

  if (afterHash === openHash) {
    throw new Error('Dismiss assertion failed: screen still shows open drawer after closeRelay()');
  }

  const afterText = ocrScreenshot(afterImg);
  if (afterText.toLowerCase().includes('connection error')) {
    throw new Error(`Dismiss OCR failed: 'Connection Error' still visible after dismiss`);
  }

  console.log(`\nVerification loop complete. All assertions passed! Screenshots saved in ${targetDir}`);
  return { pf, beforeImg, openImg, afterImg, foundKeywords };
}

// CLI entry point
import { fileURLToPath } from 'node:url';

function isDirectRun() {
  if (!process.argv[1]) return false;
  return fileURLToPath(import.meta.url) === resolve(process.argv[1]);
}

if (isDirectRun()) {
  const [cmd, ...args] = process.argv.slice(2);
  if (!cmd || cmd === '--help' || cmd === '-h') {
    console.log(`Usage: node tools/drive-relay.mjs <command> [args...]

Commands:
  status                Show enabled status and bar position
  open                  Open the Relay drawer
  close                 Close the Relay drawer
  toggle                Toggle open/closed state
  locate                Print calculated crop geometry for grim
  screenshot <file>     Capture drawer area screenshot
  ocr <file>            Run OCR on screenshot and print text
  preflight             Run test suite and probe Beeper Desktop port
  verify-loop [outdir]  Full automated preflight, drive, screenshot, OCR loop
`);
  process.exit(0);
}

try {
  if (cmd === 'status') {
    console.log(JSON.stringify(getStatus(), null, 2));
  } else if (cmd === 'open') {
    openRelay();
    console.log('Opened Relay');
  } else if (cmd === 'close') {
    closeRelay();
    console.log('Closed Relay');
  } else if (cmd === 'toggle') {
    toggleRelay();
    console.log('Toggled Relay');
  } else if (cmd === 'locate') {
    console.log(locateGeometry());
  } else if (cmd === 'screenshot') {
    const file = args[0] || 'relay-screenshot.png';
    const res = captureScreenshot(file);
    console.log(`Saved screenshot to ${res.outFile} (geometry: ${res.geom.geomString})`);
  } else if (cmd === 'ocr') {
    console.log(ocrScreenshot(args[0]));
  } else if (cmd === 'preflight') {
    const res = await preflight();
    console.log(JSON.stringify(res, null, 2));
    if (!res.makeCheck) process.exit(1);
  } else if (cmd === 'verify-loop') {
    await verifyLoop(args[0]);
  } else {
    console.error(`Unknown command: ${cmd}`);
    process.exit(1);
  }
} catch (e) {
  console.error(`Error: ${e.message}`);
  process.exit(1);
}
}
