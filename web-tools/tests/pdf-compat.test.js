import test from 'node:test';
import assert from 'node:assert/strict';
import {viewerPdfApi} from '../../app/web/pdf-compat.mjs';

test('closing a viewer document releases the PDF.js 6 loading task', async () => {
  let destroyed = false;
  const document = {numPages: 5};
  const task = {get promise() { return Promise.resolve(document); }, async destroy() { destroyed = true; }};
  const viewer = viewerPdfApi({getDocument: () => task});
  const loading = viewer.getDocument({data: new Uint8Array()});
  assert.equal(loading, task);
  const loaded = await loading.promise;
  assert.equal(loaded.numPages, 5);
  await loaded.destroy();
  assert.equal(destroyed, true);
});

test('an existing document disposal method is retained', async () => {
  let closed = false;
  const destroy = () => { closed = true; };
  const api = viewerPdfApi({getDocument: () => ({promise: Promise.resolve({destroy})})});
  const document = await api.getDocument().promise;
  assert.equal(document.destroy, destroy);
  document.destroy();
  assert.equal(closed, true);
});
