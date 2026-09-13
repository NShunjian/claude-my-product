import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/category_presentation.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';

/// 对齐 components/TransactionRow.vue — emoji + title + amount。
class TransactionRow extends ConsumerWidget {
  const TransactionRow({
    super.key,
    required this.record,
    required this.category,
    required this.account,
    this.onTap,
    this.horizontalPadding = AppSpacing.lg,
  });

  final Record record;
  final Category? category;
  final Account? account;
  final VoidCallback? onTap;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final pres = category != null ? presentCategory(category!) : null;

    final isExpense = record.type == RecordType.expense;
    final sign = isExpense ? '-' : '+';
    final amountColor = isExpense ? c.error : const Color(0xFF006D40);

    final note = record.note?.trim();
    final title = (note != null && note.isNotEmpty)
        ? note
        : (category?.name ?? lang.t('transactions.titleAll'));

    final catLabel = category?.name ?? '';
    final accLabel = account?.name ?? '';
    final subtitle = [catLabel, accLabel].where((s) => s.isNotEmpty).join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _parseHex(pres?.color ?? '#E0E0E0').withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                pres?.icon ?? '⋯',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(color: c.textVariant, fontSize: 11),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign¥${formatAmount(record.amount)}',
                  // uniapp .amt { font-size: 32rpx; font-weight: 700 } → 16dp
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                // uniapp 右侧 .meta:`记账时间: ${date}${time ? ' ' + time : ''}`
                Text(
                  '${lang.t('transactions.recordTime')}: ${formatLocalYMD(record.createdAt)} ${formatLocalHHMM(record.createdAt)}',
                  // .meta { font-size: 22rpx } → 11dp
                  style: TextStyle(color: c.textVariant, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}