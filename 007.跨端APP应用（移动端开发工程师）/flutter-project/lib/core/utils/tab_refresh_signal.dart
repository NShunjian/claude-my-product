import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 每个 tab 一个递增计数器。tab 切换时 `_TabScaffold.onDestinationSelected`
/// 把对应 index 的计数器 +1,页面在 initState 里 `ref.listenManual` 自己
/// index 的 provider,`next > prev` 时调用 `_load()`。
///
/// ponytail: 初始值 0,首页 initState 第一次触发也会收到回调(prev=null 跳过),
/// 不会无意义重拉。
///
/// 索引对齐 StatefulShellRoute branches:
/// 0=home,1=transactions,2=reports,3=accounts,4=settings。
final tabRefreshSignalProvider = StateProvider.family<int, int>((_, tabIndex) => 0);
