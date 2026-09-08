import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_base_url_stub.dart'
    if (dart.library.html) 'api_base_url_web.dart';

/// 解析 API baseUrl。
/// - Web:取 window.location.hostname(桌面 `localhost` / 手机 `192.168.31.46` 都能命中本机后端)。
/// - Native:用 [defaultUrl](默认 `http://localhost:4001`,Android 模拟器请改成 10.0.2.2)。
String resolveApiBaseUrl(String defaultUrl) {
  if (kIsWeb) return apiBaseUrlForWeb(defaultUrl);
  return defaultUrl;
}