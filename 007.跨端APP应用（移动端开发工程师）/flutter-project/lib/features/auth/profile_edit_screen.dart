import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../shared/app_header.dart';
import '../shared/auth_controller.dart';
import '../shared/providers.dart';

/// 对齐 uniapp pages/profile/edit.vue — 头像 / 昵称 / 性别 / 年龄 / 修改密码。
/// 卡片结构(标题 + 描述 + 字段 + 内联提示 + 右下保存按钮)按 uniapp 同款视觉重建。
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
  // 头像预览 — 跨平台 bytes(用于 Image.memory),base64 dataURL 用于提交。
  // ponytail: 之前 _avatarLocalPath + File().readAsBytes() 在 web 炸,
  //          dart:io 在 Flutter Web 不可用(跟 export.dart 那个 _Namespace 错
  //          同款)。改用 XFile.readAsBytes()(image_picker 自带 web 适配,
  //          底层走 Blob 读取)+ Image.memory 渲染,完全脱离 dart:io。
  Uint8List? _avatarBytes;
  String? _avatarBase64;
  bool _savingAvatar = false;
  final _picker = ImagePicker();

  // ponytail: 内联 ok/err 提示替代 toast(uniapp 同款)。每段一组,_Kind=ok 表
  //          示成功提示,err 表示校验/后端错误。保存动作会把前一段提示清掉。
  _Msg? _avatarMsg;
  _Msg? _profileMsg;
  _Msg? _pwdMsg;

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
      setState(() => _profileMsg = _Msg.err(lang.t('profileEdit.nameRequired')));
      return;
    }
    int? age;
    if (_ageCtrl.text.trim().isNotEmpty) {
      final parsed = int.tryParse(_ageCtrl.text.trim());
      if (parsed == null || parsed < 0 || parsed > 150) {
        setState(() => _profileMsg = _Msg.err(lang.t('profileEdit.ageInvalid')));
        return;
      }
      age = parsed;
    }
    setState(() {
      _saving = true;
      _profileMsg = null;
    });
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
      setState(() {
        _saving = false;
        _profileMsg = _Msg.ok(lang.t('profileEdit.profileSaved'));
      });
      // ponytail: uniapp 用 goBack() 留在本页(展示"资料已保存"提示);
      //          Flutter 之前 context.pop() 直接跳走,提示一闪就消失。保留
      //          在本页,用户能直接看到 ok 提示。
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _profileMsg = _Msg.err(
          e is ApiException
              ? e.message
              : '${lang.t('profileEdit.saveFailDefault')} $e',
        );
      });
    }
  }

  Future<void> _changePassword() async {
    final lang = I18n.of(context);
    final old = _oldPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;
    if (old.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      setState(() => _pwdMsg = _Msg.err(lang.t('profileEdit.passwordFillAll')));
      return;
    }
    if (newPw.length < 8) {
      setState(() => _pwdMsg = _Msg.err(lang.t('profileEdit.passwordTooShort')));
      return;
    }
    if (newPw != confirm) {
      setState(() => _pwdMsg = _Msg.err(lang.t('profileEdit.passwordMismatch')));
      return;
    }
    if (newPw == old) {
      setState(() => _pwdMsg = _Msg.err(lang.t('profileEdit.passwordSame')));
      return;
    }
    setState(() {
      _changingPw = true;
      _pwdMsg = null;
    });
    try {
      await ref
          .read(usersApiProvider)
          .changePassword(oldPassword: old, newPassword: newPw);
      if (!mounted) return;
      // 对齐 uniapp handleChangePassword:改密后旧 token 视为失效 → 清掉并跳登录页。
      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) return;
      // 清空密码字段避免回退到本页时看到残留值
      _oldPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      if (context.canPop()) context.pop();
      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPw = false;
        _pwdMsg = _Msg.err(
          e is ApiException
              ? e.message
              : '${lang.t('profileEdit.passwordChangeFailDefault')} $e',
        );
      });
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
      // ponytail: 用 XFile.readAsBytes() 而不是 File(picked.path).readAsBytes()
      //          —— image_picker 在 web 端 picked.path 是 blob:http://... URL,
      //          不是真实路径,File() 来自 dart:io,在 web 编译期就不存在
      //          (报 Unsupported operation: _Namespace)。XFile.readAsBytes()
      //          自带 web Blob 读取实现,跨平台通用。
      final bytes = await picked.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarBase64 = b64;
        _avatarMsg = _Msg.ok(lang.t('profileEdit.avatarPreviewReady'));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _avatarMsg = _Msg.err(
          e is ApiException
              ? e.message
              : '${lang.t('profileEdit.avatarReadFail')} $e',
        );
      });
    }
  }

  Future<void> _saveAvatar() async {
    final lang = I18n.of(context);
    final b64 = _avatarBase64;
    if (b64 == null) {
      setState(() => _avatarMsg = _Msg.err(lang.t('profileEdit.avatarSelectFile')));
      return;
    }
    setState(() {
      _savingAvatar = true;
      _avatarMsg = null;
    });
    try {
      await ref
          .read(usersApiProvider)
          .updateProfile(UpdateProfileInput(avatar: b64));
      await ref.read(authControllerProvider.notifier).me();
      if (!mounted) return;
      setState(() {
        _avatarBytes = null;
        _avatarBase64 = null;
        _savingAvatar = false;
        _avatarMsg = _Msg.ok(lang.t('profileEdit.avatarUpdated'));
      });
      // 保留在本页展示"头像已更新",uniapp 同样 goBack 前先 set msg。
      // 注:头像改动立刻生效(_avatarLocalPath 已清),用户能直接看到新头像。
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingAvatar = false;
        _avatarMsg = _Msg.err(
          e is ApiException
              ? e.message
              : '${lang.t('profileEdit.saveFailDefault')} $e',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final auth = ref.watch(authControllerProvider);
    final c = context.appColors;
    return Scaffold(
      appBar: AppHeader(
        title: lang.t('profileEdit.title'),
        back: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          // ===== 头像卡 =====
          _SectionCard(
            title: lang.t('profileEdit.avatarSection'),
            desc: lang.t('profileEdit.avatarDesc'),
            children: [
              // ponytail: 头像区居中(uniapp .avatar-center:flex column align-items
              //          center gap:24rpx),"上传新头像" 是 outline 按钮,跟截图一致。
              Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: c.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: _avatarBytes != null
                        ? Image.memory(
                            _avatarBytes!,
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
                                  style: TextStyle(
                                    fontSize: 60,
                                    color: c.primary,
                                  ),
                                ),
                              )
                            : Text(
                                '👤',
                                style: TextStyle(
                                  fontSize: 60,
                                  color: c.primary,
                                ),
                              ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // ponytail: uniapp .btn-outline 是 inline-flex + padding 0 32rpx,
                  //          wrap 在文字宽度(Material 默认 OutlinedButton.icon
                  //          会因 minimumSize.fromHeight 把 width 撑成全宽)。
                  //          这里去 minimumSize,用 padding 控制垂直高度,
                  //          让按钮只占文字宽度居中。
                  OutlinedButton.icon(
                    onPressed: _pickAvatar,
                    // ponytail: 2026-09-12 — emoji 换 Material Icons,
                    //          baseline 自动对齐,不需要任何手动微调。
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    label: Text(lang.t('profileEdit.uploadAvatar')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      side: BorderSide(color: c.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                  if (_avatarMsg != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _MsgBadge(msg: _avatarMsg!),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // 卡片底部:分割线 + 右下保存按钮(uniapp .card-footer)。
              Container(
                height: 1,
                color: c.divider,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: _PrimaryButton(
                  label: lang.t('profileEdit.saveAvatar'),
                  busy: _savingAvatar,
                  disabled: _savingAvatar || _avatarBase64 == null,
                  onTap: _saveAvatar,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // ===== 个人资料卡 =====
          _SectionCard(
            title: lang.t('profileEdit.profileSection'),
            desc: lang.t('profileEdit.profileDesc'),
            children: [
              _Field(
                label: lang.t('profileEdit.displayName'),
                child: _IconInput(
                  emojiIcon: '👤',
                  controller: _nameCtrl,
                  hint: lang.t('profileEdit.displayNamePlaceholder'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                label: lang.t('profileEdit.gender'),
                child: _GenderRow(
                  current: _gender,
                  maleLabel: lang.t('profileEdit.gender.male'),
                  femaleLabel: lang.t('profileEdit.gender.female'),
                  onChange: (g) => setState(() => _gender = g),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                label: lang.t('profileEdit.age'),
                child: _IconInput(
                  emojiIcon: '🎂',
                  controller: _ageCtrl,
                  hint: lang.t('profileEdit.agePlaceholder'),
                  keyboardType: TextInputType.number,
                ),
              ),
              if (_profileMsg != null) ...[
                const SizedBox(height: AppSpacing.md),
                _MsgBadge(msg: _profileMsg!),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(height: 1, color: c.divider),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: _PrimaryButton(
                  label: lang.t('profileEdit.saveProfile'),
                  busy: _saving,
                  disabled: _saving,
                  onTap: _saveProfile,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // ===== 安全设置卡 =====
          _SectionCard(
            title: lang.t('profileEdit.securitySection'),
            desc: lang.t('profileEdit.securityDesc'),
            children: [
              _Field(
                label: lang.t('profileEdit.oldPassword'),
                child: _IconInput(
                  emojiIcon: '🔒',
                  controller: _oldPwCtrl,
                  hint: lang.t('profileEdit.oldPasswordPlaceholder'),
                  obscure: true,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                label: lang.t('profileEdit.newPassword'),
                child: _IconInput(
                  emojiIcon: '🔑',
                  controller: _newPwCtrl,
                  hint: lang.t('profileEdit.newPasswordPlaceholder'),
                  obscure: true,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                label: lang.t('profileEdit.confirmPassword'),
                child: _IconInput(
                  emojiIcon: '🛡️',
                  controller: _confirmPwCtrl,
                  hint: lang.t('profileEdit.confirmPasswordPlaceholder'),
                  obscure: true,
                ),
              ),
              if (_pwdMsg != null) ...[
                const SizedBox(height: AppSpacing.md),
                _MsgBadge(msg: _pwdMsg!),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(height: 1, color: c.divider),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: _PrimaryButton(
                  label: lang.t('profileEdit.savePassword'),
                  busy: _changingPw,
                  disabled: _changingPw,
                  onTap: _changePassword,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== 内联提示(对齐 uniapp .msg / .msg-ok / .msg-err) =====

class _Msg {
  const _Msg(this.kind, this.text);
  factory _Msg.ok(String t) => _Msg(true, t);
  factory _Msg.err(String t) => _Msg(false, t);
  final bool kind; // true=ok, false=err
  final String text;
}

class _MsgBadge extends StatelessWidget {
  const _MsgBadge({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ok = msg.kind;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        // ponytail: tokens 里没有 secondaryContainer/errorContainer,沿用
        //          primaryLight(成功)/error 13% alpha(失败),跟整套卡片
        //          视觉一致。
        color: ok
            ? c.primaryLight
            : c.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        msg.text,
        style: TextStyle(
          color: ok ? c.primary : c.error,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ===== 卡片容器(对齐 uniapp .card + .section-header { title 16 w700 + desc 13 variant }) =====

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.desc,
    required this.children,
  });
  final String title;
  final String desc;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      // ponytail: padding 16 → 12 对齐 uniapp .card padding: 24rpx ≈ 12px。
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ponytail: title 16 w700 + desc 12 variant 紧贴(uniapp .section-title
          //          font-size:32rpx = 16px w700;.section-desc font-size:26rpx
          //          ≈ 13px variant)。
          Text(
            title,
            style: TextStyle(
              color: c.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(color: c.textVariant, fontSize: 12),
          ),
          // ponytail: 20rpx ≈ 10px(uniapp .section-header margin-bottom:20rpx),
          //          之前 AppSpacing.lg=16 偏大。
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

// ===== 字段(label + 子控件,uniapp .field) =====

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
        // label 16 w600(uniapp .field-label font-size:32rpx w600)
        Text(
          label,
          style: TextStyle(
            color: c.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ===== 自定义 input(对齐 uniapp .input-wrap + .input-icon-box + .text-input) =====

class _IconInput extends StatelessWidget {
  const _IconInput({
    required this.emojiIcon,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });
  // ponytail: 2026-09-12 — emoji 字符串(👤 🎂 🔒 🔑 🛡️ 等),emoji 跟
  //          文字两个 widget 完全独立 vertical center,不再 baseline 绑定。
  final String emojiIcon;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      // ponytail: 高度 48 → 44 对齐 uniapp .text-input height: 88rpx ≈ 44px。
      height: 44,
      decoration: BoxDecoration(
        // ponytail: 2026-09-12 — 输入框 bg 用 c.surface(#F5F5F5 真浅灰),
        //          c.bg 是 #FFFFFF 纯白,看不出差别。
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.divider),
      ),
      // ponytail: 2026-09-12 — emoji + TextField 两个 widget 完全独立
      //          vertical center:
      //          - emoji 用 SizedBox(22) + Center → emoji glyph visual
      //          center 自动落在 22 高度的 center,跟 fontSize 解耦。
      //          - TextField 用 contentPadding.vertical=14 让 14sp 文字
      //          baseline 居中到 44 容器:文字 glyph 高 ~16,上下各 14。
      //          两个 widget 各自 Align 到容器垂直中线,不再 baseline 绑。
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: AppSpacing.md,
          ),
          SizedBox(
            width: 22,
            child: Center(
              child: Text(
                emojiIcon,
                style: TextStyle(
                  fontSize: 18,
                  color: c.textVariant,
                  decoration: TextDecoration.none,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: TextStyle(color: c.text, fontSize: 14, height: 1.15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: c.textVariant,
                  fontSize: 14,
                  height: 1.15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: AppSpacing.md,
          ),
        ],
      ),
    );
  }
}

// ===== 性别两段(对齐 uniapp .gender-row + .gender-btn) =====

class _GenderRow extends StatelessWidget {
  const _GenderRow({
    required this.current,
    required this.maleLabel,
    required this.femaleLabel,
    required this.onChange,
  });
  final Gender? current;
  final String maleLabel;
  final String femaleLabel;
  final ValueChanged<Gender> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderBtn(
            label: maleLabel,
            icon: Icons.male,
            active: current == Gender.male,
            onTap: () => onChange(Gender.male),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _GenderBtn(
            label: femaleLabel,
            icon: Icons.female,
            active: current == Gender.female,
            onTap: () => onChange(Gender.female),
          ),
        ),
      ],
    );
  }
}

class _GenderBtn extends StatelessWidget {
  const _GenderBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  // ponytail: 同 _IconInput — 从 String emoji 换 IconData,Icon widget
  //          自带 alphabetic baseline 跟文字精确对齐。
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: active ? c.primaryLight : c.bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          // ponytail: 高度 48 → 44 对齐 uniapp .gender-btn height: 88rpx。
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? c.primary : c.divider,
              width: active ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ponytail: 2026-09-12 — 用 Icon(Material Icons)代替 emoji。
              //          iOS emoji glyph 没有标准 baseline,任何 Transform.translate
              //          都无法精确对齐文字 alphabetic baseline。Icon 自带
              //          baseline,跟文字 14sp 默认对齐,视觉中心点对中心点。
              Icon(
                icon,
                size: 18,
                color: active ? c.primary : c.text,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? c.primary : c.text,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 主按钮(对齐 uniapp .btn-primary:primary bg + 白字 + 右下 + 忙时转圈) =====

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });
  final String label;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: Material(
        color: c.primary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: disabled ? null : onTap,
          child: Container(
            // ponytail: 高度 48px(uniapp .btn-primary height:80rpx ≈ 40px;
            //          Flutter 上 40 偏矮放不下 16px 字 + spinner,提到 48)。
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  label,
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
      ),
    );
  }
}