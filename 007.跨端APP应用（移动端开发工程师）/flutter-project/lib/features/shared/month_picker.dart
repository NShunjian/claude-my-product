import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/modal_state.dart';

/// 对齐 components/MonthPicker.vue — 默认 stepper 模式 + compact 弹窗模式。
class MonthPicker extends ConsumerWidget {
  const MonthPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final String value; // YYYY-MM
  final ValueChanged<String> onChanged;
  final bool compact;

  void _step(BuildContext context, int delta) {
    final parts = value.split('-');
    if (parts.length != 2) return;
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? 1;
    final ny = y + (m + delta - 1) ~/ 12;
    final nm = (m + delta - 1) % 12 + 1;
    final pad = (int n) => n.toString().padLeft(2, '0');
    onChanged('$ny-${pad(nm)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;

    if (compact) {
      // 流水页 filter-row 跟 _SelectBox 完全一致:Container 边框 + 背景 + GestureDetector
      // 点击。月份文本左对齐(非居中),文字 + ▼ 与其他两个 picker 视觉一致。
      // ponytail: 之前 InkWell + Padding 没有 Container,在浅色背景下看不到边界,
      //          跟 _SelectBox 视觉重量不匹配 — 改成同款 Container 后边框 + 背景一致。
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openModal(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: c.bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatMonthCN(value, langCode: lang.code),
                  style: TextStyle(color: c.text, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '▼',
                style: TextStyle(color: c.textVariant, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // 对齐 uniapp .mp: padding 8/24rpx、radius 32rpx、bg-card + 1px divider border、
    // .btn 56×56rpx + 40rpx 字符 / .label 30rpx fontWeight 600。
    // 整个 pill 可点击打开 modal(对齐 uniapp `<view class="mp" @tap="open">`);
    // chevron 自己有 InkWell 会优先消费 tap,不冒泡。
    // GestureDetector 而非 InkWell:Flutter web CanvasKit 上 InkWell + Material 的
    // 嵌套 splash 在某些 Chrome 版本会拦截 pointer 事件,GestureDetector 干净。
    return GestureDetector(
      onTap: () => _openModal(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.divider, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepBtn(
              icon: Icons.chevron_left,
              onTap: () => _step(context, -1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                formatMonthCN(value, langCode: lang.code),
                style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _StepBtn(
              icon: Icons.chevron_right,
              onTap: () => _step(context, 1),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openModal(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final currentY = int.tryParse(value.split('-')[0]) ?? now.year;
    final currentM = int.tryParse(value.split('-').last) ?? now.month;
    final yearOptions =
        List<int>.generate(10, (i) => now.year - 5 + i);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: _MonthPickerModal(
            currentYear: currentY,
            currentMonth: currentM,
            yearOptions: yearOptions,
            onClear: () => Navigator.of(ctx).pop(),
            onThisMonth: () {
              final d = DateTime.now();
              final pad = (int n) => n.toString().padLeft(2, '0');
              onChanged('${d.year}-${pad(d.month)}');
              Navigator.of(ctx).pop();
            },
            onPick: (year, month) {
              final pad = (int n) => n.toString().padLeft(2, '0');
              onChanged('$year-${pad(month)}');
              Navigator.of(ctx).pop();
            },
          ),
        ),
    );
  }
}

/// 对齐 uniapp .btn:56×56rpx hit area + 40rpx 字符 chevron。
/// 比 IconButton 紧一圈(月历模式挤在一行里也能放得下)。
class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 20, color: c.textVariant),
      ),
    );
  }
}

/// 对齐 components/MonthPicker.vue .modal-mask + .modal-card。
/// 居中卡片 280dp + bg-card + 阴影 + 内部:年份行 / 4×3 月份网格 / 底部链接。
class _MonthPickerModal extends StatefulWidget {
  const _MonthPickerModal({
    required this.currentYear,
    required this.currentMonth,
    required this.yearOptions,
    required this.onClear,
    required this.onThisMonth,
    required this.onPick,
  });

  final int currentYear;
  final int currentMonth;
  final List<int> yearOptions;
  final VoidCallback onClear;
  final VoidCallback onThisMonth;
  final void Function(int year, int month) onPick;

  @override
  State<_MonthPickerModal> createState() => _MonthPickerModalState();
}

class _MonthPickerModalState extends State<_MonthPickerModal> {
  late int _draftYear;

  @override
  void initState() {
    super.initState();
    _draftYear = widget.currentYear;
  }

  /// 对齐 uniapp `<picker mode="selector">` 的 native 滚轮体验:
  /// 底部弹起的 sheet(uniapp 原生 picker 即为底部 sheet)+ 取消/完成 顶部条 +
  /// CupertinoPicker 高亮当前年份 + 放大镜。
  /// showModalBottomSheet 是独立 route,不会被 modal Dialog 遮挡。
  Future<void> _openYearWheel(BuildContext context) async {
    final picked = await showYearWheelPicker(
      context,
      years: widget.yearOptions,
      initialYear: _draftYear,
    );
    if (picked != null && mounted) {
      setState(() => _draftYear = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.18),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 年份行:.modal-year-row
            // 对齐 uniapp `<picker mode="selector">`:点胶囊 → 弹出原生滚轮选年份
            // (uniapp MP 用系统 Picker,Flutter web 用 CupertinoPicker 视觉等价)
            Row(
              children: [
                Text(
                  '年份',
                  style: TextStyle(color: c.textVariant, fontSize: 14),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openYearWheel(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.primary, width: 1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$_draftYear',
                              style: TextStyle(
                                color: c.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // uniapp .caret 用字符 ▾ 而非 Material icon(色号 / 字号更贴合)
                          Text(
                            '▾',
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // 4×3 月份网格:.modal-grid { grid-template-columns: repeat(4,1fr); gap: 16rpx }
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (int m = 1; m <= 12; m++)
                  _MonthCell(
                    label: '$m月',
                    active: widget.currentYear == _draftYear &&
                        widget.currentMonth == m,
                    onTap: () => widget.onPick(_draftYear, m),
                  ),
              ],
            ),
            // 底部:.modal-footer { border-top: 1px divider }
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.xs),
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.divider, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FooterLink(
                    label: '清除',
                    bold: false,
                    onTap: widget.onClear,
                  ),
                  _FooterLink(
                    label: '本月',
                    bold: true,
                    onTap: widget.onThisMonth,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 网格单格 .modal-month:active:主色填充 + 白字 + w600。
class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 56,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : c.text,
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 底部链接 .footer-link / .footer-link.primary。
class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.bold,
    required this.onTap,
  });

  final String label;
  final bool bold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c.primary,
            fontSize: 14,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 对齐 uniapp `<picker mode="selector">`:取消/完成 顶部条 + 中间 CupertinoPicker
/// 滚轮。Flutter web 用 CupertinoPicker 视觉等价于 iOS/Android 原生滚轮 picker
/// (放大镜高亮当前项)。
/// Public helper:跟 _MonthPickerModal 同款 showDialog(居中卡片 280dp),内
/// 含年份行(点胶囊调 showYearWheelPicker 弹滚轮)+ 完成/取消按钮。复用
/// _MonthPickerModal 的"dialog 嵌套 sheet"路径,让 wheel 贴屏底(用户截图
/// 验证:月报 dialog 内 wheel 能正确贴屏底)。
/// 2026-09-12 用户要求年报页年份选择跟月报一致用滚轮,从 reports_screen.dart 调用。
Future<int?> showYearPicker(
  BuildContext context, {
  required List<int> years,
  required int initialYear,
}) {
  // ponytail: 2026-09-12 — 走跟 _MonthPickerModal 完全一样的路径:
  //          showDialog 包居中卡片(280dp),卡片内有"年份"胶囊,点胶囊
  //          触发 showYearWheelPicker。modalOpenProvider 控制 tabbar 隐藏。
  final container = ProviderScope.containerOf(context);
  container.read(modalOpenProvider.notifier).state = true;
  return showDialog<int>(
    context: context,
    barrierColor: Colors.black54,
    barrierDismissible: true,
    builder: (ctx) => _YearPickerDialog(
      years: years,
      initialYear: initialYear,
    ),
  ).whenComplete(() {
    container.read(modalOpenProvider.notifier).state = false;
  });
}

/// 内部 helper:被 _MonthPickerModal / _YearPickerDialog 共用,弹底部滚轮
/// sheet。modalOpenProvider 控制 tabbar 隐藏。
Future<int?> showYearWheelPicker(
  BuildContext context, {
  required List<int> years,
  required int initialYear,
}) {
  final container = ProviderScope.containerOf(context);
  container.read(modalOpenProvider.notifier).state = true;
  final c = context.appColors;
  return showModalBottomSheet<int>(
    context: context,
    // ponytail: 2026-09-12 — 对齐 account_new_screen.dart _WheelPickerSheet:
    //          backgroundColor: bgCard + shape 圆角,sheet 本身不透明,wheel
    //          底部 = 屏幕底部(没有透明 sheet 漏出 modal barrier 黑区)。
    backgroundColor: c.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => YearWheelSheet(
      years: years,
      initialYear: initialYear,
    ),
  ).whenComplete(() {
    container.read(modalOpenProvider.notifier).state = false;
  });
}

/// 对齐 _MonthPickerModal — 居中卡片 280dp,卡片内:
/// 年份行(点胶囊调 showYearWheelPicker 弹滚轮)+ 完成/取消按钮。
class _YearPickerDialog extends StatefulWidget {
  const _YearPickerDialog({
    required this.years,
    required this.initialYear,
  });

  final List<int> years;
  final int initialYear;

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _draftYear;

  @override
  void initState() {
    super.initState();
    _draftYear = widget.initialYear;
  }

  Future<void> _openYearWheel(BuildContext context) async {
    final picked = await showYearWheelPicker(
      context,
      years: widget.years,
      initialYear: _draftYear,
    );
    if (picked != null && mounted) {
      setState(() => _draftYear = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final topInset = mq.padding.top;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 居中卡片 280dp — 跟 _MonthPickerModal 同款,放在屏幕中央
          Positioned(
            left: 0,
            right: 0,
            top: topInset + (screenH - topInset) * 0.2,
            child: Center(
              child: SizedBox(
                width: 280,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: c.bgCard,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.18),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 年份行 — 点胶囊弹滚轮
                      Row(
                        children: [
                          Text(
                            '年份',
                            style: TextStyle(
                                color: c.textVariant, fontSize: 14),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openYearWheel(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: c.primary, width: 1),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$_draftYear',
                                        style: TextStyle(
                                          color: c.text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '▾',
                                      style: TextStyle(
                                        color: c.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // 底部链接 — 清除 / 完成
                      Container(
                        margin: const EdgeInsets.only(top: AppSpacing.xs),
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        decoration: BoxDecoration(
                          border: Border(
                            top:
                                BorderSide(color: c.divider, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  Navigator.of(context).pop(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                child: Text(
                                  '清除',
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context)
                                  .pop(_draftYear),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                child: Text(
                                  '完成',
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}

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
    // ponytail: 2026-09-12 — 对齐 account_new_screen.dart _WheelPickerSheet:
    //          showModalBottomSheet 已经传 backgroundColor: bgCard + shape
    //          圆角,sheet 本身不透明且自带顶部圆角。这里只放内容,SafeArea
    //          让出 home indicator 区。
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 取消 / 完成 头部条
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: c.textVariant,
                      fontSize: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(_current),
                  child: Text(
                    '完成',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
    );
  }
}
