# Public website

Scope: `site/`. The application's existing interface is not rebranded by this work.

The user's black/charcoal, cyan and green reference is the visual authority. Primary conversion: desktop download. Build directly in the existing static HTML/CSS/JS stack, using the supplied reference and real product evidence; no invented screenshots, sales metrics or testimonials.

## Direction

A premium download gateway: a large white/cyan statement on near-black, immediately paired with six platform choices. Green emphasizes the two Windows installers; charcoal and subdued cyan distinguish desktop and web entry points. OS marks sit to the left of each label. On mobile the same six choices fit the opening viewport, before product detail. All download choices are visible without JavaScript; no carousel, hidden tabs or FAQ.

The real workspace capture follows the download gateway. Supporting content stays concise. The PWA installation route at `/app/installa.html` shares the app's manifest identity and existing service-worker scope, with a native install prompt when offered by the browser and device-specific fallback instructions.

## Tokens

- Ground: #0b0d0e; supporting surface: #181c1e; raised surface: #252b2e.
- Ink: #f5f7f7; supporting ink: #b9c3c7.
- Action: #adf3cb with #10271a text. Cyan field: #c4edf2 with #11282d text.
- Inter, served locally. Display 62–84px on desktop, 44px on phones; two-line headline. Body 17–19px. Sentence case, no eyebrow labels.
- 1280px maximum content frame; symmetric 64px desktop / 24px phone gutters. Meaningful section gaps; different compositions for demonstration, workflow, download and help.
- Rounded controls, quiet rectangular product surfaces. No decorative gradients, stock photography, floating glass navigation or icon-card grids.

## Motion

Content arrives once on scroll; the main statement has a short entrance. Download controls are visible immediately and respond to pointer/focus, without delaying the primary action. Reduced motion keeps the page still and fully functional.

## Language

Public copy: `codice di attivazione`, `referente dello studio`, `scarica`, `apri nel browser`. Keep API keys, SHA-256, architectures, build numbers and runtime dependencies in `tecnica.html`. `assistenza.html` contains plain-language setup and OS confirmation guidance. Never imply public signup or automatic synchronization.

## Release integration

`data-site-version="3"` refreshes every `data-download` link, including both Windows entry points, while preserving icons and labels. Desktop releases update home download links and technical metadata together. Public pages remain usable without JavaScript. Never replace the PWA or remove historical installers during a site deployment.


## Verification and scoped choices

Browser checks cover 1440, 768, 390 and 320px, keyboard selection, direct platform links,
native PWA prompt states, reduced motion, and the no-JavaScript fallback. Delivery tests cover future release
rendering and preservation of the previous technical page.
The host OS requests reduced motion in the inspection browser; normal-motion inspection explicitly
emulates no-preference, while keeping the separate reduced-motion pass. One real workspace capture replaces stock imagery and video; the opening visual priority is the download selection. Inter preserves continuity with the product. The full-width cyan section's inner frame has
symmetric gutters; automatic padding and text-ink margin warnings do not indicate clipped content.

The platform grid is a deliberate exception to generic icon-card avoidance: the owner explicitly requests OS icons and immediately visible choices. These are direct download controls, not decorative feature cards. The footer wordmark is branding; the preceding conversion button is not an eyebrow label. Nine one-time content entrances are sufficient; controls remain visible immediately.
