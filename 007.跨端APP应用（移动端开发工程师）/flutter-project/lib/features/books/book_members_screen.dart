import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../shared/auth_controller.dart';
import '../shared/providers.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/book-members/index.vue — 成员管理。
class BookMembersScreen extends ConsumerStatefulWidget {
  const BookMembersScreen({super.key, required this.bookUuid});
  final String bookUuid;

  @override
  ConsumerState<BookMembersScreen> createState() => _BookMembersScreenState();
}

class _BookMembersScreenState extends ConsumerState<BookMembersScreen> {
  late Future<List<BookMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BookMember>> _load() async {
    return ref.read(booksApiProvider).listMembers(widget.bookUuid);
  }

  Future<void> _invite() async {
    final lang = I18n.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _InviteSheet(bookUuid: widget.bookUuid),
    );
    if (ok == true && mounted) {
      // ponytail: 两步走 — 先拿 Future 再 setState 赋值,否则闭包返回
      //          Future 触发 setState assert。
      final f = _load();
      setState(() {
        _future = f;
      });
      ref.read(toastControllerProvider.notifier).show(lang.t('bookMembers.invite.success'));
    }
  }

  Future<void> _changeRole(BookMember m, BookRole role) async {
    final lang = I18n.of(context);
    try {
      await ref.read(booksApiProvider).updateMemberRole(
            widget.bookUuid,
            m.userUuid,
            UpdateMemberRoleInput(role),
          );
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('bookMembers.role.success'));
      final f = _load();
      setState(() {
        _future = f;
      });
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('bookMembers.role.failPrefix')} ${e is ApiException ? e.message : '$e'}',
          );
    }
  }

  Future<void> _remove(BookMember m) async {
    final lang = I18n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(lang.t('bookMembers.remove.confirm', {
          'name': m.displayName ?? m.username,
        })),
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
      await ref.read(booksApiProvider).removeMember(widget.bookUuid, m.userUuid);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('bookMembers.remove.success'));
      final f = _load();
      setState(() {
        _future = f;
      });
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('bookMembers.remove.failPrefix')} ${e is ApiException ? e.message : '$e'}',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final myUuid = ref.watch(authControllerProvider).user?.uuid;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('pageTitle.bookMembers')),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _invite,
            tooltip: lang.t('bookMembers.invite.toggle'),
          ),
        ],
      ),
      body: FutureBuilder<List<BookMember>>(
        future: _future,
        builder: (context, snap) {
          // 首次加载还没数据 → 整页占位
          if (!snap.hasData) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(child: Text(lang.t('common.loading')));
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  '加载失败:${snap.error}',
                  style: TextStyle(color: c.error),
                ),
              );
            }
          }
          // 已有数据(包括刷新中的 stale snapshot)→ 渲染数据,顶部加进度条
          final list = snap.data!;
          final isReloading =
              snap.connectionState != ConnectionState.done;
          return Column(
            children: [
              if (isReloading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Color(0x00000000),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  lang.t('bookMembers.count', {'count': list.length}),
                  style: TextStyle(color: c.textVariant, fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
                  itemBuilder: (context, i) {
                    final m = list[i];
                    final isMe = m.userUuid == myUuid;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (m.displayName ?? m.username).characters.first.toUpperCase(),
                        ),
                      ),
                      title: Text(m.displayName ?? m.username),
                      subtitle: Text(
                        isMe
                            ? '${m.username} · ${lang.t('bookMembers.you')}'
                            : m.username,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<BookRole>(
                            value: m.role,
                            underline: const SizedBox.shrink(),
                            items: BookRole.values
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(lang.t('books.role.${r.name}')),
                                  ),
                                )
                                .toList(),
                            onChanged: (r) {
                              if (r != null) _changeRole(m, r);
                            },
                          ),
                          IconButton(
                            onPressed: isMe ? null : () => _remove(m),
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: isMe ? c.textVariant : c.error,
                            ),
                            tooltip: lang.t('bookMembers.remove.button'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.bookUuid});
  final String bookUuid;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _usernameCtrl = TextEditingController();
  BookRole _role = BookRole.editor;
  bool _busy = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = I18n.of(context);
    final u = _usernameCtrl.text.trim();
    if (u.isEmpty) {
      ref.read(toastControllerProvider.notifier).show(lang.t('bookMembers.invite.username'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(booksApiProvider).addMember(
            widget.bookUuid,
            AddMemberInput(username: u, role: _role),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('bookMembers.invite.failPrefix')} ${e is ApiException ? e.message : '$e'}',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.t('bookMembers.invite.title'),
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: lang.t('bookMembers.invite.username'),
                hintText: lang.t('bookMembers.invite.usernamePlaceholder'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(lang.t('bookMembers.invite.role'),
                style: TextStyle(color: c.textVariant, fontSize: 12)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final r in BookRole.values)
                  ChoiceChip(
                    label: Text(lang.t('books.role.${r.name}')),
                    selected: r == _role,
                    onSelected: (_) => setState(() => _role = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(lang.t('bookMembers.invite.submit')),
            ),
          ],
        ),
      ),
    );
  }
}