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
  // 数字键盘表达式(对齐 uniapp .qa-keypad:digits/. + back/+/−/✓)。
  // 最多 12 字符;_computeAmount() 解析 '+' 分段求和。
  String _expression = '';

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
    final amount = _computeAmount();
    if (amount <= 0) {
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
        ),
      );
    } else {
      await api.createRecord(
        CreateExpenseInput(
          amount: amount,
          accountId: accId,
          categoryId: catId,
          recordDate: date,
          note: note.isEmpty ? null : note,
        ),
      );
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
      _expression = '';
    });
  }

  // ===== 数字键盘表达式(对齐 uniapp pressKey + computeAmount) =====

  double _computeAmount() {
    if (_expression.isEmpty) return 0;
    if (!_expression.contains('+')) {
      final n = double.tryParse(_expression) ?? 0;
      return n.isFinite ? n : 0;
    }
    return _expression
        .split('+')
        .fold<double>(0, (s, x) => s + (double.tryParse(x) ?? 0));
  }

  void _pressKey(String key) {
    setState(() {
      if (key == 'back') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        return;
      }
      if (key == '+' || key == '−') {
        if (_expression.isEmpty) {
          _expression = '0+';
        } else {
          final last = _expression[_expression.length - 1];
          if (last == '+' || last == '-') {
            _expression = '${_expression.substring(0, _expression.length - 1)}+';
          } else {
            _expression = '$_expression+';
          }
        }
        return;
      }
      if (key == '.') {
        final seg = _expression.split(RegExp(r'[+\-]')).last;
        if (!seg.contains('.')) _expression = '$_expression.';
        return;
      }
      if (key == '✓') {
        // 提交按键 — 复用 _submit 流程。
        _amountCtrl.text = _computeAmount().toStringAsFixed(2);
        _submit();
        return;
      }
      // 数字
      if (_expression.length >= 12) return;
      _expression = '$_expression$key';
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
                          // 金额显示:readOnly,值由 _expression 计算并写到 controller
                          // (对齐 uniapp .qa-amount:¥ prefix + 大字号数字 + 自带 keypad)。
                          TextField(
                            controller: _amountCtrl,
                            readOnly: true,
                            showCursor: false,
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
                          const SizedBox(height: AppSpacing.md),
                          // 数字键盘(对齐 uniapp .qa-keypad 4 列 × 4 行)
                          _NumPad(onKey: _pressKey, submitting: _submitting),
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

// ===== 数字键盘(对齐 uniapp components/QuickAddModal.vue .qa-keypad) =====
//
// 4 列 × 4 行;键值语义:
//   digits → 追加到 _expression(最多 12 字符)
//   '.'    → 当前数字段已含 . 时忽略
//   'back' → 删最后一字符
//   '+'/'−'→ 在表达式后追加 '+'(已 + / - 则替换)
//   '✓'    → 触发 _submit
class _NumPad extends StatelessWidget {
  const _NumPad({required this.onKey, required this.submitting});
  final ValueChanged<String> onKey;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_KeyDef>>[
      [
        const _KeyDef('1'),
        const _KeyDef('2'),
        const _KeyDef('3'),
        const _KeyDef('⌫', kind: _KeyKind.back),
      ],
      [
        const _KeyDef('4'),
        const _KeyDef('5'),
        const _KeyDef('6'),
        const _KeyDef('+', kind: _KeyKind.op),
      ],
      [
        const _KeyDef('7'),
        const _KeyDef('8'),
        const _KeyDef('9'),
        const _KeyDef('−', kind: _KeyKind.op),
      ],
      [
        const _KeyDef('0', span: 2),
        const _KeyDef('.'),
        const _KeyDef('✓', kind: _KeyKind.confirm),
      ],
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  Expanded(
                    flex: row[i].span,
                    child: _NumKey(
                      def: row[i],
                      submitting: submitting,
                      onTap: () => onKey(row[i].value),
                    ),
                  ),
                  if (i < row.length - 1)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

enum _KeyKind { digit, back, op, confirm }

class _KeyDef {
  const _KeyDef(this.value, {this.kind = _KeyKind.digit, this.span = 1});
  final String value;
  final _KeyKind kind;
  final int span;
}

class _NumKey extends StatelessWidget {
  const _NumKey({
    required this.def,
    required this.onTap,
    required this.submitting,
  });
  final _KeyDef def;
  final VoidCallback onTap;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    Color bg;
    Color fg;
    switch (def.kind) {
      case _KeyKind.confirm:
        bg = c.primary;
        fg = Colors.white;
        break;
      case _KeyKind.back:
      case _KeyKind.op:
        bg = c.surface;
        fg = c.textVariant;
        break;
      case _KeyKind.digit:
        bg = c.surface;
        fg = c.text;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: def.kind == _KeyKind.confirm && submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  def.value,
                  style: TextStyle(
                    color: fg,
                    fontSize: 20,
                    fontWeight: def.kind == _KeyKind.confirm
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}