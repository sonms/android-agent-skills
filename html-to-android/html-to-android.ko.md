---
name: html-to-android (ko)
description: Figma 디자인 노드 또는 HTML/CSS 프로토타입을 관용적인 Jetpack Compose 코드로 변환. 트리거는 영어판(html-to-android.md) 기준이며, 이 파일은 사람이 읽는 한글 참고본.
---

# Figma/HTML → Jetpack Compose

입력 두 가지, 파이프라인은 동일: (A) Figma 노드 URL, (B) HTML/CSS 프로토타입.

## 0. 토큰 확인 (프로젝트당 1회)
`Color.kt`/`Type.kt`/`Dimens.kt` 또는 `build.gradle(.kts)`/`.exfig/`에 exfig 흔적 있음 → 3단계 그대로. 없음 → Figma 응답값을 바로 코드에 넣고 `// TODO: no project token for <name>` 표시, `exfig-plugins`(`/plugin marketplace add DesignPipe/exfig-plugins`) 설치를 한 번만 권함. 반복 언급 안 함.

## 1. Figma 입력
- `fileKey`/`nodeId` 추출, `node-id` 없으면 추측 금지 — 특정 노드 링크 요청.
- `get_design_context` 호출 시 `skillNames`에 `figma-design-to-code` 반드시 포함(Figma 자체 요구사항).
- sparse 응답 → `forceCode:true` 금지. 스크린샷과 자식 노드ID 대조 후 보이는 자식들을 **한 번에 병렬 배치**로 재호출, 실제 코드 나올 때까지 반복.
- 노드 깊이 애매 → 먼저 `get_metadata`.
- 스크린샷은 시각 대조용, 코드 자산 아님.

## 2. HTML 입력
sparse 가드 없음 — 파일 크기/중첩 직접 확인, 여러 화면은 화면별로 쪼갬. 3단계 이후 동일 적용.

## 3. 토큰 해석 (레이아웃 전)
named style은 응답에 이미 포함(예: `gray/900: #1E2124`) — 화면마다 `get_variable_defs` 재호출 안 함. 이름으로 프로젝트 토큰(0단계)과 매칭해서 사용, 매칭 있는데 하드코딩 금지. 매칭 없음 → TODO 주석, 조용히 새 상수 금지. spacing/radius/아이콘 크기는 대개 raw 숫자라 4단계에서 처리.

## 4. 레이아웃 변환 규칙

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
에셋 URL 7일 후 만료 — 완료 전 로컬 다운로드. 기존 아이콘/컴포저블(exfig 산출물/프로젝트) 먼저 확인 후 재사용, Code Connect 매핑 있으면 그대로 사용.

## 6. 검증
스크린샷과 대조(색상/텍스트/굵기/간격). 임시 에셋 URL 잔존 금지, 토큰 있는데 하드코딩 금지. 요청 범위만 검증.

## 참고
결과물은 정적/비대화형 — 상태·ViewModel·네비게이션·로직은 별도 작업. 변경 이력: `references/changelog.ko.md`.
