import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash, webcrypto} from 'node:crypto';
import vm from 'node:vm';

const source = await readFile(new URL('../../scripts/web-service-worker.js', import.meta.url), 'utf8');
const digest = value => createHash('sha256').update(value).digest('hex');
function worker({corrupt = false} = {}) {
  const events = {};
  const entries = new Map();
  const assets = {'index.html': digest('index'), 'main.dart.js': digest('script')};
  const context = {
    URL, Uint8Array, crypto: webcrypto,
    caches: {open: async () => ({put: async (url, response) => entries.set(url, await response.text()), match: async url => entries.get(url)}), keys: async () => []},
    fetch: async url => new Response(corrupt ? 'tampered' : url.endsWith('index.html') ? 'index' : 'script'),
    self: {registration: {scope: 'https://daylex.test/app/'}, addEventListener: (name, handler) => events[name] = handler, clients: {claim: async () => {}}, skipWaiting: () => {}},
  };
  vm.runInNewContext(source.replace('__VERSION__', 'test').replace('__ASSETS__', JSON.stringify(assets)), context);
  return {events, entries};
}
test('worker caches the complete verified build', async () => {
  const {events, entries} = worker();
  let installation;
  events.install({waitUntil: promise => installation = promise});
  await installation;
  assert.equal(entries.size, 2);
});
test('worker refuses an update whose content changed during download', async () => {
  const {events} = worker({corrupt: true});
  let installation;
  events.install({waitUntil: promise => installation = promise});
  await assert.rejects(installation, /changed during download/);
});
test('worker never intercepts API responses, POSTs or out-of-inventory URLs', () => {
  const {events} = worker();
  for (const [method, url] of [
    ['GET', 'https://daylex.test/v1/client/status'],
    ['POST', 'https://daylex.test/v1/agent/runs'],
    ['POST', 'https://daylex.test/app/index.html'],
    ['GET', 'https://daylex.test/app/private.json'],
  ]) events.fetch({request: {method, url}, respondWith: () => assert.fail('Sensitive or unknown response was intercepted')});
});
