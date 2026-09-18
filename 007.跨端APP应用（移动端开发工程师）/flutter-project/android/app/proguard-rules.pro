# Flutter / Riverpod / Dio 不需要自定义 keep 规则,
# 默认 proguard-android-optimize.txt 已正确处理。
# 后续若有第三方 SDK 反射调用 Crash,在此加:
#   -keep class xxx { *; }
# ponytail: 此文件存在只是为了满足 buildTypes.release.proguardFiles 引用。