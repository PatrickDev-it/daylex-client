const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const controls = document.querySelector('.example-controls');
const sheet = document.querySelector('.folio-sheet');
const text = document.getElementById('example-text');
const note = document.getElementById('example-note');
const status = document.getElementById('example-status');
const stages = {
  draft: {text: 'Ci occupiamo dell’analisi dei documenti e vi inviamo una relazione con quanto emerso.', note: 'Il punto di partenza: una bozza scritta con le tue parole.', label: 'La bozza iniziale'},
  review: {text: 'L’incarico comprende l’analisi della documentazione e la redazione di una relazione conclusiva.', note: 'Una formulazione più precisa, da rivedere con il tuo criterio.', label: 'La proposta dell’intelligenza artificiale'},
  final: {text: 'L’incarico comprende l’analisi della documentazione fornita dal cliente e la redazione di una relazione conclusiva.', note: 'Aggiungi il dettaglio che conta. La decisione finale è tua.', label: 'La tua revisione finale'}
};
if (controls && sheet && text && note && status) {
  controls.hidden = false;
  controls.addEventListener('click', event => {
    const button = event.target.closest('button[data-stage]');
    if (!button || button.getAttribute('aria-pressed') === 'true') return;
    const stage = stages[button.dataset.stage];
    if (!stage) return;
    controls.querySelectorAll('button').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    text.replaceChildren();
    const phrase = 'l’analisi della documentazione';
    const at = button.dataset.stage === 'review' ? stage.text.indexOf(phrase) : -1;
    if (at >= 0) {
      text.append(stage.text.slice(0, at));
      const highlighted = document.createElement('mark');
      highlighted.textContent = phrase;
      text.append(highlighted, stage.text.slice(at + phrase.length));
    } else {
      text.textContent = stage.text;
    }
    note.textContent = stage.note;
    status.textContent = stage.label + '. ' + stage.text;
    if (!reducedMotion.matches) {
      sheet.classList.remove('changing');
      requestAnimationFrame(() => sheet.classList.add('changing'));
    }
  });
  sheet.addEventListener('animationend', () => sheet.classList.remove('changing'));
}

// Read the live, release-managed anchors: never duplicate installer filenames here.
function downloadChoice(hints = {}) {
  const ua = navigator.userAgent || '';
  const platform = hints.platform || navigator.userAgentData?.platform || navigator.platform || '';
  const appleTouch = /Mac/i.test(platform) && navigator.maxTouchPoints > 1;
  if (/iPad/i.test(ua) || appleTouch) return {id: 'ios', label: 'Installa su iPad'};
  if (/iPhone|iPod/i.test(ua)) return {id: 'ios', label: 'Installa su iPhone'};
  if (/Android/i.test(ua + platform)) return {id: 'pwa', label: 'Installa su Android'};
  if (/CrOS/i.test(ua)) return {id: 'pwa', label: 'Installa l’app web'};
  if (/Windows|Win32|Win64/i.test(ua + platform)) {
    const version = parseInt(hints.platformVersion, 10);
    const unsupportedCPU = hints.architecture === 'arm' || hints.bitness === '32' && !hints.wow64;
    const oldWindows = /Windows NT [0-6]\./.test(ua) || version === 0;
    if (unsupportedCPU || oldWindows) return {id: 'pwa', label: 'Installa l’app web'};
    if (version >= 13) return {id: 'windows', label: 'Scarica per Windows 11'};
    if (version >= 1 && version <= 10) return {id: 'windows10', label: 'Scarica per Windows 10'};
    return {id: 'windows', label: 'Scarica per Windows'};
  }
  if (/Mac/i.test(platform + ua)) return {id: 'macos', label: 'Scarica per macOS'};
  if (/Linux/i.test(platform + ua)) {
    if (hints.architecture === 'arm' || hints.bitness === '32' || /aarch64|armv|i[3-6]86/i.test(ua + platform)) {
      return {id: 'pwa', label: 'Installa l’app web'};
    }
    if (hints.architecture === 'x86' && hints.bitness === '64' || /x86_64|amd64/i.test(ua + platform)) {
      return {id: 'linux', label: 'Scarica per Linux'};
    }
  }
  return null;
}

function showDownloadChoice(choice) {
  if (!choice) return;
  const target = document.getElementById(choice.id);
  if (!target) return;
  document.querySelectorAll('[data-smart-download]').forEach(action => {
    // Do not change a target once the person is interacting with that action.
    if (action.matches(':hover, :focus')) return;
    action.href = target.href;
    action.toggleAttribute('download', target.hasAttribute('download'));
    action.querySelector('.cta-label').textContent = choice.label;
    const icon = action.querySelector('.cta-os');
    icon.src = target.querySelector('img').src;
    icon.hidden = false;
  });
}

async function personalizeDownloads() {
  let hints = {};
  if (navigator.userAgentData?.getHighEntropyValues) {
    let timer;
    try {
      hints = await Promise.race([
        navigator.userAgentData.getHighEntropyValues(['platformVersion', 'architecture', 'bitness', 'wow64']),
        new Promise(resolve => { timer = setTimeout(() => resolve({}), 650); })
      ]);
    } catch { /* Restricted browsers retain the safe platform-level fallback. */ }
    finally { clearTimeout(timer); }
  }
  showDownloadChoice(downloadChoice(hints));
}
personalizeDownloads();

// One bounded entrance for the device choices; links stay visible if JS fails.
const downloadList = document.querySelector('.download-list');
if (downloadList && !reducedMotion.matches && 'IntersectionObserver' in window) {
  const animations = [];
  const observer = new IntersectionObserver(entries => {
    if (!entries.some(entry => entry.isIntersecting)) return;
    observer.disconnect();
    if (reducedMotion.matches) return;
    downloadList.querySelectorAll('.download-link').forEach((link, index) => {
      if (link.matches(':focus, :hover')) return;
      const animation = link.animate([
        {opacity: 0, translate: '0 12px'},
        {opacity: 1, translate: '0 0'}
      ], {duration: 640, delay: index * 110, easing: 'cubic-bezier(.16,1,.3,1)', fill: 'backwards'});
      animations.push(animation);
      const reveal = () => animation.cancel();
      link.addEventListener('focus', reveal, {once: true});
      link.addEventListener('pointerenter', reveal, {once: true});
    });
  }, {threshold: 0.15});
  observer.observe(downloadList);
  reducedMotion.addEventListener('change', event => {
    if (event.matches) {
      observer.disconnect();
      animations.forEach(animation => animation.cancel());
    }
  });
}
