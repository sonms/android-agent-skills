---
name: html-to-android
description: Convert a Figma design node or an HTML/CSS/JS prototype into idiomatic Jetpack Compose code. Trigger whenever the user shares a Figma link or an HTML/CSS file and asks to implement, build, port, or "turn into" a screen or component in Compose/Android — even without the word "convert". Covers Figma MCP node-level fetching, HTML↔CSS↔JS tracing, design-token resolution, and Tailwind/CSS-to-Compose layout idioms.
---

# Figma/HTML → Jetpack Compose

Two inputs, one pipeline: (A) Figma node URL, (B) HTML/CSS/JS prototype. Steps 1–2 read the input; Steps 3–6 are shared.

## 0. Check tokens (once per project)
`Color.kt`/`Type.kt`/`Dimens.kt`, or `exfig` in `build.gradle(.kts)`/`.exfig/`? Use Step 3. None → take values from the source, inline as `// TODO: no project token for <name>`, and mention once that `exfig-plugins` (`/plugin marketplace add DesignPipe/exfig-plugins`) would automate this.

## 1. Figma input
- Extract `fileKey`/`nodeId`. Never guess a missing `node-id` — ask for a node-specific link. If the node is a page/canvas root (e.g. `0:1`), ask for a screen link too: `get_metadata` on a root dumps the whole page tree into context. Scan only if the user can't provide one.
- Always pass `skillNames` incl. `figma-design-to-code` to `get_design_context`.
- Sparse response (metadata only) → never `forceCode:true`. Match child node IDs to the screenshot, re-call on all visible children in **one parallel batch**, repeat until every leaf returns code. Unsure of depth → `get_metadata`.
- The code is already-resolved React+Tailwind (styles inlined, states as separate variant nodes, no JS). The screenshot is a visual reference only, never a code asset.

## 2. HTML input
No sparse guard — split multi-screen files, one screen at a time. HTML alone isn't the picture: result = HTML + CSS + JS.

1. **Sources.** List stylesheets, `<style>`, `@import`, scripts, `style=`, inline handlers. Read local files touching the target selectors; skip vendor/minified/CDN. Missing/remote → say so, don't guess.
2. **HTML↔CSS.** Resolve every rule matching each target element (classes, combinators, pseudo-states, media queries, `var(--x)` → `:root`); inline `style=` wins.
3. **HTML↔JS.** For interactive elements record the hook (`querySelector`, `getElementById`, `data-*`, delegated listener) and event → effect (class toggle, style/`hidden`/text change, node create/remove, navigate, fetch).
4. **JS↔CSS.** Classes JS adds/removes/toggles map to CSS rules — **state variants** (open/selected/active/disabled), not dead code.
5. **JS-generated DOM** (`createElement`/templates/`innerHTML`) isn't in the HTML: read the generator for real structure and data source — often the actual lists/cards.
6. **Initial vs. later state:** record load-time state (incl. `DOMContentLoaded`/`onload` init code) apart from interaction states.

Before coding, output a table for interactive/stateful elements only: `element | CSS rules | JS hook | event → effect | states`. Anything without a counterpart (undefined class, selector matching nothing, CSS state never triggered) → open question, not inference. Capture a reference screenshot now (Step 6) — Step 4's "check the screenshot" needs one.

## 3. Tokens (before layout)
- Figma: the code body carries raw hex/font values; the trailing style list (e.g. `gray/900: #1E2124`) is the value→name table. Replace raw values with tokens, only for styles the kept elements use (the list can include mock-component styles, e.g. an M3 status-bar kit). Don't call `get_variable_defs` again per screen.
- HTML: resolve `var(--x)` chains to `:root` first.
- Then match names to project tokens (Step 0); never hardcode a color/sp when a match exists. No match → TODO comment, don't invent silently. Spacing/radius/icon size are usually raw numbers — Step 4 handles them.

## 4. Layout idioms
Same targets for Tailwind classes and raw CSS (`position:absolute`, `display:flex`, `gap`, `border-radius`).

