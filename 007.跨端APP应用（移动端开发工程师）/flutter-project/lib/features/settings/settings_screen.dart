import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../shared/auth_controller.dart';
import '../shared/providers.dart';
import '../shared/theme_controller.dart';
import '../shared/toast_controller.dart';

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