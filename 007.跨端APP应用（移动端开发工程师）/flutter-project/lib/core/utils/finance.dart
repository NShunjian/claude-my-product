import 'package:intl/intl.dart';

import '../api/models.dart';

/// V1.2 金额核算审计:ISO 4217 货币码 → 显示符号。
/// 没收录的码(空/null)回退 `¥`,与历史行为一致。
String currencySymbol(String? code) {
  switch (code?.toUpperCase()) {
    case 'CNY':
    case 'RMB':
      return '¥';
    case 'USD':
      return r'$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'HKD':
      return 'HK\$';
    default:
      return '¥';
  }
}

/// 对齐 utils/finance.ts。
///
/// V1.2 金额核算审计:
///   - 入参若 NaN / Infinity / null,返回 `'--'` 而不是渲染 `¥NaN`(避免炸屏)。
///   - `currency` 优先于 `withSymbol`;传 `currency` 时直接用货币码对应的符号,
///     否则按 `withSymbol` 兜底为 `¥`。
String formatAmount(num? n, {bool withSymbol = false, String? currency}) {
  if (n == null || !n.isFinite) return '--';
  final formatter = NumberFormat('#,##0.00', 'zh_CN');
  final sym = currency != null ? currencySymbol(currency) : (withSymbol ? '¥' : '');
  return sym + formatter.format(n);
}

/// ISO 字符串 -> `YYYY-MM-DD HH:mm`(本地时区)。
/// 与原 utils/formatDateTime 一致;parse 失败返回原字符串。
String formatDateTime(String iso) {
  try {
    final d = DateTime.parse(iso).toLocal();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month + 1 - 1)}-${pad(d.day)} ${pad(d.hour)}:${pad(d.minute)}';
  } catch (_) {
    return iso;
  }
}

String typeOfAccount(AccountType t) {
  switch (t) {
    case AccountType.cash:
      return '现金';
    case AccountType.debit:
      return '借记卡';
    case AccountType.credit:
      return '信用卡';
    case AccountType.wallet:
      return '钱包';
    case AccountType.investment:
      return '投资';
    case AccountType.other:
      return '其他';
  }
}

/// recordType 字面量,与 uniapp 中 utils/finance.typeOfCategory 等价。
String typeOfCategory(CategoryType t) => t.name;

int balanceSign(num n) => n < 0 ? -1 : (n > 0 ? 1 : 0);
