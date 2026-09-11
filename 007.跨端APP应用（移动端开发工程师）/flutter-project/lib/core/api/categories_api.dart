import 'api_client.dart';
import 'models.dart';

class CategoriesApi {
  CategoriesApi(this._c);
  final ApiClient _c;

  Future<List<Category>> listCategories({CategoryType? type}) async {
    final env = await _c.get<Map<String, dynamic>>(
      '/api/categories',
      query: type != null ? {'type': type.name} : null,
    );
    final items = (env['items'] as List? ?? []).cast<Map<String, dynamic>>();
    return items.map(Category.fromJson).toList();
  }

  Future<Category> createCategory(CreateCategoryInput input) async {
    // 后端: ApiResponse.ok(Map.of("category", service.create(...))) —
    // envelope.data = {category: {...}},request<T> 拿到 env = {category: ...}。
    final env = await _c.post<Map<String, dynamic>>(
      '/api/categories',
      data: input.toJson(),
    );
    return Category.fromJson(env['category'] as Map<String, dynamic>);
  }

  Future<Category> updateCategory(String id, UpdateCategoryInput input) async {
    // 后端: ApiResponse.ok(Map.of("category", service.update(...)))。
    final env = await _c.patch<Map<String, dynamic>>(
      '/api/categories/${Uri.encodeComponent(id)}',
      data: input.toJson(),
    );
    return Category.fromJson(env['category'] as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) =>
      _c.delete('/api/categories/${Uri.encodeComponent(id)}');
}
