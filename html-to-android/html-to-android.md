---
name: html-to-android
description: Convert a Figma design node or an HTML/CSS prototype into idiomatic Jetpack Compose code. Trigger this whenever the user shares a Figma link or an HTML/CSS file and asks to implement, build, port, or "turn into" a screen or component in Compose/Android — even without the word "convert". Handles rate-limit-aware Figma MCP node-level chunking (get_metadata / get_design_context, bounded parallel batch on sparse responses), token resolution against the project's design-token files, skip/merge rules for leftover or non-UI layers in messy Figma files, and the Tailwind/CSS-to-Compose layout idioms (absolute positioning, flex centering, gap, radius) that are otherwise left to guesswork.
---

# Figma/HTML → Jetpack Compose

Two inputs, one pipeline: (A) Figma node URL, (B) HTML/CSS prototype.

## 0. Project context (once per project)
- **Tokens**: `Color.kt`/`Type.kt`/`Dimens.kt` or an `exfig` reference in `build.gradle(.kts)`/`.exfig/`? Use Step 3. None found → pull values straight from the Figma response, inline as `// TODO: no project token for <name>`, and mention once that `exfig-plugins` (`/plugin marketplace add DesignPipe/exfig-plugins`) would automate this. Don't repeat the suggestion.
- **Figma map**: if `FIGMA-MAP.md` (or `docs/figma-map.md`) exists in the project, read it first. Use its node IDs instead of exploring with `get_metadata`, treat its skip list and open questions as input. The map can be stale — if it conflicts with the live Figma response, trust Figma and report the drift.

## 1. Figma input
- Extract `fileKey`/`nodeId`; never guess a missing `node-id` — ask for a node-specific link.
- **Call budget.** Every read call (`get_design_context`, `get_metadata`, `get_variable_defs`, `get_screenshot`) counts against a plan rate limit that can be very low on free plans. One `get_design_context` per screen-frame link; never re-call the same node. Skip `get_metadata` when the link already points to a single frame. Never call it on a page root (`0:1`) or any node with dozens of children — it dumps the whole tree into context; ask for a frame/section link instead.
- Always pass `skillNames` incl. `figma-design-to-code` to `get_design_context` (Figma's own requirement).
- Sparse response → never `forceCode:true`. Match child node IDs to the screenshot, re-call `get_design_context` on the visible children in **one parallel batch of at most 5**. If leaves remain, stop and report the remaining node IDs instead of looping.
- Unclear node depth on a single frame → `get_metadata` on that frame only.
- Screenshot = visual reference only, never a code asset.

## 2. HTML input
No sparse guard here — check size/nesting yourself; split multi-screen files per screen. Steps 3+ apply the same.

## 3. Tokens (before layout)
Named styles arrive inline in the response (e.g. `gray/900: #1E2124`) — don't call `get_variable_defs` again per screen. Match names to project tokens (Step 0) and use them; never hardcode a color/sp when a match exists. No match → TODO comment, don't invent silently. Raw hex with no style name means no Variable/Style is bound in Figma — note it in the report. Spacing/radius/icon-size are usually raw numbers, not Variables — handled by Step 4, not here.

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

### Messy-file rules (skip / merge)
Design files often carry leftovers. Apply these, and **list every skip in the final report** — silent omission is the failure mode.

| Pattern | Action |
|---|---|
| Node with `hidden="true"` | Don't implement. Report it (it may be a planned feature) |
| Child lying outside its screen frame's bounds (e.g. a 484px image at x=574 inside a 393px frame) | Leftover layer — skip and report |
| Screenshot-image status bar (`스크린샷*`, `Screenshot*`, `StatusBar` as a bitmap) | Same as OS-chrome: skip; the system draws it |
| Explanatory/placeholder text (`"…표시 영역"`, `"area shown briefly after X"`, wireframe labels like `제목`/`뒤로가기`) | **Never render the label.** Implement the region it describes (image slot, transient toast) and carry the text into the report as a behavior spec |
| One paragraph split into sibling Text nodes with the same x (hard line breaks, even mid-word) | One `Text`, fixed width; verify wrapping against the screenshot |
| Several same-size frames whose layout is the same and only values/check marks differ (form states) | One screen composable + state params + one `@Preview` per frame — not N screens |
| Default-named variants (`속성 1=…`, `Variant2`, `Property 1=…`) | Map to a meaningful enum/param; report the naming |
| Same component drawn as plain frames in many places (tab bar, header, check icon) | One shared composable; if copies differ in size/geometry, treat as separate variants and report |
| Copy that contradicts the screen's purpose (e.g. a "Login" button on a sign-up form) | Implement literally, flag in the report. Don't silently fix |

Ambiguous pattern? Check the screenshot for intent; still unclear → ask, don't guess.

## 5. Assets & reuse
Asset URLs expire in 7 days — download and store locally before finishing. Reuse an existing matching icon/composable (check exfig output / project) before creating new; use a Code Connect mapping directly if one exists. If an image looks like a placeholder (generated/screenshot filename), say so instead of shipping it as a final asset.

## 6. Verify & report
Diff against the screenshot (color/text/weight/spacing). No leftover asset URLs; no hardcoded values where a token exists. Touch only the requested scope.

The final report always lists: skipped nodes (hidden / off-frame / OS-chrome, with IDs), inferred states, copy or layout anomalies, unresolved tokens, and nodes left unfetched because of the call budget.

## Notes
Output is a static, non-interactive prototype — state, ViewModel, navigation, business logic are separate work. Change history: `references/changelog.md`.
