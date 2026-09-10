import 'dart:async';
import 'dart:math' as math;

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

/// 对齐 components/DonutChart.vue — fl_chart PieChart + 中心数值 + 图例 +
/// segment 点击浮窗(label + ¥amount + pct%,挂在命中段中线外侧,贴边翻转,
/// 2s 自动消失)。
///
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
  Timer? _hoverTimer;

  @override
  void didUpdateWidget(covariant DonutChart old) {
    super.didUpdateWidget(old);
    if (old.segments != widget.segments) {
      _hoverTimer?.cancel();
      _hoverIdx = null;
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _onTouch(FlTouchEvent event, PieTouchResponse? response) {
    final idx = response?.touchedSection?.touchedSectionIndex;
    if (idx == null || idx < 0 || idx >= widget.segments.length) {
      // 点空(中心孔/外圈):保留 hover(uniapp H5 clearHover 是 tap 整个 wrap 才清,平时不清)
      return;
    }
    _hoverTimer?.cancel();
    setState(() => _hoverIdx = idx);
    // 2s 自动消失(对齐 uniapp onTap setTimeout 2000)
    _hoverTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _hoverIdx = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (widget.segments.isEmpty || widget.segments.every((s) => s.value == 0)) {
      return Center(
        child: Text('—', style: TextStyle(color: c.textVariant)),
      );
    }
    final total = widget.segments.fold<double>(0, (s, e) => s + e.value);
    if (widget.hideLegend) {
      return AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: PieChart(
                    PieChartData(
                      // ponytail: sectionsSpace=0 让扇区无缝拼接(uniapp DonutChart
                      // 的扇区在 SVG 层是 path 而不是 circle,本来就没缝)。
                      sectionsSpace: 0,
                      // 340px box 下:内孔 85 + 环厚 65 = 外径 300,轻微放大。
                      centerSpaceRadius: 85,
                      pieTouchData: PieTouchData(
                        touchCallback: _onTouch,
                      ),
                      sections: [
                        for (int i = 0; i < widget.segments.length; i++)
                          PieChartSectionData(
                            value: widget.segments[i].value,
                            color: widget.segments[i].color,
                            // hover 只比 normal 大 5(轻微放大效果,不要夸张弹出)。
                            radius: _hoverIdx == i ? 70 : 65,
                            title: '',
                          ),
                      ],
                    ),
                  ),
                ),
                // 中心文字("总计 / ¥...")— PieChart 中心孔是透明的,得自己叠
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CenterTextPainter(
                        label: widget.totalLabel,
                        value: widget.totalValue,
                        labelColor: c.textVariant,
                        valueColor: c.text,
                      ),
                    ),
                  ),
                ),
                if (_hoverIdx != null && _hoverIdx! < widget.segments.length)
                  _SegmentTip(
                    segments: widget.segments,
                    total: total,
                    idx: _hoverIdx!,
                    size: size,
                    cardColor: c.bgCard,
                    borderColor: c.divider,
                    textColor: c.text,
                    textVariantColor: c.textVariant,
                  ),
              ],
            );
          },
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 85,
                pieTouchData: PieTouchData(touchCallback: _onTouch),
                sections: [
                  for (int i = 0; i < widget.segments.length; i++)
                    PieChartSectionData(
                      value: widget.segments[i].value,
                      color: widget.segments[i].color,
                      radius: _hoverIdx == i ? 70 : 65,
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
              for (int i = 0; i < widget.segments.length; i++)
                Padding(
                  // vertical: 1 (不是 2) — 给 Column 在 flex=3 / h=180 约束下留
                  // ~1px 余量,干掉 "RenderFlex overflowed by 1px"。
                  padding: const EdgeInsets.symmetric(vertical: 1),
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
                            ? '${(widget.segments[i].value / total * 100).toStringAsFixed(2)}%'
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

/// segment 命中浮窗(对齐 uniapp DonutChart.vue .seg-tip)。
/// 位置 = segment 中线角 + radius + 12(外侧),贴边翻转 left/center/right。
class _SegmentTip extends StatelessWidget {
  const _SegmentTip({
    required this.segments,
    required this.total,
    required this.idx,
    required this.size,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.textVariantColor,
  });

  final List<DonutSegment> segments;
  final double total;
  final int idx;
  final Size size;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color textVariantColor;

  @override
  Widget build(BuildContext context) {
    final seg = segments[idx];
    // 计算该 segment 中线角(uniapp 用 SVG path 的 mid angle,FlChart 没有
    // 直接 API,从 values 累推)。
    double acc = 0;
    for (int i = 0; i < idx; i++) {
      acc += segments[i].value;
    }
    final startDeg = (acc / total) * 360.0;
    final endDeg = ((acc + seg.value) / total) * 360.0;
    final midDeg = (startDeg + endDeg) / 2.0;
    // uniapp: tipR = radius + 12(外侧),锚定到该角的圆周上。FlChart 没暴露
    // 外径(我们传的是 inner=85 + thickness=65 = outer=150),取 0.48 * size
    // 略大于外径(163),加 12 当 tip offset,效果一致。
    final midRad = (midDeg - 90) * math.pi / 180.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tipR = size.width * 0.48 + 12;
    final tipX = cx + math.cos(midRad) * tipR;
    final tipY = cy + math.sin(midRad) * tipR;

    // 贴边翻转(对齐 uniapp mpTipAnchor):cos > 0.3 → tip-right
    final c = math.cos(midRad);
    final anchor =
        c > 0.3 ? _TipAnchor.right : (c < -0.3 ? _TipAnchor.left : _TipAnchor.center);

    final pct = total > 0 ? (seg.value / total * 100).toStringAsFixed(2) : '0.00';

    return Positioned(
      left: tipX,
      top: tipY,
      child: FractionalTranslation(
        translation: anchor == _TipAnchor.left
            ? const Offset(0, -0.5)
            : anchor == _TipAnchor.right
                ? const Offset(-1, -0.5)
                : const Offset(-0.5, -0.5),
        child: Container(
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: seg.color, width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    seg.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '¥${seg.value.round().toString()}',
                style: TextStyle(color: textColor, fontSize: 10),
              ),
              const SizedBox(height: 1),
              Text(
                '$pct%',
                style: TextStyle(color: textVariantColor, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TipAnchor { left, center, right }

/// 把 "总计 / ¥value" 中心文字画在 donut 中心(因为 PieChart 占了整个 AspectRatio,
/// 中心孔是 fl_chart 内部 transparent,我们用 CustomPaint 覆盖)。
class _CenterTextPainter extends CustomPainter {
  _CenterTextPainter({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });
  final String? label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    // 中心文字两行(label + value),整体垂直居中。centerSpaceRadius=50
    // → 中心孔直径 100px,所以 text 总高度 ~36px 完全能装下。
    double yCursor = cy - 18;
    if (label != null) {
      tp.text = TextSpan(
        text: label,
        style: TextStyle(color: labelColor, fontSize: 12),
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, yCursor));
      yCursor += tp.height + 4;
    }
    tp.text = TextSpan(
      text: value,
      style: TextStyle(
        color: valueColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, yCursor));
  }

  @override
  bool shouldRepaint(covariant _CenterTextPainter old) =>
      old.label != label ||
      old.value != value ||
      old.labelColor != labelColor ||
      old.valueColor != valueColor;
}