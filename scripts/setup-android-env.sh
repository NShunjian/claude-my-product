#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# 007 Flutter Android 模拟器 / 真机 环境一键脚本
#
# 干什么:
#   1. NDK r28c (28.2.13676358) 装到 $ANDROID_HOME/ndk/  (从腾讯云镜像拉)
#   2. ~/.gradle/init.d/aliyun-mirror.gradle   全局 repo 镜像
#   3. ~/.gradle/gradle.properties             并发 / 超时
#
# 用法:
#   bash scripts/setup-android-env.sh
#
# 幂等:每个步骤都先检"是否已经做好",做好就跳过。可以重复跑。
# ----------------------------------------------------------------------------
set -e

NDK_VER="28.2.13676358"
NDK_DIR="${ANDROID_HOME:-$HOME/Library/Android/sdk}/ndk/$NDK_VER"
NDK_ZIP="/tmp/android-ndk-r28c-darwin.zip"
NDK_MIRROR="https://mirrors.cloud.tencent.com/AndroidSDK/android-ndk-r28c-darwin.zip"

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
blue()  { printf "\033[34m%s\033[0m\n" "$*"; }

# ---------- 1. NDK ----------
blue "[1/3] 检查 NDK r28c ..."
if [ -f "$NDK_DIR/source.properties" ]; then
  green "  ✓ 已装好,跳过"
else
  echo "  本地没装,准备从腾讯云镜像下载(908MB)"
  if [ ! -f "$NDK_ZIP" ]; then
    curl -L --fail -o "$NDK_ZIP" "$NDK_MIRROR"
  fi
  rm -rf "$NDK_DIR" /tmp/android-ndk-r28c
  unzip -q "$NDK_ZIP" -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}/ndk/"
  mv "${ANDROID_HOME:-$HOME/Library/Android/sdk}/ndk/android-ndk-r28c" "$NDK_DIR"
  rm -f "$NDK_ZIP"
  green "  ✓ NDK 装好 → $NDK_DIR"
fi

# ---------- 2. gradle 仓库镜像 ----------
blue "[2/3] 配置 ~/.gradle/init.d/aliyun-mirror.gradle ..."
mkdir -p ~/.gradle/init.d
cat > ~/.gradle/init.d/aliyun-mirror.gradle <<'GRADLE'
def aliyunPublic       = 'https://maven.aliyun.com/repository/public'
def aliyunGoogle       = 'https://maven.aliyun.com/repository/google'
def aliyunGradlePlugin = 'https://maven.aliyun.com/repository/gradle-plugin'
def rewrite = { repo ->
    if (repo instanceof org.gradle.api.artifacts.repositories.MavenArtifactRepository) {
        def url = repo.url.toString()
        if (url.contains('repo.maven.apache.org') || url.contains('repo1.maven.org')) {
            repo.url = uri(aliyunPublic)
        } else if (url.contains('dl.google.com/dl/android/maven2') || url.contains('maven.google.com')) {
            repo.url = uri(aliyunGoogle)
        } else if (url.contains('plugins.gradle.org')) {
            repo.url = uri(aliyunGradlePlugin)
        }
    }
}
allprojects {
    buildscript.repositories.all(rewrite)
    repositories.all(rewrite)
}
settingsEvaluated { settings ->
    settings.pluginManagement.repositories.all(rewrite)
    if (settings.respondsTo('dependencyResolutionManagement')) {
        settings.dependencyResolutionManagement.repositories.all(rewrite)
    }
}
GRADLE
green "  ✓ 镜像脚本已写入"

# ---------- 3. gradle.properties ----------
blue "[3/3] 配置 ~/.gradle/gradle.properties ..."
if grep -q "org.gradle.parallel" ~/.gradle/gradle.properties 2>/dev/null; then
  green "  ✓ 已存在配置,跳过"
else
  cat >> ~/.gradle/gradle.properties <<'PROPS'

# 国内网络环境优化
org.gradle.parallel=true
org.gradle.workers.max=4
systemProp.http.connectionTimeout=60000
systemProp.https.connectionTimeout=60000
PROPS
  green "  ✓ 已写入"
fi

echo ""
green "环境就绪。下一步:"
echo "  cd 007.跨端APP应用（移动端开发工程师）/flutter-project"
echo "  /Users/apple/flutter/bin/flutter devices            # 看模拟器在不在"
echo "  /Users/apple/flutter/bin/flutter run -d emulator-5554 \\"
echo "      --dart-define=API_BASE_URL=http://10.0.2.2:4001"
