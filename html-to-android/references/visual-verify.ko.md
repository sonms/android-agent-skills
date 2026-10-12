# 시각 검증 — 상세 (캡처할 때만 읽는다)

## 기준 캡처 (HTML 입력만)
감지: PATH에 `pixelshot`, `playwright`, Chrome/Chromium 바이너리. 없으면 사용자에게 스크린샷 요청. 묻지 않고 설치 금지 — 정확한 명령과 무엇이 바뀌는지 알리고 한 번만 묻고, 거절하면 없이 진행.

pixelshot(자체 스킬 문서 기준):
`pixelshot <file.html> --output /tmp/ref --tile-height 1568 --viewport-width 390 --wait-network-idle`
- 데스크톱 모드 렌더러다(`mobile`이 false로 하드코딩). 폭은 조절되지만 터치/모바일 에뮬레이션은 없다.
- 로드 시점 상태만 캡처하고 클릭은 못 한다. JS가 트리거하는 상태는 Playwright로 페이지를 직접 조작해서 2단계 연결표의 상태 행마다 한 장씩 캡처.
- `tiles.json`을 먼저 읽는다. `"complete": false`거나 매니페스트가 없으면 실패한 캡처 — 페이지로 취급하지 말고 보고.
- 모바일 한 화면에는 멀티 타일을 피한다 — 타일이 늘면 이미지 토큰만 늘어난다.

## 결과 캡처 (Compose)
`build.gradle(.kts)`/버전 카탈로그에서 감지: `io.github.takahirom.roborazzi`, `app.cash.paparazzi`, `com.android.compose.screenshot`. 있는 것을 쓰고, 없으면 무언가 추가하기 전에 먼저 묻는다(빌드 파일 수정) — 아니면 "수행 안 함"으로 보고.
- Compose Preview Screenshot Testing: `updateDebugScreenshotTest`(기록) / `validateDebugScreenshotTest`(검증)
- Paparazzi: `recordPaparazziDebug` / `verifyPaparazziDebug`
- Roborazzi: JVM + Robolectric, 에뮬레이터 불필요, 프로젝트에 설정된 태스크 확인
- 에뮬레이터/기기: `adb exec-out screencap -p > out.png`
태스크 이름은 서드파티 문서(2026년 중반) 기준이고 이 도구들은 알파/변동이 빠르니 프로젝트에서 확인. Preview 기반 도구는 대상 컴포저블의 `@Preview`가 필요.

## 비교
- 기준과 결과에서 같은 영역을 같은 배율로 crop(Pillow: `Image.open(p).crop((x1, y1, x2, y2))`), crop은 ~800×800 이하로 읽는다.
- 색상 확인: 평평한 영역의 픽셀을 샘플링(`getpixel`)해서 토큰 값과 비교, 압축/안티앨리어싱 허용 오차 약간. (이 스킬이 제안한 기법이고 특정 도구에서 가져온 게 아님.)
- 읽을 때 긴 변 ~1568px 이하(PixelRAG 스킬의 Sonnet/Haiku 기준 수치, 현재 모델 문서로 재확인).

## 권한 (Claude Code)
스킬 frontmatter의 `allowed-tools`로 `Bash(pixelshot *)` 같은 범위 패턴의 명령을 미리 승인할 수 있다. 읽기/캡처 명령만 미리 승인하고 설치나 빌드 파일 수정은 제외. 이 필드가 미리 승인만 하는지 제한도 하는지는 자료마다 설명이 다르고 다른 에이전트는 무시할 수 있어서, 이 스킬에는 아직 적용하지 않았다.
