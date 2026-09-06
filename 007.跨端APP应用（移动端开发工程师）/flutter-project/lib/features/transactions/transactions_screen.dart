import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/api/records_api.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_util.dart';
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
                  final data = snap.data!;
                  if (data.records.isEmpty) {
                    return Center(
                      child: Text(
                        lang.t('transactions.empty'),
                        style: TextStyle(color: c.textVariant),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: data.records.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: c.divider),
                    itemBuilder: (context, i) {
                      final r = data.records[i];
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
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Icon(Icons.delete, color: Colors.white),
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
                    },
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