import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../../core/utils/tab_refresh_signal.dart';
import '../shared/charts/donut_chart.dart';
import '../shared/providers.dart';

/// 对齐 pages/reports/monthly.vue — 自绘分段 Tab + 头部 + KPI 三卡 + 图表。
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
      appBar: AppBar(
        title: Text(lang.t('pageTitle.reportMonthly')),
      ),
      body: Column(
        children: [
          if (_mode == 0)
            _MonthlyTab(
              month: _month,
              onMonthChanged: (m) => setState(() => _month = m),
              header: _Header(
                title: lang.t('reportMonthly.title'),
                subtitle:
                    '${_month.split('-').first}年 ${int.parse(_month.split('-').last)}月',
                rightCtrl: _MonthCtrl(
                  month: _month,
                  onPicked: (m) => setState(() => _month = m),
                ),
              ),
            )
          else
            _YearlyTab(
              year: _year,
              onYearChanged: (y) => setState(() => _year = y),
              header: _Header(
                title: lang.t('reportYearly.title'),
                subtitle: '$_year年',
                rightCtrl: _YearCtrl(
                  year: _year,
                  onPicked: (y) => setState(() => _year = y),
                ),
              ),
            ),
          // 自绘分段控件(uniapp .tab-bar:surface bg,radius 6dp,padding 2dp,
          // .tab.active:bgCard+primary text+w600)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
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
        ],
      ),
    );
  }
}

/// 头部行:左侧 title-block(page-title + page-subtitle),右侧 month/year ctrl。
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
        AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
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

/// 月份选择控件:对齐 uniapp MonthPicker("YYYY年M月" + 月历图标)。
class _MonthCtrl extends StatelessWidget {
  const _MonthCtrl({required this.month, required this.onPicked});
  final String month;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () async {
          final parts = month.split('-');
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(int.parse(parts[0]), int.parse(parts[1])),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            helpText: lang.t('reportMonthly.pickMonth'),
          );
          if (picked != null) onPicked(formatLocalMonth(picked));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            month,
            style: TextStyle(color: c.text, fontSize: 13),
          ),
        ),
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
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
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

class _MonthlyTab extends ConsumerStatefulWidget {
  const _MonthlyTab({
    required this.month,
    required this.onMonthChanged,
    required this.header,
  });
  final String month;
  final ValueChanged<String> onMonthChanged;
  final Widget header;

  @override
  ConsumerState<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends ConsumerState<_MonthlyTab> {
  late Future<MonthlyReport> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // ponytail: 切到 reports tab 时重拉月报(3)。next>prev 才触发,初始 0 不触发。
    ref.listenManual<int>(tabRefreshSignalProvider(2), (prev, next) {
      if (prev != null && next > prev) _reload();
    });
  }

