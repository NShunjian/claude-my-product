import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../api/accounts_api.dart';
import '../api/categories_api.dart';
import '../api/models.dart';
import '../api/records_api.dart';
// ponytail: 平台分流 — web 走 dart:html Blob 下载,android/ios 走 share_plus。
//          dart.library.html 编译期检查,web build 才把 _share_web.dart 编进去;
//          否则 _share_io.dart 编进去。这样 export.dart 自身不用 kIsWeb 分支,
//          也不需要把 dart:html import 在非 web 编译时报错。
import '_share_io.dart' if (dart.library.html) '_share_web.dart';

/// 对齐 utils/export.ts — Excel 导出(月报 / 按分类 / 全部)。
/// Web 平台:返回字节流,由调用方通过 dart:html 触发下载。
/// Native 平台:写到临时目录并 share_plus 触发系统分享 / 保存面板。

typedef BytesWriter = Future<void> Function(Uint8List bytes, String filename);

class _RecordRow {
  _RecordRow({
    required this.date,
    required this.type,
    required this.category,
    required this.account,
    required this.toAccount,
    required this.amount,
    required this.currency,
    required this.note,
  });
  final String date;
  final String type;
  final String category;
  final String account;
  final String toAccount;
  final double amount;
  final String currency;
  final String note;
}

List<String> _headers = const [
  '日期',
  '类型',
  '分类',
  '账户',
  '转入账户',
  '金额',
  '币种',
  '备注',
];

List<List<dynamic>> _rows(List<_RecordRow> rs) =>
    rs.map((r) => [r.date, r.type, r.category, r.account, r.toAccount, r.amount, r.currency, r.note]).toList();

class ExportService {
  ExportService({
    required this.records,
    required this.accounts,
    required this.categories,
  });
  final RecordsApi records;
  final AccountsApi accounts;
  final CategoriesApi categories;

  Future<List<_RecordRow>> _loadAllRows() async {
    final allRecords = await records.listRecords();
    final accs = await accounts.listAccounts();
    final expCats = await categories.listCategories(type: CategoryType.expense);
    final incCats = await categories.listCategories(type: CategoryType.income);
    final allCats = [...expCats, ...incCats];
    final accMap = {for (final a in accs) a.id: a.name};
    final catMap = {for (final c in allCats) c.id: c.name};
    return allRecords.map((r) {
      return _RecordRow(
        date: r.recordDate,
        type: switch (r.type) {
          RecordType.expense => '支出',
          RecordType.income => '收入',
          RecordType.transfer => '转账',
        },
        category: r.categoryId == null ? '' : (catMap[r.categoryId] ?? r.categoryId!),
        account: accMap[r.accountId] ?? r.accountId,
        toAccount: r.toAccountId == null ? '' : (accMap[r.toAccountId] ?? r.toAccountId!),
        amount: r.amount,
        currency: r.currency,
        note: r.note ?? '',
      );
    }).toList();
  }

  Future<Uint8List> _bytes(List<List<dynamic>> rows, List<String> sheetNames, String activeSheet) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', activeSheet);
    excel[activeSheet].appendRow(_toRow(_headers));
    for (final r in rows) {
      excel[activeSheet].appendRow(_toRow(r));
    }
    return Uint8List.fromList(excel.encode()!);
  }

  /// 把 `List<dynamic>` 转成 excel 4.x 的 `List<CellValue?>`。
  static List<CellValue?> _toRow(List<dynamic> values) => [
        for (final v in values)
          switch (v) {
            null => null,
            num n => DoubleCellValue(n.toDouble()),
            bool b => BoolCellValue(b),
            String s => TextCellValue(s),
            _ => TextCellValue(v.toString()),
          },
      ];

  Future<void> _shareBytes(Uint8List bytes, String filename) =>
      writeBytesForExport(bytes, filename);

  /// 导出本月报表。
  Future<void> exportMonthly() async {
    final month = DateTime.now().toIso8601String().substring(0, 7);
    final all = await _loadAllRows();
    final rows = all.where((r) => r.date.startsWith(month)).toList();
    final bytes = await _bytes(_rows(rows), ['$month 月度流水'], '$month 月度流水');
    await _shareBytes(bytes, '轻账-$month月报表-${DateTime.now().toIso8601String().substring(0, 10)}.xlsx');
  }

  /// 按分类导出:每个分类独立 sheet + 汇总 sheet。
  Future<void> exportByCategory() async {
    final all = await _loadAllRows();
    final excel = Excel.createExcel();
    excel.rename('Sheet1', '汇总');

    final groups = <String, List<_RecordRow>>{};
    for (final r in all) {
      // 这里用 type + category 复合 key,因为同 categoryId 在 expense/income 下同名会撞。
      final key = '${r.type}::${r.category}';
      groups.putIfAbsent(key, () => []).add(r);
    }

    final summary = <List<dynamic>>[];
    for (final entry in groups.entries) {
      final sheetName = entry.key.replaceAll('::', '-');
      final safeName = sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName;
      excel[safeName].appendRow(_toRow(_headers));
      for (final r in entry.value) {
        excel[safeName].appendRow(_toRow([r.date, r.type, r.category, r.account, r.toAccount, r.amount, r.currency, r.note]));
      }
      final total = entry.value.fold<double>(0, (s, r) => s + r.amount);
      summary.add([sheetName, entry.value.length, total]);
    }
    if (summary.isNotEmpty) {
      excel['汇总'].appendRow(_toRow(['分类', '笔数', '金额合计']));
      for (final row in summary) {
        excel['汇总'].appendRow(_toRow(row));
      }
    }

    final bytes = Uint8List.fromList(excel.encode()!);
    await _shareBytes(bytes, '轻账-按分类导出-${DateTime.now().toIso8601String().substring(0, 10)}.xlsx');
  }

  /// 导出全部数据。
  Future<void> exportAll() async {
    final all = await _loadAllRows();
    final bytes = await _bytes(_rows(all), ['全部交易'], '全部交易');
    await _shareBytes(bytes, '轻账-全部数据-${DateTime.now().toIso8601String().substring(0, 10)}.xlsx');
  }
}
