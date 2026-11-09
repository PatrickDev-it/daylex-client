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
