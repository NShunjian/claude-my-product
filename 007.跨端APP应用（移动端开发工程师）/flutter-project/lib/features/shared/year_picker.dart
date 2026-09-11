// ponytail: 2026-09-12 — 独立年份滚轮 picker。弹出机制复用
//          bottom_sheet_route.dart 的 showAppBottomSheet(不走
//          showModalBottomSheet,避免 Flutter 自动 safeArea padding 把 sheet
//          顶上去 34dp)。YearWheelSheet 内部 Stack > Positioned(bottom: 0)
//          锚物理屏底,wheel 底部 = 屏幕底部。
import 'package:flutter/cupertino.dart';

import '../../core/theme/tokens.dart';
import 'bottom_sheet_route.dart';

/// 公开 API:弹一个底部滚轮 sheet 选年份,wheel 底部贴屏底。
/// 与 month_picker.dart 的同名函数签名一致,reports_screen.dart 可以
/// 无缝切换。
Future<int?> showYearWheelPicker(
  BuildContext context, {
  required List<int> years,
  required int initialYear,
}) {
  return showAppBottomSheet<int>(
    context,
    builder: (_) => YearWheelSheet(years: years, initialYear: initialYear),
  );
}

/// 全屏 sheet:Stack > Positioned(bottom: 0) 锚到物理屏底。
class YearWheelSheet extends StatefulWidget {
  const YearWheelSheet({
    super.key,
    required this.years,
    required this.initialYear,
  });

  final List<int> years;
  final int initialYear;

  @override
  State<YearWheelSheet> createState() => _YearWheelSheetState();
}

class _YearWheelSheetState extends State<YearWheelSheet> {
  late FixedExtentScrollController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialYear;
    final idx = widget.years.indexOf(widget.initialYear);
    _ctrl = FixedExtentScrollController(initialItem: idx >= 0 ? idx : 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: c.bgCard,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 取消 / 完成 顶部条
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: c.divider, width: 1),
                      ),
                    ),
                    child: SelectionContainer.disabled(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).pop(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Text(
                                '取消',
                                style: TextStyle(
                                  color: c.textVariant,
                                  fontSize: 16,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                Navigator.of(context).pop(_current),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Text(
                                '完成',
                                style: TextStyle(
                                  color: c.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 220,
                    child: CupertinoPicker(
                      scrollController: _ctrl,
                      itemExtent: 40,
                      useMagnifier: true,
                      magnification: 1.2,
                      backgroundColor: c.bgCard,
                      onSelectedItemChanged: (i) =>
                          setState(() => _current = widget.years[i]),
                      children: [
                        for (final y in widget.years)
                          Center(
                            child: Text(
                              '$y',
                              style: TextStyle(
                                color: c.text,
                                fontSize: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}