  @override
  void didUpdateWidget(covariant _MonthlyTab old) {
    super.didUpdateWidget(old);
    // 月份切换 → 重新拉数据(月报依赖 month 参数)。
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
    return Expanded(
      child: FutureBuilder<MonthlyReport>(
        future: _future,
        builder: (context, snap) {
          // 首次加载还没数据 → 整页占位
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
          // 已有数据(包括刷新中的 stale snapshot)→ 渲染数据,顶部加进度条
          final r = snap.data!;
          final isReloading =
              snap.connectionState != ConnectionState.done;
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
                    final expSegs = _buildMonthlySegments(
                      r.expenseByCategory,
                      catList,
                    );
                    final incSegs = _buildMonthlySegments(
                      r.incomeByCategory,
                      catList,
                    );
                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        widget.header,
                        const SizedBox(height: AppSpacing.lg),
                        _KpiColumn(
                          report: r,
                          lang: lang,
                          isYearly: false,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ChartCard(
                          title: lang.t('reportMonthly.dailyTrend'),
                          child: SizedBox(
                            height: 160,
                            child: _DailyChart(dailyData: r.dailyData),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _CategoryCard(
                          title: lang.t('reportMonthly.incomeShare'),
                          emptyKey: 'reportMonthly.noIncomeRecords',
                          segments: incSegs,
                          total: r.totalIncome,
                          totalLabel: lang.t('reportMonthly.totalIncome'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _CategoryCard(
                          title: lang.t('reportMonthly.expenseShare'),
                          emptyKey: 'reportMonthly.noExpenseRecords',
                          segments: expSegs,
                          total: r.totalExpense,
                          totalLabel: lang.t('reportMonthly.totalExpense'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

List<DonutSegment> _buildMonthlySegments(
  List<CategoryAggregate> aggs,
  List<Category> cats,
) {
  return [
    for (final agg in aggs)
      (() {
        final cat = cats.firstWhere(
          (c) => c.id == agg.categoryId,
          orElse: () => Category(
            id: agg.categoryId ?? '',
            type: CategoryType.expense,
            name: agg.categoryId ?? '',
            icon: '',
            color: '#727782',
            sortOrder: 0,
            isPreset: false,
          ),
        );
        final color = cat.color.startsWith('#')
            ? Color(
                int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16),
              )
            : Colors.grey;
        return DonutSegment(
          label: cat.name.isEmpty ? '—' : cat.name,
          value: agg.amount,
          color: color,
        );
      })(),
  ];
}

class _YearlyTab extends ConsumerStatefulWidget {
  const _YearlyTab({
    required this.year,
    required this.onYearChanged,
    required this.header,
  });
  final int year;
  final ValueChanged<int> onYearChanged;
  final Widget header;

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
    // 年份切换 → 重新拉数据(年报依赖 year 参数)。
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
    return Expanded(
      child: FutureBuilder<YearlyReport>(
        future: _future,
        builder: (context, snap) {
          // 首次加载还没数据 → 整页占位
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
          // 已有数据(包括刷新中的 stale snapshot)→ 渲染数据,顶部加进度条
          final r = snap.data!;
          final isReloading =
              snap.connectionState != ConnectionState.done;
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
                    final expSegs = _buildYearlySegments(
                      r.expenseByCategory,
                      catList,
                    );
                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        widget.header,
                        const SizedBox(height: AppSpacing.lg),
                        _KpiColumn(
                          report: r,
                          lang: lang,
                          isYearly: true,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ChartCard(
                          title: lang.t('reportYearly.monthlyTrend'),
                          child: SizedBox(
                            height: 160,
                            child: _MonthlyChart(data: r.monthlyData),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _CategoryCard(
                          title: lang.t('reportYearly.expenseBreakdown'),
                          emptyKey: 'reportYearly.noExpenseRecords',
                          segments: expSegs,
                          total: r.totalExpense,
                          totalLabel: lang.t('reportYearly.totalExpense'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

List<DonutSegment> _buildYearlySegments(
  List<CategoryAggregate> aggs,
  List<Category> cats,
) {
  return [
    for (final agg in aggs)
      (() {
        final cat = cats.firstWhere(
          (c) => c.id == agg.categoryId,
          orElse: () => Category(
            id: agg.categoryId ?? '',
            type: CategoryType.expense,
            name: agg.categoryId ?? '',
            icon: '',
            color: '#727782',
            sortOrder: 0,
            isPreset: false,
          ),
        );
        final color = cat.color.startsWith('#')
            ? Color(
                int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16),
              )
            : Colors.grey;
        return DonutSegment(
          label: cat.name.isEmpty ? '—' : cat.name,
          value: agg.amount,
          color: color,
        );
      })(),
  ];
}

/// KPI 三卡 stacked(uniapp .kpi-list + .kpi-card + .kpi-net/income/expense 配色)。
class _KpiColumn extends StatelessWidget {
  const _KpiColumn({required this.report, required this.lang, required this.isYearly});
  final dynamic report; // MonthlyReport | YearlyReport
  final dynamic lang; // I18n (avoid hard dep on Lang type)
  final bool isYearly;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final totalIncome = report.totalIncome as double;
    final totalExpense = report.totalExpense as double;
    final netSavings = report.netSavings as double;
    return Column(
      children: [
        _KpiCard(
          kind: _KpiKind.net,
          icon: '🏦',
          label: lang.t(isYearly ? 'reportYearly.netSavingsLabel' : 'reportMonthly.netSavings'),
          amount: netSavings,
          isIncome: netSavings >= 0,
        ),
        _KpiCard(
          kind: _KpiKind.income,
          icon: '📉',
          label: lang.t(isYearly ? 'reportYearly.totalIncomeLabel' : 'reportMonthly.totalIncomeLabel'),
          amount: totalIncome,
          isIncome: true,
        ),
        _KpiCard(
          kind: _KpiKind.expense,
          icon: '📈',
          label: lang.t(isYearly ? 'reportYearly.totalExpenseLabel' : 'reportMonthly.totalExpenseLabel'),
          amount: totalExpense,
          isIncome: false,
        ),
        // keep c usage to avoid unused warning
        SizedBox(height: c.bg == c.bg ? 0 : 0),
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
  });
  final _KpiKind kind;
  final String icon;
  final String label;
  final double amount;
  final bool isIncome;

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
    return Container(
      margin: EdgeInsets.only(top: kind == _KpiKind.net ? AppSpacing.md : AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tintBg ?? c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          top: const BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
          right: const BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
          bottom: const BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(icon, style: TextStyle(fontSize: 14, color: iconFg)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
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
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.emptyKey,
    required this.segments,
    required this.total,
    required this.totalLabel,
  });
  final String title;
  final String emptyKey;
  final List<DonutSegment> segments;
  final double total;
  final String totalLabel;

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
          Text(title, style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          if (segments.isEmpty)
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
            SizedBox(
              height: 180,
              child: DonutChart(
                segments: segments,
                totalValue: formatAmount(total),
                totalLabel: totalLabel,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final s in segments) ...[
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      s.label,
                      style: TextStyle(color: c.text, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '¥${formatAmount(s.value)}',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: total > 0 ? (s.value / total).clamp(0.0, 1.0) : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.dailyData});
  final List<DailyDataPoint> dailyData;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (dailyData.isEmpty) {
      return Center(child: Text('—', style: TextStyle(color: c.textVariant)));
    }
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    for (var i = 0; i < dailyData.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), dailyData[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), dailyData[i].expense));
    }
    return LineChart(
      LineChartData(
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            color: const Color(0xFF005394),
            isCurved: true,
            barWidth: 2,
          ),
          LineChartBarData(
            spots: expenseSpots,
            color: c.error,
            isCurved: true,
            barWidth: 2,
          ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.data});
  final List<MonthlyDataPoint> data;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (data.isEmpty) {
      return Center(child: Text('—', style: TextStyle(color: c.textVariant)));
    }
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), data[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), data[i].expense));
    }
    return LineChart(
      LineChartData(
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            color: const Color(0xFF005394),
            isCurved: true,
            barWidth: 2,
          ),
          LineChartBarData(
            spots: expenseSpots,
            color: c.error,
            isCurved: true,
            barWidth: 2,
          ),
        ],
      ),
    );
  }
}