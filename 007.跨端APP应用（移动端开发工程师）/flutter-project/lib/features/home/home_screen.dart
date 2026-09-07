import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/api/records_api.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/category_presentation.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../shared/auth_controller.dart';
import '../shared/providers.dart';
import '../shared/quick_add_controller.dart';
import '../shared/transaction_row.dart';

/// 对齐 pages/home/index.vue — 总资产 + 本月概览 + 最近流水 + 分类占比。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    // StatefulShellRoute.indexedStack 会把全部 tab 分支预构建,即便用户还没登录。
    // 没 token 时打 /api/* 会被后端 400/401 拒绝,所以未登录直接跳过。
    _future = ref.read(authControllerProvider).isLoggedIn
        ? _load()
        : Future.value(_HomeData.empty());
    ref.listenManual<QuickAddState>(quickAddControllerProvider, (prev, next) {
      if (prev != null && next.savedAt != prev.savedAt) {
        setState(() => _future = _load());
      }
    });
  }

  Future<_HomeData> _load() async {
    final reports = ref.read(reportsApiProvider);
    final accounts = ref.read(accountsApiProvider);
    final records = ref.read(recordsApiProvider);
    final categories = ref.read(categoriesApiProvider);
    final month = formatLocalMonth(DateTime.now());
    final bookId = ref.read(currentBookIdProvider);
    final results = await Future.wait([
      reports.getMonthly(month: month, bookId: bookId.isEmpty ? null : bookId),
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
    return _HomeData(
      report: report,
      accounts: accList,
      records: recs.take(8).toList(),
      categories: cats,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('home.greeting')),
        actions: [
          IconButton(
            tooltip: lang.t('home.quickAdd'),
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () =>
                ref.read(quickAddControllerProvider.notifier).open(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final f = _load();
          setState(() => _future = f);
          await f;
        },
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(
                child: Text(
                  lang.t('home.loading'),
                  style: TextStyle(color: c.textVariant),
                ),
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
            final data = snap.data!;
            final expenseRows = _buildBreakdownRows(
              data,
              RecordType.expense,
              data.report.totalExpense,
            );
            final incomeRows = _buildBreakdownRows(
              data,
              RecordType.income,
              data.report.totalIncome,
            );
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _AccountSummaryCard(
                  totalAssets: data.totalAssets,
                  accounts: data.accounts.length,
                  userName: auth.user?.displayName ?? auth.user?.username,
                  color: c.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                _MonthOverview(report: data.report),
                const SizedBox(height: AppSpacing.lg),
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
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _BreakdownCard(
                        title: lang.t('home.incomeByCategory'),
                        rows: incomeRows,
                        total: data.report.totalIncome,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.t('home.recentTransactions'),
                      style: TextStyle(color: c.text, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.transactions),
                      child: Text(lang.t('home.viewAll')),
                    ),
                  ],
                ),
                if (data.records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        lang.t('home.empty'),
                        style: TextStyle(color: c.textVariant),
                      ),
                    ),
                  )
                else
                  ...data.records.map((r) {
                    final cat = data.categories.firstWhere(
                      (x) => x.id == r.categoryId,
                      orElse: () => Category(
                        id: '',
                        type: CategoryType.expense,
                        name: '',
                        icon: '',
                        color: '#727782',
                        sortOrder: 0,
                        isPreset: false,
                      ),
                    );
                    return TransactionRow(
                      record: r,
                      category: cat.id.isEmpty ? null : cat,
                      account: null,
                      onTap: null,
                    );
                  }),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(quickAddControllerProvider.notifier).open(),
        icon: const Icon(Icons.flash_on),
        label: Text(lang.t('home.quickAdd')),
      ),
    );
  }

  List<_CatRow> _buildBreakdownRows(
    _HomeData data,
    RecordType type,
    double total,
  ) {
    final aggs = type == RecordType.expense
        ? data.report.expenseByCategory
        : data.report.incomeByCategory;
    if (aggs.isEmpty) return const [];
    final result = <_CatRow>[];
    for (final agg in aggs) {
      final cat = data.categories.firstWhere(
        (c) => c.id == agg.categoryId,
        orElse: () => Category(
          id: agg.categoryId ?? '',
          type: type == RecordType.expense ? CategoryType.expense : CategoryType.income,
          name: agg.categoryId ?? '',
          icon: '',
          color: '#727782',
          sortOrder: 0,
          isPreset: false,
        ),
      );
      result.add(_CatRow(cat: cat, total: agg.amount, grandTotal: total));
    }
    return result;
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

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({
    required this.totalAssets,
    required this.accounts,
    required this.userName,
    required this.color,
  });

  final double totalAssets;
  final int accounts;
  final String? userName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userName != null && userName!.isNotEmpty)
            Text(
              '$userName · ${lang.t('home.greeting')}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            lang.t('home.totalAssets'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatAmount(totalAssets, withSymbol: true),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            lang.t('home.accountsCount', {'n': accounts}),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MonthOverview extends StatelessWidget {
  const _MonthOverview({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('home.monthOverview'),
            style: TextStyle(color: c.textVariant, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Metric(
                label: lang.t('home.income'),
                value: formatAmount(report.totalIncome, withSymbol: true),
                color: const Color(0xFF2E7DE6),
                textColor: c.text,
              ),
              _Metric(
                label: lang.t('home.expense'),
                value: formatAmount(report.totalExpense, withSymbol: true),
                color: c.error,
                textColor: c.text,
              ),
              _Metric(
                label: lang.t('home.balance'),
                value: formatAmount(report.netSavings, withSymbol: true),
                color: report.netSavings >= 0 ? c.primary : c.error,
                textColor: c.text,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  row.cat.name,
                  style: TextStyle(color: c.text, fontSize: 13),
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
          // 横条:uniapp 高度 10rpx(5dp),底色 #E8EEF7,圆角 6rpx(3dp)。
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF7),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: row.pct,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
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