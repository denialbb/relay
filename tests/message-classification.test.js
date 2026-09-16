import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { loadHelper } from "./loadHelper.js";

const { classifyMessage, unsupportedTag, normalizeMessage } = loadHelper(
  "./models/TriageModel.js",
);

describe("message classification", () => {
  it("TEXT with text -> text", () => {
    assert.equal(classifyMessage({ type: "TEXT", text: "hello" }), "text");
  });
  it("media with caption stays unsupported", () => {
    assert.equal(
      classifyMessage({ type: "IMAGE", text: "caption" }),
      "unsupported",
    );
    assert.equal(
      classifyMessage({ type: "VIDEO", text: "caption" }),
      "unsupported",
    );
  });
  it("empty/blank/missing text -> unsupported", () => {
    assert.equal(classifyMessage({ type: "TEXT", text: "" }), "unsupported");
    assert.equal(classifyMessage({ type: "TEXT", text: "  " }), "unsupported");
    assert.equal(classifyMessage({ type: "TEXT" }), "unsupported");
  });
  it("unknown type -> unsupported", () => {
    assert.equal(classifyMessage({ type: "STICKER" }), "unsupported");
    assert.equal(classifyMessage({}), "unsupported");
  });
});

describe("unsupportedTag", () => {
  it("labels media kinds", () => {
    assert.equal(unsupportedTag({ type: "IMAGE" }), "Image");
    assert.equal(unsupportedTag({ type: "VIDEO" }), "Video");
    assert.equal(unsupportedTag({ type: "VOICE" }), "Audio");
    assert.equal(unsupportedTag({ type: "AUDIO" }), "Audio");
  });
  it("deleted wins over media kind", () => {
    assert.equal(unsupportedTag({ type: "IMAGE", isDeleted: true }), "Deleted");
    assert.equal(
      unsupportedTag({ type: "TEXT", text: "", isDeleted: true }),
      "Deleted",
    );
  });
  it("falls back to Unsupported", () => {
    assert.equal(unsupportedTag({ type: "STICKER" }), "Sticker");
    assert.equal(unsupportedTag({}), "Unsupported");
    assert.equal(unsupportedTag(null), "Unsupported");
  });
  it("normalizeMessage carries tag only for unsupported", () => {
    assert.equal(normalizeMessage({ type: "IMAGE" }).tag, "Image");
    assert.equal(normalizeMessage({ type: "TEXT", text: "hi" }).tag, null);
  });
});
