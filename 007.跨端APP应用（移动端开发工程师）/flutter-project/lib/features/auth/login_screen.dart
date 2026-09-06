import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/router/app_router.dart';
import '../shared/auth_controller.dart';
import '../shared/book_controller.dart';
import '../shared/providers.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/login/index.vue — 用户名 + 密码 + 登录。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _lastUsername;

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
    setState(() {
      _lastUsername = prefs.lastUsername;
      if (_lastUsername != null && _lastUsername!.isNotEmpty) {
        _usernameCtrl.text = _lastUsername!;
      }
    });
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
      // 触发账本 + 报表刷新
      await ref.read(bookControllerProvider.notifier).reload();
      if (!mounted) return;
      if (context.canPop()) context.pop();
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('login.opFailed')} ($e)',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                lang.t('login.brandName'),
                style: TextStyle(
                  color: c.primary,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                lang.t('login.tagline'),
                style: TextStyle(color: c.textVariant, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: lang.t('login.username'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: lang.t('login.password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _busy ? lang.t('login.submitting') : lang.t('login.submit'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                lang.t('login.dataStoredAt'),
                style: TextStyle(color: c.textVariant, fontSize: 12),
              ),
              if (_lastUsername != null && _lastUsername!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '👋 $_lastUsername',
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}