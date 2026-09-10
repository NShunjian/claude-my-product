import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../../core/utils/tab_refresh_signal.dart';
import '../shared/app_header.dart';
import '../shared/charts/donut_chart.dart';
import '../shared/month_picker.dart';
import '../shared/providers.dart';

/// 对齐 pages/reports/monthly.vue — header-row + 月/年 segmented tab +
/// 月报 KPI(三卡带 footer)+ 折线图 + 双 donut;年报 KPI(三卡)+ 12 月柱状图
/// (CustomPaint + tap tooltip)+ 双 donut。
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _mode = 0; // 0=monthly 1=yearly
  String _month = formatLocalMonth(DateTime.now());
  int _year = DateTime.now().year;

  void _setMode(int i) {
    if (i == _mode) return;
    setState(() => _mode = i);
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    return Scaffold(
      appBar: AppHeader(title: lang.t('pageTitle.reportMonthly')),
      body: Column(
        children: [
          // header-row(uniapp:左 title-block,右 month/year ctrl)。
          _Header(
            title: _mode == 0
                ? lang.t('reportMonthly.title')
                : lang.t('reportYearly.title'),
            subtitle: _mode == 0
                ? '${_month.split('-').first}年 ${int.parse(_month.split('-').last)}月'
                : '$_year年',
            rightCtrl: _mode == 0
                ? MonthPicker(
                    value: _month,
                    onChanged: (m) => setState(() => _month = m),
                  )
                : _YearCtrl(
                    year: _year,
                    onPicked: (y) => setState(() => _year = y),
                  ),
          ),
          // tab-bar(uniapp:.tab-bar 在 header-row 和内容之间)。
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: _SegmentedTabs(
              labels: [
                lang.t('reportMonthly.tabMonthly'),
                lang.t('reportMonthly.tabYearly'),
              ],
              current: _mode,
              onTap: _setMode,
            ),
          ),
          Expanded(
            child: _mode == 0
                ? _MonthlyTab(month: _month)
                : _YearlyTab(year: _year),
          ),
        ],
      ),
    );
  }
}

/// 头部行:左 title-block(page-title + page-subtitle),右 month/year ctrl。
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.rightCtrl,
  });
  final String title;
  final String subtitle;
  final Widget rightCtrl;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: c.textVariant, fontSize: 13),
              ),
            ],
          ),
          rightCtrl,
        ],
      ),
    );
  }
}

