import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../shared/auth_controller.dart';
import '../shared/providers.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/profile/edit.vue — 头像 / 昵称 / 性别 / 年龄 / 修改密码。
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
  // 头像预览:本地文件路径(用于 Image.file 渲染);保存后清空。
  String? _avatarLocalPath;
  String? _avatarBase64;
  bool _savingAvatar = false;
  final _picker = ImagePicker();

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
      // 对齐 uniapp handleChangePassword:改密后旧 token 视为失效 → 清掉并跳登录页。
      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) return;
      if (context.canPop()) context.pop();
      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      setState(() => _changingPw = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('profileEdit.passwordChangeFailDefault')} ($e)',
          );
    }
  }

  // ===== 头像(对齐 uniapp triggerAvatarInput / readAvatarBase64 / handleSaveAvatar) =====

  Future<void> _pickAvatar() async {
    final lang = I18n.of(context);
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return; // user cancelled
    try {
      final bytes = await File(picked.path).readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      setState(() {
        _avatarLocalPath = picked.path;
        _avatarBase64 = b64;
      });
      ref.read(toastControllerProvider.notifier).show(
            lang.t('profileEdit.avatarPreviewReady'),
          );
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('profileEdit.avatarReadFail')} ($e)',
          );
    }
  }

  Future<void> _saveAvatar() async {
    final lang = I18n.of(context);
    final b64 = _avatarBase64;
    if (b64 == null) {
      ref.read(toastControllerProvider.notifier).show(
            lang.t('profileEdit.avatarSelectFile'),
          );
      return;
    }
    setState(() => _savingAvatar = true);
    try {
      await ref
          .read(usersApiProvider)
          .updateProfile(UpdateProfileInput(avatar: b64));
      await ref.read(authControllerProvider.notifier).me();
      if (!mounted) return;
      setState(() {
        _avatarLocalPath = null;
        _avatarBase64 = null;
        _savingAvatar = false;
      });
      ref.read(toastControllerProvider.notifier).show(
            lang.t('profileEdit.avatarUpdated'),
          );
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAvatar = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('profileEdit.saveFailDefault')} ($e)',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final auth = ref.watch(authControllerProvider);
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('profileEdit.title')),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // 头像(uniapp avatar section:大圆 + 上传按钮 + 保存按钮)
          _SectionCard(
            title: lang.t('profileEdit.avatarSection'),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Text(
                      lang.t('profileEdit.avatarDesc'),
                      style: TextStyle(color: c.textVariant, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: c.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: _avatarLocalPath != null
                          ? Image.file(
                              File(_avatarLocalPath!),
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            )
                          : (auth.user?.avatar != null &&
                                  auth.user!.avatar!.isNotEmpty)
                              ? Image.network(
                                  auth.user!.avatar!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  errorBuilder: (_, __, ___) => Text(
                                    '👤',
                                    style: TextStyle(fontSize: 60, color: c.primary),
                                  ),
                                )
                              : Text(
                                  '👤',
                                  style: TextStyle(fontSize: 60, color: c.primary),
                                ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Text('⬆️'),
                      label: Text(lang.t('profileEdit.uploadAvatar')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: BorderSide(color: c.divider),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed:
                          (_savingAvatar || _avatarBase64 == null) ? null : _saveAvatar,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _savingAvatar
                            ? lang.t('profileEdit.saving')
                            : lang.t('profileEdit.saveAvatar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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