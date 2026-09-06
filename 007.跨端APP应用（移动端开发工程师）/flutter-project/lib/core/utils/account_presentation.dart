import 'package:flutter/material.dart';

import '../api/models.dart';

/// 对齐 utils/account-presentation.ts — Account → 图标/背景/前景色。
class AccountPresentation {
  AccountPresentation({
    required this.icon,
    required this.background,
    required this.foreground,
  });
  final IconData icon;
  final Color background;
  final Color foreground;
}

const _typeMap = <AccountType, _PresentationSpec>{
  AccountType.cash: _PresentationSpec(Icons.account_balance_wallet_outlined, Color(0xFFE8F1FF), Color(0xFF2E7DE6)),
  AccountType.debit: _PresentationSpec(Icons.credit_card_outlined, Color(0xFFE3F2FD), Color(0xFF1976D2)),
  AccountType.credit: _PresentationSpec(Icons.credit_card, Color(0xFFFDE7E9), Color(0xFFBA1A1A)),
  AccountType.wallet: _PresentationSpec(Icons.account_balance_wallet, Color(0xFFEDE7F6), Color(0xFF7B1FA2)),
  AccountType.investment: _PresentationSpec(Icons.trending_up, Color(0xFFE8F5E9), Color(0xFF388E3C)),
  AccountType.other: _PresentationSpec(Icons.more_horiz, Color(0xFFEEEEEE), Color(0xFF727782)),
};

class _PresentationSpec {
  const _PresentationSpec(this.icon, this.background, this.foreground);
  final IconData icon;
  final Color background;
  final Color foreground;
}

AccountPresentation presentAccount(Account a) {
  final spec = _typeMap[a.type] ?? _typeMap[AccountType.other]!;
  return AccountPresentation(
    icon: spec.icon,
    background: spec.background,
    foreground: spec.foreground,
  );
}

String accountAccent(AccountType t) => switch (t) {
      AccountType.cash => '#2E7DE6',
      AccountType.debit => '#1976D2',
      AccountType.credit => '#BA1A1A',
      AccountType.wallet => '#7B1FA2',
      AccountType.investment => '#388E3C',
      AccountType.other => '#727782',
    };