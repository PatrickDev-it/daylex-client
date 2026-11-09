import {createStorage} from './storage.mjs';
import * as pdfjsLib from './vendor/pdfjs/pdf.min.mjs';
import {viewerPdfApi} from './pdf-compat.mjs';

window.pdfjsLib = viewerPdfApi(pdfjsLib);
pdfjsLib.GlobalWorkerOptions.workerSrc = new URL('./vendor/pdfjs/pdf.worker.min.mjs', import.meta.url).href;
const status = document.getElementById('startup-status');
const controls = document.getElementById('web-controls');
const message = document.getElementById('web-message');
let releaseLock;
let reloading = false;
let registration;

function download(bytes, name, type) {
  const url = URL.createObjectURL(new Blob([bytes], {type}));
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
}
async function backup() {
  window.daylex.onSave?.();
  // Include in-memory edits even if quota prevents committing them.
  const bytes = new TextEncoder().encode(JSON.stringify(window.daylex.snapshot()));
  download(bytes, `Daylex-archivio-${new Date().toISOString().slice(0, 10)}.json`, 'application/json');
}
document.getElementById('backup').addEventListener('click', backup);
document.getElementById('restore').addEventListener('change', async event => {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;
  try {
    if (file.size > 100_000_000) throw new Error('Il backup supera 100 MB');
    const data = JSON.parse(await file.text());
    if (!confirm('Sostituire l’archivio di questo browser con il backup? Verrà prima scaricata una copia dell’archivio attuale.')) return;
    await backup();
    await window.daylex.restore(data);
    window.daylex.onSave = null; // Do not overwrite restored data with the old Flutter state.
    reloading = true;
    location.reload();
  } catch (error) { message.textContent = error.message || 'Importazione non riuscita'; }
});
document.getElementById('refresh').addEventListener('click', async () => {
  try {
    if (window.daylex.onSave?.() === false) throw new Error('Archivio in sola lettura');
    await window.daylex.flush();
    reloading = true;
    if (registration?.waiting) registration.waiting.postMessage({type: 'ACTIVATE'});
    else location.reload();
  } catch (_) { message.textContent = 'Salvataggio non riuscito: scarica una copia dell’archivio prima di aggiornare.'; }
});
window.addEventListener('beforeunload', event => {
  if (reloading) return;
  let saved = true;
  try { saved = window.daylex?.onSave?.() !== false; } catch (_) { saved = false; }
  if (!saved || window.daylex?.pending) { event.preventDefault(); event.returnValue = ''; }
});
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') window.daylex?.onSave?.();
});
window.addEventListener('pagehide', () => { releaseLock?.(); });
window.addEventListener('pageshow', event => { if (event.persisted) location.reload(); });

async function start() {
  if (!navigator.locks || !window.indexedDB) throw new Error('Questo browser non supporta l’archivio Daylex. Aggiorna Safari, Chrome, Edge o Firefox.');
  await new Promise((resolve, reject) => {
    navigator.locks.request('daylex-workspace', {ifAvailable: true}, async lock => {
      if (!lock) { reject(new Error('Daylex è già aperto in un’altra scheda o finestra. Chiudila, poi ricarica questa pagina.')); return; }
      resolve();
      await new Promise(done => { releaseLock = done; });
    }).catch(reject);
  });
  window.daylex = await createStorage(indexedDB, () => {
    if (window.daylex?.error) message.textContent = window.daylex.error;
    syncTheme();
  });
  function syncTheme() {
    try {
      const theme = JSON.parse(window.daylex?.read('data/preferences.json') || '{}').themeMode || 'dark';
      document.documentElement.dataset.theme = theme === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : theme;
    } catch (_) { /* The app reports any damaged preferences. */ }
  }
  syncTheme();
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', syncTheme);
  window.daylex.download = download;
  controls.hidden = false;
  navigator.storage?.persist?.().catch(() => {});
  if ('serviceWorker' in navigator) {
    registration = await navigator.serviceWorker.register('./service-worker.js', {updateViaCache: 'none'});
    const notifyUpdate = () => {
      if (registration.waiting && navigator.serviceWorker.controller) {
        message.textContent = 'Nuova versione disponibile. Salva e ricarica quando hai terminato il lavoro.';
        document.getElementById('refresh').hidden = false;
      }
    };
    notifyUpdate();
    registration.addEventListener('updatefound', () => registration.installing?.addEventListener('statechange', notifyUpdate));
    navigator.serviceWorker.addEventListener('controllerchange', () => { if (reloading) location.reload(); });
    setInterval(() => registration.update().catch(() => {}), 30 * 60 * 1000);
  }
  const script = document.createElement('script');
  script.src = 'flutter_bootstrap.js';
  script.onerror = () => { status.textContent = 'Impossibile caricare Daylex. Controlla la connessione e ricarica.'; };
  document.body.append(script);
}
start().catch(error => { status.textContent = error.message || 'Archivio non disponibile. Ricarica per riprovare.'; });
