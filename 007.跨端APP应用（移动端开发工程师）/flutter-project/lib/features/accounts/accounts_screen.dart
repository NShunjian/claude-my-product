import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/account_presentation.dart';
import '../../core/utils/finance.dart';
import '../shared/providers.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/zhanghu/index.vue — 账户列表 + 删除 + 新增。
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  late Future<List<Account>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Account>> _load() async {
    final bookId = ref.read(currentBookIdProvider);
    return ref
        .read(accountsApiProvider)
        .listAccounts(bookId: bookId.isEmpty ? null : bookId);
  }

  Future<void> _confirmDelete(Account a) async {
    final lang = I18n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(lang.t('accounts.deleteConfirm')),
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
      await ref.read(accountsApiProvider).deleteAccount(a.id);
      if (!mounted) return;
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('accounts.title'))),
      body: RefreshIndicator(
        onRefresh: () async {
          final f = _load();
          setState(() => _future = f);
          await f;
        },
        child: FutureBuilder<List<Account>>(
          future: _future,
          builder: (context, snap) {
            // 首次加载还没数据 → 整页占位
            if (!snap.hasData) {
              if (snap.connectionState != ConnectionState.done) {
                return Center(
                  child: Text(
                    lang.t('accounts.loading'),
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
                        '${lang.t('accounts.loadErrorPrefix')}${snap.error}',
                        style: TextStyle(color: c.error),
                      ),
                    ),
                  ],
                );
              }
            }
            // 已有数据(包括刷新中的 stale snapshot)→ 渲染数据,顶部加进度条
            final list = snap.data!;
            final isReloading =
                snap.connectionState != ConnectionState.done;
            final total =
                list.fold<double>(0, (sum, a) => sum + a.balance);
            return Column(
              children: [
                if (isReloading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Color(0x00000000),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _NetCard(
                        total: total,
                        label: lang.t('accounts.netAssets'),
                        addCta: lang.t('accounts.addCta'),
                        onAdd: () => context.push(AppRoutes.accountNew),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                          ),
                          child: Center(
                            child: Text(
                              lang.t('accounts.empty'),
                              style: TextStyle(color: c.textVariant),
                            ),
                          ),
                        )
                      else
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.4,
                          children: [
                            for (final a in list)
                              _AccountCard(
                                account: a,
                                onTap: () {},
                                onLongPress: () => _confirmDelete(a),
                                onMore: () => _confirmDelete(a),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({
    required this.total,
    required this.label,
    required this.addCta,
    required this.onAdd,
  });
  final double total;
  final String label;
  final String addCta;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 对齐 uniapp .net-label:uppercase + letter-spacing(Flutter 没有 text-transform,
          // 用 fontFeatures uppercase + letterSpacing 模拟视觉)。
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.textVariant,
              fontSize: 12,
              letterSpacing: 1.0,
              fontFeatures: const [FontFeature.enable('case')],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatAmount(total, withSymbol: true),
            style: TextStyle(
              color: total < 0 ? c.error : c.text,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 内联 "+ 添加账户" 按钮(uniapp .add-btn:primary 实色 + 白字 + 圆角)。
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '+',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    addCta,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 对齐 uniapp .acc-card:icon + ⋮ 顶行、name + subtitle 中行、balance 底行。
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });
  final Account account;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pres = presentAccount(account);
    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: c.divider),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: pres.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(pres.icon, color: pres.foreground, size: 20),
                  ),
                  InkWell(
                    onTap: onMore,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Text(
                        '⋮',
                        style: TextStyle(
                          color: c.textVariant,
                          fontSize: 16,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    typeOfAccount(account.type),
                    style: TextStyle(color: c.textVariant, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Text(
                formatAmount(account.balance, withSymbol: true),
                style: TextStyle(
                  color: account.balance < 0 ? c.error : c.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}