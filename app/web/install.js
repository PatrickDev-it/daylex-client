const installButton = document.getElementById('install-button');
const statusMessage = document.getElementById('install-status');
const manualGuides = document.getElementById('manual-guides');
const guideChoices = document.querySelector('.guide-choices');
const choices = [...document.querySelectorAll('[data-guide]')];
let pendingPrompt = null;
let requesting = false;
let installed = matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

function markInstalled() {
  installed = true;
  pendingPrompt = null;
  installButton.hidden = true;
  guideChoices.hidden = true;
  manualGuides.hidden = true;
  statusMessage.textContent = 'Daylex è installato. Puoi aprirlo dalla sua icona.';
  document.querySelector('.open-app').textContent = 'Apri Daylex';
}

addEventListener('beforeinstallprompt', event => {
  event.preventDefault();
  if (installed) return;
  pendingPrompt = event;
  installButton.hidden = false;
  installButton.disabled = false;
  statusMessage.textContent = 'Il tuo browser è pronto. Premi Installa Daylex e conferma.';
});
addEventListener('appinstalled', markInstalled);

installButton.addEventListener('click', async () => {
  if (!pendingPrompt || requesting || installed) return;
  const prompt = pendingPrompt;
  pendingPrompt = null;
  requesting = true;
  installButton.disabled = true;
  try {
    await prompt.prompt();
    const result = await prompt.userChoice;
    if (!installed) statusMessage.textContent = result.outcome === 'accepted'
      ? 'Installazione richiesta. Il browser sta completando l’operazione.'
      : 'Installazione annullata. Puoi seguire la guida oppure aprire Daylex nel browser.';
  } catch {
    if (!installed) statusMessage.textContent = 'Non è stato possibile avviare l’installazione. Segui la guida oppure apri Daylex nel browser.';
  } finally {
    requesting = false;
    installButton.hidden = !pendingPrompt || installed;
    installButton.disabled = false;
  }
});

function selectGuide(id, focus = false) {
  if (!choices.some(button => button.dataset.guide === id)) return;
  for (const button of choices) {
    const selected = button.dataset.guide === id;
    button.setAttribute('aria-selected', String(selected));
    button.tabIndex = selected ? 0 : -1;
    document.getElementById(`guide-${button.dataset.guide}`).hidden = !selected;
    if (selected && focus) button.focus();
  }
}
guideChoices.setAttribute('role', 'tablist');
for (const [index, button] of choices.entries()) {
  const id = button.dataset.guide;
  button.id = `choose-${id}`;
  button.setAttribute('role', 'tab');
  button.setAttribute('aria-controls', `guide-${id}`);
  const panel = document.getElementById(`guide-${id}`);
  panel.setAttribute('role', 'tabpanel');
  panel.setAttribute('aria-labelledby', button.id);
  button.addEventListener('click', () => selectGuide(id));
  button.addEventListener('keydown', event => {
    const next = event.key === 'ArrowRight' ? (index + 1) % choices.length
      : event.key === 'ArrowLeft' ? (index + choices.length - 1) % choices.length
      : event.key === 'Home' ? 0 : event.key === 'End' ? choices.length - 1 : undefined;
    if (next !== undefined) { event.preventDefault(); selectGuide(choices[next].dataset.guide, true); }
  });
}
const appleMobile = /iPhone|iPad|iPod/.test(navigator.userAgent) || (/Mac/.test(navigator.platform) && navigator.maxTouchPoints > 1);
const detected = appleMobile ? 'ios' : /Android/i.test(navigator.userAgent) ? 'android' : /Mac/.test(navigator.platform) ? 'mac' : 'desktop';
const fromHash = () => selectGuide(choices.some(button => button.dataset.guide === location.hash.slice(1)) ? location.hash.slice(1) : detected);
fromHash();
addEventListener('hashchange', fromHash);
guideChoices.hidden = false;
if (installed) markInstalled();
// Use the existing app identity, scope and verified asset cache. No parallel PWA is created.
if ('serviceWorker' in navigator) navigator.serviceWorker.register('./service-worker.js', {updateViaCache:'none'}).catch(() => {
  if (!installed && !pendingPrompt) statusMessage.textContent = 'L’installazione non è pronta. Puoi seguire la guida o aprire Daylex nel browser e riprovare.';
});
