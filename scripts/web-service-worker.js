const CACHE = 'daylex-web-__VERSION__';
const ASSETS = __ASSETS__;
const urls = new Map(Object.entries(ASSETS).map(([path, hash]) => [new URL(path, self.registration.scope).href, hash]));
const index = new URL('index.html', self.registration.scope).href;
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    for (const [url, hash] of urls) {
      const response = await fetch(url, {cache: 'reload'});
      if (!response.ok) throw new Error('Incomplete update');
      const digest = await crypto.subtle.digest('SHA-256', await response.clone().arrayBuffer());
      const actual = [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, '0')).join('');
      if (actual !== hash) throw new Error('Update changed during download');
      await cache.put(url, response);
    }
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith('daylex-web-') && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('message', event => {
  if (event.data?.type === 'ACTIVATE') self.skipWaiting();
});
self.addEventListener('fetch', event => {
  // Only the exact public build inventory is cached. API/auth/document data never enter CacheStorage.
  if (event.request.method !== 'GET') return;
  const requested = new URL(event.request.url);
  const url = requested.href === self.registration.scope ? index : requested.href;
  if (!urls.has(url)) return;
  event.respondWith(caches.open(CACHE).then(async cache => (await cache.match(url)) || fetch(event.request)));
});
