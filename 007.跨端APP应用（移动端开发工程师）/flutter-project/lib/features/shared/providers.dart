import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/accounts_api.dart';
import '../../core/api/api_client.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/books_api.dart';
import '../../core/api/categories_api.dart';
import '../../core/api/records_api.dart';
import '../../core/api/reports_api.dart';
import '../../core/api/users_api.dart';
import '../../core/api/version_api.dart';
import '../../core/storage/prefs.dart';
import '../../core/utils/export.dart';
import 'book_controller.dart';

/// 全局 ApiClient — 单例,由 main 注入 baseUrl + prefs 后用 override。
final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Override in main() with real baseUrl + prefs');
});

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));
final usersApiProvider = Provider<UsersApi>((ref) => UsersApi(ref.watch(apiClientProvider)));
final booksApiProvider = Provider<BooksApi>((ref) => BooksApi(ref.watch(apiClientProvider)));
final accountsApiProvider = Provider<AccountsApi>((ref) => AccountsApi(ref.watch(apiClientProvider)));
final categoriesApiProvider = Provider<CategoriesApi>((ref) => CategoriesApi(ref.watch(apiClientProvider)));
final recordsApiProvider = Provider<RecordsApi>((ref) => RecordsApi(ref.watch(apiClientProvider)));
final reportsApiProvider = Provider<ReportsApi>((ref) => ReportsApi(ref.watch(apiClientProvider)));
final versionApiProvider = Provider<VersionApi>((ref) => VersionApi(ref.watch(apiClientProvider)));

/// Excel 导出服务 — 我的页 / 数据管理用。
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    records: ref.watch(recordsApiProvider),
    accounts: ref.watch(accountsApiProvider),
    categories: ref.watch(categoriesApiProvider),
  );
});

/// Prefs 单例 — 由 main 注入 Prefs.getInstance()。
final prefsProvider = Provider<Prefs>((ref) {
  throw UnimplementedError('Override in main() with Prefs.getInstance() result');
});

/// 当前账本 uuid — 来自 BookController.state.currentId。
final currentBookIdProvider = Provider<String>((ref) {
  return ref.watch(bookControllerProvider.select((s) => s.currentId ?? ''));
});