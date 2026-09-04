// Layer 1b — message classification matrix (spec §11). RED.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { classifyMessage } from '../models/TriageModel.js';

describe('message classification', () => {
  it('TEXT with text -> text', () => {
    assert.equal(classifyMessage({ type: 'TEXT', text: 'hello' }), 'text');
  });
  it('media with caption stays unsupported', () => {
    assert.equal(classifyMessage({ type: 'IMAGE', text: 'caption' }), 'unsupported');
    assert.equal(classifyMessage({ type: 'VIDEO', text: 'caption' }), 'unsupported');
  });
  it('empty/blank/missing text -> unsupported', () => {
    assert.equal(classifyMessage({ type: 'TEXT', text: '' }), 'unsupported');
    assert.equal(classifyMessage({ type: 'TEXT', text: '  ' }), 'unsupported');
    assert.equal(classifyMessage({ type: 'TEXT' }), 'unsupported');
  });
  it('unknown type -> unsupported', () => {
    assert.equal(classifyMessage({ type: 'STICKER' }), 'unsupported');
    assert.equal(classifyMessage({}), 'unsupported');
  });
});
