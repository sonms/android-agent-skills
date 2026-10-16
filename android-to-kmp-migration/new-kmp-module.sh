#!/usr/bin/env bash
# 새 KMP(Kotlin Multiplatform) 모듈 골격을 만든다.
# commonMain/androidMain/iosMain 소스셋 + build.gradle.kts를 생성한다.
# 기존 모듈에 KMP를 끼워넣는 용도가 아니다 — 그건 매번 기존 파일 포맷이 달라
# 안전하게 스크립트화할 수 없으므로 android-to-kmp-migration 스킬 0번 단계에서
# 에이전트가 직접 처리한다. 이 스크립트는 "새 모듈을 하나 만드는" 순수 생성 작업만 한다.
#
# 사용법: 아래 네 변수를 고치고 실행하거나, 인자로 덮어쓴다.
#   인자: <모듈 경로> <패키지명> [AGP 모드: classic|agp9] [androidMain 포함: yes|no]
set -euo pipefail

# ===== 여기를 수정 =====
MODULE_PATH=""               # 저장소 루트 기준 모듈 경로 (예: data/home, feature/discover)
PACKAGE=""                   # 패키지명 (예: com.example.app.data.home)
AGP_MODE="agp9"               # classic(AGP 9 미만) | agp9(AGP 9 이상 — 스킬 0번 표 참고)
INCLUDE_ANDROID_MAIN="yes"    # shared(iOS export 전용) 모듈을 만들 때만 no
# =======================

MODULE_PATH="${1:-$MODULE_PATH}"
PACKAGE="${2:-$PACKAGE}"
AGP_MODE="${3:-$AGP_MODE}"
INCLUDE_ANDROID_MAIN="${4:-$INCLUDE_ANDROID_MAIN}"

if [[ -z "$MODULE_PATH" || -z "$PACKAGE" ]]; then
    echo "MODULE_PATH와 PACKAGE는 필수입니다." >&2
    exit 1
fi

if [[ "$AGP_MODE" != "classic" && "$AGP_MODE" != "agp9" ]]; then
    echo "AGP_MODE는 classic 또는 agp9여야 합니다: $AGP_MODE" >&2
    exit 1
fi

if [[ "$INCLUDE_ANDROID_MAIN" != "yes" && "$INCLUDE_ANDROID_MAIN" != "no" ]]; then
    echo "INCLUDE_ANDROID_MAIN은 yes 또는 no여야 합니다: $INCLUDE_ANDROID_MAIN" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/$MODULE_PATH"

if [[ -e "$TARGET" ]]; then
    echo "이미 존재합니다: $MODULE_PATH" >&2
    exit 1
fi

PKG_DIR="$(tr '.' '/' <<< "$PACKAGE")"

mkdir -p "$TARGET/src/commonMain/kotlin/$PKG_DIR"
mkdir -p "$TARGET/src/iosMain/kotlin/$PKG_DIR"
[[ "$INCLUDE_ANDROID_MAIN" == "yes" ]] && mkdir -p "$TARGET/src/androidMain/kotlin/$PKG_DIR"

# git은 빈 디렉터리를 추적 안 하므로 실제 파일이 생기기 전까지 .gitkeep으로 유지
find "$TARGET/src" -type d -empty -exec touch {}/.gitkeep \;

if [[ "$AGP_MODE" == "agp9" ]]; then
    ANDROID_PLUGIN_LINE='    id("com.android.kotlin.multiplatform.library")'
else
    ANDROID_PLUGIN_LINE='    id("com.android.library")'
fi

ANDROID_SOURCESET=""
if [[ "$INCLUDE_ANDROID_MAIN" == "yes" ]]; then
    ANDROID_SOURCESET='
        androidMain {
            dependencies {
            }
        }'
fi

cat > "$TARGET/build.gradle.kts" << GRADLE_EOF
plugins {
    kotlin("multiplatform")
$ANDROID_PLUGIN_LINE
}

kotlin {
    androidTarget()
    iosX64()
    iosArm64()
    iosSimulatorArm64()

    sourceSets {
        commonMain {
            dependencies {
            }
        }
        iosMain {
            dependencies {
            }
        }$ANDROID_SOURCESET
    }
}

android {
    namespace = "$PACKAGE"
    compileSdk = 36 // android-to-kmp-migration 스킬 0번 표 기준 — 실제 적용 시 현재 AGP 릴리스 노트로 재확인
}
GRADLE_EOF

echo "생성 완료: $MODULE_PATH"
echo "  패키지              : $PACKAGE"
echo "  AGP 모드            : $AGP_MODE"
echo "  androidMain 포함    : $INCLUDE_ANDROID_MAIN"
echo
echo "다음 단계 (자동으로 안 한 것들 — 프로젝트마다 기존 포맷이 달라 수동 확인 필요):"
echo "  1. settings.gradle.kts에 직접 추가: include(\":${MODULE_PATH//\//:}\")"
echo "  2. Gradle sync"
echo "  3. 스킬 1번(진단) 절차로 기존 코드를 분류해서 이 모듈로 옮기기 시작"
