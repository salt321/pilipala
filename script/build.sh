#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PLATFORM="apk"
MODE="release"
RUN_CLEAN=false
RUN_PUB_GET=true
SPLIT_PER_ABI=true
NO_CODESIGN=true
USE_OFFLINE_CACHE=true

# 本机使用 OpenHarmony Flutter 特殊版；仍允许通过 FLUTTER_ROOT 覆盖。
DEFAULT_FLUTTER_ROOT="$HOME/Desktop/flutter_OH/flutter_flutter"
if [[ -z "${FLUTTER_ROOT:-}" && -x "$DEFAULT_FLUTTER_ROOT/bin/flutter" ]]; then
  export FLUTTER_ROOT="$DEFAULT_FLUTTER_ROOT"
fi
if [[ -n "${FLUTTER_ROOT:-}" ]]; then
  export PATH="$FLUTTER_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
fi

if [[ -z "${ANDROID_HOME:-}" && -d "$HOME/Library/Android/sdk" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

# PiliPala 当前使用 Gradle 7.5，构建时需要 JDK 17（不能使用 JDK 21）。
if [[ -z "${JAVA_HOME:-}" ]]; then
  if [[ -d "/Library/Java/JavaVirtualMachines/jdk-17.0.2.jdk/Contents/Home" ]]; then
    export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-17.0.2.jdk/Contents/Home"
  elif [[ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
  fi
fi
if [[ -n "${JAVA_HOME:-}" ]]; then
  export PATH="$JAVA_HOME/bin:$PATH"
  export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.java.home=$JAVA_HOME"
fi

usage() {
  cat <<'EOF'
PiliPala 构建脚本

用法：
  ./script/build.sh [选项]

选项：
  -p, --platform <平台>  apk（默认）、appbundle、ios、macos、web、linux、windows
  -m, --mode <模式>      release（默认）、profile、debug
      --clean            构建前执行 flutter clean
      --skip-pub         跳过 flutter pub get
      --no-split         Android APK 不按 ABI 拆分
      --codesign         iOS 构建启用代码签名
      --online           不使用项目内的 Android/Gradle 离线缓存
  -h, --help             显示帮助

示例：
  ./script/build.sh
  ./script/build.sh --platform apk --mode debug --no-split
  ./script/build.sh --platform appbundle
  ./script/build.sh --platform ios --codesign
EOF
}

fail() {
  echo "错误：$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--platform)
      [[ $# -ge 2 ]] || fail "$1 缺少参数"
      PLATFORM="$2"
      shift 2
      ;;
    -m|--mode)
      [[ $# -ge 2 ]] || fail "$1 缺少参数"
      MODE="$2"
      shift 2
      ;;
    --clean)
      RUN_CLEAN=true
      shift
      ;;
    --skip-pub)
      RUN_PUB_GET=false
      shift
      ;;
    --no-split)
      SPLIT_PER_ABI=false
      shift
      ;;
    --codesign)
      NO_CODESIGN=false
      shift
      ;;
    --online)
      USE_OFFLINE_CACHE=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "未知选项：$1（使用 --help 查看帮助）"
      ;;
  esac
done

case "$PLATFORM" in
  apk|appbundle|ios|macos|web|linux|windows) ;;
  *) fail "不支持的平台：$PLATFORM" ;;
esac

case "$MODE" in
  release|profile|debug) ;;
  *) fail "不支持的构建模式：$MODE" ;;
esac

command -v flutter >/dev/null 2>&1 || fail "未找到 flutter，请先安装 Flutter 并配置 PATH"
[[ -f "$PROJECT_ROOT/pubspec.yaml" ]] || fail "找不到 pubspec.yaml：$PROJECT_ROOT"

cd "$PROJECT_ROOT"

echo "项目目录：$PROJECT_ROOT"
echo "构建目标：$PLATFORM ($MODE)"
echo "Flutter：$(flutter --version | head -n 1)"
echo "Android SDK：${ANDROID_SDK_ROOT:-未设置}"
echo "Java：$(java -version 2>&1 | head -n 1)"

if [[ "$RUN_CLEAN" == true ]]; then
  echo "正在清理旧构建产物……"
  flutter clean
fi

if [[ "$RUN_PUB_GET" == true ]]; then
  echo "正在获取依赖……"
  if [[ "$USE_OFFLINE_CACHE" == true ]]; then
    flutter pub get --offline
  else
    flutter pub get
  fi
fi

# 特殊版 Flutter 配合旧版 Android Gradle Plugin 时，直接注入项目内 Maven
# 缓存与 SDK 自带 AAPT2，避免 Gradle 再访问外网或错误解析 macOS 工具包。
if [[ "$PLATFORM" == "apk" && "$USE_OFFLINE_CACHE" == true ]]; then
  case "$MODE" in
    release) GRADLE_TASK="assembleRelease" ;;
    profile) GRADLE_TASK="assembleProfile" ;;
    debug) GRADLE_TASK="assembleDebug" ;;
  esac

  INIT_SCRIPT="$PROJECT_ROOT/script/gradle-cache-compat.init.gradle"
  [[ -f "$INIT_SCRIPT" ]] || fail "找不到离线缓存配置：$INIT_SCRIPT"

  GRADLE_ARGS=(
    --offline
    --refresh-dependencies
    --init-script "$INIT_SCRIPT"
    -Ptarget-platform=android-arm,android-arm64,android-x64
    -Ptarget=lib/main.dart
    -Pbase-application-name=android.app.Application
    -Pdart-obfuscation=false
    -Ptrack-widget-creation=true
    -Ptree-shake-icons=true
    "-Psplit-per-abi=$SPLIT_PER_ABI"
  )

  AAPT2="${ANDROID_SDK_ROOT:-}/build-tools/35.0.0/aapt2"
  if [[ -x "$AAPT2" ]]; then
    GRADLE_ARGS+=("-Pandroid.aapt2FromMavenOverride=$AAPT2")
  fi

  echo "正在使用项目内缓存执行：android/gradlew $GRADLE_TASK"
  (cd "$PROJECT_ROOT/android" && ./gradlew "${GRADLE_ARGS[@]}" "$GRADLE_TASK")
  echo "构建完成。APK 位于：$PROJECT_ROOT/build/app/outputs/flutter-apk"
  exit 0
fi

BUILD_ARGS=(build "$PLATFORM" "--$MODE")

if [[ "$PLATFORM" == "apk" && "$SPLIT_PER_ABI" == true ]]; then
  BUILD_ARGS+=(--split-per-abi)
fi

if [[ "$PLATFORM" == "ios" && "$NO_CODESIGN" == true ]]; then
  BUILD_ARGS+=(--no-codesign)
fi

echo "正在执行：flutter ${BUILD_ARGS[*]}"
flutter "${BUILD_ARGS[@]}"

echo "构建完成。产物位于：$PROJECT_ROOT/build"
