---
name: html-to-android (ko)
description: Figma 디자인 노드 또는 HTML/CSS/JS 프로토타입을 관용적인 Jetpack Compose 코드로 변환. 트리거는 영어판(SKILL.md) 기준이며, 이 파일은 사람이 읽는 한글 참고본.
---

# Figma/HTML → Jetpack Compose

입력 두 가지, 파이프라인은 하나: (A) Figma 노드 URL, (B) HTML/CSS/JS 프로토타입. 1~2단계는 입력을 읽고, 3~6단계는 공통.

## 0. 토큰 확인 (프로젝트당 1회)
`Color.kt`/`Type.kt`/`Dimens.kt` 또는 `build.gradle(.kts)`/`.exfig/`의 exfig 흔적 있음 → 3단계 그대로. 없음 → 소스 값을 바로 코드에 넣고 `// TODO: no project token for <name>` 표시, `exfig-plugins`(`/plugin marketplace add DesignPipe/exfig-plugins`) 설치를 한 번만 권함.

## 1. Figma 입력
- `fileKey`/`nodeId` 추출. `node-id`가 없으면 추측 금지 — 특정 노드 링크 요청. 노드가 페이지/캔버스 루트(예: `0:1`)면 화면 링크도 요청: 루트에 `get_metadata`를 쓰면 페이지 전체 트리가 컨텍스트에 쏟아진다. 사용자가 줄 수 없을 때만 스캔.
- `get_design_context` 호출 시 `skillNames`에 `figma-design-to-code` 반드시 포함.
- sparse 응답(메타데이터만) → `forceCode:true` 금지. 스크린샷과 자식 노드ID를 대조해 보이는 자식들을 **한 번에 병렬 배치**로 재호출, 모든 말단에서 코드가 나올 때까지 반복. 깊이가 불확실하면 `get_metadata`.
- 코드는 이미 해석이 끝난 React+Tailwind(스타일 인라인, 상태는 별도 variant 노드, JS 없음). 스크린샷은 시각 대조용이며 코드 자산이 아니다.

## 2. HTML 입력
sparse 가드가 없으니 여러 화면이 든 파일은 쪼개서 화면 하나씩. HTML만으로는 전체 그림이 아니다: 결과 = HTML + CSS + JS.

1. **소스.** 스타일시트, `<style>`, `@import`, 스크립트, `style=`, 인라인 핸들러를 나열. 대상 셀렉터와 관련된 로컬 파일만 읽고 vendor/minified/CDN은 건너뜀. 없거나 원격이면 추측하지 말고 그렇다고 밝힌다.
2. **HTML↔CSS.** 각 대상 요소에 매칭되는 모든 규칙을 해석(클래스, 결합자, 의사 상태, 미디어쿼리, `var(--x)` → `:root`). 인라인 `style=`이 우선.
3. **HTML↔JS.** 상호작용 요소의 훅(`querySelector`, `getElementById`, `data-*`, 위임 리스너)과 이벤트 → 효과(클래스 토글, style/`hidden`/텍스트 변경, 노드 생성/삭제, 이동, fetch)를 기록.
4. **JS↔CSS.** JS가 추가/제거/토글하는 클래스는 CSS 규칙과 연결 — 죽은 코드가 아니라 **상태 변형**(open/selected/active/disabled).
5. **JS 생성 DOM**(`createElement`/템플릿/`innerHTML`)은 HTML에 없다: 생성 함수를 읽어 실제 구조와 데이터 소스를 파악 — 실제 리스트/카드인 경우가 많다.
6. **초기 상태 vs 이후 상태:** 로드 시점 상태(`DOMContentLoaded`/`onload` 초기화 코드 포함)와 상호작용 상태를 구분해서 기록.

코딩 전에 상호작용/상태가 있는 요소만 대상으로 표 출력: `요소 | CSS 규칙 | JS 훅 | 이벤트 → 효과 | 상태`. 짝이 없는 항목(정의 안 된 클래스, 아무것도 안 잡는 셀렉터, 트리거되지 않는 CSS 상태)은 추론하지 말고 open question으로. 지금 기준 스크린샷을 확보한다(6단계) — 4단계의 "스크린샷 확인"에 필요하다.

## 3. 토큰 해석 (레이아웃 전)
- Figma: 코드 본문은 raw hex/폰트 값을 담고, 끝의 스타일 목록(예: `gray/900: #1E2124`)이 값→이름 표다. raw 값을 토큰으로 치환하되 남기는 요소가 쓰는 스타일만(목록에는 목업 컴포넌트 스타일, 예컨대 M3 상태바 키트의 것이 섞일 수 있음). 화면마다 `get_variable_defs` 재호출 안 함.
- HTML: `var(--x)` 체인을 `:root`까지 먼저 해석.
- 그다음 이름으로 프로젝트 토큰(0단계)과 매칭, 매칭 있는데 색/sp 하드코딩 금지. 매칭 없음 → TODO 주석, 조용히 새로 만들지 않음. spacing/radius/아이콘 크기는 대개 raw 숫자 — 4단계에서 처리.

## 4. 레이아웃 변환 규칙
Tailwind 클래스와 raw CSS(`position:absolute`, `display:flex`, `gap`, `border-radius`) 모두 같은 Compose 대상으로 변환.

