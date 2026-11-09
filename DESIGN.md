---
name: Daylex
description: A professional open folio for document work under human control.
colors:
  black: "#000"
  ground: "#0c0c0c"
  sheet: "#171717"
  layer: "#242424"
  ink: "#f3f3f3"
  muted: "#b5b5b5"
  quiet: "#8d8d8d"
  cyan: "#00aeb3"
  mint: "#dff4e2"
  green: "#15803d"
typography:
  display:
    fontFamily: "Archivo, sans-serif"
    fontSize: "clamp(60px, 5.4vw, 80px)"
    fontWeight: 550
    lineHeight: 1.04
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "Archivo, sans-serif"
    fontSize: "44px"
    fontWeight: 550
    lineHeight: 1.08
    letterSpacing: "-0.035em"
  title:
    fontFamily: "Archivo, sans-serif"
    fontSize: "22px"
    fontWeight: 550
    lineHeight: 1.25
    letterSpacing: "-0.035em"
  body:
    fontFamily: "Archivo, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.55
  document:
    fontFamily: "Archivo, sans-serif"
    fontSize: "22px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "-0.02em"
  caption:
    fontFamily: "Archivo, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  wordmark:
    fontFamily: "Archivo, sans-serif"
    fontSize: "22px"
    fontWeight: 650
    lineHeight: 1.55
    letterSpacing: "-0.035em"
rounded:
  square: "0px"
  action: "7px"
  device: "7px"
spacing:
  compact: "8px"
  icon: "12px"
  small: "16px"
  inset-small: "20px"
  inset: "24px"
  inset-large: "28px"
  group: "32px"
  grid-small: "36px"
  section-small: "44px"
  panel: "64px"
  grid-large: "80px"
  section: "120px"
components:
  button-primary:
    backgroundColor: "{colors.green}"
    textColor: "{colors.ink}"
    rounded: "{rounded.action}"
    padding: "14px 22px"
  button-primary-hover:
    backgroundColor: "{colors.mint}"
    textColor: "{colors.black}"
  download-link:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    rounded: "{rounded.device}"
    padding: "12px 14px"
  download-link-hover:
    backgroundColor: "{colors.layer}"
  revision-control:
    backgroundColor: "{colors.layer}"
    textColor: "{colors.mint}"
    rounded: "{rounded.action}"
    padding: "11px 14px"
  revision-control-hover:
    backgroundColor: "{colors.mint}"
    textColor: "{colors.black}"
  folio-sheet:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    padding: "28px"
  navigation-link:
    textColor: "{colors.ink}"
  navigation-link-hover:
    textColor: "{colors.mint}"
---

# Design System: Daylex

## Overview

**Creative North Star: "The Open Case Folio"**

Authority, precision and calm come from a black field, compact Archivo lettering and opposed square steps. A professional document remains the central material; the AI contribution sits alongside a legible text that the person can review and control.

The approved homepage identity extends across the public website, support and technical documentation, PWA installation and chrome, and Flutter desktop/web workspace. Source authority is `site/home.css`, `site/style.css`, `app/web/install.css`, `app/web/web.css` and `app/lib/core/theme/app_theme.dart`. The opposed folio mark is shared across web and native launch icons. PRODUCT.md supplies durable product constraints; HOME_BRAND.md retains the homepage surface brief.

**Key Characteristics:**
- Dominant black and near-black grounds with rare, meaningful accents.
- Dense sans-serif lettering, generous section intervals and legible document text.
- Repeated opposed orthogonal steps, with flat tonal layering.
- Human-triggered revision, honest examples and a real workspace capture.

## Colors

Neutral black and graphite carry the composition; color identifies an action, focus or a meaningful revision state.

### Primary
- **Action green** (`green`): the principal download action.
- **Control cyan** (`cyan`): keyboard focus outlines and the AI margin symbol.

### Secondary
- **Revision mint** (`mint`): the next-step revision control, marked wording, action/link hover, text selection and the favicon mark. It is a local emphasis, never a large section fill.

### Neutral
- **Black field** (`black`): the page and opening ground; dark text on mint.
- **Near-black ground** (`ground`): opening tonal field, download band and closing panel.
- **Document graphite** (`sheet`): the document sheet and download controls.
- **Layer graphite** (`layer`): the folio backing and interactive hover/selection surfaces.
- **Primary ink** (`ink`): headings, primary body copy and default action text.
- **Supporting ink** (`muted`): captions, device details, help links and unselected controls.
- **Quiet graphite** (`quiet`): the decorative folio mark, not body text.

**The Rare Accent Rule.** Keep black and near-black dominant; reserve the three owner-defined accents for actions and meaningful states. Do not expand them into decorative section backgrounds. Explicit owner exception: OS marks use recognizable colors (Windows blue, Tux native colors, mint Apple and cyan web); these do not become new page accents.

