import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class DonutSegment {
  DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;
}

/// 对齐 components/DonutChart.vue — fl_chart PieChart + 中心数值 + 图例。
/// 原 uniapp 用 SVG 弧或 conic-gradient 兜底,Flutter 直接 PieChart 稳定。
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.segments,
    required this.totalValue,
    this.totalLabel,
    this.hideLegend = false,
  });

  final List<DonutSegment> segments;
  final String totalValue;
  final String? totalLabel;
  final bool hideLegend;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int? _hoverIdx;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (widget.segments.isEmpty || widget.segments.every((s) => s.value == 0)) {
      return Center(
        child: Text('—', style: TextStyle(color: c.textVariant)),
      );
    }
    final total = widget.segments.fold<double>(0, (s, e) => s + e.value);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _hoverIdx = response?.touchedSection?.touchedSectionIndex;
                    });
                  },
                ),
                sections: [
                  for (int i = 0; i < widget.segments.length; i++)
                    PieChartSectionData(
                      value: widget.segments[i].value,
                      color: widget.segments[i].color,
                      radius: _hoverIdx == i ? 50 : 40,
                      title: '',
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.totalLabel != null)
                Text(widget.totalLabel!, style: TextStyle(color: c.textVariant, fontSize: 12)),
              const SizedBox(height: AppSpacing.xs),
              Text(widget.totalValue,
                  style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              if (!widget.hideLegend)
                for (int i = 0; i < widget.segments.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: widget.segments[i].color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            widget.segments[i].label,
                            style: TextStyle(color: c.text, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          total > 0
                              ? '${(widget.segments[i].value / total * 100).toStringAsFixed(1)}%'
                              : '0%',
                          style: TextStyle(color: c.textVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
