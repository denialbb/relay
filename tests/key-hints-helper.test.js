import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { loadHelper } from "./loadHelper.js";

const hintsHelper = loadHelper("./components/KeyHintsHelper.js");

describe("KeyHintsHelper", () => {
  const hints = [
    { key: "j/k", label: "nav" },
    { key: "o", label: "open" },
    { key: "r", label: "read" },
    { key: "i", label: "reply" },
    { key: "h", label: "hide pinned" },
    { key: "C-j/k", label: "size" },
    { key: "?", label: "less" }
  ];

  it("formatHints returns empty string for empty hints", () => {
    assert.equal(hintsHelper.formatHints(null, false, "#777", "#fff"), "");
    assert.equal(hintsHelper.formatHints([], false, "#777", "#fff"), "");
  });

  it("formatHints uses non-breaking space between key and label and inside labels", () => {
    const single = [{ key: "C-j/k", label: "hide pinned" }];
    const formatted = hintsHelper.formatHints(single, false, "#777", "#fff");
    assert.ok(formatted.includes("\u00A0"));
    assert.ok(formatted.includes("hide\u00A0pinned"));
  });

  it("formatHints single-line does not have trailing dot symbol", () => {
    const formatted = hintsHelper.formatHints(hints.slice(0, 3), false, "#777", "#fff");
    assert.ok(!formatted.trim().endsWith("·"));
    assert.ok(!formatted.trim().endsWith("·</font>"));
  });

  it("formatHints multi-line splits into rows without trailing dots on lines", () => {
    const formatted = hintsHelper.formatHints(hints, true, "#777", "#fff");
    const lines = formatted.split("<br>");
    assert.equal(lines.length, 2);
    for (const line of lines) {
      assert.ok(!line.trim().endsWith("·"));
      assert.ok(!line.trim().endsWith("·</font>"));
    }
  });
});
