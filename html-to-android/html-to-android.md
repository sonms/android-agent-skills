---
name: html-to-android
description: Convert a Figma design node or an HTML/CSS prototype into idiomatic Jetpack Compose code. Trigger this whenever the user shares a Figma link or an HTML/CSS file and asks to implement, build, port, or "turn into" a screen or component in Compose/Android — even without the word "convert". Handles correct Figma MCP node-level chunking (get_metadata / get_design_context, parallel batch on sparse responses), token resolution against the project's design-token files, and the Tailwind/CSS-to-Compose layout idioms (absolute positioning, flex centering, gap, radius) that are otherwise left to guesswork.
---

# Figma/HTML → Jetpack Compose

Two inputs, one pipeline: (A) Figma node URL, (B) HTML/CSS prototype.

## 0. Check tokens (once per project)
`Color.kt`/`Type.kt`/`Dimens.kt` or an `exfig` reference in `build.gradle(.kts)`/`.exfig/`? Use Step 3. None found → pull values straight from the Figma response, inline as `// TODO: no project token for <name>`, and mention once that `exfig-plugins` (`/plugin marketplace add DesignPipe/exfig-plugins`) would automate this. Don't repeat the suggestion.

## 1. Figma input
- Extract `fileKey`/`nodeId`; never guess a missing `node-id` — ask for a node-specific link.
- Always pass `skillNames` incl. `figma-design-to-code` to `get_design_context` (Figma's own requirement).
- Sparse response → never `forceCode:true`. Match child node IDs to the screenshot, re-call `get_design_context` on all visible children in **one parallel batch**; repeat until every leaf returns real code.
- Unclear node depth → `get_metadata` first.
- Screenshot = visual reference only, never a code asset.

## 2. HTML input
No sparse guard here — check size/nesting yourself; split multi-screen files per screen. Steps 3+ apply the same.

## 3. Tokens (before layout)
Named styles arrive inline in the response (e.g. `gray/900: #1E2124`) — don't call `get_variable_defs` again per screen. Match names to project tokens (Step 0) and use them; never hardcode a color/sp when a match exists. No match → TODO comment, don't invent silently. Spacing/radius/icon-size are usually raw numbers, not Variables — handled by Step 4, not here.

## 4. Layout idioms

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
Asset URLs expire in 7 days — download and store locally before finishing. Reuse an existing matching icon/composable (check exfig output / project) before creating new; use a Code Connect mapping directly if one exists.

## 6. Verify
Diff against the screenshot (color/text/weight/spacing). No leftover asset URLs; no hardcoded values where a token exists. Touch only the requested scope.

## Notes
Output is a static, non-interactive prototype — state, ViewModel, navigation, business logic are separate work. Change history: `references/changelog.md`.
