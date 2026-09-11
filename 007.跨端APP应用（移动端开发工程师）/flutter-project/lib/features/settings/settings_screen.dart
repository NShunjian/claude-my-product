import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/models.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/category_presentation.dart';
import '../../core/utils/tab_refresh_signal.dart';
import '../shared/auth_controller.dart';
import '../shared/app_header.dart';
import '../shared/providers.dart';
import '../shared/theme_controller.dart';
import '../shared/toast_controller.dart';

/// 对齐 uniapp pages/settings/index.vue:40 emoji × 21 色 swatch。
/// 选中 = 该色填充 + 白字 emoji;未选中 = 仅展示。
const List<String> _kIconChoices = [
  '🍔', '☕', '🛍️', '🚗', '✈️', '🏠',
  '🎮', '🎵', '💰', '❤️', '🎁', '🐱',
  '🍕', '🍷', '🎬', '📚', '💊', '🎨',
  '⚽', '🚲', '🚌', '✏️', '🎂', '🌹',
  '🍎', '🍞', '🍜', '🍰',
  '🍵', '🍺',
  '🛒', '💳',
  '📱', '💻',
  '🏥', '🏋️',
  '🎓', '💼',
  '🐶', '🌷',
  '🗂️',
];

const List<String> _kColorChoices = [
  '#FFFFFF',
  '#ED8936', '#4299E1', '#ED64A6', '#805AD5',
  '#8B6E4E', '#E53E3E', '#319795', '#718096',
  '#A0AEC0', '#38B2AC', '#DD6B20', '#D69E2E',
  '#10b981', '#3b82f6', '#6366f1', '#ec4899',
  '#f43f5e', '#84cc16', '#facc15', '#a855f7',
];

/// 对齐 uniapp pages/settings/index.vue — 6 节:用户卡 + 系统偏好 + 自定义分类 + 数据导出 + 关于轻账 + 账号安全。
/// 卡片内部结构(head + 子内容 + 退出按钮)全部按 uniapp 同款视觉重建。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppHeader(title: lang.t('pageTitle.settings'), back: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          // heading(对齐 uniapp .heading:32rpx w700 — Flutter 用 18 w600 折中)
          Text(
            lang.t('settings.heading'),
            style: TextStyle(
              color: c.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _UserCard(user: auth.user),
          const SizedBox(height: AppSpacing.lg),
          const _PrefsCard(),
          const SizedBox(height: AppSpacing.lg),
          const _CategoriesCard(),
          const SizedBox(height: AppSpacing.lg),
          const _ExportCard(),
          const SizedBox(height: AppSpacing.lg),
          const _AboutCard(),
          const SizedBox(height: AppSpacing.lg),
          const _SecurityCard(),
        ],
      ),
    );
  }
}

