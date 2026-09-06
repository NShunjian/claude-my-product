import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/storage/prefs.dart';
import 'providers.dart';

class BookState {
  BookState({
    required this.books,
    required this.currentId,
    required this.loading,
  });

  final List<Book> books;
  final String? currentId;
  final bool loading;

  Book? get current {
    if (currentId == null) return null;
    for (final b in books) {
      if (b.uuid == currentId) return b;
    }
    return null;
  }

  BookState copyWith({
    List<Book>? books,
    String? currentId,
    bool? loading,
    bool clearCurrent = false,
  }) =>
      BookState(
        books: books ?? this.books,
        currentId: clearCurrent ? null : (currentId ?? this.currentId),
        loading: loading ?? this.loading,
      );
}

/// 对齐 stores/book.ts — books 列表 + currentId 持久化 + 自动建默认账本。
class BookController extends Notifier<BookState> {
  @override
  BookState build() {
    return BookState(books: const [], currentId: null, loading: false);
  }

  Future<void> hydrate() async {
    final p = await Prefs.getInstance();
    state = state.copyWith(currentId: p.currentBookUuid);
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true);
    try {
      final api = ref.read(booksApiProvider);
      var list = await api.listBooks();
      if (list.isEmpty) {
        // 新用户:自动建一个默认账本(对齐 uniapp 中的 onEmptyCreateDefault)。
        final created = await api.createBook(
          CreateBookInput(name: '默认账本', type: BookType.personal, currency: 'CNY'),
        );
        list = [created];
      }
      final p = await Prefs.getInstance();
      String? currentId = p.currentBookUuid;
      if (currentId == null || !list.any((b) => b.uuid == currentId)) {
        final def = list.firstWhere(
          (b) => b.isDefault,
          orElse: () => list.first,
        );
        currentId = def.uuid;
        await p.setCurrentBookUuid(currentId);
      }
      state = state.copyWith(books: list, currentId: currentId, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> setCurrent(String uuid) async {
    final p = await Prefs.getInstance();
    await p.setCurrentBookUuid(uuid);
    state = state.copyWith(currentId: uuid);
    // 后端同步(对齐 uniapp setDefaultBook — localStorage 为主,后端 200 兼容)。
    try {
      await ref.read(booksApiProvider).setDefaultBook(uuid);
    } catch (_) {/* 容忍 */}
  }

  Future<Book> createBook(CreateBookInput input) async {
    final created = await ref.read(booksApiProvider).createBook(input);
    await reload();
    return created;
  }

  Future<Book> updateBook(String uuid, UpdateBookInput input) async {
    final updated = await ref.read(booksApiProvider).updateBook(uuid, input);
    await reload();
    return updated;
  }

  Future<void> deleteBook(String uuid) async {
    await ref.read(booksApiProvider).deleteBook(uuid);
    await reload();
  }
}

final bookControllerProvider =
    NotifierProvider<BookController, BookState>(BookController.new);
