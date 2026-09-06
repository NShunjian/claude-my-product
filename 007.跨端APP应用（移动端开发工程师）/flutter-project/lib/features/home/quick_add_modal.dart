import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/category_presentation.dart';
import '../../core/utils/date_util.dart';
import '../shared/providers.dart';
import '../shared/quick_add_controller.dart';
import '../shared/toast_controller.dart';

/// 对齐 components/QuickAddModal.vue — 顶部悬浮式快捷记一笔。
class QuickAddModal extends ConsumerStatefulWidget {
  const QuickAddModal({super.key});

  @override
  ConsumerState<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends ConsumerState<QuickAddModal> {
  late Future<_QuickAddData> _future;
  RecordType _kind = RecordType.expense;
  Category? _category;
  Account? _account;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(quickAddControllerProvider);
    _kind = s.kind;
    _future = _load(_kind);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<_QuickAddData> _load(RecordType kind) async {
    final bookId = ref.read(currentBookIdProvider);
    final accs = await ref
        .read(accountsApiProvider)
        .listAccounts(bookId: bookId.isEmpty ? null : bookId);
    final cats = await ref
        .read(categoriesApiProvider)
        .listCategories(type: _mapType(kind));
    return _QuickAddData(categories: cats, accounts: accs);
  }

  CategoryType _mapType(RecordType kind) =>
      kind == RecordType.income ? CategoryType.income : CategoryType.expense;

  void _setKind(RecordType kind) {
    setState(() {
      _kind = kind;
      _category = null;
      _future = _load(kind);
    });
  }

  Future<void> _submit() async {
    final lang = I18n.of(context);
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ref.read(toastControllerProvider.notifier).show(lang.t('recordExpense.amountPrompt'));
      return;
    }
    if (_category == null) {
      ref.read(toastControllerProvider.notifier).show(lang.t('recordExpense.categoryRequired'));
      return;
    }
    if (_account == null) {
      ref.read(toastControllerProvider.notifier).show(lang.t('recordExpense.accountRequired'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(recordsApiProvider);
      final date = todayLocal();
      final note = _noteCtrl.text.trim();
      final catId = _category!.id;
      final accId = _account!.id;
      if (_kind == RecordType.income) {
        await api.createRecord(CreateIncomeInput(
          amount: amount,
          accountId: accId,
          categoryId: catId,
          recordDate: date,
          note: note.isEmpty ? null : note,
        ));
      } else {
        await api.createRecord(CreateExpenseInput(
          amount: amount,
          accountId: accId,
          categoryId: catId,
          recordDate: date,
          note: note.isEmpty ? null : note,
        ));
      }
      ref.read(quickAddControllerProvider.notifier).close();
      ref.read(quickAddControllerProvider.notifier).notifySaved();
      ref.read(toastControllerProvider.notifier).show(lang.t('recordExpense.success'));
      _reset();
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('common.submitFailed')} ($e)',
          );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    _amountCtrl.clear();
    _noteCtrl.clear();
    setState(() {
      _category = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final visible = ref.watch(quickAddControllerProvider.select((s) => s.show));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: visible
          ? _buildModal(lang)
          : const SizedBox.shrink(key: ValueKey('quick-add-hidden')),
    );
  }

  Widget _buildModal(Lang lang) {
    final c = context.appColors;
    return Positioned.fill(
      key: const ValueKey('quick-add-shown'),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: FutureBuilder<_QuickAddData>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return Center(
                  child: Text(
                    lang.t('recordModal.categoryLoading'),
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }
              final data = snap.data!;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: c.bgCard,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                lang.t('home.quickAdd'),
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: c.textVariant),
                                onPressed: () => ref
                                    .read(quickAddControllerProvider.notifier)
                                    .close(),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SegmentedButton<RecordType>(
                            segments: [
                              ButtonSegment(
                                value: RecordType.expense,
                                label: Text(lang.t('recordModal.expense')),
                              ),
                              ButtonSegment(
                                value: RecordType.income,
                                label: Text(lang.t('recordModal.income')),
                              ),
                            ],
                            selected: {_kind},
                            onSelectionChanged: (s) => _setKind(s.first),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              prefixText: '¥ ',
                              hintText: lang.t('recordExpense.amountPrompt'),
                              border: const OutlineInputBorder(),
                            ),
                            style: TextStyle(color: c.text, fontSize: 24),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            lang.t('recordModal.category'),
                            style: TextStyle(color: c.textVariant, fontSize: 12),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final cat in data.categories)
                                _CategoryChip(
                                  cat: cat,
                                  selected: cat.id == _category?.id,
                                  onTap: () => setState(() => _category = cat),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            lang.t('recordModal.accountLabel'),
                            style: TextStyle(color: c.textVariant, fontSize: 12),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<Account>(
                            initialValue: _account,
                            items: data.accounts
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (a) => setState(() => _account = a),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _noteCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: lang.t('recordModal.notePlaceholder'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text(
                              _submitting
                                  ? lang.t('recordExpense.submitting')
                                  : lang.t('recordExpense.submit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _QuickAddData {
  _QuickAddData({required this.categories, required this.accounts});
  final List<Category> categories;
  final List<Account> accounts;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.cat,
    required this.selected,
    required this.onTap,
  });
  final Category cat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final pres = presentCategory(cat);
    final bg = selected ? c.primaryLight : c.surface;
    final fg = selected ? c.primary : c.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? c.primary : c.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pres.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              cat.name.isEmpty ? lang.t('recordModal.category') : cat.name,
              style: TextStyle(color: fg, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}