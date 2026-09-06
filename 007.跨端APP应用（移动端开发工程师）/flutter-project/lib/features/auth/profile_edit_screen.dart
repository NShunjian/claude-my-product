import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../shared/auth_controller.dart';
import '../shared/providers.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/profile/edit.vue — 昵称 / 性别 / 年龄 / 修改密码。
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _oldPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  Gender? _gender;
  bool _saving = false;
  bool _changingPw = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameCtrl.text = user?.displayName ?? '';
    _ageCtrl.text = user?.age?.toString() ?? '';
    _gender = user?.gender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final lang = I18n.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ref.read(toastControllerProvider.notifier).show(lang.t('profileEdit.nameRequired'));
      return;
    }
    int? age;
    if (_ageCtrl.text.trim().isNotEmpty) {
      final parsed = int.tryParse(_ageCtrl.text.trim());
      if (parsed == null || parsed < 0 || parsed > 150) {
        ref.read(toastControllerProvider.notifier).show(lang.t('profileEdit.ageInvalid'));
        return;
      }
      age = parsed;
    }
    setState(() => _saving = true);
    try {
      await ref.read(usersApiProvider).updateProfile(
            UpdateProfileInput(
              displayName: name,
              gender: _gender,
              age: age,
            ),
          );
      await ref.read(authControllerProvider.notifier).me();
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('profileEdit.profileSaved'));
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('profileEdit.saveFailDefault')} ($e)',
          );
    }
  }

  Future<void> _changePassword() async {
    final lang = I18n.of(context);
    final old = _oldPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;
    if (old.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      ref.read(toastControllerProvider.notifier).show(
            lang.t('profileEdit.passwordFillAll'),
          );
      return;
    }
    if (newPw.length < 8) {
      ref.read(toastControllerProvider.notifier).show(
            lang.t('profileEdit.passwordTooShort'),
          );
      return;
    }
    if (newPw != confirm) {
      ref.read(toastControllerProvider.notifier).show(
            lang.t('profileEdit.passwordMismatch'),
          );
      return;
    }
    if (newPw == old) {
      ref.read(toastControllerProvider.notifier).show(
            lang.t('profileEdit.passwordSame'),
          );
      return;
    }
    setState(() => _changingPw = true);
    try {
      await ref
          .read(usersApiProvider)
          .changePassword(oldPassword: old, newPassword: newPw);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('profileEdit.passwordChanged'));
      _oldPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      setState(() => _changingPw = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _changingPw = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('profileEdit.passwordChangeFailDefault')} ($e)',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('profileEdit.title')),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SectionCard(
            title: lang.t('profileEdit.profileSection'),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: lang.t('profileEdit.displayName'),
                        hintText: lang.t('profileEdit.displayNamePlaceholder'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<Gender>(
                      initialValue: _gender,
                      decoration: InputDecoration(
                        labelText: lang.t('profileEdit.gender'),
                        border: const OutlineInputBorder(),
                      ),
                      items: Gender.values
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text(lang.t('profileEdit.gender.${g.name}')),
                            ),
                          )
                          .toList(),
                      onChanged: (g) => setState(() => _gender = g),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: lang.t('profileEdit.age'),
                        hintText: lang.t('profileEdit.agePlaceholder'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _saving
                            ? lang.t('profileEdit.saving')
                            : lang.t('profileEdit.saveProfile'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: lang.t('profileEdit.securitySection'),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _oldPwCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: lang.t('profileEdit.oldPassword'),
                        hintText: lang.t('profileEdit.oldPasswordPlaceholder'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _newPwCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: lang.t('profileEdit.newPassword'),
                        hintText: lang.t('profileEdit.newPasswordPlaceholder'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _confirmPwCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: lang.t('profileEdit.confirmPassword'),
                        hintText: lang.t('profileEdit.confirmPasswordPlaceholder'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _changingPw ? null : _changePassword,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _changingPw
                            ? lang.t('profileEdit.saving')
                            : lang.t('profileEdit.savePassword'),
                      ),
                    ),
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}