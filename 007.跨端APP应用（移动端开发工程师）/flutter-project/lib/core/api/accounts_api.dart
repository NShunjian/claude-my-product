import 'api_client.dart';
import 'models.dart';

class AccountsApi {
  AccountsApi(this._c);
  final ApiClient _c;

  Future<List<Account>> listAccounts({String? bookId}) async {
    final env = await _c.get<Map<String, dynamic>>(
      '/api/accounts',
      query: bookId != null ? {'bookId': bookId} : null,
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
}
