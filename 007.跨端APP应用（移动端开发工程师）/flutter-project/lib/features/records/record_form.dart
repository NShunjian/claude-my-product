import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/category_presentation.dart';
import '../../core/utils/date_util.dart';
import '../shared/providers.dart';
import '../shared/toast_controller.dart';

/// 复用的 RecordForm — 给 RecordExpenseScreen / RecordIncomeScreen 用。
class RecordForm extends ConsumerStatefulWidget {
  const RecordForm({super.key, required this.kind});
  final RecordType kind;

  @override
  ConsumerState<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends ConsumerState<RecordForm> {
  late Future<_FormData> _future;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  Category? _category;
  Account? _account;
  DateTime _date = DateTime.now();
  bool _submitting = false;

  bool get _isExpense => widget.kind == RecordType.expense;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<_FormData> _load() async {
    final bookId = ref.read(currentBookIdProvider);
    final cats = await ref
        .read(categoriesApiProvider)
        .listCategories(type: _isExpense ? CategoryType.expense : CategoryType.income);
    final accs = await ref
        .read(accountsApiProvider)
        .listAccounts(bookId: bookId.isEmpty ? null : bookId);
    return _FormData(categories: cats, accounts: accs);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final lang = I18n.of(context);
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ref.read(toastControllerProvider.notifier).show(lang.t('recordExpense.amountPrompt'));
      return;
    }
    if (_category == null) {
      ref.read(toastControllerProvider.notifier).show(
            _isExpense
                ? lang.t('recordExpense.categoryRequired')
                : lang.t('recordIncome.categoryRequired'),
          );
      return;
    }
    if (_account == null) {
      ref.read(toastControllerProvider.notifier).show(
            _isExpense
                ? lang.t('recordExpense.accountRequired')
                : lang.t('recordIncome.accountRequired'),
          );
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(recordsApiProvider);
      final date = formatLocalDate(_date);
      final note = _noteCtrl.text.trim();
      final catId = _category!.id;
      final accId = _account!.id;
      if (_isExpense) {
        await api.createRecord(CreateExpenseInput(
          amount: amount,
          accountId: accId,
          categoryId: catId,
          recordDate: date,
          note: note.isEmpty ? null : note,
        ));
      } else {
        await api.createRecord(CreateIncomeInput(
          amount: amount,
          accountId: accId,
          categoryId: catId,
          recordDate: date,
          note: note.isEmpty ? null : note,
        ));
      }
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('recordExpense.success'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('common.submitFailed')} ${e is ApiException ? e.message : '$e'}',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return FutureBuilder<_FormData>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: Text(
              lang.t('recordModal.categoryLoading'),
              style: TextStyle(color: c.textVariant),
            ),
          );
        }
        final data = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '¥ ',
                hintText: lang.t('recordExpense.amountPrompt'),
                border: const OutlineInputBorder(),
              ),
              style: TextStyle(color: c.text, fontSize: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(
              label: _isExpense
                  ? lang.t('recordExpense.category')
                  : lang.t('recordIncome.category'),
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
            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(
              label: _isExpense
                  ? lang.t('recordExpense.account')
                  : lang.t('recordIncome.account'),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<Account>(
              initialValue: _account,
              items: data.accounts
                  .map(
                    (a) => DropdownMenuItem(value: a, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (a) => setState(() => _account = a),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(
              label: _isExpense
                  ? lang.t('recordExpense.date')
                  : lang.t('recordIncome.date'),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                child: Text(formatLocalDate(_date)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(
              label: _isExpense
                  ? lang.t('recordExpense.note')
                  : lang.t('recordIncome.note'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _isExpense
                    ? lang.t('recordExpense.notePlaceholder')
                    : lang.t('recordIncome.notePlaceholder'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                _submitting
                    ? (_isExpense
                        ? lang.t('recordExpense.submitting')
                        : lang.t('recordIncome.submitting'))
                    : (_isExpense
                        ? lang.t('recordExpense.submit')
                        : lang.t('recordIncome.submit')),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FormData {
  _FormData({required this.categories, required this.accounts});
  final List<Category> categories;
  final List<Account> accounts;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(color: context.appColors.textVariant, fontSize: 12),
    );
  }
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
            Text(cat.name, style: TextStyle(color: fg, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}