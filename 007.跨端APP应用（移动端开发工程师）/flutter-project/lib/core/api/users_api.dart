import 'api_client.dart';
import 'models.dart';

class UsersApi {
  UsersApi(this._c);
  final ApiClient _c;

  Future<User> updateProfile(UpdateProfileInput input) async {
    // 后端 PATCH /api/users/me 返回 envelope { code, message, data: UserDTO },
    // _c.request<T>() 已剥掉 envelope 拿到的 env 就是 UserDTO 平铺,不要再 ['user']。
    // 之前 env['user'] 在头像-only 更新时为 null → "Null is not a subtype of Map"。
    final env = await _c.patch<Map<String, dynamic>>(
      '/api/users/me',
      data: input.toJson(),
    );
    return User.fromJson(env);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) =>
      _c.post('/api/users/me/password',
          data: {'oldPassword': oldPassword, 'newPassword': newPassword});
}
