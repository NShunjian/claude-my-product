import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/api/records_api.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../../core/utils/modal_state.dart';
import '../shared/app_header.dart';
import '../shared/month_picker.dart';
import '../shared/providers.dart';
import '../shared/quick_add_controller.dart';
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
  String _month = formatLocalMonth(DateTime.now());
  String _categoryId = 'all'; // 'all' = 所有分类
  String _accountId = 'all'; // 'all' = 所有账户

  @override
  void initState() {
    super.initState();
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
  }

  Future<_TxData> _load() async {
    final bookId = ref.read(currentBookIdProvider);
    final records = await ref.read(recordsApiProvider).listRecords(
          q: RecordsQuery(
            month: _month,
            bookId: bookId.isEmpty ? null : bookId,
          ),
        );
    final categories = await ref.read(categoriesApiProvider).listCategories();
    final accounts = await ref.read(accountsApiProvider).listAccounts(
          bookId: bookId.isEmpty ? null : bookId,
        );
    records.sort((a, b) {
      final byDate = b.recordDate.compareTo(a.recordDate);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return _TxData(records: records, categories: categories, accounts: accounts);
  }

  void _onMonthChanged(String m) {
    if (m == _month) return;
    setState(() {
      _month = m;
      _future = _load();
    });
  }

  void _onFilterChanged() {
    // 切分类/账户只触发 UI 重渲染过滤后数据,不再打后端 — 跟 uniapp 一致。
    setState(() {});
  }

  Future<void> _confirmDelete(Record r) async {
    final lang = I18n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
    } catch (_) {/* 容忍 */}
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Scaffold(
      appBar: AppHeader(title: lang.t('pageTitle.transactions')),
      body: FutureBuilder<_TxData>(
        future: _future,
        builder: (context, snap) {
          // 首次加载还没数据 → 整页占位
          if (!snap.hasData) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(
                child: Text(
                  lang.t('transactions.loading'),
                  style: TextStyle(color: c.textVariant),
                ),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  '${lang.t('transactions.loadErrorPrefix')}${snap.error}',
                  style: TextStyle(color: c.error),
                ),
              );
            }
          }
          final data = snap.data!;
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

          return RefreshIndicator(
            onRefresh: () async {
              final f = _load();
              setState(() => _future = f);
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
              ],
            ),
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
}) async {
  // ponytail: 切换 modalOpenProvider → _TabScaffold 把 bottomNavigationBar
  //          换成 SizedBox.shrink(),底部 tab bar 真正消失 → picker 任何高度
  //          都能盖到屏幕底。这是 app 已有的通用机制(quickAdd / 通用 modal
  //          也用同一 provider),比让 picker 强行盖在 tab bar 上更干净。
  ref.read(modalOpenProvider.notifier).state = true;
  try {
    // ponytail: 用 View.of(context) 而不是 MediaQuery.of(context) — Scaffold
    //          body 内的 MediaQuery.size.height 被 Scaffold 改写成 body 高度
    //          (扣掉 appbar + bottomNavigationBar),不是真实屏幕高度。
    //          View.of 拿到的是 FlutterView 的物理尺寸除以 dpr,跨任何 widget
    //          位置都是一致的全屏尺寸。
    final view = View.of(context);
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    return await showModalBottomSheet<_PickerOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // ponytail: useSafeArea: false 让 modal 延伸到屏幕底边缘(包括 home
      //          indicator 区),否则 safe area 之外的位置不被覆盖。
      useSafeArea: false,
      builder: (ctx) => _OptionSheet(
        options: options,
        selectedId: selectedId,
        screenHeight: screenHeight,
      ),
    );
  } finally {
    // ponytail: 用 context.mounted 而不是 ref 生命周期检查 — context 是
    //          BuildContext(StatelessWidget._FilterCard.build 传入),dispose
    //          后 mounted=false,避免在 widget 卸载后还写 provider。
    if (context.mounted) {
      ref.read(modalOpenProvider.notifier).state = false;
    }
  }
}

/// 滚轮选择器:对齐 uniapp MP `<picker mode="selector">` 的 iOS 原生滚轮
/// 体验 — CupertinoPicker + 上下渐变蒙层。中心 item 黑色 w600,其余 c.textVariant
/// 灰色,渐变蒙层让边缘 item 自然变淡(用户反馈:"滑动中间高亮,其他就渐变")。
class _OptionSheet extends StatefulWidget {
  const _OptionSheet({
    required this.options,
    required this.selectedId,
    required this.screenHeight,
  });

