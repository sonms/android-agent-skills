# Android to KMP 마이그레이션 (한국어 번역본)

> 에이전트가 실제로 로드하는 원본은 `android-to-kmp-migration.md`(영문)입니다. 이 문서는 검토용 번역본이며, 원본을 고치면 같이 갱신해야 합니다.

Android 전용 코드를 KMP로 전환하는 건 아키텍처적 판단이 필요한 작업이라 완전 자동화가 안 됩니다. 이 문서는 그 판단을 체크리스트로 만든 것이지, 기계적 변환기가 아닙니다.

## 하드 블로커 — 무엇보다 먼저 확인

일부 의존성은 절대 Android 밖으로 못 나갑니다: 네이티브 SDK 임베딩(예: Unity as a Library), Android 전용 벤더 하드웨어 SDK, Kotlin/Native(웹 타겟이면 wasm도) 빌드가 없는 라이브러리. 여기 해당하면 `ANDROID_ONLY`로 고정 — 재검토 안 함.

## 0. 부트스트랩 — 진단 이전

**AGP 체크** (마이너 버전마다 임계값이 바뀌니 현재 AGP 9 릴리스 노트로 재확인):

| 확인 항목 | 임계값 | 조치 |
|---|---|---|
| AGP | 9.0.0 미만 | 기존 `com.android.library/application` + `kotlin.multiplatform` 그대로 동작 |
| AGP | 9.0.0 이상 | 기존 조합은 **빌드 자체가 거부됨** — `com.android.kotlin.multiplatform.library` 사용, Android 앱 진입점은 별도 모듈 |
| KGP | 2.2.10 이상(2.3.0+ 권장) | 자동 업그레이드에 맡기지 말고 명시적으로 고정 |
| Gradle | AGP 9.0.0 기준 9.1.0 이상 | 플러그인 버전보다 wrapper 먼저 올림 |
| compileSdk/targetSdk | AGP 9.x마다 하한 상승 | 현재 릴리스 노트 확인 후 플러그인 적용 전에 올림 |

opt-out 플래그(`android.builtInKotlin=false`, `android.newDsl=false`)로 옛 DSL을 임시 유지 가능 — AGP 10(현재 로드맵 기준 2026년 하반기)에서 제거 예정. 임시방편으로만 취급, 조용히 적용하지 말고 알림. 전용 AGP/KMP 마이그레이션 스킬이 있으면 직접 하지 말고 그쪽으로 라우팅.

**KMP 플러그인 미적용 시:** 플러그인 적용 후 타겟 선언(`androidTarget()`, `iosX64()`/`iosArm64()`/`iosSimulatorArm64()`). 빈 `commonMain`이 컴파일되면 1번으로 넘어갈 체크포인트.

**단일 모듈:** 기존 모듈에 `commonMain`/`androidMain`/`iosMain` 추가하고 바로 진단으로. 모듈 분리는 진단 결과 실제로 필요할 때만 나중에.

**멀티모듈:** 기존 모듈 경계를 그대로 2번 순서에 활용.

## 1. 진단

파일마다 버킷 하나로 분류:
- **COMMON** — 순수 Kotlin, 플랫폼 API/라이브러리 없음. 제일 먼저 이동.
- **EXPECT_ACTUAL** — 의도상 공유 가능, 구현은 플랫폼별(DB 드라이버, 알림, 커넥티비티, 딥링크, 외부 링크, 백그라운드 스케줄링). `expect` + 타겟별 `actual`.
- **ANDROID_ONLY** — Compose UI, Activity/Fragment, WorkManager 세부사항, 하드 블로커.

```bash
grep -rl "^import android\." <모듈>/src/main/{java,kotlin} 2>/dev/null
grep -rl "Context" <모듈>/src/main/{java,kotlin} 2>/dev/null
grep -E "implementation|api\(" <모듈>/build.gradle.kts
```

파일 옮기기 전에 파일당 한 줄씩 산출 (아래는 포맷 예시, 실제 데이터 아님):

| 파일 | 버킷 | 시그널 |
|---|---|---|
| `UserRepository.kt` | COMMON | android import 없음 |
| `UserDao.kt` | 확인 필요 | Room DAO — 현재 KMP 지원 여부 확인 |
| `NotificationHelper.kt` | EXPECT_ACTUAL | `NotificationCompat` 사용 |

## 2. 모듈 재구성 순서

1. 처음부터 `commonMain` + `iosMain` 구성 — `commonMain`은 두 번째 타겟에서 컴파일돼야 비로소 공유 검증됨.
2. 실제 Xcode 프로젝트(`iosApp`)는 iOS 빌드가 진짜 필요할 때까지 미룸.
3. 도메인 → 데이터 → 피처 순으로 전환; Compose UI 모듈은 마지막.
4. 전환된 모듈마다 각자의 `commonMain`/`androidMain`/`iosMain` — 모듈 단위지 하나의 공유 덩어리가 아님.
5. 모듈이 여러 개 전환되면, `iosMain`이 재-export하는 `shared` 모듈 추가해서 Xcode가 프레임워크 하나만 링크. Android는 필요 없음 — Gradle이 멀티모듈 의존성 직접 해결.
6. 플랫폼 앱 모듈(`androidApp`/`iosApp`/`desktopApp`/`webApp`)은 얇은 진입점 유지.

## 3. 라우팅: SWAP vs BRANCH

**SWAP** — 라이브러리 하나가 다른 걸 대체. 감지 후 기존 마이그레이션 스킬로 라우팅 — 여기서 다시 구현 안 함.

| Concern | Android 전용 | 방향 |
|---|---|---|
| DI | Hilt/Dagger | Koin / 멀티플랫폼 DI |
| 네트워킹 | Retrofit + OkHttp | Ktor |
| JSON | Gson/Moshi | kotlinx.serialization |
| 로컬 DB | Room(버전 확인) | 멀티플랫폼 지원 확인된 현재 Room |
| Preferences | SharedPreferences/Proto DataStore | DataStore + 멀티플랫폼 serializer |

**BRANCH** — 바꿔 끼울 라이브러리 없음, 각 플랫폼의 `actual`이 네이티브 API 직접 호출: 커넥티비티 감지, 알림, 딥링크 진입, 외부 링크 열기, 백그라운드 작업 스케줄링, 분석/크래시 훅.

어느 쪽에도 안 맞으면 추측하지 말고 물어봄.

## Field notes

(비어있음 — `- YYYY-MM-DD (프로젝트): 발견 내용`)
