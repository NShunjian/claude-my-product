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
      return InkWell(
        onTap: () => _openModal(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMonthCN(value, langCode: lang.code),
                style: TextStyle(color: c.text, fontSize: 14),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.arrow_drop_down, color: c.textVariant),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _step(context, -1),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            formatMonthCN(value, langCode: lang.code),
            style: TextStyle(color: c.text, fontSize: 15),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _step(context, 1),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _openModal(BuildContext context, WidgetRef ref) async {
    final lang = I18n.of(context);
    final c = context.appColors;
    final now = DateTime.now();
    final currentY = int.tryParse(value.split('-')[0]) ?? now.year;
    final currentM = int.tryParse(value.split('-').last) ?? now.month;
    int year = currentY;
    int? month = currentM;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      lang.t('reportMonthly.picker.yearLabel'),
                      style: TextStyle(color: c.textVariant, fontSize: 13),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => year--),
                    ),
                    Text(
                      '$year',
                      style: TextStyle(color: c.text, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => year++),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (int m = 1; m <= 12; m++)
                      GestureDetector(
                        onTap: () => setState(() => month = m),
                        child: Container(
                          width: 64,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: month == m ? c.primary : c.surface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '$m',
                            style: TextStyle(
                              color: month == m ? Colors.white : c.text,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: Text(lang.t('common.close')),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        final pad = (int n) => n.toString().padLeft(2, '0');
                        onChanged('$year-${pad(month ?? 1)}');
                      },
                      child: Text(lang.t('common.confirm')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
