---
name: html-to-android (ko)
description: Figma 디자인 노드 또는 HTML/CSS/JS 프로토타입을 관용적인 Jetpack Compose 코드로 변환. 트리거는 영어판(SKILL.md) 기준이며, 이 파일은 사람이 읽는 한글 참고본.
---

# Figma/HTML → Jetpack Compose

입력 두 가지, 파이프라인은 하나: (A) Figma 노드 URL, (B) HTML/CSS/JS 프로토타입. 3~6단계는 두 입력에서 동일하고, 입력을 읽는 단계만 다르다.

## 0. 토큰 확인 (프로젝트당 1회)
`Color.kt`/`Type.kt`/`Dimens.kt` 또는 `build.gradle(.kts)`/`.exfig/`에 exfig 흔적 있음 → 3단계 그대로. 없음 → 소스 값을 바로 코드에 넣고 `// TODO: no project token for <name>` 표시, `exfig-plugins`(`/plugin marketplace add DesignPipe/exfig-plugins`) 설치를 한 번만 권함. 반복 언급 안 함.

## 1. Figma 입력
- `fileKey`/`nodeId` 추출. `node-id` 없으면 추측 금지 — 특정 노드 링크 요청.
- `get_design_context` 호출 시 `skillNames`에 `figma-design-to-code` 반드시 포함(Figma 자체 요구사항).
- sparse 응답 → `forceCode:true` 금지. 스크린샷과 자식 노드ID를 대조해 보이는 자식들을 **한 번에 병렬 배치**로 재호출, 모든 말단 노드에서 실제 코드가 나올 때까지 반복.
- 노드 깊이 애매 → 먼저 `get_metadata`.
- 스크린샷은 시각 대조용, 코드 자산 아님.
- 출력은 이미 해석이 끝난 React+Tailwind(스타일 인라인, 상태는 별도 variant 노드, JS 없음)라 추적 작업 불필요.

## 2. HTML 입력
sparse 가드가 없으니 여러 화면이 든 파일은 쪼개서 화면 하나씩 처리. HTML만으로는 전체 그림이 아니다: 렌더 결과 = HTML + CSS + JS.

1. **소스 수집.** 스타일시트, `<style>`, `@import`, `<script src>`, 인라인 스크립트, `style=`, 인라인 핸들러를 나열. 대상 화면의 셀렉터와 관련된 로컬 파일만 읽고 vendor/minified/CDN 파일은 건너뜀. 없거나 원격인 파일은 내용을 추측하지 말고 그렇다고 밝힌다.
2. **HTML↔CSS.** 각 대상 요소에 매칭되는 모든 규칙을 해석(클래스, id, 결합자, 의사 상태, 미디어쿼리, `:root`까지 이어지는 `var(--x)` 체인). 인라인 `style=`이 우선.
3. **HTML↔JS.** 상호작용/상태가 있는 요소에 대해 훅(`querySelector`, `getElementById`, `data-*`, 위임 리스너)과 이벤트 → 효과(클래스 토글, style/`hidden`/텍스트 변경, 노드 생성/삭제, 이동, fetch)를 기록.
4. **JS↔CSS.** JS가 추가/제거/토글하는 클래스는 해당 CSS 규칙과 연결 — 이건 죽은 코드가 아니라 **상태 변형**(open/selected/active/disabled)이다.
5. **JS 생성 DOM.** `createElement`/템플릿/`innerHTML`로 만들어지는 요소는 HTML에 없다. 생성 함수를 읽어 실제 구조와 데이터 소스를 파악 — 실제 리스트/카드인 경우가 많다.
6. **초기 상태 vs 이후 상태.** 로드 시점 상태(`DOMContentLoaded`/`onload` 초기화 코드 포함)와 상호작용으로 도달하는 상태를 구분해서 기록.

