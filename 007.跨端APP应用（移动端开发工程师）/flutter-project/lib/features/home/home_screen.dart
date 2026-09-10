import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/api/records_api.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/category_presentation.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../../core/utils/tab_refresh_signal.dart';
import '../shared/app_header.dart';
import '../shared/auth_controller.dart';
import '../shared/month_picker.dart';
import '../shared/providers.dart';
import '../shared/quick_add_controller.dart';
import '../shared/transaction_row.dart';

/// 对齐 pages/home/index.vue — 顶部 AppHeader + 总览/月份 + 资产卡(内嵌快速记账)
/// + 本月概览三列 + 双卡分类占比 + 按日分组的最近交易。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _future;
  // ponytail: stale-while-revalidate — FutureBuilder 在 future 变化时把
  //          snap.data 重置为 null,reload 期间会闪 loading。_data 保留最后
  //          一次成功数据,build 永远用 _data 渲染(直到下次 _load 完成)。
  _HomeData? _data;
  late String _month; // YYYY-MM

  @override
  void initState() {
    super.initState();
    _month = formatLocalMonth(DateTime.now());
    // StatefulShellRoute.indexedStack 会把全部 tab 分支预构建,即便用户还没登录。
    // 没 token 时打 /api/* 会被后端 400/401 拒绝,所以未登录直接跳过。
    _future = ref.read(authControllerProvider).isLoggedIn
        ? _load()
        : Future.value(_HomeData.empty());
    // 监听 quickAdd 保存 + 弹窗关闭,任一发生都触发首页重拉。
    // - savedAt 变化 = closeAndNotify() 的原子通知(主路径)
    // - show 从 true → false = 兜底:即便 closeAndNotify 因 Riverpod 边角 case
    //   漏发 savedAt,弹窗关闭这一事件也会触发刷新
    ref.listenManual<QuickAddState>(quickAddControllerProvider, (prev, next) {
      if (prev != null &&
          (next.savedAt != prev.savedAt || (prev.show && !next.show))) {
        // Future 必须先算出再传进 setState — 用箭头 () => _future = _load()
        // 会让 setState 收到 Future 返回值而抛错(_load() 是 async)。
        final f = _load();
        setState(() {
          _future = f;
        });
      }
    });
    // ponytail: 切到 home tab 时重拉(3)。next>prev 才触发,初始 0 不触发空拉;
    //          月份已切的视图仍走 _onMonthChanged。
    ref.listenManual<int>(tabRefreshSignalProvider(0), (prev, next) {
      if (prev != null && next > prev) {
        final f = _load();
        setState(() {
          _future = f;
        });
      }
    });
  }

  void _onMonthChanged(String m) {
    if (m == _month) return;
    setState(() {
      _month = m;
      _future = _load();
    });
  }

  Future<_HomeData> _load() async {
    final reports = ref.read(reportsApiProvider);
    final accounts = ref.read(accountsApiProvider);
    final records = ref.read(recordsApiProvider);
    final categories = ref.read(categoriesApiProvider);
    final bookId = ref.read(currentBookIdProvider);
    final results = await Future.wait([
      reports.getMonthly(month: _month, bookId: bookId.isEmpty ? null : bookId),
      accounts.listAccounts(bookId: bookId.isEmpty ? null : bookId),
      records.listRecords(
        q: RecordsQuery(bookId: bookId.isEmpty ? null : bookId),
      ),
      categories.listCategories(),
    ]);
    final report = results[0] as MonthlyReport;
    final accList = results[1] as List<Account>;
    final recs = results[2] as List<Record>;
    final cats = results[3] as List<Category>;
    recs.sort((a, b) {
      final byDate = b.recordDate.compareTo(a.recordDate);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    // 切换月份时整个页面都要刷新到当月数据:后端 records API 不带 month 参数,
    // 拉到的是全量流水,这里按当前 _month 过滤后再交给 UI
    // (最近交易按月取前 5;分类占比也按月算 — 见 _buildBreakdownRows)。
    final monthRecs =
        recs.where((r) => r.recordDate.startsWith(_month)).toList();
    return _HomeData(
      report: report,
      accounts: accList,
      records: monthRecs,
      categories: cats,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;

    return Scaffold(
      appBar: AppHeader(title: lang.t('pageTitle.home')),
      body: RefreshIndicator(
        onRefresh: () async {
          final f = _load();
          setState(() => _future = f);
          await f;
        },
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snap) {
            // 同步新数据到 _data(引用相等即停止更新,避免重复 setState)。
            if (snap.hasData && !identical(snap.data, _data)) {
              _data = snap.data;
            }
            // 首次加载还没数据 → 显示整页 loading 占位
            if (_data == null) {
              if (snap.connectionState != ConnectionState.done) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        lang.t('home.loading'),
                        style: TextStyle(color: c.textVariant),
                      ),
                    ),
                  ],
                );
              }
              if (snap.hasError) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        '${lang.t('home.loadErrorPrefix')}${snap.error}',
                        style: TextStyle(color: c.error),
                      ),
                    ),
                  ],
                );
              }
            }
            // 已有数据(包括刷新中的 stale snapshot)→ 渲染数据,顶部加进度条表示在重新拉取
            final data = _data!;
            final isReloading =
                snap.connectionState != ConnectionState.done;
            final expenseRows = _buildBreakdownRows(
              data,
              RecordType.expense,
            );
            final incomeRows = _buildBreakdownRows(
              data,
              RecordType.income,
            );
            return Column(
              children: [
                if (isReloading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Color(0x00000000),
                  ),
                Expanded(
                  child: ListView(
                    // uniapp .scroll-area { padding: 0 24rpx 24rpx } → 12dp
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    children: [
                      _GreetingRow(
                        month: _month,
                        onMonthChanged: _onMonthChanged,
                      ),
                      // uniapp .scroll-area { gap: 20rpx } → 10dp
                      const SizedBox(height: 10),
                      _AssetsCard(
                        totalAssets: data.totalAssets,
                        accounts: data.accounts.length,
                        onQuickAdd: () =>
                            ref.read(quickAddControllerProvider.notifier).open(),
                      ),
                      const SizedBox(height: 10),
                      _ExpenseCard(amount: data.report.totalExpense),
                      const SizedBox(height: 10),
                      _IncomeCard(amount: data.report.totalIncome),
                      const SizedBox(height: 10),
                      _BalanceCard(net: data.report.netSavings),
                      const SizedBox(height: 10),
                      // uniapp 顺序: 当月结余 → 最近交易 → 分类汇总
                      _RecentTransactionsCard(
                        records: data.records.take(5).toList(),
                        categories: data.categories,
                        accounts: data.accounts,
                        onViewAll: () => context.go(AppRoutes.transactions),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _BreakdownCard(
                              title: lang.t('home.expenseByCategory'),
                              rows: expenseRows,
                              total: data.report.totalExpense,
                            ),
                          ),
                          // uniapp .breakdown-row { gap: 16rpx } → 8dp
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BreakdownCard(
                              title: lang.t('home.incomeByCategory'),
                              rows: incomeRows,
                              total: data.report.totalIncome,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 对齐 uniapp `expenseByCat` / `incomeByCat`:
  /// 遍历**所有**该类型分类(不只是当月有流水的),客户端按 records 计算 total,
  /// 按 total 降序,¥0 也展示(uniapp 也是 map 后 sort,不 filter 0)。
  /// 关键:data.records 是全量(recordsApi 不带 month 参数),必须按当前 _month 过滤
  /// 才能对齐 `data.report` 的当月口径(否则会显示全部历史累计金额)。
  List<_CatRow> _buildBreakdownRows(_HomeData data, RecordType type) {
    final catType = type == RecordType.expense
        ? CategoryType.expense
        : CategoryType.income;
    final cats = data.categories.where((c) => c.type == catType).toList();
    if (cats.isEmpty) return const [];
    // 按当前月过滤:recordDate 是 YYYY-MM-DD,_month 是 YYYY-MM。
    final typeRecords = data.records
        .where((r) => r.type == type && r.recordDate.startsWith(_month))
        .toList();
    // 当月总额(uniapp 用 monthExpense / monthIncome,即 totalExpense / totalIncome)。
    final grandTotal =
        type == RecordType.expense ? data.report.totalExpense : data.report.totalIncome;

    final rows = <_CatRow>[];
    for (final cat in cats) {
      final total = typeRecords
          .where((r) => r.categoryId == cat.id)
          .fold<double>(0, (s, r) => s + r.amount);
      rows.add(_CatRow(cat: cat, total: total, grandTotal: grandTotal));
    }
    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }
}

class _HomeData {
  _HomeData({
    required this.report,
    required this.accounts,
    required this.records,
    required this.categories,
  });
  final MonthlyReport report;
  final List<Account> accounts;
  final List<Record> records;
  final List<Category> categories;

  double get totalAssets =>
      accounts.fold<double>(0, (sum, a) => sum + a.balance);

  /// 未登录占位 — 避免 StatefulShellRoute 预构建时打 /api/* 被后端 400/401 拒绝。
  factory _HomeData.empty() => _HomeData(
        report: MonthlyReport(
          month: '',
          totalIncome: 0,
          totalExpense: 0,
          netSavings: 0,
          incomeByCategory: const [],
          expenseByCategory: const [],
          dailyData: const [],
        ),
        accounts: const [],
        records: const [],
        categories: const [],
      );
}

/// 顶部 "总览 / 2026 年 9 月" + MonthPicker(对齐 uniapp .header + MonthPicker)。
class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.month, required this.onMonthChanged});

  final String month;
  final ValueChanged<String> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.t('home.overview'),
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatMonthCN(month, langCode: lang.code),
              style: TextStyle(color: c.textVariant, fontSize: 13),
            ),
          ],
        ),
        MonthPicker(value: month, onChanged: onMonthChanged),
      ],
    );
  }
}

