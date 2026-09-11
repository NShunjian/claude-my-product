import 'api_client.dart';
import 'models.dart';

class BooksApi {
  BooksApi(this._c);
  final ApiClient _c;

  Future<List<Book>> listBooks() async {
    final env = await _c.get<Map<String, dynamic>>('/api/books');
    final items = (env['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Book.fromJson).toList();
  }

  Future<Book> getBook(String uuid) async {
    // 后端: ApiResponse.ok(Map.of("book", service.get(...))) —
    // envelope.data = {book: {...}},request<T> 拿到 env = {book: ...}。
    final env = await _c.get<Map<String, dynamic>>(
      '/api/books/${Uri.encodeComponent(uuid)}',
    );
    return Book.fromJson(env['book'] as Map<String, dynamic>);
  }

  Future<Book> createBook(CreateBookInput input) async {
    // 后端: ApiResponse.ok(Map.of("book", service.create(...)))。
    final env = await _c.post<Map<String, dynamic>>(
      '/api/books',
      data: input.toJson(),
    );
    return Book.fromJson(env['book'] as Map<String, dynamic>);
  }

  Future<Book> updateBook(String uuid, UpdateBookInput input) async {
    // 后端: ApiResponse.ok(Map.of("book", service.update(...)))。
    final env = await _c.patch<Map<String, dynamic>>(
      '/api/books/${Uri.encodeComponent(uuid)}',
      data: input.toJson(),
    );
    return Book.fromJson(env['book'] as Map<String, dynamic>);
  }

  Future<void> deleteBook(String uuid) =>
      _c.delete('/api/books/${Uri.encodeComponent(uuid)}');

  Future<Book> setDefaultBook(String uuid) async {
    // 后端: ApiResponse.ok(Map.of("book", service.setDefault(...)))。
    final env = await _c.post<Map<String, dynamic>>(
      '/api/books/${Uri.encodeComponent(uuid)}/default',
    );
    return Book.fromJson(env['book'] as Map<String, dynamic>);
  }

  // ===== members =====
  Future<List<BookMember>> listMembers(String bookUuid) async {
    final env = await _c.get<Map<String, dynamic>>(
      '/api/books/${Uri.encodeComponent(bookUuid)}/members',
    );
    final items = (env['items'] as List).cast<Map<String, dynamic>>();
    return items.map(BookMember.fromJson).toList();
  }

  Future<BookMember> addMember(String bookUuid, AddMemberInput input) async {
    // 后端: ApiResponse.ok(Map.of("member", service.addMember(...)))。
    final env = await _c.post<Map<String, dynamic>>(
      '/api/books/${Uri.encodeComponent(bookUuid)}/members',
      data: input.toJson(),
    );
    return BookMember.fromJson(env['member'] as Map<String, dynamic>);
  }

  Future<BookMember> updateMemberRole(
    String bookUuid,
    String userUuid,
    UpdateMemberRoleInput input,
  ) async {
    // 后端: ApiResponse.ok(Map.of("member", service.updateMemberRole(...)))。
    final env = await _c.patch<Map<String, dynamic>>(
      '/api/books/${Uri.encodeComponent(bookUuid)}/members/${Uri.encodeComponent(userUuid)}',
      data: input.toJson(),
    );
    return BookMember.fromJson(env['member'] as Map<String, dynamic>);
  }

  Future<void> removeMember(String bookUuid, String userUuid) => _c.delete(
        '/api/books/${Uri.encodeComponent(bookUuid)}/members/${Uri.encodeComponent(userUuid)}',
      );
}
