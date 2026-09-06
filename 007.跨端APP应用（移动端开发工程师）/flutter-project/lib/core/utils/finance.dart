import 'package:intl/intl.dart';

import '../api/models.dart';

/// 对齐 utils/finance.ts。
String formatAmount(num n, {bool withSymbol = false}) {
  final formatter = NumberFormat('#,##0.00', 'zh_CN');
  return (withSymbol ? '¥' : '') + formatter.format(n);
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