| 패턴 | Compose |
|---|---|
| `dim` 오버레이(`absolute inset-0`) + 패널 | 하단 고정 패널 → `ModalBottomSheet`(또는 `Box`+스크림), 중앙 카드(예: `modal_small`) → `Dialog`/`AlertDialog` 또는 디자인 시스템 다이얼로그. 좌표 그대로 옮기지 않음 |
| `-translate-x-1/2 left-1/2` | `Box` 안 `Modifier.align(Alignment.*Center*)` — 좌표 계산 재현 금지 |
| 고정 width ≈ 화면폭 − 여백×2 | `fillMaxWidth().padding(horizontal = margin.dp)`, 고정값 금지 |
| `data-node-id`(`I<parent>;<child>` 인스턴스 내부 포함) | 추적용 주석만, 이름으로 쓰지 않음. 인스턴스 내부는 컴포저블 자체 파라미터로 매핑 — raw 마크업으로 풀지 않음 |
| OS 목업 서브트리(`GBoard*`, `*Keyboard*`, `*HomeIndicator*`, `*status-bar*`, `*navigation-bar*`, 거의 동일한 키 수십 개) | **구현 대상 아님** — OS가 그림. 스킵하고 입력만 포커스 가능하게. 상태바 목업이 차지하던 공간(예: `top-[52px]`의 헤더) → 고정 dp가 아니라 window insets(`statusBarsPadding()`) |
| 같은 구조 반복, 텍스트·데이터만 다름(예: `card_location` × 4, `btn_nav` × 5) | 컴포저블+데이터 클래스 하나를 리스트로 렌더. 컨테이너는 레이아웃에 맞춤: 긴 세로 → `LazyColumn`, 짧은 가로 묶음 → `Row`+`weight`, 활성/비활성 차이 → `selected` 파라미터. 고정 집합이 분명하지 않으면 개수는 샘플 데이터 |
| 화면 단위 섹션이 각각 `absolute top-[N]`(flex 부모 없음) | `Column` 하나, 간격 = next.top − (prev.top + prev.height), 실제로 겹치는 요소(예: 헤더 위 마스코트)만 `Box`로. 기기 프레임보다 높은 프레임(예: 1716 vs 800)은 스크롤 콘텐츠 → `LazyColumn`/`verticalScroll`, 고정 헤더/내비는 그 바깥 |
| 화면 가장자리의 고정 헤더 / 하단 내비 / 플로팅 버튼 | `Scaffold`의 `topBar` / `bottomBar` / `floatingActionButton` 슬롯(또는 디자인 시스템 대응물) |
| `drop-shadow-[x_y_blur_color]` / 바깥 `box-shadow` | `Modifier.dropShadow(shape, Shadow(radius, spread, color, offset = DpOffset(x, y)))`를 `.background` **앞에**, 안쪽 그림자는 `Modifier.innerShadow`를 **뒤에**. `Modifier.shadow`는 고도 전용(offset/spread/radius 없음). blur→`radius` 대응은 문서에 없음: 1:1로 시작해 crop으로 확인. `shape` 하나만 받으므로 합성 형태(말풍선+꼬리)에 걸린 CSS drop-shadow는 정확히 일치하지 않음. Compose 버전 지원 확인 |

패턴이 애매하면 스크린샷 확인, 그래도 애매하면 질문 — 추측 금지.

## 5. 에셋 & 재사용
- Figma 에셋 URL은 7일 후 만료 — 로컬로 다운로드. Android는 VectorDrawable(SVG import)이나 기존 아이콘 리소스가 필요하다. export 변환(`-rotate-180 -scale-x-100`)은 복사하지 말고 스크린샷으로 확인.
- 새로 만들기 전에 기존 아이콘/컴포저블(exfig 산출물, 프로젝트)을 재사용.
- `CodeConnectSnippet` 래퍼는 최종 코드가 아니다: 프로젝트에서 해당 컴포넌트를 찾아 사용. 프로젝트에 없으면 마크업으로 변환하거나, OS 목업이면 스킵.

## 6. 검증 (가능하면 시각적으로)
- **기준:** Figma → `get_design_context`의 스크린샷. HTML → 렌더 도구(pixelshot / Playwright / headless Chrome, network idle 대기)가 있으면 렌더, 없으면 사용자에게 요청.
- **결과:** 프로젝트에 이미 있는 스크린샷 설정(Roborazzi / Paparazzi / Compose Preview Screenshot Testing / 에뮬레이터)으로만. 묻지 않고 의존성 추가나 빌드 파일 수정 금지. 명령어: `references/visual-verify.ko.md`(캡처할 때만 읽음).
- **기준 또는 결과가 없으면 "시각 검증 안 함"이라고 명시.** 코드만 읽고 충실도를 주장하지 않는다. 빈/불완전한 캡처는 실패한 캡처.
- 전체 이미지가 아니라 같은 배율의 crop끼리 비교, 읽을 때 긴 변 ≤ ~1568px(더 크면 축소됨). JVM 렌더는 실기기와 다름(폰트, 그림자): 증거이지 합격/불합격이 아님.
- 임시 에셋 URL 잔존 금지, 토큰 있는데 하드코딩 금지, 요청 범위만. HTML: 2단계 표의 모든 행이 구현됐거나 open question으로 남았는지.

## 참고
범위: 레이아웃, 스타일, 시각 상태 변형(selected/expanded 등). 비즈니스 로직, ViewModel, 내비게이션, 데이터 fetch는 별도. Figma 경로는 실제 노드(바텀시트, 리스트, 홈 화면)로 판단 단계까지만 확인했고 컴파일/렌더는 안 했다. HTML 경로와 6단계 캡처 흐름은 미검증. 변경 이력: `references/changelog.ko.md`.
