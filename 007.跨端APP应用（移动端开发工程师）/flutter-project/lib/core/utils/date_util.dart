/// 对齐 utils/date.ts — 全部使用本地时区,绝不调 toISOString()(那会丢一天)。
String formatLocalDate(DateTime d) {
  final pad = (int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${pad(d.month)}-${pad(d.day)}';
}

String formatLocalMonth(DateTime d) {
  final pad = (int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${pad(d.month)}';
}

String formatLocalHHMM(String iso) {
  try {
    final d = DateTime.parse(iso).toLocal();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${pad(d.hour)}:${pad(d.minute)}';
  } catch (_) {
    return iso;
  }
}

String formatLocalYMD(String iso) {
  try {
    return formatLocalDate(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

String todayLocal() => formatLocalDate(DateTime.now());

/// '2026-09' -> '2026 年 9 月'(zh) / '2026/09' (en) / '2026 年 9 月' (zh-TW)。
String formatMonthCN(String month, {required String langCode}) {
  final parts = month.split('-');
  if (parts.length != 2) return month;
  final y = parts[0];
  final m = parts[1].replaceFirst(RegExp(r'^0'), '');
  switch (langCode) {
    case 'en':
      return '$m/$y';
    default:
      return '$y 年 $m 月';
  }
}

/// 对齐 uniapp `日组标题:M月D日,星期X`(pages/transactions/index.vue)。
/// - 今天:`今天 9月4日`
/// - 昨天:`昨天 9月4日`
/// - 其他:`9月4日`
String formatRelativeDayLabel(
  String iso,
  DateTime today, {
  required String todayLabel,
  required String yesterdayLabel,
}) {
  final d = DateTime.parse(iso).toLocal();
  final dDate = DateTime(d.year, d.month, d.day);
  final tDate = DateTime(today.year, today.month, today.day);
  final diff = tDate.difference(dDate).inDays;
  final dateStr = '${d.month}月${d.day}日';
  if (diff == 0) return '$todayLabel $dateStr';
  if (diff == 1) return '$yesterdayLabel $dateStr';
  return dateStr;
}

int compareRecordDesc<T>(T a, T b, String Function(T) recordDate, String Function(T) createdAt) {
  final ad = recordDate(a);
  final bd = recordDate(b);
  if (ad != bd) return bd.compareTo(ad);
  return createdAt(b).compareTo(createdAt(a));
}

String weekdayLabel(DateTime d, {required String Function(int) labelOf}) {
  return labelOf(d.weekday % 7); // Dart: weekday 1=Mon..7=Sun,uniapp 0=Sun..6=Sat
}
