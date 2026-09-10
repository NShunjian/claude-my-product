import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/category_presentation.dart';
import '../../core/utils/tab_refresh_signal.dart';
import '../shared/auth_controller.dart';
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

/// 对齐 pages/me/index.vue — 用户卡 + 系统偏好 + 自定义分类 + 数据导出 + 关于 + 退出。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('pageTitle.settings'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _UserCard(user: auth.user),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: lang.t('settings.prefs.title'),
            children: [
              const _ThemePrefTile(),
              const _LanguagePrefTile(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _CategoriesCard(),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: lang.t('settings.data.title'),
            children: [
              _DataExportTile(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: lang.t('settings.about.title'),
            children: const [
              _AboutTile(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: lang.t('settings.accountSecurity.title'),
            children: [
              ListTile(
                leading: Icon(Icons.logout, color: c.error),
                title: Text(
                  lang.t('settings.accountSecurity.logout'),
                  style: TextStyle(color: c.error),
                ),
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (!context.mounted) return;
                  if (context.canPop()) context.pop();
                  context.go(AppRoutes.login);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: c.primaryLight,
            child: Text(
              (user?.displayName ?? user?.username ?? '?')
                  .characters
                  .first
                  .toUpperCase(),
              style: TextStyle(
                color: c.primary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? user?.username ?? lang.t('login.title'),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  lang.t('settings.userCard.freeVersion'),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.profileEdit),
                  child: Text(lang.t('settings.userCard.editProfile')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
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
              AppSpacing.xs,
            ),
            child: Text(
              title,
              style: TextStyle(
                color: c.textVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _ThemePrefTile extends ConsumerWidget {
  const _ThemePrefTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final current = ref.watch(themeControllerProvider);
    return ListTile(
      title: Text(lang.t('settings.prefs.theme.label')),
      subtitle: Text(lang.t('settings.prefs.theme.desc'),
          style: TextStyle(color: c.textVariant, fontSize: 12)),
      trailing: DropdownButton<ThemeChoice>(
        value: current,
        underline: const SizedBox.shrink(),
        items: ThemeChoice.values
            .map(
              (m) => DropdownMenuItem(
                value: m,
                child: Text(_themeLabel(lang, m)),
              ),
            )
            .toList(),
        onChanged: (m) {
          if (m != null) ref.read(themeControllerProvider.notifier).setMode(m);
        },
      ),
    );
  }

  String _themeLabel(Lang lang, ThemeChoice m) {
    final key = switch (m) {
      ThemeChoice.system => 'settings.prefs.theme.system',
      ThemeChoice.light => 'settings.prefs.theme.light',
      ThemeChoice.dark => 'settings.prefs.theme.dark',
    };
    return lang.t(key);
  }
}

class _LanguagePrefTile extends ConsumerWidget {
  const _LanguagePrefTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final lang = I18n.of(context);
    final current = ref.watch(languageProvider);
    return ListTile(
      title: Text(lang.t('settings.prefs.lang.label')),
      subtitle: Text(lang.t('settings.prefs.lang.desc'),
          style: TextStyle(color: c.textVariant, fontSize: 12)),
      trailing: DropdownButton<Lang>(
        value: current,
        underline: const SizedBox.shrink(),
        items: Lang.values
            .map(
              (l) => DropdownMenuItem(
                value: l,
                child: Text(l.label),
              ),
            )
            .toList(),
        onChanged: (l) {
          if (l != null) ref.read(languageProvider.notifier).setLang(l);
        },
      ),
    );
  }
}

class _DataExportTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DataExportTile> createState() => _DataExportTileState();
}

class _DataExportTileState extends ConsumerState<_DataExportTile> {
  bool _busy = false;

  Future<void> _runExport(String kind) async {
    final lang = I18n.of(context);
    setState(() => _busy = true);
    try {
      // 占位:实际导出逻辑在 utils/export.dart(由后续 PR 实现)。
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show('exported $kind');
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('settings.data.exportFailPrefix')} $e',
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.calendar_view_month),
          title: Text(lang.t('settings.data.exportMonthly')),
          onTap: _busy ? null : () => _runExport('monthly'),
        ),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: Text(lang.t('settings.data.exportCategory')),
          onTap: _busy ? null : () => _runExport('category'),
        ),
        ListTile(
          leading: const Icon(Icons.dataset_outlined),
          title: Text(lang.t('settings.data.exportAll')),
          onTap: _busy ? null : () => _runExport('all'),
        ),
      ],
    );
  }
}

class _AboutTile extends ConsumerWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    final future = ref.read(versionApiProvider).getSystemVersion();
    return FutureBuilder<SystemVersion>(
      future: future,
      builder: (context, snap) {
        final v = snap.data?.version ?? lang.t('settings.versionFallback');
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(lang.t('settings.about.currentVersion')),
          trailing: Text(v, style: TextStyle(color: context.appColors.textVariant)),
        );
      },
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

  void _refresh() => setState(() => _future = _load());

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
      toast.show('${lang.t('settings.categories.create.failPrefix')} $e');
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
        toast.show('${lang.t('settings.categories.delete.failPrefix')} $e');
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
      toast.show('${lang.t('settings.categories.edit.failPrefix')} $e');
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
              return Column(
                children: [
                  for (final cat in list)
                    _CatItemRow(category: cat, onEdit: () => _openEdit(cat)),
                  const SizedBox(height: AppSpacing.sm),
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

/// .cat-item:dot(colored bg + emoji 白字) + name + color hex + preset/edit badge。
class _CatItemRow extends StatelessWidget {
  const _CatItemRow({required this.category, required this.onEdit});
  final Category category;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final pres = presentCategory(category);
    final color = _parseHex(pres.color);
    final hasIcon = pres.icon.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: hasIcon
                ? Text(
                    pres.icon,
                    style: const TextStyle(fontSize: 16, height: 1),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  pres.color.toUpperCase(),
                  style: TextStyle(color: c.textVariant, fontSize: 11),
                ),
              ],
            ),
          ),
          if (category.isPreset)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                lang.t('settings.categories.presetBadge'),
                style: TextStyle(
                  color: c.textVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Material(
              color: c.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  child: Text(
                    lang.t('common.edit'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
                // icon picker
                Text(
                  lang.t('settings.categories.field.icon'),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
                const SizedBox(height: AppSpacing.md),
                // color picker
                Text(
                  lang.t('settings.categories.field.color'),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
    return Material(
      color: selected ? activeColor : c.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Text(
            icon,
            style: TextStyle(
              fontSize: 16,
              color: selected ? (glyphIsWhite ? Colors.white : const Color(0xFF1A202C)) : c.text,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
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