코딩 전에 상호작용/상태가 있는 요소만 대상으로 연결표 출력: `요소 | CSS 규칙 | JS 훅 | 이벤트 → 효과 | 상태`. 짝이 없는 항목(정의 안 된 클래스, 아무것도 안 잡는 셀렉터, 트리거되지 않는 CSS 상태)은 추론으로 메우지 말고 open question으로 나열.

## 3. 토큰 해석 (레이아웃 전)
Figma: named style이 응답에 이미 포함(예: `gray/900: #1E2124`) — 화면마다 `get_variable_defs` 재호출 안 함. HTML: `var(--x)` 체인을 `:root` 값까지 먼저 해석. 어느 쪽이든 이름으로 프로젝트 토큰(0단계)과 매칭해서 사용, 매칭 있는데 하드코딩 금지. 매칭 없음 → TODO 주석, 조용히 새 상수 금지. spacing/radius/아이콘 크기는 대개 Variable이 아니라 raw 숫자라 4단계에서 처리.

## 4. 레이아웃 변환 규칙
Tailwind 클래스와 raw CSS(`position:absolute`, `display:flex`, `gap`, `border-radius`) 모두 같은 Compose 대상으로 변환.

| 패턴 | Compose |
|---|---|
| `absolute inset-0` 딤 + 하단 고정 패널 | 모달/바텀시트 — `ModalBottomSheet` 또는 `Box`+스크림, 좌표 그대로 옮기지 않음 |
| `flex items-center justify-center` | `Row`/`Column` + `Arrangement.Center` / `Alignment.Center*` |
| `-translate-x-1/2 left-1/2` | `Box` 안 `Modifier.align(Alignment.*Center*)` — 좌표 계산 재현 금지 |
| `gap-[N]` (flex column/row) | `Arrangement.spacedBy(N.dp)` |
| `rounded-t[lr]-[N]` | `RoundedCornerShape(topStart/topEnd = N.dp)` |
| `p-[N]` | `Modifier.padding(N.dp)` |
| 고정 width ≈ 화면폭 − 여백×2 | `fillMaxWidth().padding(horizontal = margin.dp)`, 고정값 금지 |
| `I<parentId>;<childId>` 참조 | 인스턴스 override — 컴포저블 파라미터로 매핑, raw 마크업으로 풀지 않음 |
| `data-node-id` | 추적용 주석만, 변수/리소스명 노출 금지 |
| OS 목업 서브트리(`GBoard*`, `*Keyboard*`, `*HomeIndicator*`, 거의 동일한 "키" 수십 개) | **구현 대상 아님** — 런타임에 OS가 그림. 스킵하고 입력만 포커스 가능하게 |
| 같은 이름/구조 반복, 텍스트·데이터만 다름(예: `card_location` × 4) | 고정 개수 아닌 샘플 데이터 — 컴포저블+데이터 클래스 하나, `LazyColumn`/`items()`로 렌더 |

패턴 애매하면 스크린샷 확인, 그래도 애매하면 질문 — 추측 금지.

## 5. 에셋 & 재사용
Figma 에셋 URL은 7일 후 만료 — 완료 전 로컬 다운로드. 기존 아이콘/컴포저블(exfig 산출물/프로젝트) 먼저 확인 후 재사용, Code Connect 매핑 있으면 그대로 사용.

## 6. 검증
스크린샷과 대조(색상/텍스트/굵기/간격). 임시 에셋 URL 잔존 금지, 토큰 있는데 하드코딩 금지. 요청 범위만 건드림. HTML 입력: 2단계 연결표를 다시 훑어 모든 행(JS가 트리거하는 상태, JS가 생성한 요소 포함)이 구현됐거나 open question으로 남았는지 확인.

## 참고
범위: 레이아웃, 스타일, 시각 상태 변형(selected/expanded 등). 비즈니스 로직, ViewModel 연결, 네비게이션, 데이터 fetch는 별도 작업. HTML 경로(2단계)는 아직 실제 파일로 검증되지 않았다. 변경 이력: `references/changelog.ko.md`.
