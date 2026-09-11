import 'api_client.dart';
import 'models.dart';

class AccountsApi {
  AccountsApi(this._c);
  final ApiClient _c;

  Future<List<Account>> listAccounts({
    String? bookId,
    bool includeArchived = false,
  }) async {
    final q = <String, String>{};
    if (bookId != null) q['bookId'] = bookId;
    if (includeArchived) q['includeArchived'] = 'true';
    final env = await _c.get<Map<String, dynamic>>(
      '/api/accounts',
      query: q.isEmpty ? null : q,
    );
    final items = (env['items'] as List? ?? []).cast<Map<String, dynamic>>();
    return items.map(Account.fromJson).toList();
  }

  Future<Account> getAccount(String id) async {
    final env = await _c.get<Map<String, dynamic>>('/api/accounts/$id');
    return Account.fromJson(env['account'] as Map<String, dynamic>);
  }

  Future<Account> createAccount(CreateAccountInput input) async {
    final env = await _c.post<Map<String, dynamic>>(
      '/api/accounts',
      data: input.toJson(),
    );
    return Account.fromJson(env['account'] as Map<String, dynamic>);
  }

  Future<Account> updateAccount(String id, Map<String, dynamic> patch) async {
    final env = await _c.patch<Map<String, dynamic>>(
      '/api/accounts/$id',
      data: patch,
    );
    return Account.fromJson(env['account'] as Map<String, dynamic>);
  }

  Future<void> deleteAccount(String id) => _c.delete('/api/accounts/$id');

  /// 归档账户 —— 隐藏不显示,records / balance / 报表全部保留
  Future<void> archiveAccount(String id) => _c.post('/api/accounts/$id/archive');

  /// 取消归档
  Future<void> unarchiveAccount(String id) => _c.delete('/api/accounts/$id/archive');
}
