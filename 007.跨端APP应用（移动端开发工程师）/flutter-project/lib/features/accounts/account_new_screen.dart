import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/account_presentation.dart';
import '../shared/providers.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/zhanghu-add/index.vue — 新建账户表单。
class AccountNewScreen extends ConsumerStatefulWidget {
  const AccountNewScreen({super.key});

  @override
  ConsumerState<AccountNewScreen> createState() => _AccountNewScreenState();
}

class _AccountNewScreenState extends ConsumerState<AccountNewScreen> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  AccountType _type = AccountType.cash;
  bool _isDefault = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = I18n.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ref.read(toastControllerProvider.notifier).show(lang.t('accountAdd.name'));
      return;
    }
    final bal = double.tryParse(_balanceCtrl.text.trim()) ?? 0;
    setState(() => _submitting = true);
    try {
      await ref.read(accountsApiProvider).createAccount(
            CreateAccountInput(
              name: name,
              type: _type,
              icon: _iconFor(_type),
              initialBalance: bal,
              currency: 'CNY',
              isDefault: _isDefault,
              note: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
            ),
          );
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('accountAdd.submitAccount'));
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/accounts');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('accountAdd.saveFailPrefix')} ($e)',
          );
    }
  }

  String _iconFor(AccountType t) {
    switch (t) {
      case AccountType.cash:
        return 'wallet';
      case AccountType.debit:
        return 'card';
      case AccountType.credit:
        return 'credit-card';
      case AccountType.wallet:
        return 'wallet-fill';
      case AccountType.investment:
        return 'trending-up';
      case AccountType.other:
        return 'more';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final preset = presentAccount(Account(
      id: 'tmp',
      name: '',
      type: _type,
      icon: '',
      initialBalance: 0,
      balance: 0,
      currency: 'CNY',
      isDefault: false,
      sortOrder: 0,
      createdAt: '',
    ));
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('accountAdd.title')),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: preset.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(preset.icon, color: preset.foreground, size: 36),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: lang.t('accountAdd.namePlaceholder'),
                      hintStyle: TextStyle(color: preset.foreground),
                    ),
                    style: TextStyle(
                      color: preset.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(lang.t('accountAdd.type'),
              style: TextStyle(color: c.textVariant, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in AccountType.values)
                ChoiceChip(
                  label: Text(_typeLabel(lang, t)),
                  selected: t == _type,
                  selectedColor: c.primaryLight,
                  labelStyle: TextStyle(color: t == _type ? c.primary : c.text),
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(lang.t('accountAdd.balance'),
              style: TextStyle(color: c.textVariant, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _balanceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixText: '¥ ',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            title: Text(lang.t('accountAdd.isDefault')),
            subtitle: Text(lang.t('accountAdd.isDefaultHint'),
                style: TextStyle(color: c.textVariant, fontSize: 12)),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
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
                  ? lang.t('accountAdd.submitting')
                  : lang.t('accountAdd.submitAccount'),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(Lang lang, AccountType t) {
    final key = 'accountAdd.type.${t.name}';
    return lang.t(key);
  }
}