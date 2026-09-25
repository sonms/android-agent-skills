# android-agent-skills

Android 개발에서 반복되는 작업을 위한 [Claude Agent Skill](https://docs.claude.com/en/docs/claude-code/skills) 모음. 실제 프로젝트에서 코딩 에이전트를 굴리다가 반복적으로 부딪힌 문제를 추측이 아니라 실제 도구 호출과 실제 파일로 검증하면서 만든 스킬들을 모아둔다.

## Agent Skill이란

Claude Code가 특정 상황(트리거 조건)에서 자동으로 불러오는 절차 문서다. 매번 프롬프트에 규칙을 새로 설명하지 않아도, 에이전트가 상황을 인식하고 정해진 절차·주의사항을 따르게 만든다. 각 스킬은 `SKILL.md`(영문, 트리거·실행 로직)에 해당하는 원본 파일을 갖고, 이 저장소에서는 `<skill-name>.md`로 이름 붙인다.

## 스킬 목록

| 스킬 | 무엇을 하는가 |
|---|---|
| [`html-to-android`](html-to-android) | Figma 디자인 노드 또는 HTML/CSS 프로토타입을 관용적인 Jetpack Compose 코드로 변환. 노드 청킹, 디자인 토큰 매칭, Tailwind→Compose 레이아웃 관용구, OS 목업/반복 리스트 같은 함정 패턴 처리를 다룬다. |
| [`android-to-kmp-migration`](android-to-kmp-migration) | Android 전용 모듈/앱을 Kotlin Multiplatform으로 전환. 어떤 코드가 `commonMain`으로 갈 수 있는지, `expect`/`actual`이 필요한지, Android 전용으로 남아야 하는지 판단하는 절차. 완전 자동 변환이 아니라 판단 지점을 구조화한 체크리스트다. |

각 스킬 폴더의 `README.md`에는 왜 이 스킬이 필요했는지, 무엇을 검토하고 무엇을 버렸는지에 대한 배경과 사고 과정이 한글로 정리되어 있다.

## 저장소 구조

```
<skill-name>/
├── README.md               # 배경, 사고 과정, 설계 근거 (한글, 에이전트에 로드되지 않음)
├── <skill-name>.md          # 실제 SKILL 원본 (영문, 트리거될 때마다 로드됨)
└── <skill-name>.ko.md       # 위 원본의 한글 번역 (사람이 검토용으로 참고, 자동 로드 안 됨)
```

원본(`<skill-name>.md`)을 고치면 번역본(`<skill-name>.ko.md`)도 같이 갱신한다. 번역본은 에이전트에게 직접 로드되지 않는 리뷰용 사본이다.

## 사용법

1. Claude Code에서 이 저장소를 스킬 경로로 인식시킨다 (예: 프로젝트 루트에 두거나 스킬 디렉터리로 심볼릭 링크).
2. 스킬별 사전 조건을 확인한다 — 예를 들어 `html-to-android`는 Figma MCP 커넥터 연결이 필요하다. 자세한 내용은 각 스킬 폴더의 `README.md`를 참고.
3. 트리거 조건에 맞는 요청을 하면(예: Figma 링크를 주며 "Compose로 구현해줘", "이 모듈 KMP로 바꿔줘") 해당 스킬이 자동으로 로드된다.

## 기여

실사용 중 스킬이 커버하지 못하는 패턴을 발견하면, 해당 스킬의 `<skill-name>.md`/`<skill-name>.ko.md`를 함께 갱신하고 PR로 올린다. 새 스킬을 추가할 때도 위 저장소 구조(원본/번역/README) 컨벤션을 따른다.