/// 年份选择控件:对齐 uniapp 年报 .year-ctrl(‹ + 年份 + › + picker)。
class _YearCtrl extends StatelessWidget {
  const _YearCtrl({required this.year, required this.onPicked});
  final int year;
  final ValueChanged<int> onPicked;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final now = DateTime.now().year;
    final options = [for (var i = now - 5; i <= now + 4; i++) i];
    return Row(
      children: [
        _RoundIconBtn(
          glyph: '‹',
          onTap: () => onPicked(year - 1),
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          child: PopupMenuButton<int>(
            tooltip: '',
            color: c.bgCard,
            offset: const Offset(0, 36),
            onSelected: onPicked,
            itemBuilder: (ctx) => [
              for (final y in options)
                PopupMenuItem<int>(
                  value: y,
                  child: Text(
                    '$y年',
                    style: TextStyle(
                      color: y == year ? c.primary : c.text,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                '$year年',
                style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _RoundIconBtn(
          glyph: '›',
          onTap: () => onPicked(year + 1),
        ),
      ],
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.glyph, required this.onTap});
  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: c.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Text(
            glyph,
            style: TextStyle(
              color: c.textVariant,
              fontSize: 16,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// 自绘分段控件(uniapp .tab-bar + .tab + .tab.active)。
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.current,
    required this.onTap,
  });
  final List<String> labels;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == current ? c.bgCard : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == current ? c.primary : c.textVariant,
                      fontSize: 13,
                      fontWeight: i == current
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 月报 tab body:对齐 uniapp .kpi-list(3 卡带 footer)+ 折线图 +
/// 收入/支出 donut。
class _MonthlyTab extends ConsumerStatefulWidget {
  const _MonthlyTab({required this.month});
  final String month;

  @override
  ConsumerState<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends ConsumerState<_MonthlyTab> {
  late Future<MonthlyReport> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // ponytail: 切到 reports tab 时重拉月报(2)。next>prev 才触发,初始 0 不触发。
    ref.listenManual<int>(tabRefreshSignalProvider(2), (prev, next) {
      if (prev != null && next > prev) _reload();
    });
  }

  @override
  void didUpdateWidget(covariant _MonthlyTab old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _reload();
  }

  void _reload() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  Future<MonthlyReport> _load() {
    final bookId = ref.read(currentBookIdProvider);
    return ref.read(reportsApiProvider).getMonthly(
          month: widget.month,
          bookId: bookId.isEmpty ? null : bookId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return FutureBuilder<MonthlyReport>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: Text(lang.t('common.loading')));
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                '${lang.t('reportMonthly.loadErrorPrefix')}${snap.error}',
                style: TextStyle(color: c.error),
              ),
            );
          }
        }
        final r = snap.data!;
        final isReloading = snap.connectionState != ConnectionState.done;
        final cats = ref.read(categoriesApiProvider);
        return Column(
          children: [
            if (isReloading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0x00000000),
              ),
            Expanded(
              child: FutureBuilder<List<Category>>(
                future: cats.listCategories(),
                builder: (context, catsSnap) {
                  final catList = catsSnap.data ?? const [];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    children: [
                      _KpiColumnMonthly(report: r, lang: lang, cats: catList),
                      const SizedBox(height: AppSpacing.md),
                      _ChartCard(
                        title: lang.t('reportMonthly.dailyTrend'),
                        legend: const _ChartLegend(),
                        // viewBox 800x320 → 自适应高度。uniapp 也是 width:100%; height:auto。
                        child: _DailyChart(dailyData: r.dailyData),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CategoryCard(
                        title: lang.t('reportMonthly.incomeShare'),
                        emptyKey: 'reportMonthly.noIncomeRecords',
                        aggs: r.incomeByCategory,
                        cats: catList,
                        total: r.totalIncome,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CategoryCard(
                        title: lang.t('reportMonthly.expenseShare'),
                        emptyKey: 'reportMonthly.noExpenseRecords',
                        aggs: r.expenseByCategory,
                        cats: catList,
                        total: r.totalExpense,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 年报 tab body:对齐 uniapp .kpi-list(3 卡无 footer)+ 12 月柱状图
/// (CustomPaint + tap tooltip)+ 费用分布 + 收入构成 双 donut。
class _YearlyTab extends ConsumerStatefulWidget {
  const _YearlyTab({required this.year});
  final int year;

  @override
  ConsumerState<_YearlyTab> createState() => _YearlyTabState();
}

class _YearlyTabState extends ConsumerState<_YearlyTab> {
  late Future<YearlyReport> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // ponytail: 切到 reports tab 时也重拉年报。next>prev 才触发,初始 0 不触发。
    ref.listenManual<int>(tabRefreshSignalProvider(2), (prev, next) {
      if (prev != null && next > prev) _reload();
    });
  }

  @override
  void didUpdateWidget(covariant _YearlyTab old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year) _reload();
  }

  void _reload() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  Future<YearlyReport> _load() {
    final bookId = ref.read(currentBookIdProvider);
    return ref.read(reportsApiProvider).getYearly(
          year: widget.year,
          bookId: bookId.isEmpty ? null : bookId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return FutureBuilder<YearlyReport>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: Text(lang.t('common.loading')));
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                '${lang.t('reportYearly.loadErrorPrefix')}${snap.error}',
                style: TextStyle(color: c.error),
              ),
            );
          }
        }
        final r = snap.data!;
        final isReloading = snap.connectionState != ConnectionState.done;
        final cats = ref.read(categoriesApiProvider);
        return Column(
          children: [
            if (isReloading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0x00000000),
              ),
            Expanded(
              child: FutureBuilder<List<Category>>(
                future: cats.listCategories(),
                builder: (context, catsSnap) {
                  final catList = catsSnap.data ?? const [];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    children: [
                      _KpiColumnYearly(report: r, lang: lang),
                      const SizedBox(height: AppSpacing.md),
                      _ChartCard(
                        title: lang.t('reportYearly.monthlyTrend'),
                        legend: const _ChartLegend(
                          incomeColor: Color(0xFF006D40),
                        ),
                        child: SizedBox(
                          height: 180,
                          child: _MonthlyBarChart(
                            data: r.monthlyData,
                            lang: lang,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CategoryCard(
                        title: lang.t('reportYearly.expenseBreakdown'),
                        emptyKey: 'reportYearly.noExpenseRecords',
                        aggs: r.expenseByCategory,
                        cats: catList,
                        total: r.totalExpense,
                        totalValueOverride:
                            '¥${(r.totalExpense / 1000).toStringAsFixed(1)}k',
                        showPct: false,
                        compact: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CategoryCard(
                        title: lang.t('reportYearly.incomeShare'),
                        emptyKey: 'reportYearly.noIncomeRecords',
                        aggs: r.incomeByCategory,
                        cats: catList,
                        total: r.totalIncome,
                        totalValueOverride:
                            '¥${(r.totalIncome / 1000).toStringAsFixed(1)}k',
                        showPct: false,
                        compact: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 月报 KPI 三卡 stacked:net 卡含 trend pill + "较上月" 文字,income 卡含
/// top-2 分类 mini-row,expense 卡含 top-1 分类 + "最多分类:" 前缀。
class _KpiColumnMonthly extends StatelessWidget {
  const _KpiColumnMonthly({
    required this.report,
    required this.lang,
    required this.cats,
  });
  final MonthlyReport report;
  final Lang lang;
  final List<Category> cats;

  @override
  Widget build(BuildContext context) {
    // 算 trend pct:对齐 uniapp monthlyNetChangePct,用 MonthlyComparison.netSavings
    // (后端直接给的值),不要用 income-expense 推算。
    final lastMonthSavings = report.lastMonth?.netSavings;
    final pct = (lastMonthSavings != null && lastMonthSavings != 0)
        ? ((report.netSavings - lastMonthSavings) / lastMonthSavings.abs()) *
              100
        : null;

    // top-2 收入分类 mini-row(uniapp .cat-mini-row)。
    final incomeRanking = [...report.incomeByCategory]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top2Income = incomeRanking.take(2).toList();

    // top-1 支出分类(uniapp .footer-text.expense)。
    final expenseRanking = [...report.expenseByCategory]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top1Expense = expenseRanking.isEmpty ? null : expenseRanking.first;

    return Column(
      children: [
        _KpiCard(
          kind: _KpiKind.net,
          icon: '🏦',
          label: lang.t('reportMonthly.netSavings'),
          amount: report.netSavings,
          isIncome: report.netSavings >= 0,
          trendPct: pct,
          lastMonthLabel: lang.t('reportMonthly.lastMonth'),
        ),
        _KpiCard(
          kind: _KpiKind.income,
          icon: '📉',
          label: lang.t('reportMonthly.totalIncomeLabel'),
          amount: report.totalIncome,
          isIncome: true,
          // top-2 mini-row footer
          customFooter: top2Income.isEmpty
              ? _KpiFooterText(
                  text: lang.t('reportMonthly.noIncome'),
                  color: context.appColors.textVariant,
                )
              : _KpiFooterMiniList(
                  items: [
                    for (final agg in top2Income)
                      (
                        name: agg.name ?? _findCatName(cats, agg.categoryId),
                        amount: agg.amount,
                      ),
                  ],
                ),
        ),
        _KpiCard(
          kind: _KpiKind.expense,
          icon: '📈',
          label: lang.t('reportMonthly.totalExpenseLabel'),
          amount: report.totalExpense,
          isIncome: false,
          customFooter: top1Expense == null
              ? _KpiFooterText(
                  text: lang.t('reportMonthly.noExpense'),
                  color: context.appColors.textVariant,
                )
              : _KpiFooterText(
                  text:
                      '${lang.t('reportMonthly.topCategoryPrefix')}${top1Expense.name ?? _findCatName(cats, top1Expense.categoryId)} (¥${formatAmount(top1Expense.amount)})',
                  color: context.appColors.error.withValues(alpha: 0.85),
                ),
        ),
      ],
    );
  }

  String _findCatName(List<Category> cats, String? id) {
    if (id == null) return '—';
    for (final cat in cats) {
      if (cat.id == id) return cat.name;
    }
    return '—';
  }
}

/// 年报 KPI 三卡 stacked:无 trend pill,无 footer(对齐 uniapp .kpi-card 仅
/// label + amount)。
class _KpiColumnYearly extends StatelessWidget {
  const _KpiColumnYearly({required this.report, required this.lang});
  final YearlyReport report;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _KpiCard(
          kind: _KpiKind.net,
          icon: '🏦',
          label: lang.t('reportYearly.netSavingsLabel'),
          amount: report.netSavings,
          isIncome: report.netSavings >= 0,
        ),
        _KpiCard(
          kind: _KpiKind.income,
          icon: '📉',
          label: lang.t('reportYearly.totalIncomeLabel'),
          amount: report.totalIncome,
          isIncome: true,
        ),
        _KpiCard(
          kind: _KpiKind.expense,
          icon: '📈',
          label: lang.t('reportYearly.totalExpenseLabel'),
          amount: report.totalExpense,
          isIncome: false,
        ),
      ],
    );
  }
}

enum _KpiKind { net, income, expense }

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.kind,
    required this.icon,
    required this.label,
    required this.amount,
    required this.isIncome,
    this.trendPct,
    this.lastMonthLabel,
    this.customFooter,
  });
  final _KpiKind kind;
  final String icon;
  final String label;
  final double amount;
  final bool isIncome;
  // 月报 net 卡专属:涨跌幅百分比(已 *100)。null → 不显示 trend pill。
  final double? trendPct;
  // 月报 net 卡专属:"较上月" 文案,跟 trendPct 配对显示。
  final String? lastMonthLabel;
  // 月报 income/expense 卡专属:mini-list 或 "topCategoryPrefix" 文本。
  // null → 不显示 footer(年报默认)。
  final Widget? customFooter;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final Color borderColor;
    final Color? tintBg;
    final Color amountColor;
    final Color labelColor;
    final Color iconBg;
    final Color iconFg;
    switch (kind) {
      case _KpiKind.net:
        borderColor = const Color(0xFF005394);
        tintBg = null;
        amountColor = isIncome ? const Color(0xFF10B981) : c.error;
        labelColor = c.textVariant;
        iconBg = const Color(0x1A005394); // 10% blue
        iconFg = const Color(0xFF005394);
      case _KpiKind.income:
        borderColor = const Color(0xFF10B981);
        tintBg = const Color(0x0F10B981); // 6% green
        amountColor = const Color(0xFF10B981);
        labelColor = const Color(0xFF10B981);
        iconBg = const Color(0x2610B981); // 15% green
        iconFg = const Color(0xFF10B981);
      case _KpiKind.expense:
        borderColor = c.error;
        tintBg = const Color(0x0DA70819); // 5% red
        amountColor = c.error;
        labelColor = c.error;
        iconBg = const Color(0x1FA70819); // 12% red
        iconFg = const Color(0xFFA70819);
    }
    final sign = kind == _KpiKind.net
        ? (isIncome ? '' : '-')
        : (isIncome ? '+' : '-');
    final absAmt = amount.abs();
    return IntrinsicHeight(
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        decoration: BoxDecoration(
          color: tintBg ?? c.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧 4px accent。IntrinsicHeight 让这个 Container 跟兄弟等高,
            // 不需要父级给 bounded height (Column-in-ListView 也没有)。
            Container(width: 4, color: borderColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            icon,
                            style: TextStyle(
                              fontSize: 14,
                              color: iconFg,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          label,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '$sign¥${formatAmount(absAmt)}',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trendPct != null && lastMonthLabel != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: trendPct! >= 0
                                  ? const Color(0x1F10B981)
                                  : const Color(0x1AA70819),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  trendPct! >= 0 ? '↑' : '↓',
                                  style: TextStyle(
                                    color: trendPct! >= 0
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFB91C1C),
                                    fontSize: 11,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${trendPct! >= 0 ? '+' : ''}${trendPct!.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: trendPct! >= 0
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFB91C1C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lastMonthLabel!,
                            style: TextStyle(
                              color: c.textVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ] else if (customFooter != null) ...[
                      const SizedBox(height: 6),
                      customFooter!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// income 卡 footer:cat-mini-list(uniapp .cat-mini-row × 2)。
class _KpiFooterMiniList extends StatelessWidget {
  const _KpiFooterMiniList({required this.items});
  final List<({String name, double amount})> items;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(it.name, style: TextStyle(color: c.textVariant, fontSize: 12)),
                Text(
                  '¥${formatAmount(it.amount)}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// expense 卡 footer 或 income 卡空状态:单行文字(uniapp .footer-text /
/// .footer-empty)。
class _KpiFooterText extends StatelessWidget {
  const _KpiFooterText({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 12),
    );
  }
}

/// 图表卡片:uniapp .card(padding 12,bgCard,圆角 8,border 1px divider)。
/// chart-header:左 title,右 legend。
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.legend,
  });
  final String title;
  final Widget child;
  final Widget? legend;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (legend != null) legend!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// chart legend(uniapp .chart-legend):income / expense 圆点 + 文字。
/// incomeColor 默认蓝 #005394(月报折线),年报柱状图传 #006D40 暗绿。
class _ChartLegend extends StatelessWidget {
  const _ChartLegend({this.incomeColor = const Color(0xFF005394)});
  final Color incomeColor;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: incomeColor),
        const SizedBox(width: 4),
        Text(
          lang.t('chart.line.income'),
          style: TextStyle(color: context.appColors.textVariant, fontSize: 11),
        ),
        const SizedBox(width: 12),
        _LegendDot(color: context.appColors.error),
        const SizedBox(width: 4),
        Text(
          lang.t('chart.line.expense'),
          style: TextStyle(color: context.appColors.textVariant, fontSize: 11),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 分类饼图 + cat-list:对齐 uniapp .card + DonutChart + .cat-list(icon +
/// name + amount + pct% + bar)。
///
/// totalValueOverride — 年报 donut 中心总额用 k 格式(¥1.5k),月报不传,默认
/// formatAmount(total)。showPct=false → 不显示 pct%(年报)。compact=true →
/// cat-icon 24dp/text 10dp + cat-name 12dp + cat-amount 12dp(年报用)。
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.emptyKey,
    required this.aggs,
    required this.cats,
    required this.total,
    this.totalValueOverride,
    this.showPct = true,
    this.compact = false,
  });
  final String title;
  final String emptyKey;
  final List<CategoryAggregate> aggs;
  final List<Category> cats;
  final double total;
  final String? totalValueOverride;
  final bool showPct;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final sorted = [...aggs]..sort((a, b) => b.amount.compareTo(a.amount));
    final segments = [
      for (final agg in sorted)
        DonutSegment(
          label: agg.name ?? _findCat(cats, agg.categoryId)?.name ?? '—',
          value: agg.amount,
          color: _parseHex(
            agg.color ?? _findCat(cats, agg.categoryId)?.color ?? '#727782',
          ),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  lang.t(emptyKey),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
              ),
            )
          else ...[
            // donut 340×340(外径 300px,inner 85 + thickness 65),轻微放大。
            // box 340 比 donut 外径大 40px(各 20px)给 tip 浮窗留位。
            SizedBox(
              height: 340,
              child: Center(
                child: SizedBox(
                  width: 340,
                  height: 340,
                  child: DonutChart(
                    segments: segments,
                    totalValue: totalValueOverride ?? formatAmount(total),
                    totalLabel: '总计',
                    hideLegend: true, // 下面自带 .cat-list 更详细,不再画 DonutChart 自带 legend
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final agg in sorted) ...[
              Builder(
                builder: (context) {
                  final cat = _findCat(cats, agg.categoryId);
                  final presColor = _parseHex(
                    agg.color ?? cat?.color ?? '#727782',
                  );
                  final name = agg.name ?? cat?.name ?? '—';
                  final icon = agg.icon ?? cat?.icon ?? '⋯';
                  final pct = total > 0 ? (agg.amount / total * 100).toStringAsFixed(2) : '0.00';
                  final iconSize = compact ? 24.0 : 28.0;
                  final iconFontSize = compact ? 10.0 : 12.0;
                  final nameFontSize = compact ? 12.0 : 13.0;
                  final amountFontSize = compact ? 12.0 : 13.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // .cat-icon:圆 + 13% 颜色背景 + emoji
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              color: presColor.withValues(alpha: 0.13),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              icon,
                              style: TextStyle(
                                fontSize: iconFontSize,
                                color: presColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: c.text,
                                fontSize: nameFontSize,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // .cat-right:amount + (pct% 只在月报展示)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '¥${formatAmount(agg.amount)}',
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: amountFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (showPct)
                                Text(
                                  '$pct%',
                                  style: TextStyle(
                                    color: c.textVariant,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // .cat-bar:对齐 home_screen _CatBarRow(高度 5 + 底色
                      // #E8EEF7 + 圆角 3,Stack + 显式 SizedBox + DecoratedBox)。
                      // 用 SizedBox 锁宽锁高,避免 Container(decoration, no child)
                      // 退化成 0×0 DecoratedBox;¥0 行仍能看到占位 track。
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          return SizedBox(
                            height: 5,
                            width: w,
                            child: Stack(
                              children: [
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
                                if (total > 0 && agg.amount > 0)
                                  SizedBox(
                                    width: w *
                                        (agg.amount / total).clamp(0.0, 1.0),
                                    height: 5,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: presColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Category? _findCat(List<Category> cats, String? id) {
    if (id == null) return null;
    for (final c in cats) {
      if (c.id == id) return c;
    }
    return null;
  }

  Color _parseHex(String hex) {
    var h = hex.replaceFirst('#', '').trim();
    // 兜底:非法 hex(如空串、奇数位、非 0-9a-f 字符)直接用灰,不再让
    // FormatException 飘到控制台(dartvm 1.x 上 FormatException 会让
    // CustomPaint/paint 静默失败,后续曲线就画不出来)。
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length != 6 && h.length != 8) return const Color(0xFF727782);
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(h)) return const Color(0xFF727782);
    return Color(int.parse('FF$h', radix: 16));
  }
}

/// 月报折线图(uniapp LineChart with legend):income 蓝,expense 错误色。
/// 每日收支折线图(对齐 uniapp LineChart.vue):SVG 风格 CustomPaint。
/// - viewBox 800x320,PAD top:20/right:20/bottom:40/left:50
/// - YMAX=4000,9 条 grid 线 + Y 轴标签(0/500/.../4000)
/// - X 轴 7 个标签(1/5/10/15/20/25/30)
/// - Income 曲线下面积填充 10% 蓝
/// - Catmull-Rom 平滑 + round join/cap
/// - 点击/触摸:算最近数据点 → 画 dashed line + 2 个圆点 + 浮窗显示 day/income/expense,
///   1.5s 自动消失,贴边翻转(left/right/center 三种 anchor)。
class _DailyChart extends StatefulWidget {
  const _DailyChart({required this.dailyData});
  final List<DailyDataPoint> dailyData;

  // viewBox 与 PAD/innerW 提到这里供 State 和 Painter 共享。
  static const double _w = 800;
  static const double _h = 320;
  static const double _pt = 20;
  static const double _pr = 20;
  static const double _pb = 40;
  static const double _pl = 50;
  static const double _ymax = 4000;
  static double get innerW => _w - _pl - _pr;
  static double get innerH => _h - _pt - _pb;

  // 暴露给 tooltip 算垂直位置(viewBox 单位,跟 painter 内部一致)。
  static double _ysForTooltip(double v) =>
      _pt + innerH - (v.clamp(0, _ymax) / _ymax) * innerH;

  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  int? _hoverIdx;
  double _hoverLocalX = 0; // 浮窗 left(物理像素,非 viewBox 单位)
  Timer? _hoverTimer;

  @override
  void didUpdateWidget(covariant _DailyChart old) {
    super.didUpdateWidget(old);
    // 数据源切换时清掉 tooltip(否则 idx 可能越界)。
    if (old.dailyData != widget.dailyData) {
      _hoverTimer?.cancel();
      _hoverIdx = null;
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _handleTap(TapDownDetails d, Size size) {
    if (widget.dailyData.isEmpty) return;
    final localX = d.localPosition.dx;
    // localX → viewBox X(0.._w)
    final vbX = (localX / size.width) * _DailyChart._w;
    // 落在绘图区内才命中(对齐 uniapp pickIdx 边界)
    if (vbX < _DailyChart._pl - 10 || vbX > _DailyChart._w - _DailyChart._pr + 10) return;
    final ratio = (vbX - _DailyChart._pl) / _DailyChart.innerW;
    final day = (ratio * (widget.dailyData.length - 1)).round();
    final idx = day.clamp(0, widget.dailyData.length - 1);
    _hoverTimer?.cancel();
    setState(() {
      _hoverIdx = idx;
      _hoverLocalX = localX;
    });
    // 1.5s 自动消失(对齐 uniapp onTouchEnd setTimeout 1500)
    _hoverTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _hoverIdx = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (widget.dailyData.isEmpty) {
      return Center(child: Text('—', style: TextStyle(color: c.textVariant)));
    }
    return AspectRatio(
      aspectRatio: _DailyChart._w / _DailyChart._h,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 触摸覆盖层 + 绘制
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _handleTap(d, size),
                  child: CustomPaint(
                    painter: _DailyChartPainter(
                      data: widget.dailyData,
                      hoverIdx: _hoverIdx,
                      incomeColor: const Color(0xFF005394),
                      expenseColor: c.error,
                      axisColor: const Color(0xFF64748B),
                      gridColor: const Color(0xFFE2E8F0),
                      hoverLineColor: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              // 浮窗:Stack 内绝对定位,位置 = 数据点 viewBox X / total width。
              if (_hoverIdx != null)
                _DailyTooltip(
                  data: widget.dailyData[_hoverIdx!],
                  hoverLocalX: _hoverLocalX,
                  chartWidth: size.width,
                  chartHeight: size.height,
                  incomeColor: const Color(0xFF005394),
                  expenseColor: c.error,
                  cardColor: c.bgCard,
                  borderColor: c.divider,
                  textColor: c.text,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DailyChartPainter extends CustomPainter {
  _DailyChartPainter({
    required this.data,
    required this.incomeColor,
    required this.expenseColor,
    required this.axisColor,
    required this.gridColor,
    required this.hoverLineColor,
    this.hoverIdx,
  });
  final List<DailyDataPoint> data;
  final Color incomeColor;
  final Color expenseColor;
  final Color axisColor;
  final Color gridColor;
  final Color hoverLineColor;
  final int? hoverIdx;

  double _xs(int i) => _DailyChart._pl +
      (i / (data.length - 1).clamp(1, double.infinity)) * _DailyChart.innerW;
  double _ys(double v) => _DailyChart._pt +
      _DailyChart.innerH -
      (v.clamp(0, _DailyChart._ymax) / _DailyChart._ymax) * _DailyChart.innerH;

  // Catmull-Rom → cubic bezier,跟 uniapp smoothPath 一致。直接返回 Path
  // (之前走 SVG 字符串再解析,FormatException 一直从 double.parse 抛)。
  Path _buildPath(List<double> values) {
    final path = Path();
    if (values.isEmpty) return path;
    final pts = [for (var i = 0; i < values.length; i++) Offset(_xs(i), _ys(values[i]))];
    path.moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i - 1 < 0 ? 0 : i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 >= pts.length ? pts.length - 1 : i + 2];
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  // 闭合面积路径 = 折线 + 底边 + close
  Path _buildAreaPath(List<double> values) {
    final p = _buildPath(values);
    if (values.isEmpty) return p;
    final lastX = _xs(values.length - 1);
    final firstX = _xs(0);
    final baseY = _ys(0);
    p.lineTo(lastX, baseY);
    p.lineTo(firstX, baseY);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox → 实际 size 等比映射
    final scaleX = size.width / _DailyChart._w;
    final scaleY = size.height / _DailyChart._h;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // 平滑窗口:对齐 uniapp 月报传 :smoothWindow="1" → 原值。
    final incomeSm = data.map((d) => d.income).toList();
    final expenseSm = data.map((d) => d.expense).toList();
    final incomeVals = incomeSm.map((v) => v.clamp(0, _DailyChart._ymax).toDouble()).toList();
    final expenseVals = expenseSm.map((v) => v.clamp(0, _DailyChart._ymax).toDouble()).toList();

    // 1) Y 轴 grid 灰线
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final v in const [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000]) {
      final y = _ys(v.toDouble());
      canvas.drawLine(Offset(_DailyChart._pl, y), Offset(_DailyChart._w - _DailyChart._pr, y), gridPaint);
    }

    // 2) Income 面积填充(10% 蓝)
    if (data.length > 1) {
      final areaPaint = Paint()
        ..color = incomeColor.withValues(alpha: 0.10)
        ..style = PaintingStyle.fill;
      canvas.drawPath(_buildAreaPath(incomeVals), areaPaint);
    }

    // 3) Income 折线(蓝)
    final incomePaint = Paint()
      ..color = incomeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_buildPath(incomeVals), incomePaint);

    // 4) Expense 折线(红)
    final expensePaint = Paint()
      ..color = expenseColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_buildPath(expenseVals), expensePaint);

    // 5) Y 轴标签(右对齐在 PAD.left 左侧 4px,垂直居中)
    _drawAxisLabels(canvas);

    // 6) hover:虚线竖线 + 收入/支出圆点(对齐 uniapp LineChart.svg hover 元素)
    if (hoverIdx != null && hoverIdx! >= 0 && hoverIdx! < data.length) {
      final hbX = _xs(hoverIdx!);
      // 虚线竖线:从 PAD.top 到 _h - PAD.bottom
      final dashPaint = Paint()
        ..color = hoverLineColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      const dashLen = 3.0;
      const dashGap = 3.0;
      double y = _DailyChart._pt.toDouble();
      final yEnd = _DailyChart._h - _DailyChart._pb;
      while (y < yEnd) {
        final y2 = (y + dashLen).clamp(0, yEnd).toDouble();
        canvas.drawLine(Offset(hbX, y), Offset(hbX, y2), dashPaint);
        y += dashLen + dashGap;
      }
      // 圆点:income (白底蓝边) + expense (白底红边),半径 5
      final pt = data[hoverIdx!];
      final iPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      final iStroke = Paint()
        ..color = incomeColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final eStroke = Paint()
        ..color = expenseColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final iCenter = Offset(hbX, _ys(pt.income.clamp(0, _DailyChart._ymax).toDouble()));
      final eCenter = Offset(hbX, _ys(pt.expense.clamp(0, _DailyChart._ymax).toDouble()));
      canvas.drawCircle(iCenter, 5, iPaint);
      canvas.drawCircle(iCenter, 5, iStroke);
      canvas.drawCircle(eCenter, 5, iPaint);
      canvas.drawCircle(eCenter, 5, eStroke);
    }

    canvas.restore();
  }

  void _drawAxisLabels(Canvas canvas) {
    // 字号 11px 在 viewBox 800x320,实际渲染会跟 scaleX 一起缩放。
    final tp = TextPainter(textDirection: TextDirection.ltr);
    // Y 轴
    for (final v in const [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000]) {
      tp.text = TextSpan(
        text: v.toString(),
        style: TextStyle(
          color: axisColor,
          fontSize: 11,
          fontFamily: '-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif',
        ),
      );
      tp.layout();
      final y = _ys(v.toDouble());
      tp.paint(canvas, Offset(_DailyChart._pl - 4 - tp.width, y - tp.height / 2));
    }
    // X 轴:1/5/10/15/20/25/30(超出 data.length 的不画)
    for (final d in const [1, 5, 10, 15, 20, 25, 30]) {
      if (d < 1 || d > data.length) continue;
      tp.text = TextSpan(
        text: d.toString(),
        style: TextStyle(
          color: axisColor,
          fontSize: 11,
          fontFamily: '-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif',
        ),
      );
      tp.layout();
      final x = _xs(d - 1);
      tp.paint(canvas, Offset(x - tp.width / 2, _DailyChart._h - _DailyChart._pb + 18));
    }
  }

  // 简化 SVG path 解析:只支持 "M x,y [C ...]* [L ...]* Z" 这种格式。
  // 按 command 切片,每段取数字 — 不用正则,直接 split 命令字母,避免
  @override
  bool shouldRepaint(covariant _DailyChartPainter old) =>
      old.data != data ||
      old.incomeColor != incomeColor ||
      old.expenseColor != expenseColor ||
      old.hoverIdx != hoverIdx ||
      old.hoverLineColor != hoverLineColor;
}

/// 点击折线后的浮窗(对齐 uniapp LineChart.vue .tip):显示 day/income/expense。
/// 贴边翻转:left(<20%)|right(>80%)|center(中段)。
class _DailyTooltip extends StatelessWidget {
  const _DailyTooltip({
    required this.data,
    required this.hoverLocalX,
    required this.chartWidth,
    required this.chartHeight,
    required this.incomeColor,
    required this.expenseColor,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
  });
  final DailyDataPoint data;
  final double hoverLocalX;
  final double chartWidth;
  final double chartHeight;
  final Color incomeColor;
  final Color expenseColor;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    // 垂直位置:数据点 income/expense 中较大值的 viewBox Y(viewBox 单位 → 像素)
    final topYVal = data.income > data.expense
        ? data.income.clamp(0, _DailyChart._ymax).toDouble()
        : data.expense.clamp(0, _DailyChart._ymax).toDouble();
    final topYPct = (_DailyChart._ysForTooltip(topYVal) / _DailyChart._h);

    // anchor:left(<0.2) → 浮窗左对齐贴数据点;right(>0.8) → 右对齐;center → 居中
    final ratio = hoverLocalX / chartWidth;
    final AlignmentGeometry align;
    if (ratio < 0.2) {
      align = Alignment(-0.9, 0);
    } else if (ratio > 0.8) {
      align = Alignment(0.9, 0);
    } else {
      align = Alignment.center;
    }

    return Positioned(
      // 水平:数据点 X(像素);垂直:对应 viewBox Y(像素,top:-自身高度浮在数据点上方)
      left: hoverLocalX,
      top: chartHeight * topYPct - 8,
      child: FractionalTranslation(
        translation: const Offset(-0.0, -1.0),
        child: Align(
          alignment: align,
          child: FractionalTranslation(
            // 二次 translate:垂直上移到 tip 顶端到数据点上方,水平按 anchor 偏移
            translation: const Offset(0, -0.15),
            child: Container(
              constraints: const BoxConstraints(minWidth: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.date,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _tipRow(incomeColor, '收入',
                      data.income.round().toString(), textColor),
                  const SizedBox(height: 2),
                  _tipRow(expenseColor, '支出',
                      data.expense.round().toString(), textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tipRow(Color swatchBorder, String label, String value, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: swatchBorder, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label: $value', style: TextStyle(color: textColor, fontSize: 11)),
      ],
    );
  }
}

/// 年报柱状图:对齐 uniapp .bar-chart — 12 个月柱(income 绿/expense 红,
/// 高度按 max 归一化),点击柱子 2s 显示 .bar-tip 气泡(边缘 bar 反向锚定)。
class _MonthlyBarChart extends StatefulWidget {
  const _MonthlyBarChart({required this.data, required this.lang});
  final List<MonthlyDataPoint> data;
  final Lang lang;

  @override
  State<_MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<_MonthlyBarChart> {
  int? _hoverIncomeIdx;
  int? _hoverExpenseIdx;
  int _hoverEpoch = 0; // 上次 tap 的毫秒时间戳,用来检测 2s 自动清除

  void _onTap(int monthIdx, _BarKind kind) {
    setState(() {
      if (kind == _BarKind.income) {
        _hoverIncomeIdx = monthIdx;
      } else {
        _hoverExpenseIdx = monthIdx;
      }
    });
    _hoverEpoch = DateTime.now().millisecondsSinceEpoch;
    final capturedEpoch = _hoverEpoch;
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      // 2s 内又被 tap 过 → 让新的 callback 处理,不清除
      if (_hoverEpoch != capturedEpoch) return;
      setState(() {
        if (kind == _BarKind.income) _hoverIncomeIdx = null;
        if (kind == _BarKind.expense) _hoverExpenseIdx = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final c = context.appColors;
    final monthLabels = [
      lang.t('reportYearly.monthJan'),
      lang.t('reportYearly.monthFeb'),
      lang.t('reportYearly.monthMar'),
      lang.t('reportYearly.monthApr'),
      lang.t('reportYearly.monthMay'),
      lang.t('reportYearly.monthJun'),
      lang.t('reportYearly.monthJul'),
      lang.t('reportYearly.monthAug'),
      lang.t('reportYearly.monthSep'),
      lang.t('reportYearly.monthOct'),
      lang.t('reportYearly.monthNov'),
      lang.t('reportYearly.monthDec'),
    ];

    final rawMax = widget.data.fold<double>(
      0,
      (m, d) => [m, d.income, d.expense].reduce((a, b) => a > b ? a : b),
    );
    final yAxisMax = (rawMax == 0 ? 10000.0 : (rawMax / 5000).ceil() * 5000);
    // bar 高度上限 100dp(uniapp .bar { max-height: 160rpx ≈ 80dp } 取整)。
    const maxBarHeight = 80.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // 上方柱状图区(Uniapp .bar-chart:padding-top 30dp 给 tooltip 留位)。
            SizedBox(
              height: maxBarHeight + 40, // tooltip 占顶部 30 + bar 区
              child: Stack(
                children: [
                  // 12 个柱子均匀分布
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < widget.data.length; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onTap(i, _BarKind.income),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // 双柱一组(income 在上,expense 在下,uniapp 同款)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _Bar(
                                          height: yAxisMax > 0
                                              ? (widget.data[i].income /
                                                      yAxisMax) *
                                                  maxBarHeight
                                              : 0,
                                          color: const Color(0xFF006D40),
                                          onTap: () => _onTap(
                                            i,
                                            _BarKind.income,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        _Bar(
                                          height: yAxisMax > 0
                                              ? (widget.data[i].expense /
                                                      yAxisMax) *
                                                  maxBarHeight
                                              : 0,
                                          color: c.error,
                                          onTap: () => _onTap(
                                            i,
                                            _BarKind.expense,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // tooltip overlay
                  if (_hoverIncomeIdx != null &&
                      widget.data[_hoverIncomeIdx!].income > 0)
                    _BarTip(
                      monthIdx: _hoverIncomeIdx!,
                      color: const Color(0xFF006D40),
                      label: lang.t('chart.line.income'),
                      amount: widget.data[_hoverIncomeIdx!].income,
                      total: widget.data.length,
                      maxWidth: constraints.maxWidth,
                    ),
                  if (_hoverExpenseIdx != null &&
                      widget.data[_hoverExpenseIdx!].expense > 0)
                    _BarTip(
                      monthIdx: _hoverExpenseIdx!,
                      color: c.error,
                      label: lang.t('chart.line.expense'),
                      amount: widget.data[_hoverExpenseIdx!].expense,
                      total: widget.data.length,
                      maxWidth: constraints.maxWidth,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 月份 label 行
            Row(
              children: [
                for (final ml in monthLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        ml,
                        style: TextStyle(color: c.textVariant, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

enum _BarKind { income, expense }

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.color,
    required this.onTap,
  });
  final double height;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 10,
        height: height > 2 ? height : 2,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
    );
  }
}

class _BarTip extends StatelessWidget {
  const _BarTip({
    required this.monthIdx,
    required this.color,
    required this.label,
    required this.amount,
    required this.total,
    required this.maxWidth,
  });
  final int monthIdx;
  final Color color;
  final String label;
  final double amount;
  final int total;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // 边缘 bar 反向锚定(uniapp .tip-left/.tip-right),避免被裁切
    final alignLeft = monthIdx <= 1;
    final alignRight = monthIdx >= 10;
    // 按 (i + 0.5) / total 比例计算水平位置
    final centerX = (monthIdx + 0.5) / total * maxWidth;
    double dx = centerX - 70; // tooltip 宽 ~140,默认居中
    if (alignLeft) {
      dx = centerX;
    } else if (alignRight) {
      dx = centerX - 140;
    }
    return Positioned(
      left: dx.clamp(0, maxWidth - 140),
      top: 2,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: c.bgCard,
            border: Border.all(color: c.divider),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.08),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '¥${formatAmount(amount)}',
                style: TextStyle(color: c.text, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}