## Typography

Archivo is served locally from `site/fonts/Archivo.ttf` with a sans-serif fallback. One family supplies the hierarchy; the wordmark's heavier weight and the display's compact spacing create authority without a second display face.

The frontmatter records the desktop type roles. The display uses a 95% font stretch. At widths up to 1250px the display becomes 58px and the headline 40px; up to 600px they become 40px and 36px. At up to 360px the display becomes 36px, the title/document size and wordmark become 20px. The mobile closing headline is 32px.

Document text uses a 29ch desktop measure, expanding to 34ch at the intermediate layout. Body descriptions stay around 34–40ch. Captions and navigation are subordinate but readable; mobile device details and revision controls use 13px. All headings and controls use sentence case. The folio title uses slightly looser tracking than section headings (-0.025em).

**The Document First Rule.** Keep working text readable beside the AI contribution; do not turn text into particles, decorative glyphs or automatic spectacle.

## Layout

The desktop content frame has a 1344px maximum width with 48px side gutters. The opening uses two columns (1.04fr / 1fr), an 80px column gap and a download band spanning both columns. The six direct device choices form one row. The masthead is 84px tall; the workspace and closing sections are separated by 120px intervals.

At up to 1250px the frame uses 32px gutters, the opening becomes one column and the download band precedes the folio. Device choices form three columns, the duplicate hero action is hidden, and section intervals reduce to 90px. At up to 600px gutters are 20px, device choices form two columns, the example follows them, workflow copy stacks and the footer wraps. At up to 360px gutters reduce to 16px. Preserve these explicit responsive order changes rather than hiding device routes behind a selector.

The real workspace image spans the frame in grayscale with no enclosing panel, padding or clipping. Its caption remains below. Supporting workflow copy uses three text columns on desktop, separated by space rather than cards.

## Elevation & Depth

There are no box shadows, gradients, blur or glass surfaces. Depth comes from the slight offset between graphite folio layers and the contrast between black, near-black and sheet surfaces. The product screenshot remains unframed. At rest all device choices are colored: recommended routes use full opacity and the layer surface, others use 84% opacity. Only while a card is hovered do all its siblings, including the recommended route, become grayscale at 74% opacity. The hovered card gains full opacity and increased brightness/contrast with no border or outline. Pointer exit restores the detected recommendation. Keyboard focus retains its accessible outline.

**The Flat Material Rule.** Use tone, alignment and the stepped silhouette to distinguish layers; do not add shadows or decorative glow.

## Shapes

Download controls are rounded: 7px for both device choices and primary actions. Revision controls also use 7px corners. The reusable signature is a pair of opposed orthogonal steps at the upper-right and lower-left corners, 24px on desktop and 18px at up to 600px. The final shared clipping rule applies to the backing sheet, front sheet, download band and closing panel; earlier diagonal cuts on the closing panel are overridden.

The Daylex mark repeats opposed rectilinear strokes. Its navigation form uses current text color; the favicon uses mint on black. The opening's broad background field has a separate diagonal entry cut; it does not replace the orthogonal folio signature. The actual workspace screenshot has no cut corners.

## Components

### Primary action

A rounded, compact green action with a 54px minimum height, 14px text/icon gap and frontmatter padding. Hover changes to mint with black text; active press moves down 2px. State transitions last 0.2s; the transform uses the shared easing. The cyan keyboard outline is 3px with a 5px offset. The opening and closing actions both remain available on mobile. Put the studio-code prerequisite and direct access-help link beside the opening action. After a native request, reveal the selected OS installation steps inline, focus their heading, and expose retry plus specific help. The native download is not intercepted, no modal or confirmation is added, and the page never claims it observed completion. Local OS detection names the destination and copies its current release-managed anchor; iOS/Android use the guided PWA. Windows 10/11 are distinguished only with reliable Client Hints; otherwise the label is Windows. Known unsupported CPU targets use the PWA; unknown platforms retain manual selection. This is platform routing, not a hardware compatibility certification. No download starts without a click.

### Device routes

Six neutral, rectangular links combine a recognizable colored OS symbol, device name and supporting line. Minimum height is 84px on desktop, 76px in the intermediate layout and 78px on phones. At rest all controls stay colored: detected recommendations are fully opaque on layer, alternatives at 84% opacity on sheet. Hover applies brightness 1.16 / contrast 1.06 at full opacity to that control, while every sibling becomes grayscale at 74% opacity on sheet, without any hover border or outline; focus uses an inset outline offset of -3px to remain visible within the clipped band. These are navigation/download controls, not a generic feature-card pattern.

