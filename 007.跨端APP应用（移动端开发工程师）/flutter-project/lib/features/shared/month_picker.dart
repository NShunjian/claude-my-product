import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';

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
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (ctx) => _YearWheelSheet(
        years: widget.yearOptions,
        initialYear: _draftYear,
      ),
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
/// (放大镜高亮当前项)。作为底部 sheet 从屏幕下方弹起。
class _YearWheelSheet extends StatefulWidget {
  const _YearWheelSheet({
    required this.years,
    required this.initialYear,
  });

  final List<int> years;
  final int initialYear;

  @override
  State<_YearWheelSheet> createState() => _YearWheelSheetState();
}

class _YearWheelSheetState extends State<_YearWheelSheet> {
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
    // 底部 sheet — 满宽 + 顶部圆角 + 阴影
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
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
            // 取消 / 完成 头部条(对齐 uniapp 原生 picker 顶部按钮)
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
            // 滚轮区:5 个 itemExtent 高度的视窗,中间项放大
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
    );
  }
}
