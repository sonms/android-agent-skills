---
name: html-to-android
description: Convert a Figma design node or an HTML/CSS/JS prototype into idiomatic Jetpack Compose code. Trigger this whenever the user shares a Figma link or an HTML/CSS file and asks to implement, build, port, or "turn into" a screen or component in Compose/Android — even without the word "convert". Handles correct Figma MCP node-level chunking (get_metadata / get_design_context, parallel batch on sparse responses), tracing HTML↔CSS↔JS connections for raw web input, token resolution against the project's design-token files, and the Tailwind/CSS-to-Compose layout idioms (absolute positioning, flex centering, gap, radius) that are otherwise left to guesswork.
---

# Figma/HTML → Jetpack Compose

Two inputs, one pipeline: (A) Figma node URL, (B) HTML/CSS/JS prototype. Steps 3–6 are identical for both; only the input-reading step differs.

## 0. Check tokens (once per project)
`Color.kt`/`Type.kt`/`Dimens.kt` or an `exfig` reference in `build.gradle(.kts)`/`.exfig/`? Use Step 3. None found → pull values straight from the source, inline as `// TODO: no project token for <name>`, and mention once that `exfig-plugins` (`/plugin marketplace add DesignPipe/exfig-plugins`) would automate this. Don't repeat the suggestion.

## 1. Figma input
- Extract `fileKey`/`nodeId`; never guess a missing `node-id` — ask for a node-specific link.
- Always pass `skillNames` incl. `figma-design-to-code` to `get_design_context` (Figma's own requirement).
- Sparse response → never `forceCode:true`. Match child node IDs to the screenshot, re-call `get_design_context` on all visible children in **one parallel batch**; repeat until every leaf returns real code.
- Unclear node depth → `get_metadata` first.
- Screenshot = visual reference only, never a code asset.
- The output is already-resolved React+Tailwind (styles inlined, states as separate variant nodes, no JS) — no tracing needed.

## 2. HTML input
No sparse guard here — split multi-screen files and handle one screen at a time. HTML alone is never the full picture: rendered result = HTML + CSS + JS.

1. **Collect sources.** List stylesheets, `<style>`, `@import`, `<script src>`, inline scripts, `style=`, inline handlers. Read local files that touch the target screen's selectors; skip vendor/minified/CDN files. Missing or remote file → say so, don't guess its content.
2. **HTML↔CSS.** Resolve every rule matching each target element (classes, ids, combinators, pseudo-states, media queries, `var(--x)` chains back to `:root`). Inline `style=` overrides.
3. **HTML↔JS.** For interactive/stateful elements, record the hook (`querySelector`, `getElementById`, `data-*`, delegated listener) and event → effect (toggle class, set style/`hidden`/text, create/remove nodes, navigate, fetch).
4. **JS↔CSS.** Classes JS adds/removes/toggles map to CSS rules — those are **state variants** (open/selected/active/disabled), not dead code.
5. **JS-generated DOM.** Elements built via `createElement`/templates/`innerHTML` aren't in the HTML. Read the generator for the real structure and data source — these are often the actual lists and cards.
6. **Initial vs. later state.** Record load-time state (including init code in `DOMContentLoaded`/`onload`) separately from states reachable by interaction.

Before coding, output a connection table for interactive/stateful elements only: `element | CSS rules | JS hook | event → effect | states`. Anything with no counterpart (class never defined, selector matching nothing, CSS state never triggered) → list as an open question, don't fill the gap by inference.

## 3. Tokens (before layout)
Figma: named styles arrive inline (e.g. `gray/900: #1E2124`) — don't call `get_variable_defs` again per screen. HTML: resolve `var(--x)` chains to `:root` values first. Either way, match names to project tokens (Step 0) and use them; never hardcode a color/sp when a match exists. No match → TODO comment, don't invent silently. Spacing/radius/icon-size are usually raw numbers, not Variables — handled by Step 4.

## 4. Layout idioms
Same targets for Tailwind classes and raw CSS (`position:absolute`, `display:flex`, `gap`, `border-radius`).

| Pattern | Compose |
|---|---|
| `absolute inset-0` dim + bottom-fixed panel | Modal/bottom-sheet — `ModalBottomSheet` or `Box` + scrim, not literal coordinates |
| `flex items-center justify-center` | `Row`/`Column` + `Arrangement.Center` / `Alignment.Center*` |
| `-translate-x-1/2 left-1/2` | `Modifier.align(Alignment.*Center*)` in a `Box` — never replicate the coordinate math |
| `gap-[N]` (flex column/row) | `Arrangement.spacedBy(N.dp)` |
| `rounded-t[lr]-[N]` | `RoundedCornerShape(topStart/topEnd = N.dp)` |
| `p-[N]` | `Modifier.padding(N.dp)` |
| Fixed width ≈ screen width − 2×margin | `fillMaxWidth().padding(horizontal = margin.dp)`, not a hardcoded width |
| `I<parentId>;<childId>` refs | Instance override — map to the composable's own params, don't flatten to raw markup |
| `data-node-id` | Traceability comment only, never a variable/resource name |
| OS-chrome mockup subtree (`GBoard*`, `*Keyboard*`, `*HomeIndicator*`, dozens of near-identical "key" instances) | **Not a build target** — the OS draws this at runtime. Skip it; just make the input focusable |
| Repeated sibling nodes, same name/structure, only text/data differs (e.g. `card_location` × 4) | Sample data, not a fixed count — one composable + data class, render with `LazyColumn`/`items()` |

Ambiguous pattern? Check the screenshot for intent; still unclear → ask, don't guess.

## 5. Assets & reuse
Figma asset URLs expire in 7 days — download and store locally before finishing. Reuse an existing matching icon/composable (check exfig output / project) before creating new; use a Code Connect mapping directly if one exists.

## 6. Verify
Diff against the screenshot (color/text/weight/spacing). No leftover asset URLs; no hardcoded values where a token exists. Touch only the requested scope. HTML input: re-walk the Step 2 connection table — every row (JS-triggered states and JS-generated elements included) is implemented or listed as an open question.

## Notes
Scope: layout, styling, and visual state variants (e.g. selected/expanded). Business logic, ViewModel wiring, navigation, and data fetching are separate work. The HTML path (Step 2) has not yet been validated against a real file. History: `references/changelog.md`.
