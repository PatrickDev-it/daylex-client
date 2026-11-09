const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
if (!reducedMotion.matches && 'IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('arriving');
      observer.unobserve(entry.target);
    }
  }, {threshold: .12});
  document.querySelectorAll('[data-reveal]').forEach(element => observer.observe(element));
}
