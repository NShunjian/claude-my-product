import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// iOS 风格滚轮日期选择器 — 对齐 uniapp `<picker mode="date">`:
/// 顶部 header(取消/完成)+ 3 列滚轮(年/月/日)。
/// 边缘项按距选中行的距离做颜色/字重渐变(锐利文字 + 由黑到灰),
/// 中间选中行加上下细线高亮带 — 跟截图里 iOS picker 视觉对齐。
class WheelDatePicker {
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initial,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      // 背景 dim — 跟截图里弹起选择器后背后 QuickAddModal 透出柔光的视觉一致。
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (ctx) => _WheelDatePickerSheet(
        initial: initial,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime(2100),
      ),
    );
  }
}

class _WheelDatePickerSheet extends StatefulWidget {
  const _WheelDatePickerSheet({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_WheelDatePickerSheet> createState() => _WheelDatePickerSheetState();
}

class _WheelDatePickerSheetState extends State<_WheelDatePickerSheet> {
  static const double _itemExtent = 40;
  static const double _pickerHeight = 220;

  late int _year;
  late int _month;
  late int _day;
  // 当前选中项的索引 — 滚动时更新,用来给每项算"距选中多远"做颜色渐变。
  late int _yearIdx;
  late int _monthIdx;
  late int _dayIdx;

  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
    _day = widget.initial.day;
    _yearIdx = (_year - widget.firstDate.year).clamp(0, 9999);
    _monthIdx = _month - 1;
    _dayIdx = _day - 1;
    _yearCtrl = FixedExtentScrollController(initialItem: _yearIdx);
    _monthCtrl = FixedExtentScrollController(initialItem: _monthIdx);
    _dayCtrl = FixedExtentScrollController(initialItem: _dayIdx);
  }

  int get _yearCount => widget.lastDate.year - widget.firstDate.year + 1;

  int get _daysInMonth {
    final next = _month == 12
        ? DateTime(_year + 1, 1, 1)
        : DateTime(_year, _month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  void _clampDay() {
    if (_day > _daysInMonth) {
      _day = _daysInMonth;
      _dayIdx = _day - 1;
      // 等 build 完再 jumpToItem,避免 controller 还未 attach
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dayCtrl.hasClients) {
          _dayCtrl.jumpToItem(_dayIdx);
        }
      });
    }
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () =>
                Navigator.of(context).pop(DateTime(_year, _month, _day)),
          ),
          SizedBox(
            height: _pickerHeight,
            child: Stack(
              children: [
                // 1. 三列滚轮 — 每项根据距离选中行的位置算颜色/字重。
                Row(
                  children: [
                    Expanded(
                      child: _WheelColumn(
                        controller: _yearCtrl,
                        count: _yearCount,
                        currentIndex: _yearIdx,
                        builder: (i) =>
                            '${widget.firstDate.year + i}年',
                        onChanged: (i) {
                          setState(() {
                            _year = widget.firstDate.year + i;
                            _yearIdx = i;
                            _clampDay();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _WheelColumn(
                        controller: _monthCtrl,
                        count: 12,
                        currentIndex: _monthIdx,
                        builder: (i) =>
                            '${(i + 1).toString().padLeft(2, '0')}月',
                        onChanged: (i) {
                          setState(() {
                            _month = i + 1;
                            _monthIdx = i;
                            _clampDay();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _WheelColumn(
                        controller: _dayCtrl,
                        count: _daysInMonth,
                        currentIndex: _dayIdx,
                        builder: (i) =>
                            '${(i + 1).toString().padLeft(2, '0')}日',
                        onChanged: (i) {
                          setState(() {
                            _day = i + 1;
                            _dayIdx = i;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // 2. 中心高亮带 — 上下各一条细线,跟截图里选中行的"上下横线"一致。
                Positioned.fill(
                  child: Center(
                    child: Container(
                      height: _itemExtent,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: c.divider, width: 0.5),
                          bottom: BorderSide(color: c.divider, width: 0.5),
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onCancel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: c.textVariant,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onConfirm,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  '完成',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

/// 单列滚轮 — ListWheelScrollView + FixedExtentScrollPhysics,中心对齐。
/// 每项根据 |index - currentIndex| 距离把颜色从 c.text(黑)渐变到 c.textVariant(灰),
/// 选中行加粗 — 跟截图里 iOS picker 那种"远处项变淡"的效果对齐。
class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.count,
    required this.currentIndex,
    required this.builder,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final int currentIndex;
  final String Function(int) builder;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _WheelDatePickerSheetState._itemExtent,
      diameterRatio: 1.6,
      physics: const FixedExtentScrollPhysics(),
      perspective: 0.0025,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) {
          // 距离选中行的格数 — 0 = 选中,3 视为完全淡出
          final distance = (index - currentIndex).abs();
          // 颜色:从 c.text(黑)渐变到 c.textVariant(灰),divisor 2.5 让距离
          // 2 项就接近 textVariant;再叠加 alpha 衰减让远处项更"虚" —
          // 严格对齐截图里"远处项明显更淡"的视觉强度。
          final factor = (distance / 2.5).clamp(0.0, 1.0);
          final base = Color.lerp(c.text, c.textVariant, factor)!;
          final alpha = (1.0 - distance * 0.22).clamp(0.3, 1.0);
          final color = distance == 0 ? base : base.withValues(alpha: alpha);
          final isSelected = distance == 0;
          return Center(
            child: Text(
              builder(index),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                height: 1,
              ),
            ),
          );
        },
      ),
    );
  }
}