Keep all six routes as direct HTML anchors usable without JavaScript. Release integration retains `data-site-version="3"` and the four `data-download` anchors: Windows 11, Windows 10, macOS and Linux. Both Windows routes target the same installer. The iPhone/iPad and PWA routes retain the existing installation guide; the native app and PWA share the same identity.

### Revision folio

The sheet uses the stepped geometry, a muted backing layer, a short document title, readable document wording, a cyan AI-margin symbol and muted explanation. Mint marks the changed phrase only in the AI stage. A single action names the next stage: AI proposal, final human revision, then replay. It uses graphite/mint with a cyan inset keyboard focus outline. Start from the draft; do not suggest a live AI request is running. An explicit caption identifies an illustrative guided example; it is not presented as a live AI response.

JavaScript reveals the next-step control and progresses between the initial draft, AI suggestion and human revision. A polite status region announces each stage and its text. Without JavaScript the labeled example remains readable and the inactive controls remain hidden. The document animation is the user-triggered 0.38s revision: text moves from 8px below at 0.5 opacity to its resting position. The owner explicitly requests one progressive entrance for the six device choices: 640ms per item, 110ms stagger, 1190ms total, once on entering view. Focus or pointer entry immediately reveals that item. All links are visible by default without JavaScript; reduced motion skips and cancels the sequence. No other scroll reveals, auto-cycling states or continuous animation. Reduced motion disables animations and transitions and changes smooth anchor scrolling to immediate scrolling.

### Navigation and wordmark

The masthead balances the compact Daylex mark/name against quiet text links with a 44px minimum interaction height. Hover uses mint. The workspace shortcut disappears at the intermediate breakpoint; phone navigation preserves the browser route. Full support, technical and installation links remain in the footer. The skip link becomes visible on keyboard focus, with mint background and black text.

### Workspace evidence and closing

Use the actual application capture in grayscale with an accurate caption and alt text. Keep the three workflow statements as open text groups. The closing panel repeats the folio steps and pairs a headline with one primary action; it does not introduce another visual system.

## Do's and Don'ts

### Do:
- **Do** preserve the dominant black/near-black field and reserve accents for meaningful roles.
- **Do** repeat the opposed square folio steps consistently across the mark, sheet, download band and closing panel.
- **Do** keep all six direct device routes visible and functional without JavaScript.
- **Do** label illustrative text as an example and use actual product evidence with accurate captions.
- **Do** retain visible keyboard focus, readable text and reduced-motion behavior.
- **Do** carry the same identity across website and app while adapting density to reading and operational tasks.

### Don't:
- **Don't** add colorful section fills, gradients, glass, shadows, pill controls or decorative feature-card grids.
- **Don't** expand the device-choice entrance into a repeated page-wide reveal or introduce automatic revision loops or particle text.
- **Don't** invent testimonials, adoption metrics, certifications or proof of brand recognition.
- **Don't** turn the background field's diagonal cut into the reusable folio silhouette.
- **Don't** hide downloads behind JavaScript, tabs or a carousel, or remove the existing release hooks.


## Application and documentation rollout

Experience principles: recognize the next action, keep primary actions distinct, preserve user control and settings, and reveal technical detail in the relevant documentation. This rollout changes presentation, not authentication, document storage or release protocols.

The Flutter workspace uses Archivo at operational sizes (13–14px body, 18–28px titles); documentation uses a comfortable 16px reading size. Fonts are bundled locally. Inter remains available for exported PDF documents and package fallbacks. White document paper and user-selected document accents are content, not application chrome.

Dark is the default for new users. Explicit light/dark/system preferences remain respected. Dark grounds are #000, #0c0c0c and #171717; text is #f3f3f3, #b5b5b5 and #8d8d8d. Light mode uses neutral white/gray grounds with #0c0c0c primary text and #595959 supporting text. Small cyan links darken to #087e82 on light surfaces for contrast.

Primary filled actions use #15803d with white text, changing to #dff4e2 with black text on hover. Cyan identifies focus and source/AI assistance. Real warnings and destructive errors retain semantic amber/red; these never become decorative section colors. Controls use 12px corners, content containers 14px, compact controls 8px. Dense toolbars keep their established dimensions and keyboard behavior.

Assistance and technical pages use the same wordmark, Archivo, grounds and actions as the homepage. Installation and PWA chrome share these tokens. Native launch icons use the opposed folio on black; `scripts/brand-assets.py` deterministically rasterizes the existing vector geometry. No stock or generated imagery is introduced.

The homepage's requested OS hover behavior and one-time stagger remain local to that selection row. The operational app does not add entrance animations. Preserve reduced motion, visible keyboard focus and text scaling.

Website refinement: all existing rounded elements on public pages, installation guides and HTML PWA chrome use 7px. The native/Flutter application retains its separately documented radii. Public web routes and assets carry noindex directives; robots.txt must permit retrieval so crawlers can read them.
