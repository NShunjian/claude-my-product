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

/// 对齐 pages/books/index.vue — 我的账本 + 创建 + 切换 + 删除。
class BooksScreen extends ConsumerStatefulWidget {
  const BooksScreen({super.key});

  @override
  ConsumerState<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends ConsumerState<BooksScreen> {
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

  Future<void> _openCreate() async {
    final lang = I18n.of(context);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _CreateBookSheet(),
    );
    if (created == true && mounted) {
      ref.read(toastControllerProvider.notifier).show(lang.t('books.create.success'));
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
            tooltip: lang.t('books.create.toggle'),
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
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: state.books.length,
              separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final b = state.books[i];
                final isCurrent = b.uuid == state.currentId;
                final isOwner = b.ownerUuid == myUuid;
                return _BookTile(
                  book: b,
                  isCurrent: isCurrent,
                  onSwitch: () => _switchTo(b),
                  onMembers: () => context.push(
                    '${AppRoutes.bookMembers}?id=${Uri.encodeComponent(b.uuid)}',
                  ),
                  onDelete: isOwner ? () => _confirmDelete(b) : null,
                );
              },
            ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.isCurrent,
    required this.onSwitch,
    required this.onMembers,
    required this.onDelete,
  });

  final Book book;
  final bool isCurrent;
  final VoidCallback onSwitch;
  final VoidCallback onMembers;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isCurrent ? c.primary : c.divider,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  book.name,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (book.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lang.t('books.badge.default'),
                    style: TextStyle(color: c.primary, fontSize: 11),
                  ),
                ),
              if (isCurrent) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lang.t('books.badge.current'),
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            book.description?.isNotEmpty == true
                ? book.description!
                : lang.t('books.noDesc'),
            style: TextStyle(color: c.textVariant, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${lang.t('books.type.${book.type.name}')} · ${lang.t('books.role.${book.role.name}')}',
                style: TextStyle(color: c.textVariant, fontSize: 11),
              ),
              const Spacer(),
              if (!isCurrent)
                TextButton(
                  onPressed: onSwitch,
                  child: Text(lang.t('books.action.switch')),
                ),
              TextButton(
                onPressed: onMembers,
                child: Text(lang.t('books.action.members')),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: c.error),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateBookSheet extends ConsumerStatefulWidget {
  const _CreateBookSheet();

  @override
  ConsumerState<_CreateBookSheet> createState() => _CreateBookSheetState();
}

class _CreateBookSheetState extends ConsumerState<_CreateBookSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  BookType _type = BookType.personal;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = I18n.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ref.read(toastControllerProvider.notifier).show(lang.t('books.create.name'));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(bookControllerProvider.notifier).createBook(
            CreateBookInput(
              name: name,
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              type: _type,
              currency: 'CNY',
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('books.create.failPrefix')} $e',
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
              lang.t('books.create.title'),
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: lang.t('books.create.name'),
                hintText: lang.t('books.create.namePlaceholder'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(lang.t('books.create.type'),
                style: TextStyle(color: c.textVariant, fontSize: 12)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final t in BookType.values)
                  ChoiceChip(
                    label: Text(lang.t('books.type.${t.name}')),
                    selected: t == _type,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: lang.t('books.create.description'),
                hintText: lang.t('books.create.descPlaceholder'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(lang.t('books.create.title')),
            ),
          ],
        ),
      ),
    );
  }
}