import 'package:flutter/material.dart';

import '../api/models.dart';

/// 对齐 uniapp pages/accounts/index.vue 的 themeMap —
/// AccountType → emoji 字形 + 背景色 + 前景色。
/// 之前用 Material Icons(cake/$/bank-building 那套)是错的,uniapp 截图里
/// 卡片图标就是 emoji 字符直接渲染在 colored circle 上。
class AccountPresentation {
  AccountPresentation({
    required this.iconText,
    required this.background,
    required this.foreground,
  });
  final String iconText;
  final Color background;
  final Color foreground;
}

const _typeMap = <AccountType, _PresentationSpec>{
  // ponytail: 完全对齐 uniapp themeMap(debit 和 other 都 fallback 到 bank)。
  AccountType.credit: _PresentationSpec('💳', Color(0x1FBA1A1A), Color(0xFFBA1A1A)),
  AccountType.cash: _PresentationSpec('💵', Color(0xFFDCE9FF), Color(0xFF8B6E4E)),
  AccountType.wallet: _PresentationSpec('👛', Color(0xFFE5F5E9), Color(0xFF09B83E)),
  AccountType.debit: _PresentationSpec('🏦', Color(0xFFE5EEFF), Color(0xFF005394)),
  AccountType.investment: _PresentationSpec('📈', Color(0xFFE5F5E9), Color(0xFF09B83E)),
  AccountType.other: _PresentationSpec('🏦', Color(0xFFE5EEFF), Color(0xFF005394)),
};

class _PresentationSpec {
  const _PresentationSpec(this.iconText, this.background, this.foreground);
  final String iconText;
  final Color background;
  final Color foreground;
}

AccountPresentation presentAccount(Account a) {
  // ponytail: 用户反馈新建账户选的 emoji 没显示。uniapp 列表严格走 type
  //          派生 themeMap(忽略后端 account.icon),Flutter 之前跟它一致
  //          所以列表也不显示用户选的 emoji。这里改成:后端 account.icon
  //          非空时优先用 icon(用户自选 emoji),fallback 才走 type 派生
  //          — 跟 uniapp 在这一点上有差异,但用户的实际反馈优先。
  final userIcon = a.icon.trim();
  if (userIcon.isNotEmpty) {
    final spec = _typeMap[a.type] ?? _typeMap[AccountType.other]!;
    return AccountPresentation(
      iconText: userIcon,
      background: spec.background,
      foreground: spec.foreground,
    );
  }
  final spec = _typeMap[a.type] ?? _typeMap[AccountType.other]!;
  return AccountPresentation(
    iconText: spec.iconText,
    background: spec.background,
    foreground: spec.foreground,
  );
}

String accountAccent(AccountType t) => switch (t) {
      AccountType.cash => '#8B6E4E',
      AccountType.debit => '#005394',
      AccountType.credit => '#BA1A1A',
      AccountType.wallet => '#09B83E',
      AccountType.investment => '#09B83E',
      AccountType.other => '#005394',
    };
