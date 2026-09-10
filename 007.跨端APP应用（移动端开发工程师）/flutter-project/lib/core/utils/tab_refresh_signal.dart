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

/// 首页"查看全部"跳转流水页时,临时存放首页当前月份。transactions 页
/// 在 initState 里 `ref.listenManual` 读本 provider,读到非空值就覆盖自己
/// 的 `_month` + 触发 reload,然后立刻清空(避免再 fire)。
///
/// ponytail: 之前用 URL `?month=` query 参数 + didChangeDependencies 消费,但
///          `StatefulShellRoute.indexedStack` 让 transactions widget 一直挂着,
///          用户从流水页切回首页换月再点"查看全部"时,didChangeDependencies
///          不会重新 fire,月份就不同步了。Riverpod provider 是全局状态,
///          任意时刻写都能让 listener 收到,与 widget 挂载状态无关 — 每次
///          点击都同步,跟 uniapp monthly.vue 用 Pinia 传 month 同思路。
final pendingTxMonthProvider = StateProvider<String?>((_) => null);
