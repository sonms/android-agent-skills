# android-to-kmp-migration 스킬

Android 전용 코드(모듈 또는 앱 전체)를 Kotlin Multiplatform(KMP)으로 전환하는 작업을 위한 에이전트 스킬입니다. "완전 자동 변환"이 아니라, 판단이 필요한 지점을 구조화된 절차로 만든 것입니다 — 어떤 코드가 진짜 공유 가능한지는 결국 아키텍처 판단이 필요하고, 이걸 대신 해주는 기계적 도구는 존재하지 않기 때문입니다.

## 파일 구성

| 파일 | 용도 |
|---|---|
| `android-to-kmp-migration.md` | 에이전트가 실제로 로드하는 원본 SKILL.md (영문) |
| `android-to-kmp-migration.ko.md` | 사람이 검토·수정할 때 참고하는 한국어 번역본 |

**원본(영문)을 고치면 번역본도 같이 갱신해야 합니다.** 번역본은 에이전트에게 직접 로드되지 않는, 검토용 사본입니다.

## 설계 배경

이 스킬은 네 단계로 설계됐습니다:

0. **부트스트랩** — 진단 이전에 AGP 9 호환성(버전 임계값, `com.android.kotlin.multiplatform.library` 필요 여부), KMP 플러그인 적용 여부, 단일모듈/멀티모듈 분기를 먼저 확인한다.
1. **진단 (Diagnosis)** — 파일/클래스를 `COMMON` / `EXPECT_ACTUAL` / `ANDROID_ONLY` 세 버킷으로 분류. Unity 임베딩 같은 "하드 블로커"는 진단 이전에 따로 걸러서 재검토 대상에서 뺀다.
2. **모듈 재구성 순서** — 도메인 → 데이터 → 피처(UI는 최후) 순서로, 모듈 단위로 `commonMain`/`androidMain`/`iosMain`을 만들어나가고, 전환된 모듈이 쌓이면 iOS 전용 export 창구 역할의 `shared` 모듈을 둔다.
3. **라우팅: SWAP vs BRANCH** — "라이브러리 하나로 치환되는 것"(SWAP형: DI, 네트워킹 등, 기존 커뮤니티 스킬로 라우팅)과 "플랫폼별 네이티브 API 분기가 필요한 것"(BRANCH형: 커넥티비티, 알림, 딥링크 등, expect/actual로 직접 구현)을 구분해서 다룬다.

## 아직 안 정해진 것 / 다음 단계

- 실제 프로젝트에 적용하면서 `Field notes` 섹션에 발견 사항을 쌓아나갈 것. 특히 Unity 오버레이와 Compose UI 사이의 통신 경계처럼, 현재 버킷 분류(`EXPECT_ACTUAL` vs `ANDROID_ONLY`) 어디에도 깔끔히 안 맞을 수 있는 케이스를 우선 확인.
- SWAP형 항목에서 라우팅할 실제 커뮤니티 스킬 이름은 하드코딩하지 않음 — 적용 시점에 탐색해서 결정.
- 0번의 AGP/Kotlin/Gradle 버전 임계값은 2026년 3분기 기준 스냅샷 — 실제 적용 시점마다 공식 릴리스 노트로 재확인 필요.
