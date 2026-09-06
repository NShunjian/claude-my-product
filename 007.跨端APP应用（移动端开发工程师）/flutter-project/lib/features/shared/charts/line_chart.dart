import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class LineChartPoint {
  LineChartPoint({required this.x, required this.y});
  final int x; // day-of-month 1..31
  final double y;
}

/// 对齐 components/charts/LineChart.vue — 双折线(收入/支出)。
/// 原组件用 SVG 平滑曲线;Flutter 用 fl_chart 的 LineChart,smoothWindow 对应 lineBars。
class AppLineChart extends StatelessWidget {
  const AppLineChart({
    super.key,
    required this.income,
    required this.expense,
    this.maxY,
  });

  final List<LineChartPoint> income;
  final List<LineChartPoint> expense;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final all = [...income, ...expense].map((p) => p.y);
    final yMax = maxY ?? (all.isEmpty ? 100 : all.reduce((a, b) => a > b ? a : b) * 1.15);
    final dayMax = [
      ...income.map((p) => p.x),
      ...expense.map((p) => p.x),
    ].fold<int>(1, (a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 1,
        maxX: dayMax.toDouble(),
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: c.divider,
            strokeWidth: 0.5,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (dayMax / 5).ceilToDouble().clamp(1, dayMax.toDouble()),
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(color: c.textVariant, fontSize: 10),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: yMax / 4,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: TextStyle(color: c.textVariant, fontSize: 10),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final p in income) FlSpot(p.x.toDouble(), p.y)],
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFF2E7DE6),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: [for (final p in expense) FlSpot(p.x.toDouble(), p.y)],
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFFBA1A1A),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
