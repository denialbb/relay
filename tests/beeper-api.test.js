// Layer 2 — API contract tests vs stub HTTP server (spec §17.3). RED: BeeperApi throws.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import {
  searchUnreadChats,
  listMessages,
  sendText,
  markRead,
} from '../services/BeeperApi.js';

let server;
let baseUrl;

before(async () => {
  server = createServer((req, res) => {
    res.setHeader('content-type', 'application/json');
    if (req.url.startsWith('/v1/chats/search')) {
      res.end(JSON.stringify({ chats: [{ id: 'c1', type: 'single', unreadCount: 1 }], query: req.url }));
    } else if (req.url.match(/^\/v1\/chats\/[^/]+\/messages$/) && req.method === 'GET') {
      res.end(JSON.stringify({ messages: [{ id: 'm1', type: 'TEXT', text: 'hi' }] }));
    } else if (req.url.match(/^\/v1\/chats\/[^/]+\/messages$/) && req.method === 'POST') {
      res.end(JSON.stringify({ id: 'm2', status: 'sent' }));
    } else if (req.url.endsWith('/read')) {
      res.end(JSON.stringify({ id: 'c1' }));
    } else {
      res.statusCode = 404;
      res.end('{}');
    }
  });
  await new Promise((r) => server.listen(0, r));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

describe('BeeperApi contract', () => {
  it('searchUnreadChats -> valid result', async () => {
    const page = await searchUnreadChats({ baseUrl, unreadOnly: true });
    assert.ok(page.chats.length >= 1);
  });
  it('listMessages -> valid result', async () => {
    const page = await listMessages('c1', { baseUrl });
    assert.ok(page.messages.length >= 1);
  });
  it('sendText -> success', async () => {
    const r = await sendText('c1', 'hello', { baseUrl });
    assert.ok(r.id);
  });
  it('markRead -> success', async () => {
    const c = await markRead('c1', 'm1', { baseUrl });
    assert.equal(c.id, 'c1');
  });
  it('searchUnreadChats defaults to unreadOnly=true&type=any', async () => {
    const page = await searchUnreadChats({ baseUrl });
    assert.match(page.query, /unreadOnly=true/);
    assert.match(page.query, /type=any/);
  });
  it('request timeout -> beeper-unavailable', async () => {
    const hanging = createServer(() => {});
    await new Promise((r) => hanging.listen(0, r));
    const hangingUrl = `http://127.0.0.1:${hanging.address().port}`;
    await assert.rejects(listMessages('c1', { baseUrl: hangingUrl, timeoutMs: 50 }), /beeper-unavailable/);
    hanging.close();
  });
  it('connection refused -> beeper-unavailable', async () => {
    const probe = createServer(() => {});
    await new Promise((r) => probe.listen(0, r));
    const closedUrl = `http://127.0.0.1:${probe.address().port}`;
    await new Promise((r) => probe.close(r));
    await assert.rejects(listMessages('c1', { baseUrl: closedUrl, timeoutMs: 2000 }), /beeper-unavailable/);
  });
});
