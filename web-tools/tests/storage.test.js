import test from 'node:test';
import assert from 'node:assert/strict';
import {IDBFactory} from 'fake-indexeddb';
import {createStorage} from '../../app/web/storage.mjs';

test('committed documents survive reopen and workspace backup is atomic', async () => {
  const idb = new IDBFactory();
  const store = await createStorage(idb);
  store.write('data/workspace.json', '{"version":1,"title":"old"}');
  await store.flush();
  store.write('data/workspace.json', '{"version":1,"title":"new"}', true);
  store.write('data/documents/a.json', '{"version":1,"text":"saved"}');
  await store.flush();
  assert.equal(store.pending, false);
  store.close();
  const reopened = await createStorage(idb);
  assert.equal(JSON.parse(reopened.read('data/workspace.json')).title, 'new');
  assert.equal(JSON.parse(reopened.read('data/workspace.json.bak')).title, 'old');
  assert.equal(JSON.parse(reopened.read('data/documents/a.json')).text, 'saved');
  reopened.close();
});

test('writes made while a transaction commits are not lost', async () => {
  const idb = new IDBFactory();
  const store = await createStorage(idb);
  store.write('data/workspace.json', '{"version":1,"revision":1}');
  const saving = store.flush();
  store.write('data/workspace.json', '{"version":1,"revision":2}', true);
  await saving;
  await store.flush();
  store.close();
  const reopened = await createStorage(idb);
  assert.equal(JSON.parse(reopened.read('data/workspace.json')).revision, 2);
  reopened.close();
});

test('invalid or newer backup leaves current data untouched', async () => {
  const store = await createStorage(new IDBFactory());
  store.write('data/workspace.json', '{"version":1,"title":"keep"}');
  await store.flush();
  for (const record of [
    {key: '../escape', value: '{}'},
    {key: 'device', value: 'credential'},
    {key: 'data/workspace.json', value: '{"version":2}'},
    {key: 'data/workspace.json', value: 'broken'},
  ]) await assert.rejects(store.restore({schema: 1, records: [record]}));
  assert.equal(JSON.parse(store.read('data/workspace.json')).title, 'keep');
  store.close();
});

test('restore replaces records without importing identity and preserves a recovery copy', async () => {
  const store = await createStorage(new IDBFactory());
  store.write('device', 'local-device');
  store.write('data/workspace.json', '{"version":1,"title":"old"}');
  store.write('data/documents/obsolete.json', '{}');
  await store.restore({schema: 1, records: [{key: 'data/workspace.json', value: '{"version":1,"title":"restored"}'}]});
  assert.equal(JSON.parse(store.read('data/workspace.json')).title, 'restored');
  assert.equal(store.read('data/documents/obsolete.json'), null);
  assert.equal(store.read('device'), 'local-device');
  assert.match(store.read('recovery-before-import'), /old/);
  assert.ok(store.snapshot().records.every(record => record.key.startsWith('data/')));
  store.close();
});

test('a failed transaction remains unsaved and can be recovered without losing edits', async () => {
  const idb = new IDBFactory();
  const store = await createStorage(idb);
  store.close();
  store.write('data/workspace.json', '{"version":1,"title":"unsaved"}');
  await assert.rejects(store.flush());
  assert.equal(store.pending, true);
  assert.ok(store.error);
  assert.match(store.snapshot().records[0].value, /unsaved/);
});

test('a backup retains quarantined damaged files without making them active', async () => {
  const source = await createStorage(new IDBFactory());
  source.write('data/workspace.json', '{"version":1}');
  source.write('data/documents/a.json.corrupt-123', 'broken JSON');
  const target = await createStorage(new IDBFactory());
  await target.restore(source.snapshot());
  assert.equal(target.read('data/documents/a.json'), null);
  assert.equal(target.read('data/documents/a.json.corrupt-123'), 'broken JSON');
  await source.flush();
  source.close();
  target.close();
});
