import 'api_client.dart';
import 'models.dart';

class AuthApi {
  AuthApi(this._c);
  final ApiClient _c;

  Future<AuthResponse> login(Credentials c) =>
      _c.post('/api/auth/login', data: c.toJson());

  Future<AuthResponse> register(Credentials c) =>
      _c.post('/api/auth/register', data: c.toJson());

  Future<User> me() => _c.get('/api/auth/me');

  Future<void> logout() => _c.post('/api/auth/logout');
}
