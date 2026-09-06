/// 对齐 utils/nav-intent.ts — go_router 不支持向 tabBar 路由传 query,
/// 改用模块级 pendingMonth 单例,首页"查看全部"调用 setPendingMonth 后
/// switchTab,流水页在 onShow 时调 consumePendingMonth 取回并清空。
String? _pendingMonth;
void setPendingMonth(String m) => _pendingMonth = m;
String? consumePendingMonth() {
  final m = _pendingMonth;
  _pendingMonth = null;
  return m;
}
