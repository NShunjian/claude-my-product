import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../shared/charts/donut_chart.dart';
import '../shared/providers.dart';

/// 对齐 pages/baobiao/index.vue — 月度 + 年度报表 tabBar。
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _month = formatLocalMonth(DateTime.now());
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('pageTitle.reportMonthly')),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: lang.t('reportMonthly.tabMonthly')),
            Tab(text: lang.t('reportMonthly.tabYearly')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MonthlyTab(month: _month, onMonthChanged: (m) {
            setState(() => _month = m);
          }),
          _YearlyTab(year: _year, onYearChanged: (y) {
            setState(() => _year = y);
          }),
        ],
      ),
    );
  }
}

class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab({required this.month, required this.onMonthChanged});
  final String month;
  final ValueChanged<String> onMonthChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final bookId = ref.watch(currentBookIdProvider);
    final future = ref
        .read(reportsApiProvider)
        .getMonthly(month: month, bookId: bookId.isEmpty ? null : bookId);
    return FutureBuilder<MonthlyReport>(
      future: future,
      builder: (context, snap) {
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
        final r = snap.data!;
        final cats = ref.read(categoriesApiProvider);
        return FutureBuilder<List<Category>>(
          future: cats.listCategories(),
          builder: (context, catsSnap) {
            final catList = catsSnap.data ?? const [];
            final expSegs = _buildSegments(r.expenseByCategory, catList);
            final incSegs = _buildSegments(r.incomeByCategory, catList);
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.t('reportMonthly.monthYear', {
                      'y': month.split('-').first,
                      'm': month.split('-').last,
                    })),
                    TextButton.icon(
                      onPressed: () async {
                        final parts = month.split('-');
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(
                            int.parse(parts[0]),
                            int.parse(parts[1]),
                          ),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          helpText: lang.t('reportMonthly.pickMonth'),
                        );
                        if (picked != null) {
                          onMonthChanged(formatLocalMonth(picked));
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(lang.t('common.edit')),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryRow(report: r),
                const SizedBox(height: AppSpacing.lg),
                Text(lang.t('reportMonthly.expenseByCategory'),
                    style: TextStyle(color: c.text, fontSize: 14)),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 220,
                  child: expSegs.isEmpty
                      ? Center(
                          child: Text(
                            lang.t('reportMonthly.noExpense'),
                            style: TextStyle(color: c.textVariant),
                          ),
                        )
                      : DonutChart(
                          segments: expSegs,
                          totalValue: formatAmount(r.totalExpense),
                          totalLabel: lang.t('reportMonthly.totalExpense'),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(lang.t('reportMonthly.incomeByCategory'),
                    style: TextStyle(color: c.text, fontSize: 14)),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 220,
                  child: incSegs.isEmpty
                      ? Center(
                          child: Text(
                            lang.t('reportMonthly.noIncome'),
                            style: TextStyle(color: c.textVariant),
                          ),
                        )
                      : DonutChart(
                          segments: incSegs,
                          totalValue: formatAmount(r.totalIncome),
                          totalLabel: lang.t('reportMonthly.totalIncome'),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(lang.t('reportMonthly.dailyTrend'),
                    style: TextStyle(color: c.text, fontSize: 14)),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 200,
                  child: _DailyChart(dailyData: r.dailyData),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<DonutSegment> _buildSegments(
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
              ? Color(int.parse('FF${cat.color.replaceFirst('#', '')}',
                  radix: 16))
              : Colors.grey;
          return DonutSegment(
            label: cat.name.isEmpty ? '—' : cat.name,
            value: agg.amount,
            color: color,
          );
        })(),
    ];
  }
}

class _YearlyTab extends ConsumerWidget {
  const _YearlyTab({required this.year, required this.onYearChanged});
  final int year;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final bookId = ref.watch(currentBookIdProvider);
    final future = ref
        .read(reportsApiProvider)
        .getYearly(year: year, bookId: bookId.isEmpty ? null : bookId);
    return FutureBuilder<YearlyReport>(
      future: future,
      builder: (context, snap) {
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
        final r = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(lang.t('reportYearly.yearOnly', {'y': year})),
            const SizedBox(height: AppSpacing.md),
            _YearlySummary(report: r),
            const SizedBox(height: AppSpacing.lg),
            Text(lang.t('reportYearly.monthlyTrend'),
                style: TextStyle(color: c.text, fontSize: 14)),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(height: 220, child: _MonthlyChart(data: r.monthlyData)),
            const SizedBox(height: AppSpacing.lg),
            Text(lang.t('reportYearly.expenseByCategory'),
                style: TextStyle(color: c.text, fontSize: 14)),
            const SizedBox(height: AppSpacing.sm),
            ...r.expenseByCategory.map((agg) => ListTile(
                  title: Text(agg.categoryId ?? lang.t('reportYearly.other')),
                  trailing: Text(formatAmount(agg.amount, withSymbol: true)),
                )),
          ],
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Metric(
          label: lang.t('reportMonthly.totalIncome'),
          value: formatAmount(report.totalIncome, withSymbol: true),
          color: const Color(0xFF2E7DE6),
        ),
        _Metric(
          label: lang.t('reportMonthly.totalExpense'),
          value: formatAmount(report.totalExpense, withSymbol: true),
          color: c.error,
        ),
        _Metric(
          label: lang.t('reportMonthly.netSavings'),
          value: formatAmount(report.netSavings, withSymbol: true),
          color: report.netSavings >= 0 ? c.primary : c.error,
        ),
      ],
    );
  }
}

class _YearlySummary extends StatelessWidget {
  const _YearlySummary({required this.report});
  final YearlyReport report;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Metric(
          label: lang.t('reportYearly.totalIncome'),
          value: formatAmount(report.totalIncome, withSymbol: true),
          color: const Color(0xFF2E7DE6),
        ),
        _Metric(
          label: lang.t('reportYearly.totalExpense'),
          value: formatAmount(report.totalExpense, withSymbol: true),
          color: c.error,
        ),
        _Metric(
          label: lang.t('reportYearly.netSavings'),
          value: formatAmount(report.netSavings, withSymbol: true),
          color: report.netSavings >= 0 ? c.primary : c.error,
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: c.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
      return Center(
        child: Text('—', style: TextStyle(color: c.textVariant)),
      );
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
            color: const Color(0xFF2E7DE6),
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
      return Center(
        child: Text('—', style: TextStyle(color: c.textVariant)),
      );
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
            color: const Color(0xFF2E7DE6),
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