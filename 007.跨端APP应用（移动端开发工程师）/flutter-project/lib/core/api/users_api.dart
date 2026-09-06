import 'api_client.dart';
import 'models.dart';

class UsersApi {
  UsersApi(this._c);
  final ApiClient _c;

  Future<User> updateProfile(UpdateProfileInput input) async {
    final env = await _c.patch<Map<String, dynamic>>(
      '/api/users/me',
      data: input.toJson(),
    );
    return User.fromJson(env['user'] as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) =>
      _c.post('/api/users/me/password',
          data: {'oldPassword': oldPassword, 'newPassword': newPassword});
}
