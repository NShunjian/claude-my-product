import 'api_client.dart';
import 'models.dart';

class AuthApi {
  AuthApi(this._c);
  final ApiClient _c;

  // _c.request<T>() 内部已经做 `env['data'] as T` 把 envelope 剥掉,
  // 这里拿到的 env 就是后端 data 内的对象,不要再剥一次 ['data']。
  // 后端 /api/auth/login 返回 data: {user, token, permissions, roleCodes, isSuperAdmin}
  // 后端 /api/auth/me    返回 data: UserDTO(平铺的 user 字段)
  Future<AuthResponse> login(Credentials c) async {
    final env = await _c.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: c.toJson(),
    );
    return AuthResponse.fromJson(env);
  }

  Future<AuthResponse> register(Credentials c) async {
    final env = await _c.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: c.toJson(),
    );
    return AuthResponse.fromJson(env);
  }

  Future<User> me() async {
    final env = await _c.get<Map<String, dynamic>>('/api/auth/me');
    return User.fromJson(env);
  }

  Future<void> logout() => _c.post('/api/auth/logout');
}