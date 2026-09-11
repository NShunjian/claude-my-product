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

/// 流水页"上次成功数据"缓存 —— key = month,value = records/categories/accounts。
///
/// ponytail: 用户反馈"切 tab 时别再等 loading"。思路 = stale-while-revalidate:
///          transactions page 在 initState 立即 ref.read 拿上个月份的缓存,
///          命中就直接渲染 + 顶部进度条;同时后台 fire-and-forget _load() 拉新,
///          回来覆盖 provider → UI 自动刷新。首次进来(没有缓存)就走 spinner。
///          Riverpod StateProvider 跨 widget 重建保留,正是 indexedStack 分支
///          切走再切回所需的页面级缓存。
class TxCacheEntry {
  TxCacheEntry({required this.records, required this.categories, required this.accounts});
  final List<dynamic> records;        // List<Record>,用 dynamic 避开跨文件 import 循环
  final List<dynamic> categories;     // List<Category>
  final List<dynamic> accounts;       // List<Account>
}

/// month → 上次成功数据。跨 page 重建保留,切 tab 立刻拿到旧数据渲染。
final txCacheProvider = StateProvider<Map<String, TxCacheEntry>>((_) => {});

/// 全局分类缓存 — categories 改动很少,几乎只在用户手动管理分类时变。
/// 流水页 / 首页 / 报表 / 记账 modal 都消费这一个,首次只拉一次。
///
/// ponytail: 用 AsyncNotifier 比 StateProvider 更合适 —— 暴露 isLoading /
///          error,UI 能渲染骨架/重试按钮。但当前各 page 多数已经用 ref.read
///          .listCategories() 同步拿到 list,改 AsyncNotifier 影响面大。先用
///          最简 StateProvider<List<Category>> + refreshNotifier,各 page 切到
///          ref.watch 后拿 .notifier.refresh() 触发更新。
class CategoriesState {
  CategoriesState({required this.items, required this.bookId});
  final List<dynamic> items; // List<Category>,dynamic 避开 import 循环
  final String bookId;       // 空字符串 = 全局,非空 = 该 bookId 的过滤(暂未启用,全量)
}

/// 全局 categories — bookId 切换 / 分类 CRUD 后需 refresh。
final categoriesStateProvider = StateProvider<CategoriesState>((_) =>
    CategoriesState(items: const [], bookId: ''));

/// 全局 accounts — bookId family(每个账本一组),切账本瞬时换数据。
final accountsStateProvider =
    StateProvider.family<List<dynamic>, String>((_, bookId) => const [],);
