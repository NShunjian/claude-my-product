import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/router/app_router.dart';
import '../shared/auth_controller.dart';
import '../shared/book_controller.dart';
import '../shared/providers.dart';
import '../shared/theme_controller.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/login/index.vue — logo + head + 卡片表单 + 底部语言/主题偏好。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLastUsername();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastUsername() async {
    final prefs = ref.read(prefsProvider);
    if (!mounted) return;
    final last = prefs.lastUsername;
    if (last != null && last.isNotEmpty) {
      setState(() => _usernameCtrl.text = last);
    }
  }

  Future<void> _submit() async {
    final lang = I18n.of(context);
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      ref.read(toastControllerProvider.notifier).show(lang.t('login.fillAll'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).login(u, p);
      if (!mounted) return;
      await ref.read(bookControllerProvider.notifier).reload();
      if (!mounted) return;
      if (context.canPop()) context.pop();
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('login.opFailed')} ${e is ApiException ? e.message : '$e'}',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final themeChoice = ref.watch(themeControllerProvider);
    final isDark = themeModeOf(themeChoice) == ThemeMode.dark ||
        (themeChoice == ThemeChoice.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 40, AppSpacing.xl, AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // .head:logo + brand 居中(uniapp .head)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Q',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      lang.t('login.brandName'),
                      style: TextStyle(
                        color: c.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // .card:bgCard + radius 8dp + padding 20dp + gap 16dp
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: c.bgCard,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: c.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(
                      label: lang.t('login.username'),
                      child: TextField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Field(
                      label: lang.t('login.password'),
                      child: TextField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // .btn-primary 实色按钮
                    Material(
                      color: _busy
                          ? c.primary.withValues(alpha: 0.6)
                          : c.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: InkWell(
                        onTap: _busy ? null : _submit,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _busy
                                ? lang.t('login.submitting')
                                : lang.t('login.submit'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // .prefs:右上角语言 picker + 主题 toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _LangPicker(),
                  const SizedBox(width: AppSpacing.sm),
                  _ThemeToggle(isDark: isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textVariant, fontSize: 14)),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

/// 语言选择:点击弹出 PopupMenu,展示 LANGS 全部条目。
class _LangPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final current = ref.watch(languageProvider);
    return PopupMenuButton<Lang>(
      tooltip: '',
      offset: const Offset(0, 40),
      color: c.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: c.divider),
      ),
      onSelected: (l) {
        ref.read(languageProvider.notifier).setLang(l);
      },
      itemBuilder: (ctx) => [
        for (final l in LANGS)
          PopupMenuItem<Lang>(
            value: l.code == 'zh-CN' ? Lang.zhCN : l.code == 'en' ? Lang.en : Lang.zhTW,
            child: Row(
              children: [
                if (l.code == current.code) ...[
                  Icon(Icons.check, size: 14, color: c.primary),
                  const SizedBox(width: 6),
                ] else
                  const SizedBox(width: 20),
                Text(
                  l.label,
                  style: TextStyle(color: c.text, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          LANGS.firstWhere((l) => l.code == current.code).label,
          style: TextStyle(color: c.text, fontSize: 13),
        ),
      ),
    );
  }
}

/// 主题 toggle:对齐 uniapp 二态切换(暗↔亮,system 也视为亮)。
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => ref
            .read(themeControllerProvider.notifier)
            .setMode(isDark ? ThemeChoice.light : ThemeChoice.dark),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          alignment: Alignment.center,
          child: Text(
            isDark ? '🌙' : '☀️',
            style: const TextStyle(fontSize: 14, height: 1),
          ),
        ),
      ),
    );
  }
}