import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_base_url_stub.dart'
    if (dart.library.html) 'api_base_url_web.dart';

/// 解析 API baseUrl。
/// - Web:取 window.location.hostname(桌面 `localhost` / 手机 `192.168.31.46` 都能命中本机后端)。
/// - Native:优先用 `--dart-define=API_BASE_URL=...` 传进来的值(真机 / 模拟器连 LAN 后端用);
///          都没传才回落到 [defaultUrl](默认 `http://localhost:4001`)。
///
/// 真机跑:
///   flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.31.46:4001
String resolveApiBaseUrl(String defaultUrl) {
  if (kIsWeb) return apiBaseUrlForWeb(defaultUrl);
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine;
  return defaultUrl;
}