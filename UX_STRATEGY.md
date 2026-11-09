# Daylex homepage — experience refoundation

Scope: the public download homepage and its handoff to installation. The native app and PWA workflows are outside this change. Preserve the owner's six visible OS routes, automatic platform recommendation, restrained identity, rounded controls and borderless hover treatment.

## UX DNA — defined before implementation

- Recommend one next action; keep alternatives recognizable and available.
- Explain prerequisites before commitment, and installation details after the download request.
- Use outcomes and familiar words, not implementation vocabulary.
- Acknowledge actions immediately, without claiming outcomes the browser cannot observe.
- Keep the person in control: direct downloads, manual OS choices, retry, and optional help.
- Teach through a short, optional sequence rather than competing demonstration controls.
- Preserve native links, keyboard navigation, reduced motion and no-JavaScript access.
- Use AI only in the product example; do not introduce AI into deterministic download selection.

## Cognitive-load audit

| Moment | Current friction | Decision |
| --- | --- | --- |
| First arrival | A download is offered before the visitor knows access requires a studio code. | State the requirement next to the primary action; link directly to existing access help. |
| Device decision | Detected CTA and six options lack a clear recommendation/alternative relationship. | Explain the recommendation; keep the six routes as an explicit manual alternative. Do not preselect or hide another OS. |
| Native download click | The homepage does not acknowledge the request or explain the next action. | Show contextual installation steps in the same page, with the selected OS, a direct retry and specific help. |
| Download failure/blocked request | The browser owns progress and errors; the page cannot certify completion. | Say a request was sent; direct the person to browser downloads, allow retry, never display invented percentages or success. |
| Missing code | The visitor must find and scan support after downloading. | Provide a direct access-help route before and after the download. Do not collect credentials on the home. |
| Web/mobile route | Labels suggest a native package or immediate installation while the destination is a guide. | Label the guide destination explicitly; keep direct browser access in navigation. |
| Optional AI example | Three concurrent stage buttons require the reader to infer order and starting point. | Start with the draft and offer one explicitly named next action; final state offers replay. |

## Intended journeys

1. Supported desktop: see the recommended platform and access prerequisite → click download once → read the relevant installation steps while the browser handles the file → enter the studio code in the app.
2. Different device: choose its visible OS route → the same contextual next steps. Automatic detection never reverses this deliberate choice.
3. Unknown platform: choose manually; never guess a package. Existing architecture restrictions continue to route to the web guide.
4. Phone/tablet: open the clearly named installation guide; no claim that a native iOS package is available or that the site can install without consent.
5. Download not visible: inspect the browser's downloads → retry the same current release or open OS-specific help. Never launch an automatic second download.
6. Missing studio code: go directly to access instructions; no signup, pricing or contact channel is invented.

## Observable status boundaries

The page observes the user's request and the chosen route. It cannot observe native download completion, OS installation, app launch or successful activation. The inline handoff must never imply those milestones occurred. It must not fetch an entire installer into memory, block native downloads behind a modal, add a confirmation, or store activation codes.

## Validation and limits

Structural comparisons: one download click remains one; the example's simultaneous stage actions decrease from three to one; native next-step guidance becomes available without navigating to and searching a separate help page. All six alternate device routes remain visible.

Verify recommendation, manual override, each native handoff, repeat request, keyboard focus, modified clicks, JavaScript-disabled links, reduced motion, narrow screens and existing release substitution. Use intercepted dummy files in browser tests, never run installers.

These are observable interface changes, not proof of improved conversion or reduced task time. A short first-use study should measure correct package selection, access-prerequisite comprehension, understanding after a download click, task completion and time to the first document. No user study or measured AI-efficiency claim is available in this session.

## Post-implementation audit
Five viewports (1440, 1366, 768, 390, 320px) keep all six device routes above 739px, with no horizontal overflow. Browser checks verified native download events and completed harmless fixture transfers from a real local HTTP endpoint; retry and manual OS switching preserve their selected targets. OS-specific help, focus transfer, one-action demo progression/replay, modified-click preservation and no-JavaScript fallbacks passed. Intercepted production fixtures verify routing/UI only; they cannot prove native installer completion.

Tradeoff: the optional example now requires two deliberate advances to see the human final version, rather than direct selection among three stages; the sequence makes order explicit without delaying the primary download. A fresh first-use study is still required to validate comprehension and conversion.

Device order confirmed by the owner: Windows 11, Windows 10, macOS, iPhone/iPad, Linux, App web. Keep the two Apple routes adjacent and PWA last.
