document.documentElement.classList.add('js');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const choices = [...document.querySelectorAll('[data-platform]')];
function select(platform, focus = false) {
  if (!choices.some(choice => choice.dataset.platform === platform)) return;
  for (const choice of choices) {
    const selected = choice.dataset.platform === platform;
    choice.setAttribute('aria-selected', String(selected));
    choice.tabIndex = selected ? 0 : -1;
    const panel = document.getElementById(choice.dataset.platform);
    if (panel) panel.hidden = !selected;
    if (selected && focus) choice.focus();
  }
}
if (choices.length) {
  document.querySelector('.platforms').setAttribute('role', 'tablist');
  for (const [index, choice] of choices.entries()) {
    choice.id = `choose-${choice.dataset.platform}`;
    choice.setAttribute('role', 'tab');
    choice.setAttribute('aria-controls', choice.dataset.platform);
    const panel = document.getElementById(choice.dataset.platform);
    panel.setAttribute('role', 'tabpanel');
    panel.setAttribute('aria-labelledby', choice.id);
    choice.addEventListener('click', event => { event.preventDefault(); select(choice.dataset.platform); });
    choice.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % choices.length;
      if (event.key === 'ArrowLeft') next = (index + choices.length - 1) % choices.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = choices.length - 1;
      if (next !== undefined) { event.preventDefault(); select(choices[next].dataset.platform, true); }
    });
  }
  const tablet = /iPad|iPhone|Android/i.test(navigator.userAgent) || (/Mac/.test(navigator.platform) && navigator.maxTouchPoints > 1);
  const preferred = /Mac/.test(navigator.platform) && !tablet ? 'macos' : /Linux/.test(navigator.platform) && !tablet ? 'linux' : 'windows';
  const fromHash = () => { const requested = location.hash.slice(1); if (choices.some(c => c.dataset.platform === requested)) select(requested); };
  select(preferred); fromHash();
  addEventListener('hashchange', fromHash);
}

const stages = [
  {request: '«Prepara una proposta di consulenza chiara, da rivedere con il cliente.»', intro: 'Un percorso condiviso, dall’analisi iniziale alla definizione dei prossimi passi.', goal: 'Mettere a fuoco le esigenze del cliente e concordare priorità, attività e risultati attesi.', method: 'Analisi dei materiali, confronto con il cliente e preparazione della proposta operativa.', status: 'Una prima bozza da rivedere'},
  {request: '«Rendi il metodo più concreto e metti in evidenza i passaggi da concordare.»', intro: 'Una proposta più diretta, con attività e passaggi da definire insieme al cliente.', goal: 'Concordare le priorità e chiarire quale risultato raggiungere con la consulenza.', method: 'Raccogliere i materiali, incontrare il cliente e concordare attività, tempi e compensi.', status: 'Una revisione da controllare'},
  {request: '«Ho rivisto il contenuto. Preparo il PDF da condividere.»', intro: 'Il documento rivisto, pronto per essere esportato e condiviso.', goal: 'Concordare le priorità e chiarire quale risultato raggiungere con la consulenza.', method: 'Raccogliere i materiali, incontrare il cliente e concordare attività, tempi e compensi.', status: 'Il passo successivo: esportare il PDF'},
];
const demoButtons = [...document.querySelectorAll('[data-demo]')];
const replay = document.getElementById('replay');
let timers = [];
function stopReplay() { timers.forEach(clearTimeout); timers = []; if (replay) { replay.querySelector('span').textContent = 'Riproduci'; replay.setAttribute('aria-label', 'Riproduci l’esempio'); } }
function showStage(index) {
  const stage = stages[index];
  for (const key of ['request', 'intro', 'goal', 'method', 'status']) document.getElementById(`demo-${key}`).textContent = stage[key];
  demoButtons.forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset.demo) === index)));
  if (!reducedMotion.matches) document.getElementById('demo-paper').animate([{opacity: .45, transform: 'translateY(6px)'}, {opacity: 1, transform: 'translateY(0)'}], {duration: 360, easing: 'cubic-bezier(.16,1,.3,1)'});
}
demoButtons.forEach(button => button.addEventListener('click', () => { stopReplay(); showStage(Number(button.dataset.demo)); }));
if (replay) {
  replay.hidden = false;
  replay.addEventListener('click', () => {
    if (timers.length) { stopReplay(); return; }
    showStage(0);
    if (reducedMotion.matches) { showStage(2); return; }
    replay.querySelector('span').textContent = 'Pausa'; replay.setAttribute('aria-label', 'Metti in pausa l’esempio');
    timers = [setTimeout(() => showStage(1), 1800), setTimeout(() => showStage(2), 3600), setTimeout(stopReplay, 4800)];
  });
  new IntersectionObserver(entries => { if (!entries[0].isIntersecting) stopReplay(); }).observe(document.querySelector('.hero-example'));
  document.addEventListener('visibilitychange', () => { if (document.hidden) stopReplay(); });
  reducedMotion.addEventListener('change', stopReplay);
}

if (!reducedMotion.matches && 'IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    entries.filter(entry => entry.isIntersecting).forEach(entry => {
      entry.target.classList.add('arriving');
      observer.unobserve(entry.target);
    });
  }, {threshold: .12});
  document.querySelectorAll('[data-reveal]').forEach(element => observer.observe(element));
  document.querySelectorAll('.paper-heading,.paper-intro,.paper-block,.paper-status').forEach(element => {
    element.classList.add('paper-arriving');
  });
}
