# Visual verification — details (read only when capturing)

## Reference capture (HTML input only)
Detect: `pixelshot`, `playwright`, or a Chrome/Chromium binary on PATH. None found → ask the user for a screenshot. Never install without asking; say the exact command and what it changes, ask once, and continue without it if declined.

pixelshot (documented in its own skill):
`pixelshot <file.html> --output /tmp/ref --tile-height 1568 --viewport-width 390 --wait-network-idle`
- It is a desktop-mode renderer (`mobile` is hardcoded false): width is adjustable, but there is no touch/mobile emulation.
- It only captures the load-time state — it cannot click. For JS-triggered states, drive the page with Playwright instead: one capture per state row of the Step 2 connection table.
- Read `tiles.json` first. `"complete": false` or no manifest → failed capture, report it; do not treat it as the page.
- Skip multi-tile output for a single mobile screen — extra tiles only add image tokens.

## Result capture (Compose)
Detect in `build.gradle(.kts)` / version catalog: `io.github.takahirom.roborazzi`, `app.cash.paparazzi`, `com.android.compose.screenshot`. Use what exists; if none, ask before adding anything (it edits build files) — otherwise report "not performed".
- Compose Preview Screenshot Testing: `updateDebugScreenshotTest` (record) / `validateDebugScreenshotTest` (verify)
- Paparazzi: `recordPaparazziDebug` / `verifyPaparazziDebug`
- Roborazzi: JVM + Robolectric, no emulator; check the project's configured tasks
- Emulator/device: `adb exec-out screencap -p > out.png`
Task names come from third-party docs (mid-2026) and these tools were alpha/fast-moving — verify against the project. Preview-based tools need a `@Preview` of the target composable.

## Compare
- Crop the same region from reference and result at the same scale (Pillow: `Image.open(p).crop((x1, y1, x2, y2))`), read crops ≤ ~800×800.
- Color check: sample a pixel in a flat area (`getpixel`) and compare to the token's value, with a small tolerance for compression/antialiasing. (Technique suggested by this skill, not taken from a tool.)
- Long edge ≤ ~1568px when reading (figure from PixelRAG's skill for Sonnet/Haiku; confirm against current model docs).

## Permissions (Claude Code)
A skill's `allowed-tools` frontmatter can pre-approve commands, with scoped patterns like `Bash(pixelshot *)`. Pre-approve only read-only/capture commands — never installs or build-file edits. Whether the field only pre-approves or also restricts is described inconsistently across sources, and other agents may ignore it, so it is not enabled in this skill yet.
