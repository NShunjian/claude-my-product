import 'dart:html' as html;

/// Web:把 defaultUrl 的 host 换成当前页面的 hostname,保留 scheme + port 4001。
/// 桌面 `localhost:5180` → `localhost:4001`;手机 `192.168.31.46:5180` → `192.168.31.46:4001`。
String apiBaseUrlForWeb(String defaultUrl) {
  try {
    final host = html.window.location.hostname;
    if (host == null || host.isEmpty) return defaultUrl;
    final uri = Uri.parse(defaultUrl);
    return uri.replace(host: host, port: 4001).toString();
  } catch (_) {
    // js-interop / 测试环境下没 window.location 时,退回 defaultUrl。
    return defaultUrl;
  }
}