| Pattern | Compose |
|---|---|
| `dim` overlay (`absolute inset-0`) + panel | Bottom-anchored panel → `ModalBottomSheet` (or `Box` + scrim); centered card (e.g. `modal_small`) → `Dialog`/`AlertDialog` or the design system's dialog. Never literal coordinates |
| `-translate-x-1/2 left-1/2` | `Modifier.align(Alignment.*Center*)` in a `Box` — never replicate the coordinate math |
| Fixed width ≈ screen width − 2×margin | `fillMaxWidth().padding(horizontal = margin.dp)`, not a hardcoded width |
| `data-node-id` (incl. `I<parent>;<child>` instance internals) | Traceability comment only, never a name. Instance internals map to the composable's own params — don't flatten to raw markup |
| OS-chrome mockup subtree (`GBoard*`, `*Keyboard*`, `*HomeIndicator*`, `*status-bar*`, `*navigation-bar*`, dozens of near-identical key instances) | **Not a build target** — the OS draws it. Skip it; make the input focusable. Space a status-bar mock occupies (e.g. header at `top-[52px]`) → window insets (`statusBarsPadding()`), not a fixed dp |
| Repeated sibling nodes, same structure, only text/data differs (e.g. `card_location` × 4, `btn_nav` × 5) | One composable + data class, rendered from a list. Container follows the layout: long vertical → `LazyColumn`; short horizontal set → `Row` + `weight`; active/inactive differences → a `selected` param. Count is sample data unless the set is clearly fixed |
| Screen-level sections each placed with `absolute top-[N]` (no flex parent) | One `Column`; gap = next.top − (prev.top + prev.height); only truly overlapping elements (e.g. a mascot over the header) stay in a `Box`. A frame taller than the device frame (e.g. 1716 vs 800) is scrolling content → `LazyColumn`/`verticalScroll`, with fixed header/nav outside it |
| Fixed header / bottom nav / floating button at the screen edges | `Scaffold` `topBar` / `bottomBar` / `floatingActionButton` slots (or the design system's equivalent) |
| `drop-shadow-[x_y_blur_color]` / outer `box-shadow` | `Modifier.dropShadow(shape, Shadow(radius, spread, color, offset = DpOffset(x, y)))` **before** `.background`; inner shadow → `Modifier.innerShadow` **after** it. `Modifier.shadow` is elevation-only (no offset/spread/radius). Blur→`radius` isn't documented: start 1:1, confirm by crop. One `shape` only, so a CSS drop-shadow over a composite (bubble + tail) won't match exactly. Check the Compose version supports it |

Ambiguous pattern? Check the screenshot; still unclear → ask, don't guess.

## 5. Assets & reuse
- Figma asset URLs expire in 7 days — download and store locally. Android needs VectorDrawable (import the SVG) or an existing icon resource; verify export transforms (`-rotate-180 -scale-x-100`) against the screenshot instead of copying them.
- Reuse existing icons/composables (exfig output, project) before creating new.
- `CodeConnectSnippet` wrappers are not final code: find the component in the project and use it. No project match → convert from the markup, or skip if it's OS chrome.

## 6. Verify (visually, when possible)
- **Reference:** Figma → the screenshot from `get_design_context`. HTML → render if a tool exists (pixelshot / Playwright / headless Chrome, wait for network idle), else ask the user.
- **Result:** only through a screenshot setup the project already has (Roborazzi / Paparazzi / Compose Preview Screenshot Testing / emulator). Never add dependencies or edit build files without asking. Commands: `references/visual-verify.md` (read only when capturing).
- **Missing reference or result → state "visual verification not performed".** Never claim fidelity from code alone; a blank/incomplete capture is a failed capture.
- Compare same-scale crops, not whole images; keep the long edge ≤ ~1568px when reading (larger images are downscaled). JVM renders differ from devices (fonts, shadows): evidence, not pass/fail.
- No leftover asset URLs; no hardcoded values where a token exists; only the requested scope. HTML: every row of the Step 2 table implemented or listed as an open question.

## Figma MCP invariants

These rules apply only to the Figma branch.

- Before `get_design_context`, load the available `figma-design-to-code` skill. Treat its React/Tailwind output as a design reference, never as Compose source to paste.
- Start with `get_design_context` for the exact node. It includes a screenshot by default; call `get_screenshot` separately only when a different node or higher-resolution visual check is needed.
- If the response is truncated or the screen is structurally unclear, use `get_metadata` to select smaller logical nodes, then fetch those nodes individually. Do not use a guessed node ID or force a huge response.
- Use `get_variable_defs` only when variables/styles are absent or ambiguous in the design-context response, or when an explicit token mapping is required. Map them to existing Compose theme tokens first.
- Figma image and SVG assets take priority. Download supplied asset URLs before they expire and add them through the project's Android resource or image-loading convention. A `localhost` URL from web-oriented Figma output is not an Android runtime `src`; do not leave it in Compose code.
- When Figma supplies an icon or image, reuse it instead of adding an icon dependency or substituting a placeholder. Generate an image only when no suitable source asset exists and the user has approved any Figma AI credit use.

## Notes
Scope: layout, styling, visual state variants (e.g. selected/expanded). Business logic, ViewModel, navigation, data fetching are separate. The Figma path was checked on real nodes (bottom sheet, list, home screen) at the decision level only — nothing compiled or rendered; the HTML path and the Step 6 capture flow are untested. History: `references/changelog.md`.