// ===== 用户卡(对齐 uniapp .user-card:居中 + 大圆头像 + 信息行 + 全宽编辑按钮) =====

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final displayName =
        user?.displayName ?? user?.username ?? lang.t('login.title');
    final genderText = switch (user?.gender) {
      Gender.male => lang.t('settings.userCard.gender.male'),
      Gender.female => lang.t('settings.userCard.gender.female'),
      Gender.other => lang.t('settings.userCard.gender.other'),
      null => lang.t('settings.userCard.gender.none'),
    };
    final ageText = user?.age != null
        ? '${user!.age}'
        : lang.t('settings.userCard.age.none');
    final avatarUrl = user?.avatar;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: c.primaryLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: hasAvatar
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        '👤',
                        style: TextStyle(fontSize: 40, color: c.primary),
                      ),
                    ),
                  )
                : Text('👤', style: TextStyle(fontSize: 40, color: c.primary)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            displayName,
            style: TextStyle(
              color: c.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${lang.t('settings.userCard.accountLabel')}: ${user?.username ?? '—'}',
            style: TextStyle(color: c.textVariant, fontSize: 13),
          ),
          Text(
            lang.t('settings.userCard.freeVersion'),
            style: TextStyle(color: c.textVariant, fontSize: 13),
          ),
          Text(
            '${lang.t('settings.userCard.genderLabel')}: $genderText',
            style: TextStyle(color: c.textVariant, fontSize: 13),
          ),
          Text(
            '${lang.t('settings.userCard.ageLabel')}: $ageText',
            style: TextStyle(color: c.textVariant, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => context.push(AppRoutes.profileEdit),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.divider),
                // ponytail: 高度直接钉 50px(用户指定)。去掉 Material 默认 48px
                //          tap target 撑高,uniapp .btn-outline 总高约 38px,
                //          这里用户要求对齐 50。
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 50),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                lang.t('settings.userCard.editProfile'),
                style: TextStyle(color: c.text, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 系统偏好卡(对齐 uniapp .prefs-card:⚙️ 标题 + 主题分段 + 分隔线 + 语言下拉) =====

class _PrefsCard extends ConsumerWidget {
  const _PrefsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final currentTheme = ref.watch(themeControllerProvider);
    final currentLang = ref.watch(languageProvider);
    return Container(
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                const _IconCircle(emoji: '⚙️'),
                const SizedBox(width: AppSpacing.md),
                Text(
                  lang.t('settings.prefs.title'),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _ThemeRow(
              current: currentTheme,
              onChange: (m) =>
                  ref.read(themeControllerProvider.notifier).setMode(m),
              lang: lang,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: _LangRow(
              current: currentLang,
              onChange: (l) =>
                  ref.read(languageProvider.notifier).setLang(l),
              lang: lang,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.current,
    required this.onChange,
    required this.lang,
  });
  final ThemeChoice current;
  final ValueChanged<ThemeChoice> onChange;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    String label(ThemeChoice m) {
      final key = switch (m) {
        ThemeChoice.system => 'settings.prefs.theme.system',
        ThemeChoice.light => 'settings.prefs.theme.light',
        ThemeChoice.dark => 'settings.prefs.theme.dark',
      };
      return lang.t(key);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t('settings.prefs.theme.label'),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lang.t('settings.prefs.theme.desc'),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: c.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ThemeChoice.values.map((m) {
                final active = m == current;
                return GestureDetector(
                  onTap: () => onChange(m),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: active ? c.bgCard : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      label(m),
                      style: TextStyle(
                        color: active ? c.text : c.textVariant,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.current,
    required this.onChange,
    required this.lang,
  });
  final Lang current;
  final ValueChanged<Lang> onChange;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('settings.prefs.lang.label'),
                style: TextStyle(
                  color: c.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                lang.t('settings.prefs.lang.desc'),
                style: TextStyle(color: c.textVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuButton<Lang>(
          tooltip: '',
          offset: const Offset(0, 32),
          onSelected: onChange,
          itemBuilder: (_) => Lang.values
              .map((l) => PopupMenuItem(value: l, child: Text(l.label)))
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: c.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current.label,
                  style: TextStyle(color: c.text, fontSize: 13),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: c.textVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===== 通用:icon-circle(对齐 uniapp .icon-circle / .icon-circle-lg) =====

class _IconCircle extends StatelessWidget {
  /// emoji 字符串 或 child Widget — 任一即可(uniapp 用 emoji,Flutter 用 Material Icon)。
  const _IconCircle({this.emoji, this.child});
  final String? emoji;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.primaryLight,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child ?? (emoji != null
          ? Text(emoji!, style: const TextStyle(fontSize: 18))
          : null),
    );
  }
}

// ===== 数据导出卡(对齐 uniapp .data-card + .export-grid:3 张卡 + Material 图标) =====

class _ExportCard extends ConsumerStatefulWidget {
  const _ExportCard();

  @override
  ConsumerState<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends ConsumerState<_ExportCard> {
  String? _busy; // 'monthly' | 'category' | 'all' | null
  String? _err;

  Future<void> _run(String kind) async {
    final lang = I18n.of(context);
    setState(() {
      _busy = kind;
      _err = null;
    });
    try {
      // 接 utils/export.dart 真函数(替代 Future.delayed 占位)。
      // ExportService 在 native 端通过 share_plus 弹系统分享面板保存;
      // web/desktop 端会抛 UnsupportedError(提示后续走 dart:html 下载)。
      final svc = ref.read(exportServiceProvider);
      switch (kind) {
        case 'monthly':
          await svc.exportMonthly();
          break;
        case 'category':
          await svc.exportByCategory();
          break;
        case 'all':
          await svc.exportAll();
          break;
      }
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            lang.t('settings.data.exportDesc'),
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e is ApiException ? e.message : '$e';
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    String label(String key, String fallback) => _busy == key
        ? lang.t('settings.data.exporting')
        : lang.t(fallback);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconCircle(child: Icon(Icons.dataset_outlined, size: 18)),
              const SizedBox(width: AppSpacing.md),
              Text(
                lang.t('settings.data.title'),
                style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _ExportBtn(
                  busy: _busy == 'monthly',
                  icon: Icons.calendar_month,
                  label: label('monthly', 'settings.data.exportMonthly'),
                  disabled: _busy != null,
                  onTap: () => _run('monthly'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ExportBtn(
                  busy: _busy == 'category',
                  icon: Icons.folder_outlined,
                  label: label('category', 'settings.data.exportCategory'),
                  disabled: _busy != null,
                  onTap: () => _run('category'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ExportBtn(
                  busy: _busy == 'all',
                  icon: Icons.check_circle_outline,
                  iconColor: c.primary,
                  label: label('all', 'settings.data.exportAll'),
                  disabled: _busy != null,
                  onTap: () => _run('all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _err != null
                ? '${lang.t('settings.data.exportFailPrefix')}$_err'
                : lang.t('settings.data.exportDesc'),
            style: TextStyle(color: c.textVariant, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ExportBtn extends StatelessWidget {
  const _ExportBtn({
    required this.busy,
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onTap,
    this.iconColor,
  });
  final bool busy;
  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.divider),
          ),
          child: Column(
            children: [
              busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      icon,
                      size: 32,
                      color: iconColor ?? c.textVariant,
                    ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(color: c.text, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 关于轻账卡(对齐 uniapp .about-card:ℹ️ + Q logo + 版本 + 链接) =====

class _AboutCard extends ConsumerWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final future = ref.read(versionApiProvider).getSystemVersion();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 蓝实心 info icon(对齐 uniapp .mat-icon primary-icon style font-size:22px)
              Icon(Icons.info, size: 22, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                lang.t('settings.about.title'),
                style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FutureBuilder<SystemVersion>(
            future: future,
            builder: (context, snap) {
              String ver;
              String status;
              if (snap.connectionState == ConnectionState.waiting) {
                ver = 'QingZhang v…';
                status = lang.t('settings.about.fetchingVersion');
              } else if (snap.hasError || !snap.hasData) {
                ver = 'QingZhang v—';
                status = lang.t('settings.about.versionUnavailable');
              } else {
                ver = 'QingZhang v${snap.data!.version}';
                status = lang.t('settings.about.currentVersion');
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 64,
                    decoration: BoxDecoration(
                      color: c.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Q',
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ver,
                          style: TextStyle(
                            color: c.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status,
                          style: TextStyle(
                            color: c.textVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                lang.t('settings.about.terms'),
                style: TextStyle(color: c.primary, fontSize: 13),
              ),
              const SizedBox(width: AppSpacing.xl),
              Text(
                lang.t('settings.about.privacy'),
                style: TextStyle(color: c.primary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== 账号安全卡(对齐 uniapp .security-card:🛡️ + 描述 + 右下退出按钮) =====

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 红实心 shield icon(对齐 uniapp .mat-icon danger-icon style font-size:22px)
              Icon(Icons.shield, size: 22, color: c.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                lang.t('settings.accountSecurity.title'),
                style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            lang.t('settings.accountSecurity.desc'),
            style: TextStyle(
              color: c.textVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (!context.mounted) return;
                if (context.canPop()) context.pop();
                context.go(AppRoutes.login);
              },
              icon: const Icon(Icons.logout, size: 16),
              label: Text(lang.t('settings.accountSecurity.logout')),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.error,
                side: BorderSide(color: c.error, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 自定义分类 CRUD(对齐 uniapp .categories-card + cat-tabs + cat-list + modal) =====

class _CategoriesCard extends ConsumerStatefulWidget {
  const _CategoriesCard();

  @override
  ConsumerState<_CategoriesCard> createState() => _CategoriesCardState();
}

class _CategoriesCardState extends ConsumerState<_CategoriesCard> {
  late Future<List<Category>> _future;
  CategoryType _tab = CategoryType.expense;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // ponytail: 切到 settings tab 时重拉分类列表(4)。沿用 ref.listenManual,
    //          next > prev 才触发,初始 0 不触发空拉。
    ref.listenManual<int>(tabRefreshSignalProvider(4), (prev, next) {
      if (prev != null && next > prev) _refresh();
    });
  }

  Future<List<Category>> _load() {
    return ref.read(categoriesApiProvider).listCategories(type: _tab);
  }

  // ponytail: setState 必须是同步闭包,`setState(() => _future = _load())`
  //          把 Future 当返回值,Flutter 拒绝执行,_future 不更新 → 列表不刷。
  //          改成两步:先 _load() 拿 Future,再 setState 赋值。
  void _refresh() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  void _switchTab(CategoryType t) {
    if (t == _tab) return;
    setState(() {
      _tab = t;
      _future = _load();
    });
  }

  Future<void> _openCreate() async {
    final lang = I18n.of(context);
    final result = await _showCategoryEditor(
      context: context,
      title: lang.t('settings.categories.create.toggle'),
      initialName: '',
      initialIcon: '',
      initialColor: '#A0AEC0',
      showDelete: false,
    );
    if (result == null || !mounted) return;
    final api = ref.read(categoriesApiProvider);
    final toast = ref.read(toastControllerProvider.notifier);
    try {
      await api.createCategory(
        CreateCategoryInput(
          type: _tab,
          name: result.name,
          icon: result.icon,
          color: result.color,
        ),
      );
      toast.show(lang.t('settings.categories.create.success'));
      _refresh();
    } catch (e) {
      toast.show('${lang.t('settings.categories.create.failPrefix')} ${e is ApiException ? e.message : '$e'}');
    }
  }

  Future<void> _openEdit(Category c) async {
    final lang = I18n.of(context);
    final result = await _showCategoryEditor(
      context: context,
      title: lang.t('settings.categories.edit.title'),
      initialName: c.name,
      initialIcon: c.icon,
      initialColor: c.color,
      showDelete: true,
    );
    if (result == null || !mounted) return;
    final api = ref.read(categoriesApiProvider);
    final toast = ref.read(toastControllerProvider.notifier);
    // 删除分支:editor 返回 _EditorResult.deleted = true。
    if (result.deleted) {
      final ok = await _confirmDelete(c);
      if (ok != true || !mounted) return;
      try {
        await api.deleteCategory(c.id);
        toast.show(lang.t('settings.categories.delete.success'));
        _refresh();
      } catch (e) {
        toast.show('${lang.t('settings.categories.delete.failPrefix')} ${e is ApiException ? e.message : '$e'}');
      }
      return;
    }
    try {
      await api.updateCategory(
        c.id,
        UpdateCategoryInput(
          name: result.name.trim().isEmpty ? null : result.name.trim(),
          icon: result.icon,
          color: result.color,
        ),
      );
      toast.show(lang.t('settings.categories.edit.success'));
      _refresh();
    } catch (e) {
      toast.show('${lang.t('settings.categories.edit.failPrefix')} ${e is ApiException ? e.message : '$e'}');
    }
  }

  Future<bool?> _confirmDelete(Category c) {
    final lang = I18n.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          lang.t('settings.categories.delete.confirm').replaceAll('{name}', c.name),
        ),
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
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    // 切换账本后刷新列表。
    ref.listen<String>(currentBookIdProvider, (prev, next) {
      if (prev != next) _refresh();
    });
    return Container(
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('📂', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        lang.t('settings.categories.title'),
                        style: TextStyle(
                          color: c.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // .btn-add:实色 + 白字 + 圆角(uniapp .btn-add)
                Material(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: _openCreate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '＋',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lang.t('settings.categories.create.toggle'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // .cat-tabs:分段(expense/income,active = primary 实色 + 白字 + w600)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _CatTabBtn(
                    active: _tab == CategoryType.expense,
                    label: lang.t('settings.categories.tab.expense'),
                    onTap: () => _switchTab(CategoryType.expense),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CatTabBtn(
                    active: _tab == CategoryType.income,
                    label: lang.t('settings.categories.tab.income'),
                    onTap: () => _switchTab(CategoryType.income),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // .cat-list
          FutureBuilder<List<Category>>(
            future: _future,
            builder: (context, snap) {
              // ponytail: 改用 !snap.hasData 而不是 connectionState != done —
              //          reload 时保留旧数据,顶部加进度条,跟 home / accounts
              //          风格一致;否则 reload 期间列表整体替换成 spinner。
              if (!snap.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.primary,
                      ),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    '${snap.error}',
                    style: TextStyle(color: c.error, fontSize: 12),
                  ),
                );
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Text(
                      lang.t('common.empty'),
                      style: TextStyle(color: c.textVariant, fontSize: 13),
                    ),
                  ),
                );
              }
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                // ponytail: 对齐 uniapp .cat-item { width: 16.66% } = 1/6,
                //          用 GridView.count(crossAxisCount:6) 模拟 flex-wrap 6 列。
                crossAxisCount: 6,
                // 6 列每格很窄(~60px @ 360 屏宽)。dot(36)+4+名称(14)+1+hex(12)+
                // 3+badge(18)+padding(8) ≈ 96px,宽高比 ≈ 0.62。0.62 给底部
                // badge 留 ~10px 余量,避免 BOTTOM OVERFLOW 报红。
                childAspectRatio: 0.62,
                children: [
                  for (final cat in list)
                    _CatGridCell(category: cat, onEdit: () => _openEdit(cat)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// .cat-tab 单个分段(active = primary bg + 白字 + w600)。
class _CatTabBtn extends StatelessWidget {
  const _CatTabBtn({
    required this.active,
    required this.label,
    required this.onTap,
  });
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: active ? c.primary : c.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : c.textVariant,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// .cat-grid-cell:九宫格单格(用户要求 3 列 3 行 — 从 uniapp 原 6 列 flex-wrap
/// 改为 3 列 grid,内容垂直堆叠)。点击非预设 → 触发 onEdit。
class _CatGridCell extends StatelessWidget {
  const _CatGridCell({required this.category, required this.onEdit});
  final Category category;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final pres = presentCategory(category);
    final color = _parseHex(pres.color);
    final hasIcon = pres.icon.isNotEmpty;
    final isPreset = category.isPreset;
    // ponytail: 白色背景 + 实色填充 → 白卡白点看不见,加一圈 outline 描边
    //          保可见性(同 uniapp .cat-pick-white)。
    final isWhiteBg = !hasIcon && color.toString().toUpperCase() == 'FFFFFFFF';
    return InkWell(
      onTap: isPreset ? null : onEdit,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                // ponytail: 对齐 uniapp `.cat-dot` 浅色背景(color + '22' ≈ 13% alpha)
                //          + 深色 emoji。原来用实色背景,跟"未设置"那种鲜艳撞色。
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                // 纯白底 13% 透明度肉眼看不见,补一圈 divider 边框保可见。
                border: isWhiteBg ? Border.all(color: c.divider) : null,
              ),
              alignment: Alignment.center,
              child: hasIcon
                  ? Text(
                      pres.icon,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1,
                        // emoji 用实色(深色)在浅背景上,跟 uniapp 同款对比度。
                        color: color,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              pres.color.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textVariant, fontSize: 9),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(999),
                // ponytail: 只有"编辑" pill 加边框(类目自身颜色 40% alpha,
                //          跟上方圆点视觉绑);"预设" pill 不加边框(看起来更像
                //          状态徽章而不是可点元素)。
                border: isPreset
                    ? null
                    : Border.all(
                        color: color.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
              ),
              child: Text(
                isPreset
                    ? lang.t('settings.categories.presetBadge')
                    : lang.t('common.edit'),
                style: TextStyle(
                  // 编辑 pill 文字加深(text)跟边框呼应;预设保留 textVariant
                  // 维持低存在感(只读状态)。
                  color: isPreset ? c.textVariant : c.text,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// hex → Color。失败 fallback 到 outline grey。
Color _parseHex(String hex) {
  var s = hex.replaceFirst('#', '');
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  if (v == null) return const Color(0xFF727782);
  return Color(v);
}

// ===== 编辑弹窗(创建/编辑共用,showDelete 切换删除按钮) =====

class _EditorResult {
  const _EditorResult({
    required this.name,
    required this.icon,
    required this.color,
    this.deleted = false,
  });
  final String name;
  final String icon;
  final String color;
  final bool deleted;
}

Future<_EditorResult?> _showCategoryEditor({
  required BuildContext context,
  required String title,
  required String initialName,
  required String initialIcon,
  required String initialColor,
  required bool showDelete,
}) {
  return showDialog<_EditorResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _CategoryEditorDialog(
      title: title,
      initialName: initialName,
      initialIcon: initialIcon,
      initialColor: initialColor,
      showDelete: showDelete,
    ),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({
    required this.title,
    required this.initialName,
    required this.initialIcon,
    required this.initialColor,
    required this.showDelete,
  });
  final String title;
  final String initialName;
  final String initialIcon;
  final String initialColor;
  final bool showDelete;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _nameCtrl;
  late String _icon;
  late String _color;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _icon = widget.initialIcon;
    _color = widget.initialColor;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final iconColor = _parseHex(_color);
    // 白色背景时,emoji 改成深色 → 提升对比度(uniapp 同逻辑)。
    final glyphIsWhite = _color.toUpperCase() != '#FFFFFF';
    return Dialog(
      backgroundColor: c.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // name
                Text(
                  lang.t('settings.categories.field.name'),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _nameCtrl,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // icon picker — 对齐 uniapp `.icon-picker-grid { grid-template-columns: repeat(6, 1fr); gap: 12rpx }`
                Text(
                  lang.t('settings.categories.field.icon'),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
                const SizedBox(height: 6),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 6,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  // ponytail: aspect-ratio 1:1 让格子随 6 列宽度自动计算高度(uniapp
                  //          .icon-pick { aspect-ratio: 1/1; min-height: 72rpx })。
                  //          dialog 已经 ConstrainedBox(maxWidth:420),减去 padding
                  //          ~384 / 6 = 64 ≈ 64,跟 uniapp 72rpx≈36px 接近。
                  childAspectRatio: 1,
                  children: [
                    for (final ic in _kIconChoices)
                      _IconPick(
                        icon: ic,
                        selected: ic == _icon,
                        activeColor: iconColor,
                        glyphIsWhite: glyphIsWhite,
                        onTap: () => setState(() => _icon = ic),
                      ),
                  ],
                ),
                // ponytail: 字段提示(uniapp .field-hint,硬编码「不选图标 = 纯色填充」)。
                //          写在 icon 网格下、color label 上,提醒没 icon 时走纯色填充逻辑。
                const Padding(
                  padding: EdgeInsets.only(top: 6, bottom: AppSpacing.md),
                  child: Text(
                    '不选图标 = 纯色填充',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
                // color picker — 对齐 uniapp `.color-picker-grid { grid-template-columns: repeat(7, 1fr); gap: 10rpx }`
                Text(
                  lang.t('settings.categories.field.color'),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
                const SizedBox(height: 6),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 1,
                  children: [
                    for (final col in _kColorChoices)
                      _ColorPick(
                        hex: col,
                        selected: col.toUpperCase() == _color.toUpperCase(),
                        onTap: () => setState(() => _color = col),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // actions
                Row(
                  children: [
                    if (widget.showDelete) ...[
                      _SmallBtn(
                        label: lang.t('common.delete'),
                        bg: c.error,
                        fg: Colors.white,
                        onTap: () => Navigator.of(context).pop(
                          const _EditorResult(
                            name: '',
                            icon: '',
                            color: '',
                            deleted: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    const Spacer(),
                    _SmallBtn(
                      label: lang.t('common.cancel'),
                      bg: Colors.transparent,
                      fg: c.text,
                      border: c.divider,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _SmallBtn(
                      label: lang.t('common.save'),
                      bg: c.primary,
                      fg: Colors.white,
                      onTap: () => Navigator.of(context).pop(
                        _EditorResult(
                          name: _nameCtrl.text,
                          icon: _icon,
                          color: _color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// icon-picker 单元格:选中 = 该色填充 + (白/深)字 emoji。
class _IconPick extends StatelessWidget {
  const _IconPick({
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.glyphIsWhite,
    required this.onTap,
  });
  final String icon;
  final bool selected;
  final Color activeColor;
  final bool glyphIsWhite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // ponytail: 对齐 uniapp `.icon-pick` 默认 2rpx divider 边框 + 选中 border 换
  //          primary 蓝(背景同步走 activeColor,emoji 颜色随 glyphIsWhite 切换)。
  return Material(
      color: selected ? activeColor : c.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? c.primary : c.divider,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            icon,
            style: TextStyle(
              fontSize: 20,
              color: selected
                  ? (glyphIsWhite ? Colors.white : const Color(0xFF1A202C))
                  : c.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// color-picker 单元格:选中 = 黑色描边 + ✓;白色单独加灰色描边(uniapp .color-pick-white)。
class _ColorPick extends StatelessWidget {
  const _ColorPick({
    required this.hex,
    required this.selected,
    required this.onTap,
  });
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isWhite = hex.toUpperCase() == '#FFFFFF';
    // ponytail: 对齐 uniapp `.color-picker-grid { grid-template-columns: repeat(7, 1fr);
    //          aspect-ratio: 1/1; min-height: 64rpx }`。去固定 32×32,让 circle 由
    //          BoxShape.circle 自动内切 grid cell(每格 ~50px,内 circle ~46px)。
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              color: _parseHex(hex),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? c.text
                    : (isWhite ? c.divider : Colors.transparent),
                width: selected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: isWhite ? c.text : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// .btn-outline-sm / .btn-primary-sm / .btn-danger-sm 共用实现。
class _SmallBtn extends StatelessWidget {
  const _SmallBtn({
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
    required this.onTap,
  });
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: border != null ? Border.all(color: border!) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}