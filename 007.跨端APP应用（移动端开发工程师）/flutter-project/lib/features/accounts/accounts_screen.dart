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
import '../shared/app_header.dart';
import '../shared/providers.dart';
import '../shared/skeleton_shimmer.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/zhanghu/index.vue — 账户列表 + 归档/删除/新增。
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

/// 0=active only, 1=all(活跃+归档), 2=archived only。默认 active。
enum _FilterMode { active, all, archived }

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  late Future<List<Account>> _future;
  // ponytail: stale-while-revalidate — FutureBuilder 在 future 变化时
  //          把 snap.data 重置为 null,reload 期间短暂会触发 loading 占位。
  //          这里保留最后一次成功加载的数据,build 用 _data 渲染而不是
  //          snap.data,reload 时旧 list 不消失(顶部加 LinearProgressIndicator
  //          表示在拉新)。
  List<Account>? _data;
  _FilterMode _filter = _FilterMode.active;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() {
    // ponytail: 之前 _reload 写成 setState(() => _future = f) — 箭头函数
    //          返回赋值表达式值(即 Future f),Flutter setState 在 debug
    //          模式 assert 检测到 callback 返回 Future 就 throw,导致
    //          markNeedsBuild 永远不被调用 → _future 字段被改了但 widget
    //          不知道 rebuild → UI 永远停留在旧 list。切 filter chip 时
    //          另一个 setState(() => _filter = m)(块体,返回 void)正常
    //          触发了 rebuild,新数据才显示。
    //          修复:setState 闭包必须用块体(无返回值)或显式返回 null。
    final f = _load();
    setState(() {
      _future = f;
    });
    f.then((list) {
      if (!mounted) return;
      setState(() {
        _data = list;
      });
    }).catchError((_) {});
  }

  Future<List<Account>> _load() async {
    final bookId = ref.read(currentBookIdProvider);
    return ref.read(accountsApiProvider).listAccounts(
          bookId: bookId.isEmpty ? null : bookId,
          includeArchived: true,
        );
  }

  // ponytail: Flutter 没原生 action sheet,uniapp showActionSheet 在这里是
  //          showModalBottomSheet + 几行 ListTile。同一份菜单根据账户是
  //          归档/活跃 切换项:archived 看「取消归档 + 删除」,active 看
  //          「归档 + 删除」。已软删的账户(将来从后端拿到 isDeleted 字段时)
  //          干脆不展示菜单 —— 概要阶段只接了 archived。
  Future<void> _showActions(Account a) async {
    final lang = I18n.of(context);
    final items = a.isArchived
        ? [lang.t('accounts.unarchive'), lang.t('common.delete')]
        : [lang.t('accounts.archive'), lang.t('common.delete')];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              ListTile(
                title: Text(items[i]),
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (a.isArchived) {
      // [unarchive, delete]
      if (picked == 0) return _confirmUnarchive(a);
      if (picked == 1) return _confirmDelete(a);
    } else {
      // [archive, delete]
      if (picked == 0) return _confirmArchive(a);
      if (picked == 1) return _confirmDelete(a);
    }
  }

  Future<void> _confirmArchive(Account a) async {
    final lang = I18n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(lang.t('accounts.archiveConfirm', {'name': a.name})),
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
      await ref.read(accountsApiProvider).archiveAccount(a.id);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('accounts.archiveSuccess'));
      _reload();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : '$e';
      ref.read(toastControllerProvider.notifier).show(msg);
    }
  }

  Future<void> _confirmUnarchive(Account a) async {
    final lang = I18n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(lang.t('accounts.unarchiveConfirm', {'name': a.name})),
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
      await ref.read(accountsApiProvider).unarchiveAccount(a.id);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('accounts.unarchiveSuccess'));
      _reload();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : '$e';
      ref.read(toastControllerProvider.notifier).show(msg);
    }
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
      _reload();
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
    // ponytail: 之前在 build 里 ref.listen tabRefreshSignalProvider(3) 监听
    //          account_new_screen 保存后推的信号,但 build 内 listen 与
    //          FutureBuilder rebuild 时序竞争导致 IndexedStack 场景下
    //          "返回后新账户不显示"。改成 onAdd 处 await push + 显式
    //          _reload,确定性顺序、无 race,信号监听也就不再需要。
    final lang = I18n.of(context);
    final c = context.appColors;
    return Scaffold(
      // ponytail: 账户页是 tab 内页不是 push 进来的,uniapp 截图顶部没返
      //          回箭头,Flutter 之前 back: true 多余,改成 false。
      appBar: AppHeader(title: lang.t('accounts.title'), back: false),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<List<Account>>(
          future: _future,
          builder: (context, snap) {
            // 同步新数据到 _data(在 build 里直接赋值,build 期间 _data 是只
            // 读缓存,snap.data 是新完成的引用,引用相等即停止更新)。
            if (snap.hasData && !identical(snap.data, _data)) {
              _data = snap.data;
            }
            // 首次加载还没数据 → 骨架屏(对齐 home/transactions 体验)。
            if (_data == null) {
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
              return const _AccountsSkeleton();
            }
            // 已有数据(包括刷新中的 stale snapshot)→ 渲染数据,顶部加进度条
            final list = _data!;
            final visible = switch (_filter) {
              _FilterMode.active => list.where((a) => !a.isArchived).toList(),
              _FilterMode.archived => list.where((a) => a.isArchived).toList(),
              _FilterMode.all => list,
            };
            final isReloading =
                snap.connectionState != ConnectionState.done;
            final total =
                visible.fold<double>(0, (sum, a) => sum + a.balance);
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
                        // ponytail: 用 await push + 显式 _reload 替代 signal 监
                        //          听 — push 返回 Future 在 pop 时完成,await 后
                        //          调用 _reload 是确定性顺序,无 race。之前的信
                        //          号方案(setState _future + context.pop + 异步
                        //          setState _data)在 IndexedStack 场景下出现
                        //          "返回后新账户不显示,切 filter chip 才刷出"
                        //          的 bug,根因是 build/setState 时序与
                        //          FutureBuilder 内部 previousData 缓存竞争。
                        onAdd: () async {
                          await context.push(AppRoutes.accountNew);
                          if (!mounted) return;
                          _reload();
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _FilterChips(
                        mode: _filter,
                        onChanged: (m) => setState(() => _filter = m),
                        labels: (
                          active: lang.t('accounts.filter.active'),
                          all: lang.t('accounts.filter.all'),
                          archived: lang.t('accounts.filter.archivedOnly'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (visible.isEmpty)
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
                            for (final a in visible)
                              _AccountCard(
                                account: a,
                                onTap: () {},
                                onLongPress: () => _showActions(a),
                                onMore: () => _showActions(a),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.mode,
    required this.onChanged,
    required this.labels,
  });
  final _FilterMode mode;
  final ValueChanged<_FilterMode> onChanged;
  final ({String active, String all, String archived}) labels;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    Widget chip(_FilterMode m, String text) {
      final selected = mode == m;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? c.primary : c.bgCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.divider),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : c.textVariant,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_FilterMode.active, labels.active),
        const SizedBox(width: AppSpacing.sm),
        chip(_FilterMode.all, labels.all),
        const SizedBox(width: AppSpacing.sm),
        chip(_FilterMode.archived, labels.archived),
      ],
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
    return Opacity(
      opacity: account.isArchived ? 0.5 : 1.0,
      child: Material(
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.name,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (account.isArchived) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              I18n.of(context).t('accounts.archivedBadge'),
                              style: TextStyle(
                                color: c.textVariant,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
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
      ),
    );
  }
}

/// 骨架屏 —— 首次 _data==null 时渲染。模仿账户页真实布局:净资产卡 +
/// 筛选 chips + 2 列网格(4 个账户卡占位)。
class _AccountsSkeleton extends StatelessWidget {
  const _AccountsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final base = c.divider;
    final high = c.textVariant.withValues(alpha: 0.15);
    Widget bar(double w, {double h = 14, Color? color}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color ?? high,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    Widget card({Widget? child}) => Container(
          // ponytail: 不写 height,Container 自适应 Column intrinsic 高度,
          //          避免 "BOTTOM OVERFLOWED BY N PIXELS"(home/transactions 同款)。
          decoration: BoxDecoration(
            color: c.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: base),
          ),
          padding: const EdgeInsets.all(12),
          child: child ?? const SizedBox.shrink(),
        );
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(80, h: 12),
                const SizedBox(height: 12),
                bar(180, h: 28),
                const SizedBox(height: 12),
                bar(120, h: 12),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                Container(
                  width: 70,
                  height: 28,
                  decoration: BoxDecoration(
                    color: high,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                if (i < 2) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.1,
            children: [
              for (int i = 0; i < 4; i++)
                card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: high,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      bar(double.infinity, h: 12),
                      const SizedBox(height: 6),
                      bar(80, h: 10),
                      const Spacer(),
                      bar(100, h: 14),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
