import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateCropGeometry } from '../tools/drive-geometry.mjs';

test('calculateCropGeometry returns correct geometry for focused monitor', () => {
  const monitors = [
    { name: 'DP-2', focused: false, x: 1920, y: 60, width: 1920, height: 1080 },
    { name: 'DP-1', focused: true, x: 3840, y: 0, width: 1920, height: 1080 }
  ];
  const barWidgets = [
    { id: 'omarchy.clock', x: 908, y: 0, width: 104, height: 26 },
    { id: 'denial.beeper-relay', x: 1723, y: 0, width: 27, height: 26 }
  ];

  const geom = calculateCropGeometry(monitors, barWidgets);
  assert.ok(geom);
  assert.equal(typeof geom.geomString, 'string');
  assert.ok(geom.geomString.startsWith('5')); // DP-1 is at 3840 + 1723 = ~5563
  assert.equal(geom.monitor.name, 'DP-1');
  assert.ok(geom.width >= 400);
  assert.ok(geom.height >= 600);
});

test('calculateCropGeometry falls back to first monitor if none focused', () => {
  const monitors = [
    { name: 'eDP-1', focused: false, x: 0, y: 0, width: 1920, height: 1080 }
  ];
  const barWidgets = [
    { id: 'denial.beeper-relay', x: 1700, y: 0, width: 27, height: 26 }
  ];

  const geom = calculateCropGeometry(monitors, barWidgets);
  assert.equal(geom.monitor.name, 'eDP-1');
  assert.ok(geom.x >= 0);
});

test('calculateCropGeometry returns null if widget not in barWidgets', () => {
  const monitors = [{ name: 'DP-1', focused: true, x: 0, y: 0, width: 1920, height: 1080 }];
  const barWidgets = [{ id: 'omarchy.clock', x: 908, y: 0, width: 104, height: 26 }];

  const geom = calculateCropGeometry(monitors, barWidgets);
  assert.equal(geom, null);
});
