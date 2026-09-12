import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/records_api.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../../core/utils/tab_refresh_signal.dart';
import '../shared/app_header.dart';
import '../shared/bottom_sheet_route.dart';
import '../shared/mobile_error_state.dart';
import '../shared/month_picker.dart';
import '../shared/providers.dart';
import '../shared/pull_to_refresh.dart';
import '../shared/quick_add_controller.dart';
import '../shared/skeleton_shimmer.dart';
import '../shared/toast_controller.dart';
import '../shared/transaction_row.dart';

/// 对齐 pages/liushui/index.vue — AppHeader + 筛选(月/分类/账户) +
/// 当月结余 summary card + 日组流水列表。
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late Future<_TxData> _future;
  // ponytail: stale-while-revalidate — _data 保留最后一次成功数据,build 永远
  //          用 _data 渲染(直到下次 _load 完成)。但 page 重建(initState 重跑)
  //          时 _data 默认 null,会闪一次 loading —— 所以下面 initState 从
  //          txCacheProvider 拿历史缓存立刻填上,首次进来也有数据可显示。
  _TxData? _data;
  String _month = formatLocalMonth(DateTime.now());
  String _categoryId = 'all'; // 'all' = 所有分类
  String _accountId = 'all'; // 'all' = 所有账户

  @override
  void initState() {
    super.initState();
    // ponytail: 首页"查看全部"在 navigation 之前已经把月份写进 pendingTxMonthProvider,
    //          但 StatefulShellRoute.indexedStack 是按需构建分支 — transactions
    //          widget 直到导航到该 tab 才挂载,此时 provider 已经是目标值。
    //          ref.listenManual 不会为初始值 fire(只 fire state change),所以
    //          必须显式 ref.read 读一次,确保"首次进入"也同步。listenManual
    //          留着负责"已挂载后用户再点 View All"的同步。
    final pendingMonth = ref.read(pendingTxMonthProvider);
    if (pendingMonth != null && pendingMonth.isNotEmpty) {
      _month = pendingMonth;
      // ponytail: 清 provider 不能在 initState 里直接做 — Riverpod 禁止在
      //          build/initState/dispose 等生命周期里修改 provider,会抛
      //          "Tried to modify a provider while the widget tree was building"。
      //          丢到 Future 里等当前 build 完成后异步清。
      Future(() {
        if (!mounted) return;
        ref.read(pendingTxMonthProvider.notifier).state = null;
      });
    }
    // ponytail: 用 txCacheProvider 历史缓存立刻填 _data,切 tab 时直接渲染旧数据,
    //          不闪 spinner。命中失败才走 _load 等待。Riverpod StateProvider 跨
    //          page 重建保留(IndexedStack 切走分支 widget 不销毁,保险用)。
    final cached = ref.read(txCacheProvider)[_month];
    if (cached != null) {
      _data = _TxData(
        records: cached.records.cast<Record>(),
        categories: cached.categories.cast<Category>(),
        accounts: cached.accounts.cast<Account>(),
      );
    }
    _future = _load();
    // 监听 quickAdd 保存 + 弹窗关闭,任一发生都触发流水页重拉。
    // 跟 home_screen 一致 — 详见那边注释。
    ref.listenManual<QuickAddState>(quickAddControllerProvider, (prev, next) {
      if (prev != null &&
          (next.savedAt != prev.savedAt || (prev.show && !next.show))) {
        // Future 必须先算出再传进 setState — 用箭头 () => _future = _load()
        // 会让 setState 收到 Future 返回值而抛错。
        final f = _load();
        setState(() {
          _future = f;
        });
      }
    });
    // ponytail: 切到 transactions tab 时重拉。next>prev 才触发,初始 0 不触发空拉;
    //          月份已切的视图仍走 _onMonthChanged。
    ref.listenManual<int>(tabRefreshSignalProvider(1), (prev, next) {
      if (prev != null && next > prev) {
        final f = _load();
        setState(() {
          _future = f;
        });
      }
    });
    // ponytail: 监听后续 state change — 已挂载的 transactions 在用户从流水页切
    //          回首页换月再点"查看全部"时也能收到(URL ?month= 做不到)。
    //          与 initState 上方的 ref.read 配合,完整覆盖"首次进入 + 后续点击"。
    //          这里的 state = null 在 listener 回调里执行,不在 build 生命周期,
    //          Riverpod 允许(回调是异步触发的,不在 build 阶段)。
    ref.listenManual<String?>(pendingTxMonthProvider, (prev, next) {
      if (next != null && next.isNotEmpty && next != _month) {
        setState(() {
          _month = next;
          _future = _load();
        });
        ref.read(pendingTxMonthProvider.notifier).state = null;
      }
    });
  }

  Future<_TxData> _load() async {
    final bookId = ref.read(currentBookIdProvider);
    // ponytail: categories/accounts 走全局 provider(categoriesStateProvider +
    //          accountsStateProvider),这里只 await records。categories/accounts
    //          通常比 records 早回来,首次进来 records 还在拉时它们已就位,
    //          _data 用本地全局状态填好,records 完事覆盖整段 _data,UI 平滑刷新。
    final records = await ref.read(recordsApiProvider).listRecords(
          q: RecordsQuery(
            month: _month,
            bookId: bookId.isEmpty ? null : bookId,
          ),
        );
    records.sort((a, b) {
      final byDate = b.recordDate.compareTo(a.recordDate);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    final categories = _readCategories();
    final accounts = _readAccounts(bookId);
    // ponytail: 把成功数据回写 txCacheProvider,下次切回 transactions tab 时
    //          initState 立刻命中,不等 _load。
    final cache = Map<String, TxCacheEntry>.from(ref.read(txCacheProvider));
    cache[_month] = TxCacheEntry(
      records: records,
      categories: categories,
      accounts: accounts,
    );
    ref.read(txCacheProvider.notifier).state = cache;
    return _TxData(records: records, categories: categories, accounts: accounts);
  }

  /// 从全局 categoriesStateProvider 读 categories;为空则同步 fire-and-forget
  /// 触发拉取,后续 initState 也能感知(provider watch 重建)。
  List<Category> _readCategories() {
    final state = ref.read(categoriesStateProvider);
    if (state.items.isEmpty) {
      // fire-and-forget: 不 await,首次 _load 不阻塞等它
      _kickCategoriesRefresh();
      return const [];
    }
    return state.items.cast<Category>();
  }

  Future<void> _kickCategoriesRefresh() async {
    try {
      final cats = await ref.read(categoriesApiProvider).listCategories();
      ref.read(categoriesStateProvider.notifier).state = CategoriesState(
        items: cats,
        bookId: '',
      );
      // ponytail: 写回后重建 _data 让 transactions 页面刷新。判断当前 _data
      //          是首条 records 已就位但 categories 为空的情况,合并更新。
      if (mounted && _data != null) {
        setState(() {
          _data = _TxData(
            records: _data!.records,
            categories: cats,
            accounts: _data!.accounts,
          );
        });
      }
    } catch (_) { /* 容忍 — 后续 reload 会再拉 */ }
  }

  List<Account> _readAccounts(String bookId) {
    final list = ref.read(accountsStateProvider(bookId));
    if (list.isEmpty) {
      _kickAccountsRefresh(bookId);
      return const [];
    }
    return list.cast<Account>();
  }

  Future<void> _kickAccountsRefresh(String bookId) async {
    try {
      final accs = await ref.read(accountsApiProvider).listAccounts(
            bookId: bookId.isEmpty ? null : bookId,
          );
      ref.read(accountsStateProvider(bookId).notifier).state = accs;
      if (mounted && _data != null) {
        setState(() {
          _data = _TxData(
            records: _data!.records,
            categories: _data!.categories,
            accounts: accs,
          );
        });
      }
    } catch (_) { /* 容忍 */ }
  }

  void _onMonthChanged(String m) {
    if (m == _month) return;
    setState(() {
      _month = m;
      // ponytail: 切月份时也尝试命中缓存,跨月份切换也不闪 loading。
      final cached = ref.read(txCacheProvider)[m];
      _data = cached == null
          ? null
          : _TxData(
              records: cached.records.cast<Record>(),
              categories: cached.categories.cast<Category>(),
              accounts: cached.accounts.cast<Account>(),
            );
      _future = _load();
    });
  }

  void _onFilterChanged() {
    // 切分类/账户只触发 UI 重渲染过滤后数据,不再打后端 — 跟 uniapp 一致。
    setState(() {});
  }

  Future<void> _confirmDelete(Record r) async {
    final lang = I18n.of(context);
    // 对齐 uniapp pages/transactions/index.vue remove() —
    // uni.showModal({ title:'common.confirm', content:'transactions.deleteConfirm',
    //                  success: ... }) → 成功后 records.value.filter(...) +
    //                  toast.show('common.delete OK'),catch (e) → toast.show。
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('common.confirm')),
        content: Text(lang.t('transactions.deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(lang.t('common.confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(recordsApiProvider).deleteRecord(r.id);
      if (!mounted) return;
      final f = _load();
      setState(() {
        _future = f;
      });
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('common.delete')} OK',
          );
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            e.toString().isNotEmpty
                ? e.toString()
                : lang.t('common.error'),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Scaffold(
      // ponytail: 流水页 Scaffold 底色用 surface(浅灰 0xFFF5F5F5),配合
      //          ListView 尾部 SizedBox(80),让"白卡片 + 灰页底"形成视觉
      //          层次,消除卡片下方"一大段空白"错觉(同 home/accounts)。
      backgroundColor: c.surface,
      appBar: AppHeader(title: lang.t('pageTitle.transactions')),
      body: FutureBuilder<_TxData>(
        future: _future,
        builder: (context, snap) {
          // 同步新数据到 _data(引用相等即停止更新,避免重复 setState)。
          if (snap.hasData && !identical(snap.data, _data)) {
            _data = snap.data;
          }
          // 首次加载还没数据 → 骨架屏(filter/balance/list 占位灰块)。
          // 用户反馈 "切换页面时不要空白等 loading" —— 骨架让 UI 立刻出现,
          // 视觉上等同 "立即渲染",数据回来平滑替换。
          if (_data == null) {
            if (snap.hasError) {
              // ponytail: 2026-09-12 — mobile 端失败走友好 UI(icon +
              //          文案 + 重试按钮),不再裸 Dio 文本;web 端保留原
              //          红字(用户跨端策略:web 端不动)。
              return kIsWeb
                  ? Center(
                      child: Text(
                        '${lang.t('transactions.loadErrorPrefix')}${snap.error}',
                        style: TextStyle(color: c.error),
                      ),
                    )
                  : MobileErrorState(
                      errorKey: 'transactions.loadErrorPrefix',
                      retryKey: 'common.retry',
                      onRetry: () {
                        // ponytail: 块体闭包,不能写 `() => _future = _load()`
                        //          —— 箭头函数返回 Future,setState debug 模式
                        //          assert throw,UI 不刷新。
                        setState(() {
                          _future = _load();
                        });
                      },
                    );
            }
            return _TransactionsSkeleton();
          }
          final data = _data!;
          final isReloading = snap.connectionState != ConnectionState.done;
          // 客户端按 categoryId / accountId 过滤 — 跟 uniapp filteredRecords 对齐。
          final filtered = data.records.where((r) {
            if (_categoryId != 'all' && r.categoryId != _categoryId) {
              return false;
            }
            if (_accountId != 'all' && r.accountId != _accountId) {
              return false;
            }
            return true;
          }).toList();
          final monthIncome = filtered
              .where((r) => r.type == RecordType.income)
              .fold<double>(0, (s, r) => s + r.amount);
          final monthExpense = filtered
              .where((r) => r.type == RecordType.expense)
              .fold<double>(0, (s, r) => s + r.amount);
          final monthNet = monthIncome - monthExpense;
          final groups = _groupByDate(filtered);

          return Column(
            children: [
              // ponytail: 重载中(切 tab / quickAdd save / 手动下拉)显示顶部进度条,
              //          已有 _data 仍渲染,避免闪 loading。首次没数据时 _data==null
              //          上面已经早 return,这里 isReloading 一定有 _data 可显示。
              if (isReloading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Color(0x00000000),
                ),
              Expanded(
                // ponytail: 2026-09-12 — PullToRefresh 替代 RefreshIndicator,
                //          阈值 100px,避免轻微过冲触发刷新圈。
                child: PullToRefresh(
                  threshold: 100,
                  onRefresh: () async {
                    final f = _load();
                    // ponytail: 块体闭包,不能写 `() => _future = f` — 箭头函
                    //          数返回 Future f,setState debug 模式 assert
                    //          throw,markNeedsBuild 永远不被调用,UI 不刷新。
                    setState(() {
                      _future = f;
                    });
                    await f;
                  },
                  child: ListView(
                    // uniapp .scroll-area { padding: 0 24rpx 24rpx } → 12dp
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    children: [
                // uniapp .filter-row { display:column; gap:16rpx; margin-top:20rpx }
                _FilterCard(
                  ref: ref,
                  month: _month,
                  onMonthChanged: _onMonthChanged,
                  categoryId: _categoryId,
                  onCategoryChanged: (id) {
                    _categoryId = id;
                    _onFilterChanged();
                  },
                  accountId: _accountId,
                  onAccountChanged: (id) {
                    _accountId = id;
                    _onFilterChanged();
                  },
                  categories: data.categories,
                  accounts: data.accounts,
                ),
                // uniapp .filter-row { gap:16rpx } → 8dp
                const SizedBox(height: 8),
                _BalanceCard(
                  net: monthNet,
                  income: monthIncome,
                  expense: monthExpense,
                ),
                const SizedBox(height: 8),
                _ListCard(
                  groups: groups,
                  categories: data.categories,
                  accounts: data.accounts,
                  onDelete: _confirmDelete,
                  empty: filtered.isEmpty,
              ),
                      // ponytail: 2026-09-11 对齐 reports/settings,去掉 80pt
                      //          视觉缓冲 — 5 页 ListView 底部都贴 nav bar 上沿。
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TxData {
  _TxData({
    required this.records,
    required this.categories,
    required this.accounts,
  });
  final List<Record> records;
  final List<Category> categories;
  final List<Account> accounts;
}

/// 按 recordDate 分组 + 计算当日净额(income - expense)。
List<_DayGroup> _groupByDate(List<Record> records) {
  final map = <String, List<Record>>{};
  for (final r in records) {
    map.putIfAbsent(r.recordDate, () => []).add(r);
  }
  return map.entries
      .map(
        (e) => _DayGroup(
          date: e.key,
          records: e.value,
          net: e.value.fold<double>(
            0,
            (s, r) => s + (r.type == RecordType.income ? r.amount : -r.amount),
          ),
        ),
      )
      .toList();
}

class _DayGroup {
  _DayGroup({required this.date, required this.records, required this.net});
  final String date; // YYYY-MM-DD
  final List<Record> records;
  final double net;
}

/// 对齐 uniapp formatDayHeaderCN: "M月D日, 星期X"。
String _formatDayHeader(String ymd, Lang lang) {
  try {
    final d = DateTime.parse(ymd);
    final wd = weekdayLabel(
      d,
      labelOf: (i) {
        switch (i) {
          case 0:
            return lang.t('transactions.weekdaySun');
          case 1:
            return lang.t('transactions.weekdayMon');
          case 2:
            return lang.t('transactions.weekdayTue');
          case 3:
            return lang.t('transactions.weekdayWed');
          case 4:
            return lang.t('transactions.weekdayThu');
          case 5:
            return lang.t('transactions.weekdayFri');
          case 6:
            return lang.t('transactions.weekdaySat');
          default:
            return '';
        }
      },
    );
    return '${d.month}月${d.day}日,$wd';
  } catch (_) {
    return ymd;
  }
}

/// 筛选卡:对齐 uniapp .filter-card(title + 3 个 select-box)。
class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.ref,
    required this.month,
    required this.onMonthChanged,
    required this.categoryId,
    required this.onCategoryChanged,
    required this.accountId,
    required this.onAccountChanged,
    required this.categories,
    required this.accounts,
  });

  // ponytail: 传 ref 进来,让 _pickCategory/_pickAccount 能切换 modalOpenProvider
  //          → _TabScaffold 隐藏底部 tabBar → picker 自然覆盖整个底部区域。
  final WidgetRef ref;
  final String month;
  final ValueChanged<String> onMonthChanged;
  final String categoryId;
  final ValueChanged<String> onCategoryChanged;
  final String accountId;
  final ValueChanged<String> onAccountChanged;
  final List<Category> categories;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      // uniapp .filter-card { padding:24rpx; radius:16rpx; border 1px } → 12dp 8dp
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // uniapp .filter-title { font-size:28rpx; font-weight:600; margin-bottom:16rpx }
          Text(
            lang.t('transactions.filterLabel'),
            style: TextStyle(
              color: c.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // uniapp .filter-selects { display:flex; gap:12rpx; align-items:stretch }
          Row(
            children: [
              Expanded(
                child: MonthPicker(
                  value: month,
                  onChanged: onMonthChanged,
                  compact: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SelectBox(
                  label: _categoryLabel(lang, categoryId),
                  onTap: () => _pickCategory(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SelectBox(
                  label: _accountLabel(lang, accountId),
                  onTap: () => _pickAccount(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _categoryLabel(Lang lang, String id) {
    if (id == 'all') return lang.t('transactions.allCategories');
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return lang.t('transactions.allCategories');
  }

  String _accountLabel(Lang lang, String id) {
    if (id == 'all') return lang.t('transactions.allAccounts');
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return lang.t('transactions.allAccounts');
  }

  Future<void> _pickCategory(BuildContext context) async {
    final lang = I18n.of(context);
    final picked = await _showOptionSheet(
      context: context,
      ref: ref,
      title: lang.t('transactions.allCategories'),
      options: [
        _PickerOption(id: 'all', name: lang.t('transactions.allCategories')),
        for (final c in categories) _PickerOption(id: c.id, name: c.name),
      ],
      selectedId: categoryId,
    );
    if (picked != null) onCategoryChanged(picked.id);
  }

  Future<void> _pickAccount(BuildContext context) async {
    final lang = I18n.of(context);
    final picked = await _showOptionSheet(
      context: context,
      ref: ref,
      title: lang.t('transactions.allAccounts'),
      options: [
        _PickerOption(id: 'all', name: lang.t('transactions.allAccounts')),
        for (final a in accounts) _PickerOption(id: a.id, name: a.name),
      ],
      selectedId: accountId,
    );
    if (picked != null) onAccountChanged(picked.id);
  }
}

/// 对齐 uniapp .select-box:1px 边框 + 12rpx radius + padding 16/20rpx +
/// 26rpx 字号,宽度由父 flex:1 控。
class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: c.text, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ▾ → ▼(U+25BC 实心下三角,跟 MonthPicker 视觉一致)
            Text(
              '▼',
              style: TextStyle(color: c.textVariant, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerOption {
  const _PickerOption({required this.id, required this.name});
  final String id;
  final String name;
}

/// 通用底部 sheet picker:点击选项关闭并返回 _PickerOption。
Future<_PickerOption?> _showOptionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required List<_PickerOption> options,
  required String selectedId,
}) {
  return showAppBottomSheet<_PickerOption>(
    context,
    ref: ref,
    builder: (_) => _OptionSheet(options: options, selectedId: selectedId),
  );
}

/// 滚轮选择器:对齐 uniapp MP `<picker mode="selector">` 的 iOS 原生滚轮
/// 体验 — CupertinoPicker + 上下渐变蒙层。中心 item 黑色 w600,其余 c.textVariant
/// 灰色,渐变蒙层让边缘 item 自然变淡(用户反馈:"滑动中间高亮,其他就渐变")。
///
/// ponytail: 2026-09-12 — 弹出走 bottom_sheet_route.dart 的 showAppBottomSheet
///          (Navigator.push + 自定 PageRoute,不走 showModalBottomSheet)。
///          这里 Stack > Positioned(bottom: 0) 锚物理屏底,wheel 底部 ==
///          屏幕底部,无视 iOS home indicator。
class _OptionSheet extends StatefulWidget {
  const _OptionSheet({
    required this.options,
    required this.selectedId,
  });

  final List<_PickerOption> options;
  final String selectedId;

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late FixedExtentScrollController _ctrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.options.indexWhere((o) => o.id == widget.selectedId);
    if (_currentIndex < 0) _currentIndex = 0;
    _ctrl = FixedExtentScrollController(initialItem: _currentIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                // ponytail: 用户反馈"背景设为白色" — picker 强制白底,跟
                //          uniapp 参考一致。
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.18),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部条:取消 + 完成(无 title,跟截图一致)。
                  // ponytail: 不要底部分割线 — 跟 uniapp picker 视觉一致,
                  //          头部/滚轮区无缝衔接。
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: SelectionContainer.disabled(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).pop(),
                            child: Text(
                              '取消',
                              style: TextStyle(
                                color: c.textVariant,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context)
                                .pop(widget.options[_currentIndex]),
                            child: Text(
                              '完成',
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 滚轮区:固定 220dp(5.5 × itemExtent 40),wheel 底部 =
                  // Container 底部 = 屏幕底部。C超出/底部让位靠 Stack
                  // top:-40/bottom:40(裁掉超出滚轮区的部分)。
                  SizedBox(
                    height: 220,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          top: -40,
                          bottom: 40,
                          left: 0,
                          right: 0,
                          child: CupertinoPicker(
                            itemExtent: 40,
                            scrollController: _ctrl,
                            backgroundColor: Colors.white,
                            selectionOverlay: const SizedBox.shrink(),
                            onSelectedItemChanged: (i) =>
                                setState(() => _currentIndex = i),
                            children: [
                              for (int i = 0; i < widget.options.length; i++)
                                Center(
                                  child: Text(
                                    widget.options[i].name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: i == _currentIndex
                                          ? c.text
                                          : c.textVariant,
                                      fontWeight: i == _currentIndex
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 选中行横线:220 - 120 = 100,/2 = 50。Container 高度 40
                        // → 上沿 y=50,下沿 y=90,正好对齐整体上移 40 的 Picker
                        // 中心(90 = 220 - 40 - 90)。
                        Positioned(
                          top: 50,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: c.divider, width: 1),
                                  bottom: BorderSide(color: c.divider, width: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 上下渐变蒙层:边缘 item 自然变淡。
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.85),
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.85),
                                  ],
                                  stops: const [0.0, 0.15, 0.85, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当月结余卡:对齐 uniapp .balance-card(primary 蓝底 + 白色文字 +
/// balance-amount + balance-sub 两栏 收入/支出)。
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.net,
    required this.income,
    required this.expense,
  });
  final double net;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    return Container(
      // uniapp .balance-card { background:var(--c-primary); padding:32rpx; gap:16rpx }
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // uniapp .balance-label { font-size:26rpx; opacity:0.9 }
          Text(
            lang.t('transactions.monthBalance'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          // uniapp .balance-card { gap:16rpx } → 8dp,显式撑开,避免只靠文字高度计算
          const SizedBox(height: 8),
          // uniapp .balance-amount { font-size:56rpx; font-weight:700 } → 28dp
          Text(
            '¥ ${formatAmount(net.abs())}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          // uniapp .balance-sub { margin-top:12rpx } → 6dp
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BalanceSubItem(
                  label: lang.t('transactions.income'),
                  value: '+¥ ${formatAmount(income)}',
                ),
                _BalanceSubItem(
                  label: lang.t('transactions.expense'),
                  value: '-¥ ${formatAmount(expense)}',
                  alignEnd: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSubItem extends StatelessWidget {
  const _BalanceSubItem({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // uniapp .sub-label { font-size:24rpx; opacity:0.9 }
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        // uniapp .balance-sub-item { gap:6rpx } → 3dp
        const SizedBox(height: 3),
        // uniapp .sub-value { font-size:30rpx; font-weight:600; tabular-nums }
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// 列表卡:对齐 uniapp .list-card(白底圆角 + 内部 day-group 块)。
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.groups,
    required this.categories,
    required this.accounts,
    required this.onDelete,
    required this.empty,
  });

  final List<_DayGroup> groups;
  final List<Category> categories;
  final List<Account> accounts;
  final Future<void> Function(Record) onDelete;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      // uniapp .list-card { radius:16rpx; overflow:hidden; border:1px }
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: empty
          ? Padding(
              // uniapp .empty { padding:80rpx; text-align:center } → 40dp
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  lang.t('transactions.empty'),
                  style: TextStyle(color: c.textVariant, fontSize: 14),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < groups.length; i++)
                  _DayGroupBlock(
                    group: groups[i],
                    isLast: i == groups.length - 1,
                    categories: categories,
                    accounts: accounts,
                    onDelete: onDelete,
                  ),
              ],
            ),
    );
  }
}

class _DayGroupBlock extends StatelessWidget {
  const _DayGroupBlock({
    required this.group,
    required this.isLast,
    required this.categories,
    required this.accounts,
    required this.onDelete,
  });
  final _DayGroup group;
  final bool isLast;
  final List<Category> categories;
  final List<Account> accounts;
  final Future<void> Function(Record) onDelete;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          // uniapp .day-header { padding:16rpx 24rpx; background:var(--c-surface) }
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: c.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDayHeader(group.date, lang),
                style: TextStyle(
                  color: c.textVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${group.net >= 0 ? '+' : '-'}¥ ${formatAmount(group.net.abs())}',
                style: TextStyle(
                  color: c.textVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        for (final r in group.records)
          // 对齐 uniapp — 整行 @tap="remove(r.id)" 触发删除确认弹窗,
          // 没有 swipe-to-delete。原 _DismissibleRow 包装(滑动手势删除)
          // 是 Flutter 私有设计,uniapp 没有。
          TransactionRow(
            record: r,
            category: _findCat(r.categoryId),
            account: _findAccount(r.accountId),
            onTap: () => onDelete(r),
          ),
        // uniapp .day-group { border-bottom:1px divider } 末组除外
        if (!isLast)
          Divider(height: 1, thickness: 1, color: c.divider),
      ],
    );
  }

  Category? _findCat(String? id) {
    if (id == null) return null;
    for (final cat in categories) {
      if (cat.id == id) return cat;
    }
    return null;
  }

  Account? _findAccount(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// 骨架屏 —— 首次 _data==null 时渲染,filter / balance / list 用灰块占位。
/// ponytail: 视觉上等同"立即有 UI",数据回来平滑替换。
class _TransactionsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final base = c.divider;
    final high = c.textVariant.withValues(alpha: 0.15);
    Widget bar(double w, {double h = 14, Color? color}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color ?? high,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    Widget block({Widget? child}) => Container(
          // ponytail: 不写 height,让 Container 自适应 Column 高度。
          //          之前固定 height + Column intrinsic 子元素超出会
          //          "BOTTOM OVERFLOWED BY N PIXELS"。骨架不要求跟真实
          //          高度完全一致,自适应即可。
          decoration: BoxDecoration(
            color: c.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: base),
          ),
          padding: const EdgeInsets.all(12),
          child: child ?? const SizedBox.shrink(),
        );
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        children: [
          block(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(80, h: 14),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: high,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )),
                const SizedBox(width: 6),
                Expanded(child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: high,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )),
                const SizedBox(width: 6),
                Expanded(child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: high,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )),
              ]),
            ],
          )),
          const SizedBox(height: 8),
          block(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(80, h: 13, color: c.primary.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              bar(160, h: 28),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  bar(80, h: 12),
                  bar(80, h: 12),
                ],
              ),
            ],
          )),
          const SizedBox(height: 8),
          block(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: base),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: high,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(double.infinity, h: 12),
                          const SizedBox(height: 6),
                          bar(120, h: 10),
                        ],
                      )),
                      bar(70, h: 14),
                    ],
                  ),
                ),
              ],
            ],
          )),
        ],
      ),
    );
  }
}