/// 资产卡(u8d44 u4ea7 u5361) + 内嵌快速记账按钮。
/// uniapp .assets-card 是白底带边框,大额数字用 primary 蓝色,不是渐变。
class _AssetsCard extends StatelessWidget {
  const _AssetsCard({
    required this.totalAssets,
    required this.accounts,
    required this.onQuickAdd,
  });

  final double totalAssets;
  final int accounts;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      // uniapp .card { padding: 24rpx } → 12dp; .assets-card { border-radius: 16rpx } → 8dp
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider),
      ),
      child: Stack(
        children: [
          // uniapp .wallet-icon { top: 24rpx; right: 24rpx; font-size: 96rpx; opacity: 0.12 }
          const Positioned(
            top: 12,
            right: 12,
            child: Opacity(
              opacity: 0.12,
              child: Text(
                '💰',
                style: TextStyle(fontSize: 48, height: 1),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('home.totalAssets'),
                style: TextStyle(color: c.textVariant, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '¥${formatAmount(totalAssets)}',
                // uniapp .amt-big.primary { color: var(--c-primary); font-size: 56rpx; font-weight: 700 }
                style: TextStyle(
                  color: c.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lang.t('home.accountsCount', {'n': accounts}),
                style: TextStyle(color: c.textVariant, fontSize: 12),
              ),
              const SizedBox(height: 12),
              // 快速记账按钮:uniapp .quick-add-btn — primary 蓝底 + 白字 + + 号。
              // padding/字号/radius 跟 uniapp 设计图视觉对齐。
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onQuickAdd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lang.t('home.quickAdd'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 三张独立 KPI 卡(本月支出 / 本月收入 / 当月结余) — 对齐 uniapp
/// .kpi-stack 中的三张 .kpi-card 各自一张白底卡 + 大号金额 + 可选副标。
/// 收入绿(#006d40)、支出红(var(--c-error))、结余按正负染色。
class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return _KpiCard(
      label: lang.t('home.expense'),
      value: '¥${formatAmount(amount)}',
      valueColor: c.error,
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.amount});
  final double amount;

  static const _incomeGreen = Color(0xFF006D40);

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    return _KpiCard(
      label: lang.t('home.income'),
      value: '¥${formatAmount(amount)}',
      valueColor: _incomeGreen,
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.net});
  final double net;

  static const _incomeGreen = Color(0xFF006D40);

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final isPositive = net >= 0;
    return _KpiCard(
      label: lang.t('home.balance'),
      value: '¥${formatAmount(net.abs())}',
      valueColor: isPositive ? _incomeGreen : c.error,
      suffix: isPositive ? lang.t('home.surplus') : lang.t('home.overBudget'),
      suffixColor: isPositive ? _incomeGreen : c.error,
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.valueColor,
    this.suffix,
    this.suffixColor,
  });
  final String label;
  final String value;
  final Color valueColor;
  final String? suffix;
  final Color? suffixColor;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      // uniapp .kpi-card { padding: 24rpx 28rpx; border-radius: 16rpx; border: 1px solid var(--c-divider) }
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .card-label { font-size: 26rpx } → 13dp,用 valueColor 当 label 颜色
          Text(
            label,
            style: TextStyle(color: valueColor, fontSize: 13),
          ),
          const SizedBox(height: 6),
          // .amt-big { font-size: 56rpx; font-weight: 700; line-height: 1.1 } → 28dp
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(height: 6),
            // .balance-sub { font-size: 26rpx } → 13dp
            Text(
              suffix!,
              style: TextStyle(
                color: suffixColor ?? c.textVariant,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单条分类汇总行(对齐 uniapp .cat-row + .cat-bar-track)。
class _CatRow {
  _CatRow({required this.cat, required this.total, required this.grandTotal});
  final Category cat;
  final double total;
  final double grandTotal;

  /// 占总盘比例 0.0~1.0。grandTotal==0 时为 0(uniapp 也是 0)。
  double get pct => grandTotal > 0 ? (total / grandTotal).clamp(0.0, 1.0) : 0.0;
}

/// 支出/收入分类横条卡(对齐 uniapp .breakdown-card)。
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.rows,
    required this.total,
  });
  final String title;
  final List<_CatRow> rows;
  final double total;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      // uniapp .card { padding: 24rpx; border-radius: 16rpx; border: 1px solid var(--c-divider) }
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // uniapp .card-title { font-size: 30rpx; font-weight: 600 } → 15dp
          Text(
            title,
            style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          // uniapp .breakdown-card { gap: 24rpx } → 12dp(title → cat-list 间距)
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  lang.t('home.empty'),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
              ),
            )
          else
            Column(
              children: [
                for (final r in rows) _CatBarRow(row: r),
              ],
            ),
        ],
      ),
    );
  }
}

