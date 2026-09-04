import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function loadHelper(filePath) {
  const code = readFileSync(filePath, 'utf8').replace('.pragma library', '');
  const context = {};
  vm.createContext(context);
  vm.runInContext(code, context);
  return context;
}

const chatRowHelper = loadHelper('./components/ChatRowHelper.js');
const errorStateHelper = loadHelper('./components/ErrorStateHelper.js');

describe('ChatRowHelper', () => {
  it('formatSnippet handles null or missing chat/preview', () => {
    assert.equal(chatRowHelper.formatSnippet(null), '');
    assert.equal(chatRowHelper.formatSnippet({}), '');
    assert.equal(chatRowHelper.formatSnippet({ preview: null }), '');
  });

  it('formatSnippet handles unsupported message kind', () => {
    assert.equal(
      chatRowHelper.formatSnippet({ preview: { kind: 'unsupported' } }),
      'Unsupported message'
    );
  });

  it('formatSnippet prefixes sender in group chats', () => {
    const chat = {
      type: 'group',
      preview: { kind: 'text', senderName: 'Alice', text: 'Hello team' }
    };
    assert.equal(chatRowHelper.formatSnippet(chat), 'Alice: Hello team');
  });

  it('formatSnippet returns text body in single chats', () => {
    const chat = {
      type: 'single',
      preview: { kind: 'text', senderName: 'Bob', text: 'Hey there' }
    };
    assert.equal(chatRowHelper.formatSnippet(chat), 'Hey there');
  });

  it('getInitials extracts first uppercase letter', () => {
    assert.equal(chatRowHelper.getInitials(null), '?');
    assert.equal(chatRowHelper.getInitials(''), '?');
    assert.equal(chatRowHelper.getInitials('  '), '?');
    assert.equal(chatRowHelper.getInitials('denial'), 'D');
    assert.equal(chatRowHelper.getInitials('Team Relay'), 'T');
  });

  it('formatTimestamp handles dates and empty values', () => {
    assert.equal(chatRowHelper.formatTimestamp(null), '');
    assert.equal(chatRowHelper.formatTimestamp('invalid-date'), '');
    const now = new Date().toISOString();
    assert.match(chatRowHelper.formatTimestamp(now), /^\d{1,2}:\d{2}/);
  });
});

describe('ErrorStateHelper', () => {
  it('humanErrorMessage maps known error codes', () => {
    assert.equal(
      errorStateHelper.humanErrorMessage('beeper-unavailable'),
      'Beeper Desktop is unreachable. Make sure Beeper is running.'
    );
    assert.equal(
      errorStateHelper.humanErrorMessage('unauthorized'),
      'Connection unauthorized. Please check your Beeper credentials.'
    );
    assert.equal(
      errorStateHelper.humanErrorMessage('rate-limited'),
      'Too many requests. Please wait a moment before retrying.'
    );
    assert.equal(
      errorStateHelper.humanErrorMessage('server-error'),
      'Beeper local server encountered an error.'
    );
    assert.equal(
      errorStateHelper.humanErrorMessage('invalid-response'),
      'Received an invalid response from Beeper.'
    );
  });

  it('humanErrorMessage handles null or unknown errors', () => {
    assert.equal(
      errorStateHelper.humanErrorMessage(null),
      'An unexpected error occurred.'
    );
    assert.equal(
      errorStateHelper.humanErrorMessage('unknown'),
      'An unexpected error occurred.'
    );
    assert.equal(
      errorStateHelper.humanErrorMessage('custom-error'),
      'Error: custom-error'
    );
  });
});
