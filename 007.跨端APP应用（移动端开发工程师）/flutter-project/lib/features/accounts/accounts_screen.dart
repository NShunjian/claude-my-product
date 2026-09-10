import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/account_presentation.dart';
import '../../core/utils/finance.dart';
import '../../core/utils/tab_refresh_signal.dart';
import '../shared/app_header.dart';
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
  // ponytail: stale-while-revalidate — FutureBuilder 在 future 变化时
  //          把 snap.data 重置为 null,reload 期间短暂会触发 loading 占位。
  //          这里保留最后一次成功加载的数据,build 用 _data 渲染而不是
  //          snap.data,reload 时旧 list 不消失(顶部加 LinearProgressIndicator
  //          表示在拉新)。
  List<Account>? _data;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // ponytail: 切到 accounts tab 时重拉(3)。next>prev 才触发,初始 0 不触发空拉。
    ref.listenManual<int>(tabRefreshSignalProvider(3), (prev, next) {
      if (prev != null && next > prev) {
        final f = _load();
        setState(() {
          _future = f;
        });
      }
    });
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
      // ponytail: setState 必须是同步闭包,之前 `setState(() => _future =
      //          _load())` 把 Future 当作闭包返回值,Flutter 拒绝执行,导致
      //          卡片不消失。改成显式两步:先拿 Future,再 setState 赋值。
      final f = _load();
      setState(() {
        _future = f;
      });
    } catch (e) {
      if (!mounted) return;
      // ponytail: 之前 catch 直接 toast '$e',把 ApiException 的 toString()
      //          全弹出来(包含 RequestOptions / validateStatus 等一堆
      //          Dio 内部细节,用户看到一堆英文)。改成识别 ApiException
      //          取 .message,后端 4002 "默认账户不可删除..." 这种友好文案
      //          才能正确展示。其他异常 fallback 原字符串。
      final msg = e is ApiException ? e.message : '$e';
      ref.read(toastControllerProvider.notifier).show(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Scaffold(
      // ponytail: 账户页是 tab 内页不是 push 进来的,uniapp 截图顶部没返
      //          回箭头,Flutter 之前 back: true 多余,改成 false。
      appBar: AppHeader(title: lang.t('accounts.title'), back: false),
      body: RefreshIndicator(
        onRefresh: () async {
          final f = _load();
          setState(() => _future = f);
          await f;
        },
        child: FutureBuilder<List<Account>>(
          future: _future,
          builder: (context, snap) {
            // 同步新数据到 _data(在 build 里直接赋值,build 期间 _data 是只
            // 读缓存,snap.data 是新完成的引用,引用相等即停止更新)。
            if (snap.hasData && !identical(snap.data, _data)) {
              _data = snap.data;
            }
            // 首次加载还没数据 → 整页占位
            if (_data == null) {
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
            final list = _data!;
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
                          // ponytail: 间距 sm→md(8→12),uniapp 截图卡片之间
                          //          视觉留白比 Flutter 之前稍宽。
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 1.35,
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
          // 对齐 uniapp 截图:"资产净值" 普通灰字 13px(没有 uppercase/letter-spacing)。
          Text(
            label,
            style: TextStyle(
              color: c.textVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatAmount(total, withSymbol: true),
            style: TextStyle(
              color: total < 0 ? c.error : c.text,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ponytail: uniapp 截图"+ 添加账户"是 ~48px 高的全宽蓝色大按钮,
          //          Flutter 之前是 sm 垂直 padding + 14px 字,显著小一截,改成
          //          垂直 md(12) + 字 16 + w600,跟截图对齐。
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
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
                      fontSize: 18,
                      height: 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    addCta,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
          // ponytail: 卡片内边距 md→lg(12→16),uniapp 截图里图标圆圈距卡边
          //          有明显留白,Flutter 之前 12 略紧。
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                    // ponytail: 之前用 Icon(pres.icon) 渲染 MaterialIcons,
                    //          跟 uniapp themeMap 用 emoji 字符直接渲染的方
                    //          案不同步,uniapp 截图里 🎂/💵/🏦 都是 emoji,
                    //          改成 Text 渲染 emoji 字符串 + colored fg。
                    child: Center(
                      child: Text(
                        pres.iconText,
                        style: TextStyle(
                          color: pres.foreground,
                          fontSize: 20,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  // ponytail: 卡片右上角更多菜单图标 — uniapp 截图是个小图标,
                  //          之前用 text '⋮' 在某些字体下渲染不一致,改用 Material
                  //          Icons.more_vert(三竖点),更清晰且跨平台一致。
                  InkWell(
                    onTap: onMore,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        Icons.more_vert,
                        color: c.textVariant,
                        size: 18,
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