  final List<_PickerOption> options;
  final String selectedId;
  // ponytail: 从外部 context 传入屏幕高度(避免 modal 内 MediaQuery.size.height
  //          返回 modal 自己的 bounding box,导致 picker 高度计算偏小,tab bar
  //          不被覆盖)。
  final double screenHeight;

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
    // ponytail: 高度 35% — modal 顶/底圆角保持,底部平直延伸到屏幕底覆盖 tab bar。
    //          (tab bar 已通过 modalOpenProvider 隐藏,所以这里只是高度比例的
    //          视觉调整,不影响覆盖效果。)
    return Container(
      // ponytail: 高度 35% 屏高再 -34(header 自然高 46 + 滚轮区 5×40=200,
      //          总 246 ≈ screenHeight*0.35 - 34)。滚轮区精确 = 200px,
      //          = CupertinoPicker 的 5 个 itemExtent,内容填满无 buffer
      //          无裁切,首 item 紧贴 header 下沿(对齐"选择内容顶到红线")。
      height: widget.screenHeight * 0.35 - 34,
      decoration: BoxDecoration(
        // ponytail: 用户反馈"背景设为白色" — picker 强制白底,跟 uniapp 参考一致。
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
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
        mainAxisSize: MainAxisSize.max,
        children: [
          // 顶部条:取消 + 完成(无 title,跟截图一致)。
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(color: c.textVariant, fontSize: 16),
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
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 滚轮区:CupertinoPicker + 选中行上下两条横线 + 上下渐变蒙层。
          // ponytail: 不用 useMagnifier(magnifier 会让中心 item 放大,跟截图里
          //          均匀字号的视觉不一致);改用文字颜色 + 横线 + 蒙层做出"中间高亮、
          //          上下渐变"的视觉,跟 iOS native picker 一致。
          // ponytail: 用 Expanded + LayoutBuilder 让轮区撑满 picker 余下空间
          //          (35% × screen - 48dp top bar),内容一直延伸到 picker 底。
          //          横线位置 (h-40)/2 动态居中,适配任意轮区高度。
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                // ponytail: StackFit.expand 强制 CupertinoPicker 撑满滚轮区
                //          — 之前 Stack 默认 loose fit,CupertinoPicker 按
                //          自身 intrinsic 渲染,在 196~200 区间内会有 4px
                //          不一致(顶部空隙或底部裁切)。expand 强制对齐
                //          Stack 边界,CupertinoPicker 占满整个滚轮区,首
                //          item 顶到 picker 上沿 = 顶到红线位置。
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // ponytail: 整个 CupertinoPicker 整体上移 40px(一个
                    //          itemExtent)— 这样选中 item(加粗黑字)从
                    //          CupertinoPicker 几何中心 跟着上移到滚轮
                    //          区 y=40-80,正好和下面 Positioned 的横线
                    //          indicator 对齐,实现"红框选中位置整体往上
                    //          移一格"。bottom 留 40 给上方让位,顶部
                    //          -40 超出滚轮区的部分被 Stack clipbehavior
                    //          默认 hardEdge 裁掉,不可见。
                    Positioned(
                      top: -40,
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: _ctrl,
                        backgroundColor: Colors.white,
                        // ponytail: CupertinoPicker 自带 selectionOverlay 默认是圆角
                        //          浅灰矩形,强制 SizedBox.shrink() 去掉,只保留我们
                        //          自己画的上下两条横线作选中标记。
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
                    // ponytail: 横线位置 (h-40)/2 - 40 = (h-120)/2 —
                    //          原 (h-40)/2 是滚轮垂直中心(对齐 CupertinoPicker
                    //          居中的选中 item)。用户反馈"红框往上移一个"→
                    //          上移一个 itemExtent(40px)。CupertinoPicker 已
                    //          整体上移 40(见上面 Positioned 包裹),所以
                    //          这里横线和选中文字仍对齐,只是位置从滚轮正中
                    //          变成正中再往上一格。
                    Positioned(
                      top: (h - 120) / 2,
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
                    // 上下渐变蒙层:顶/底用白色 0.85 透明遮罩 → 边缘 item
                    // 自然变淡。stops 拉到 [0.15, 0.85] 让中间透明区域更大,
                    // 适配更大的轮区(35% × screen - 48 ≈ 400dp on 1280)。
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
                );
              },
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
          _DismissibleRow(
            record: r,
            category: _findCat(r.categoryId),
            account: _findAccount(r.accountId),
            onDelete: () => onDelete(r),
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

/// 流水行 + 左滑删除:对 uniapp row @tap="remove",在 Flutter 上用
/// Dismissible 模拟"点击删除"前先二次确认 + 左滑删除两种入口。
class _DismissibleRow extends StatelessWidget {
  const _DismissibleRow({
    required this.record,
    required this.category,
    required this.account,
    required this.onDelete,
  });

  final Record record;
  final Category? category;
  final Account? account;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: c.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: TransactionRow(
        record: record,
        category: category,
        account: account,
        onTap: () => context.push(
          AppRoutes.recordExpense,
          extra: record,
        ),
      ),
    );
  }
}
