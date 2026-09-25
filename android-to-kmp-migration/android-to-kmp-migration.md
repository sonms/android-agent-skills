---
name: android-to-kmp-migration
description: Use when converting Android-only code (a module or a whole app) into Kotlin Multiplatform — diagnosing which code can move to commonMain vs needs expect/actual vs must stay Android-only, restructuring modules into commonMain/androidMain/iosMain, and routing library substitutions to existing migration skills. Trigger on requests like "make X KMP", "add iOS support", "share this with iOS", or when a module mixes Android-specific APIs with logic that should be shareable. This is a judgment-driven procedure, not a deterministic converter — do not promise a fully automatic conversion.
metadata:
  category: platform-dev
---

# Android to KMP Migration

Converting Android-only code to KMP requires architectural judgment — no tool does this end-to-end. This is a checklist, not a mechanical converter.

## Hard blockers — check first

Some dependencies can never leave Android: native SDK embeddings (e.g. Unity as a Library), Android-only vendor hardware SDKs, any library with no Kotlin/Native (or wasm, if targeting web) build. Anything touching one is `ANDROID_ONLY` — fixed, don't revisit.

## 0. Bootstrap — before diagnosis

**AGP check** (reverify against current AGP 9 release notes — thresholds shift every minor release):

| Check | Threshold | Action |
|---|---|---|
| AGP | < 9.0.0 | classic `com.android.library/application` + `kotlin.multiplatform` still works |
| AGP | ≥ 9.0.0 | classic combo **rejected by the build** — use `com.android.kotlin.multiplatform.library`; Android app entry point in its own module |
| KGP | ≥ 2.2.10 (2.3.0+ recommended) | pin explicitly, don't rely on auto-upgrade |
| Gradle | ≥ 9.1.0 for AGP 9.0.0 | bump wrapper first |
| compileSdk/targetSdk | floor rises each AGP 9.x release | check current notes, bump before applying plugin |

Opt-out flags (`android.builtInKotlin=false`, `android.newDsl=false`) keep the old DSL temporarily — removed in AGP 10 (H2 2026 per current roadmap). Stopgap only; flag it, don't apply silently. If a dedicated AGP/KMP migration skill is available, route to it instead of doing this by hand.

**No KMP plugin yet:** apply it, declare targets (`androidTarget()`, `iosX64()`/`iosArm64()`/`iosSimulatorArm64()`). An empty `commonMain` that compiles is the checkpoint before step 1.

**Single-module:** add `commonMain`/`androidMain`/`iosMain` to the existing module, go straight to diagnosis. Split into separate modules only later, if diagnosis shows it's actually needed.

**Multi-module:** reuse existing module boundaries for the order in step 2.

## 1. Diagnosis

Classify each file into one bucket:
- **COMMON** — pure Kotlin, no platform API/library. Move first.
- **EXPECT_ACTUAL** — shareable in intent, platform-specific implementation (DB driver, notifications, connectivity, deep links, external links, background scheduling). `expect` + one `actual` per target.
- **ANDROID_ONLY** — Compose UI, Activity/Fragment, WorkManager specifics, hard blockers.

```bash
grep -rl "^import android\." <module>/src/main/{java,kotlin} 2>/dev/null
grep -rl "Context" <module>/src/main/{java,kotlin} 2>/dev/null
grep -E "implementation|api\(" <module>/build.gradle.kts
```

Produce one row per file before moving anything (illustrative format, not real data):

| File | Bucket | Signal |
|---|---|---|
| `UserRepository.kt` | COMMON | no android import |
| `UserDao.kt` | check | Room DAO — verify current KMP support |
| `NotificationHelper.kt` | EXPECT_ACTUAL | uses `NotificationCompat` |

## 2. Module restructuring order

1. Scaffold `commonMain` + `iosMain` from the start — `commonMain` isn't proven shared until it compiles against a second target.
2. Defer the actual Xcode project (`iosApp`) until an iOS build is genuinely needed.
3. Convert domain → data → feature, in that order; Compose UI modules last.
4. Each converted module gets its own `commonMain`/`androidMain`/`iosMain` — per-module, not one shared blob.
5. Once several modules are converted, add a `shared` module whose `iosMain` re-exports them for one Xcode framework. Android doesn't need this — Gradle resolves multi-module deps directly.
6. Platform app modules (`androidApp`/`iosApp`/`desktopApp`/`webApp`) stay thin entry points.

## 3. Routing: SWAP vs BRANCH

**SWAP** — one library replaces another. Detect it, then route to an existing migration skill for the swap — don't reimplement here.

| Concern | Android-only | Direction |
|---|---|---|
| DI | Hilt/Dagger | Koin / multiplatform DI |
| Networking | Retrofit + OkHttp | Ktor |
| JSON | Gson/Moshi | kotlinx.serialization |
| Local DB | Room (check version) | current Room, if multiplatform-capable |
| Preferences | SharedPreferences/Proto DataStore | DataStore + multiplatform serializer |

**BRANCH** — no swap-in library; each platform's `actual` calls its own native API: connectivity detection, notifications, deep link entry, opening external links, background work scheduling, analytics/crash hooks.

If a concern fits neither, ask — don't guess an expect/actual shape.

## Field notes

(empty — `- YYYY-MM-DD (project): finding`)
