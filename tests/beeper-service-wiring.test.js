// Regression guard for a QML wiring bug with no runtime seam in this suite:
// the request collector dispatched its result on `parent`, which is not the
// Process, so every callback was dropped and the inbox never populated.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(
  new URL("../services/BeeperService.qml", import.meta.url),
  "utf8",
);

test("request callbacks dispatch on the Process, not the collector parent", () => {
  assert.match(source, /handleRequestStreamFinished\(requestProc,\s*stdoutCol\.text\)/);
  assert.doesNotMatch(source, /handleRequestStreamFinished\(parent,/);
});

test("the Process has the id the collector references", () => {
  assert.match(source, /Process\s*\{[\s\S]*?id:\s*requestProc/);
});
