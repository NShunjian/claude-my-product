import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../shared/auth_controller.dart';
import '../shared/book_controller.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/books/index.vue — 我的账本 + 内联创建 + 切换 + 成员 + 编辑 + 删除。
class BooksScreen extends ConsumerStatefulWidget {
  const BooksScreen({super.key});

  @override
  ConsumerState<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends ConsumerState<BooksScreen> {
  bool _showCreate = false;
  Book? _editing;
  final _createNameCtrl = TextEditingController();
  final _createDescCtrl = TextEditingController();
  final _editDescCtrl = TextEditingController();
  BookType _createType = BookType.personal;
  bool _busy = false;

  @override
  void dispose() {
    _createNameCtrl.dispose();
    _createDescCtrl.dispose();
    _editDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCreate() async {
    final lang = I18n.of(context);
    final name = _createNameCtrl.text.trim();
    if (name.isEmpty) {
      ref.read(toastControllerProvider.notifier).show(lang.t('books.create.name'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(bookControllerProvider.notifier).createBook(
            CreateBookInput(
              name: name,
              description: _createDescCtrl.text.trim().isEmpty
                  ? null
                  : _createDescCtrl.text.trim(),
              type: _createType,
              currency: 'CNY',
            ),
          );
      if (!mounted) return;
      _createNameCtrl.clear();
      _createDescCtrl.clear();
      setState(() {
        _showCreate = false;
        _busy = false;
        _createType = BookType.personal;
      });
      ref.read(toastControllerProvider.notifier).show(lang.t('books.create.success'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('books.create.failPrefix')} $e',
          );
    }
  }

  Future<void> _switchTo(Book book) async {
    final lang = I18n.of(context);
    try {
      await ref.read(bookControllerProvider.notifier).setCurrent(book.uuid);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('books.badge.current'));
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('books.switch.failPrefix')} $e',
          );
    }
  }

  Future<void> _confirmDelete(Book book) async {
    final lang = I18n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(lang.t('books.delete.confirm', {'name': book.name})),
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
      await ref.read(bookControllerProvider.notifier).deleteBook(book.uuid);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('books.delete.success'));
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('books.delete.failPrefix')} $e',
          );
    }
  }

  void _openEdit(Book book) {
    setState(() {
      _editing = book;
      _editDescCtrl.text = book.description ?? '';
    });
    _showEditDialog();
  }

  Future<void> _showEditDialog() async {
    final lang = I18n.of(context);
    final newDesc = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _EditBookDialog(
        title: lang.t('books.edit.title', {'name': _editing!.name}),
        descCtrl: _editDescCtrl,
        saveLabel: lang.t('common.save'),
        cancelLabel: lang.t('common.cancel'),
      ),
    );
    if (!mounted) return;
    if (newDesc == null) {
      // 用户取消
      setState(() => _editing = null);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(bookControllerProvider.notifier).updateBook(
            _editing!.uuid,
            newDesc.isEmpty
                ? UpdateBookInput(description: null)
                : UpdateBookInput(description: newDesc),
          );
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('books.edit.success'));
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('books.edit.failPrefix')} $e',
          );
    } finally {
      if (mounted) {
        setState(() {
          _editing = null;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    final state = ref.watch(bookControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final myUuid = auth.user?.uuid;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('books.heading')),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          // 顶栏内联 "+ 新建账本" 按钮(uniapp .add-btn)。
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: () => setState(() => _showCreate = !_showCreate),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '+ ${lang.t('books.create.toggle')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: state.books.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  lang.t('books.empty'),
                  style: TextStyle(color: c.textVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (_showCreate) ...[
                  _CreateFormCard(
                    nameCtrl: _createNameCtrl,
                    descCtrl: _createDescCtrl,
                    type: _createType,
                    busy: _busy,
                    onTypeChanged: (t) => setState(() => _createType = t),
                    onCancel: () => setState(() => _showCreate = false),
                    onSubmit: _submitCreate,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.1,
                  children: [
                    for (final b in state.books)
                      _BookCard(
                        book: b,
                        isCurrent: b.uuid == state.currentId,
                        isOwner: b.ownerUuid == myUuid,
                        onSwitch: () => _switchTo(b),
                        onMembers: () => context.push(
                          '${AppRoutes.bookMembers}?id=${Uri.encodeComponent(b.uuid)}',
                        ),
                        onEdit: () => _openEdit(b),
                        onDelete: () => _confirmDelete(b),
                      ),
                  ],
                ),
              ],
            ),
      // 编辑弹窗:沿用 uniapp .modal-mask + .modal-card 结构。
      // 用 showDialog 让 barrierColor 半透 + 内容居中。
      // 监听 _editing 变化自动 pop。
    );
  }
}

/// 对齐 uniapp .book-card:padding 20rpx(10dp),radius 16rpx(8dp),border 2rpx primary if current。
class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.isCurrent,
    required this.isOwner,
    required this.onSwitch,
    required this.onMembers,
    required this.onEdit,
    required this.onDelete,
  });

  final Book book;
  final bool isCurrent;
  final bool isOwner;
  final VoidCallback onSwitch;
  final VoidCallback onMembers;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData _typeIcon(BookType t) {
    switch (t) {
      case BookType.shared:
        return Icons.group;
      case BookType.business:
        return Icons.business_center;
      case BookType.personal:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCurrent ? c.primary : c.divider,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // book-top:name + desc + default badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.description?.isNotEmpty == true
                          ? book.description!
                          : lang.t('books.noDesc'),
                      style: TextStyle(color: c.textVariant, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (book.isDefault) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    lang.t('books.badge.default'),
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // book-meta:typeIcon + type · role
          Row(
            children: [
              Icon(_typeIcon(book.type), size: 11, color: c.textVariant),
              const SizedBox(width: 4),
              Text(
                lang.t('books.type.${book.type.name}'),
                style: TextStyle(color: c.textVariant, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Text('·', style: TextStyle(color: c.divider, fontSize: 11)),
              const SizedBox(width: 6),
              Text(
                lang.t('books.role.${book.role.name}'),
                style: TextStyle(color: c.textVariant, fontSize: 11),
              ),
            ],
          ),
          // book-actions:outlined 按钮组
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (!isCurrent)
                _ActionBtn(
                  label: lang.t('books.action.switch'),
                  onPressed: onSwitch,
                )
              else
                _ActionBtn(
                  label: lang.t('books.badge.current'),
                  variant: _ActionVariant.current,
                ),
              _ActionBtn(label: lang.t('books.action.members'), onPressed: onMembers),
              if (isOwner)
                _ActionBtn(label: lang.t('common.edit'), onPressed: onEdit),
              if (isOwner && !book.isDefault)
                _ActionBtn(
                  label: lang.t('common.delete'),
                  variant: _ActionVariant.danger,
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// uniapp .action-btn:1px primary border + radius 8rpx + padding 8rpx 16rpx + fontSize 22rpx(11dp)。
enum _ActionVariant { normal, danger, current }

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    this.onPressed,
    this.variant = _ActionVariant.normal,
  });
  final String label;
  final VoidCallback? onPressed;
  final _ActionVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final Color border;
    final Color fg;
    final Color? bg;
    switch (variant) {
      case _ActionVariant.danger:
        border = c.error;
        fg = c.error;
        bg = null;
      case _ActionVariant.current:
        border = c.primary;
        fg = c.primary;
        bg = c.primaryLight;
      case _ActionVariant.normal:
        border = c.primary;
        fg = c.primary;
        bg = null;
    }
    return Material(
      color: bg ?? Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            style: TextStyle(color: fg, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

/// 内联创建表单卡(uniapp .card:padding 24rpx(12dp),radius 16rpx(8dp),bgCard,1px divider)。
class _CreateFormCard extends StatelessWidget {
  const _CreateFormCard({
    required this.nameCtrl,
    required this.descCtrl,
    required this.type,
    required this.busy,
    required this.onTypeChanged,
    required this.onCancel,
    required this.onSubmit,
  });
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final BookType type;
  final bool busy;
  final ValueChanged<BookType> onTypeChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('books.create.title'),
            style: TextStyle(
              color: c.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // form-grid 2 列:name + type picker
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: lang.t('books.create.name'),
                  child: TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: lang.t('books.create.namePlaceholder'),
                    ),
                    maxLength: 50,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Field(
                  label: lang.t('books.create.type'),
                  child: DropdownButtonFormField<BookType>(
                    initialValue: type,
                    isDense: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in BookType.values)
                        DropdownMenuItem(
                          value: t,
                          child: Text(lang.t('books.type.${t.name}')),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) onTypeChanged(v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: lang.t('books.create.description'),
            child: TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: lang.t('books.create.descPlaceholder'),
              ),
              maxLength: 200,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _Btn(label: lang.t('common.cancel'), onPressed: busy ? null : onCancel)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Btn(
                  label: busy ? lang.t('common.loading') : lang.t('common.save'),
                  variant: _BtnVariant.confirm,
                  onPressed: busy ? null : onSubmit,
                ),
              ),
            ],
          ),
        ],
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
        Text(label, style: TextStyle(color: c.textVariant, fontSize: 12)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

enum _BtnVariant { cancel, confirm }

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.onPressed,
    this.variant = _BtnVariant.cancel,
  });
  final String label;
  final VoidCallback? onPressed;
  final _BtnVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final disabled = onPressed == null;
    final Color bg;
    final Color fg;
    final Border? border;
    switch (variant) {
      case _BtnVariant.cancel:
        bg = c.surface;
        fg = c.text;
        border = Border.all(color: c.divider);
      case _BtnVariant.confirm:
        bg = c.primary;
        fg = Colors.white;
        border = null;
    }
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              label,
              style: TextStyle(color: fg, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

/// 编辑弹窗(uniapp .modal-mask + .modal-card):返回新 description(null=取消)。
class _EditBookDialog extends StatelessWidget {
  const _EditBookDialog({
    required this.title,
    required this.descCtrl,
    required this.saveLabel,
    required this.cancelLabel,
  });
  final String title;
  final TextEditingController descCtrl;
  final String saveLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Dialog(
      backgroundColor: c.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: c.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              maxLength: 200,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _Btn(label: cancelLabel, onPressed: () => Navigator.of(context).pop())),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Btn(
                    label: saveLabel,
                    variant: _BtnVariant.confirm,
                    onPressed: () => Navigator.of(context).pop(descCtrl.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}