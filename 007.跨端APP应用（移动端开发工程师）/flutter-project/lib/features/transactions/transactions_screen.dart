import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/api/records_api.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../shared/providers.dart';
import '../shared/quick_add_controller.dart';
import '../shared/transaction_row.dart';

/// 对齐 pages/liushui/index.vue — 全部流水 + 月份 + 类型筛选 + 删除。
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late Future<_TxData> _future;
  String _month = formatLocalMonth(DateTime.now());
  RecordType? _typeFilter; // null = 全部

  @override
  void initState() {
    super.initState();
    _future = _load();
    ref.listenManual<QuickAddState>(quickAddControllerProvider, (prev, next) {
      if (prev != null && next.savedAt != prev.savedAt) {
        setState(() => _future = _load());
      }
    });
  }

  Future<_TxData> _load() async {
    final bookId = ref.read(currentBookIdProvider);
    final records = await ref.read(recordsApiProvider).listRecords(
          q: RecordsQuery(
            month: _month,
            bookId: bookId.isEmpty ? null : bookId,
            type: _typeFilter,
          ),
        );
    final categories = await ref.read(categoriesApiProvider).listCategories();
    final accounts = await ref.read(accountsApiProvider).listAccounts(
          bookId: bookId.isEmpty ? null : bookId,
        );
    records.sort((a, b) {
      final byDate = b.recordDate.compareTo(a.recordDate);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return _TxData(records: records, categories: categories, accounts: accounts);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      helpText: I18n.of(context).t('reportMonthly.pickMonth'),
    );
    if (picked == null) return;
    setState(() {
      _month = formatLocalMonth(picked);
      _future = _load();
    });
  }

  Future<void> _confirmDelete(Record r) async {
    final lang = I18n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(lang.t('transactions.deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(lang.t('common.confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(recordsApiProvider).deleteRecord(r.id);
      if (!mounted) return;
      setState(() => _future = _load());
    } catch (_) {/* 容忍 */}
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('transactions.title')),
        actions: [
          TextButton(
            onPressed: _pickMonth,
            child: Text(_month, style: TextStyle(color: c.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            current: _typeFilter,
            onChanged: (t) {
              setState(() {
                _typeFilter = t;
                _future = _load();
              });
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final f = _load();
                setState(() => _future = f);
                await f;
              },
              child: FutureBuilder<_TxData>(
                future: _future,
                builder: (context, snap) {
                  // 首次加载还没数据 → 整页占位
                  if (!snap.hasData) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Center(
                        child: Text(
                          lang.t('transactions.loading'),
                          style: TextStyle(color: c.textVariant),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Text(
                              '${lang.t('transactions.loadErrorPrefix')}${snap.error}',
                              style: TextStyle(color: c.error),
                            ),
                          ),
                        ],
                      );
                    }
                  }
                  // 已有数据(包括刷新中的 stale snapshot)→ 渲染数据,顶部加进度条
                  final data = snap.data!;
                  final isReloading =
                      snap.connectionState != ConnectionState.done;
                  final groups = _groupByDate(data.records);
                  return Column(
                    children: [
                      if (isReloading)
                        const LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Color(0x00000000),
                        ),
                      Expanded(
                        child: data.records.isEmpty
                            ? Center(
                                child: Text(
                                  lang.t('transactions.empty'),
                                  style: TextStyle(color: c.textVariant),
                                ),
                              )
                            : ListView.builder(
                                itemCount: groups.fold<int>(
                                    0, (s, g) => s + 1 + g.records.length,
                                ),
                                itemBuilder: (context, i) {
                                  // 每组 1 个 day-header + N 行 row,平铺为线性索引。
                                  for (final g in groups) {
                                    if (i == 0) {
                                      return _DayHeader(
                                        label: _formatDayHeader(g.date, lang),
                                        net: g.net,
                                      );
                                    }
                                    i -= 1;
                                    if (i < g.records.length) {
                                      final r = g.records[i];
                                      final cat = data.categories.firstWhere(
                                        (x) => x.id == r.categoryId,
                                        orElse: () => Category(
                                          id: '',
                                          type: CategoryType.expense,
                                          name: '',
                                          icon: '',
                                          color: '#727782',
                                          sortOrder: 0,
                                          isPreset: false,
                                        ),
                                      );
                                      final acc = data.accounts.firstWhere(
                                        (a) => a.id == r.accountId,
                                        orElse: () => Account(
                                          id: '',
                                          name: '',
                                          type: AccountType.other,
                                          icon: '',
                                          initialBalance: 0,
                                          balance: 0,
                                          currency: 'CNY',
                                          isDefault: false,
                                          sortOrder: 0,
                                          createdAt: '',
                                        ),
                                      );
                                      return Dismissible(
                                        key: ValueKey(r.id),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          color: c.error,
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.lg,
                                          ),
                                          child: const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                          ),
                                        ),
                                        onDismissed: (_) => _confirmDelete(r),
                                        child: TransactionRow(
                                          record: r,
                                          category: cat.id.isEmpty ? null : cat,
                                          account: acc.id.isEmpty ? null : acc,
                                          onTap: () => context.push(
                                            AppRoutes.recordExpense,
                                            extra: r,
                                          ),
                                        ),
                                      );
                                    }
                                    i -= g.records.length;
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(quickAddControllerProvider.notifier).open(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TxData {
  _TxData({
    required this.records,
    required this.categories,
    required this.accounts,
  });
  final List<Record> records;
  final List<Category> categories;
  final List<Account> accounts;
}

/// 按 recordDate 分组 + 计算当日净额(income - expense)。
List<_DayGroup> _groupByDate(List<Record> records) {
  final map = <String, List<Record>>{};
  for (final r in records) {
    map.putIfAbsent(r.recordDate, () => []).add(r);
  }
  return map.entries
      .map(
        (e) => _DayGroup(
          date: e.key,
          records: e.value,
          net: e.value.fold<double>(
            0,
            (s, r) => s + (r.type == RecordType.income ? r.amount : -r.amount),
          ),
        ),
      )
      .toList();
}

class _DayGroup {
  _DayGroup({required this.date, required this.records, required this.net});
  final String date; // YYYY-MM-DD
  final List<Record> records;
  final double net;
}

/// 对齐 uniapp formatDayHeaderCN: "M月D日, 星期X"。
String _formatDayHeader(String ymd, Lang lang) {
  try {
    final d = DateTime.parse(ymd);
    final wd = weekdayLabel(
      d,
      labelOf: (i) {
        switch (i) {
          case 0:
            return lang.t('transactions.weekdaySun');
          case 1:
            return lang.t('transactions.weekdayMon');
          case 2:
            return lang.t('transactions.weekdayTue');
          case 3:
            return lang.t('transactions.weekdayWed');
          case 4:
            return lang.t('transactions.weekdayThu');
          case 5:
            return lang.t('transactions.weekdayFri');
          case 6:
            return lang.t('transactions.weekdaySat');
          default:
            return '';
        }
      },
    );
    return '${d.month}月${d.day}日, $wd';
  } catch (_) {
    return ymd;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.net});
  final String label;
  final double net;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sign = net >= 0 ? '+' : '-';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.textVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$sign¥${formatAmount(net.abs())}',
            style: TextStyle(
              color: c.textVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChanged});
  final RecordType? current;
  final ValueChanged<RecordType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    Widget chip(String label, RecordType? value) {
      final selected = current == value;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onChanged(value),
          selectedColor: c.primaryLight,
          labelStyle: TextStyle(color: selected ? c.primary : c.text),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          chip(lang.t('transactions.filter.all'), null),
          chip(lang.t('transactions.filter.expense'), RecordType.expense),
          chip(lang.t('transactions.filter.income'), RecordType.income),
          chip(lang.t('transactions.filter.transfer'), RecordType.transfer),
        ],
      ),
    );
  }
}