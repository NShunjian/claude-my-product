// Non-web fallback:直接用 defaultUrl。
// ponytail: 真要 native 跑(Android/iOS 模拟器或真机),把 defaultUrl 改成 10.0.2.2 或 LAN IP。
String apiBaseUrlForWeb(String defaultUrl) => defaultUrl;