// Persistent document storage, isolated from the in-memory access credential.
// A Web Lock prevents two tabs from overwriting the same workspace.
export async function createStorage(indexedDB, notify = () => {}) {
  const db = await new Promise((resolve, reject) => {
    const request = indexedDB.open('daylex-workspace', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('records', {keyPath: 'key'});
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  const records = await new Promise((resolve, reject) => {
    const request = db.transaction('records').objectStore('records').getAll();
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  const cache = new Map(records.map(record => [record.key, record]));
  const dirty = new Map();
  let running = null;
  let failure = null;
  const changed = () => { notify(); api.onChange?.(); };
  async function commit() {
    if (running) return running;
    if (!dirty.size) return;
    running = (async () => {
      while (dirty.size) {
        const batch = new Map(dirty);
        try {
          await new Promise((resolve, reject) => {
            const transaction = db.transaction('records', 'readwrite');
            const store = transaction.objectStore('records');
            for (const [key, record] of batch) {
              if (record === null) store.delete(key); else store.put(record);
            }
            transaction.oncomplete = resolve;
            transaction.onerror = transaction.onabort = () => reject(transaction.error || new Error('Salvataggio interrotto'));
          });
          for (const [key, record] of batch) {
            if (dirty.get(key) === record) dirty.delete(key);
          }
          failure = null;
        } catch (error) {
          failure = 'Archivio del browser non disponibile o spazio esaurito. Mantieni aperta questa pagina e scarica una copia dei dati.';
          throw error;
        }
      }
    })();
    try { await running; } finally { running = null; changed(); }
  }
  function schedule() {
    changed();
    queueMicrotask(() => { void commit().catch(() => {}); });
  }
  const api = {
    read: key => cache.get(key)?.value ?? null,
    keys: () => JSON.stringify([...cache.keys()]),
    modified: key => cache.get(key)?.modified ?? null,
    get pending() { return dirty.size > 0 || running !== null; },
    get error() { return failure; },
    onChange: null,
    onSave: null,
    write(key, value, backup = false) {
      if (backup && cache.has(key)) {
        const previous = {...cache.get(key), key: key + '.bak'};
        cache.set(previous.key, previous);
        dirty.set(previous.key, previous);
      }
      const record = {key, value, modified: Date.now()};
      cache.set(key, record);
      dirty.set(key, record);
      schedule();
    },
    remove(key) { cache.delete(key); dirty.set(key, null); schedule(); },
    async flush() { do { await commit(); } while (dirty.size); },
    snapshot() { return {schema: 1, records: [...cache.values()].filter(record => record.key.startsWith('data/'))}; },
    async restore(snapshot) {
      if (snapshot?.schema !== 1 || !Array.isArray(snapshot.records) || snapshot.records.length > 100000) throw new Error('Backup non valido');
      const incoming = new Map();
      for (const record of snapshot.records) {
        if (typeof record.key !== 'string' || !/^data\/(workspace\.json(\.bak)?|preferences\.json|(documents|chats|snapshots)\/[A-Za-z0-9_.@-]+\.json)(\.corrupt-[0-9]+)?$/.test(record.key) ||
            typeof record.value !== 'string' || record.value.length > 50_000_000 || incoming.has(record.key)) throw new Error('Contenuto del backup non valido');
        if (!/\.corrupt-[0-9]+$/.test(record.key)) {
          const value = JSON.parse(record.value);
          if (!value || typeof value !== 'object' || Array.isArray(value) || (value.version ?? 1) > 1) throw new Error('Versione del backup non supportata');
        }
        incoming.set(record.key, {...record, modified: Date.now()});
      }
      if (!incoming.has('data/workspace.json')) throw new Error('Il backup non contiene un archivio Daylex');
      await api.flush();
      // Preserve a recovery snapshot before replacing data, in the same transaction.
      const previous = api.snapshot();
      const recovery = {key: 'recovery-before-import', value: JSON.stringify(previous), modified: Date.now()};
      await new Promise((resolve, reject) => {
        const tx = db.transaction('records', 'readwrite');
        const store = tx.objectStore('records');
        store.put(recovery);
        for (const key of cache.keys()) if (key.startsWith('data/')) store.delete(key);
        for (const record of incoming.values()) store.put(record);
        tx.oncomplete = resolve;
        tx.onerror = tx.onabort = () => reject(tx.error || new Error('Importazione interrotta'));
      });
      for (const key of cache.keys()) if (key.startsWith('data/')) cache.delete(key);
      cache.set(recovery.key, recovery);
      for (const [key, record] of incoming) cache.set(key, record);
    },
    close() { db.close(); },
  };
  return api;
}