/// 单行 emoji + 名称 + 金额 + 横条(对齐 uniapp .cat-row)。
class _CatBarRow extends StatelessWidget {
  const _CatBarRow({required this.row});
  final _CatRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pres = presentCategory(row.cat);
    final color = _parseHex(pres.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(pres.icon, style: TextStyle(color: color, fontSize: 18)),
              // uniapp .cat-row-top { gap: 12rpx } → 6dp
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  row.cat.name,
                  // uniapp .cat-name { font-weight: 500 }
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '¥${formatAmount(row.total)}',
                style: TextStyle(
                  color: c.textVariant,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // 横条:uniapp 高度 10rpx(5dp),底色 #E8EEF7,圆角 6rpx(3dp),overflow:hidden。
          // ⚠️ Container(decoration:..., 无 child) 内部会被降级为 DecoratedBox(0×0),
          //   即便 Positioned.fill 也不稳 → 必须给 track 显式 width:double.infinity + height:5
          //   让 Container 走 ConstrainedBox 分支,真正吃满 Stack bounds。
          // fill 用 SizedBox(5) + DecoratedBox 显式锁高,避免塌缩。
          // 横条:LayoutBuilder 取到父宽后,track + fill 都用显式 width 像素值,
          // 避免 Container(decoration, no child) 退化成 0×0 DecoratedBox。
          // 旧实现是 Stack+Positioned.fill+FractionallySizedBox,在 Flutter web
          // 某些缩放下 ¥0 行整条 track 看不见 —— 改为固定像素宽度后稳定可见。
          // ponytail: 每次 rebuild 都过 LayoutBuilder,数据量小(<12 行/卡)可以忽略;
          //          若改用 web 端 Paintshader 调优或上千行虚拟列表再换 RenderObject。
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return SizedBox(
                height: 5,
                width: w,
                child: Stack(
                  children: [
                    // 底色 track —— 满父宽,提供 ¥0 行也能看见的占位条
                    SizedBox(
                      width: w,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEF7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // 填充 —— 宽度 = pct × 父宽,左侧对齐,圆角与 track 一致
                    if (row.pct > 0)
                      SizedBox(
                        width: w * row.pct,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static Color _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

/// 最近交易卡:对齐 uniapp <view class="card"> + .card-head(title+view-all) +
/// loading/empty/分组列表。一张卡内含 card-head 与 day-grouped 列表。
class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.records,
    required this.categories,
    required this.accounts,
    required this.onViewAll,
  });
  final List<Record> records;
  final List<Category> categories;
  final List<Account> accounts;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final today = DateTime.now();
    final groups = _groupByDate(records, today, lang);

    return Container(
      // uniapp .card: padding 24rpx (12dp), radius 16rpx (8dp), border 1px
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // card-head: title + view-all → margin-bottom 16rpx (8dp)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.t('home.recentTransactions'),
                // .card-title { font-size: 30rpx; font-weight: 600 } → 15dp
                style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onViewAll,
                child: Text(
                  '${lang.t('home.viewAll')} →',
                  // .view-all { font-size: 26rpx; color: var(--c-primary) } → 13dp
                  style: TextStyle(color: c.primary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  lang.t('home.empty'),
                  // .empty { font-size: 28rpx; color: var(--c-text-variant) } → 14dp
                  style: TextStyle(color: c.textVariant, fontSize: 14),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < groups.length; i++)
                  _DayGroupBlock(
                    group: groups[i],
                    isLast: i == groups.length - 1,
                    categories: categories,
                    accounts: accounts,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<_DayGroup> _groupByDate(
    List<Record> recs,
    DateTime today,
    Lang lang,
  ) {
    // records 已按 recordDate desc + createdAt desc 排序(在 _load 内做)。
    // 这里只取前 5 条(对齐 uniapp slice(0, 5))。
    final top = recs.take(5).toList();
    final map = <String, List<Record>>{};
    for (final r in top) {
      map.putIfAbsent(r.recordDate, () => []).add(r);
    }
    return map.entries.map((e) {
      final net = e.value.fold<double>(
        0,
        (s, r) => s + (r.type == RecordType.income ? r.amount : -r.amount),
      );
      return _DayGroup(
        date: e.key,
        recs: e.value,
        net: net,
        label: formatRelativeDayLabel(
          e.key,
          today,
          todayLabel: lang.t('home.today'),
          yesterdayLabel: lang.t('home.yesterday'),
        ),
      );
    }).toList();
  }
}

class _DayGroup {
  _DayGroup({
    required this.date,
    required this.label,
    required this.net,
    required this.recs,
  });
  final String date;
  final String label;
  final double net;
  final List<Record> recs;
}

class _DayGroupBlock extends StatelessWidget {
  const _DayGroupBlock({
    required this.group,
    required this.isLast,
    required this.categories,
    required this.accounts,
  });
  final _DayGroup group;
  final bool isLast;
  final List<Category> categories;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          // uniapp .day-header { padding: 12rpx 16rpx; background: var(--c-surface) } → 6dp 8dp
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: c.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                group.label,
                style: TextStyle(
                  color: c.textVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '¥${formatAmount(group.net.abs())}',
                style: TextStyle(
                  color: c.textVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        for (final r in group.recs)
          TransactionRow(
            record: r,
            category: _findCat(r.categoryId),
            account: _findAccount(r.accountId),
            onTap: null,
          ),
        if (!isLast) const Divider(height: 1),
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

  Account? _findAccount(String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }
}
