import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/storage/prefs.dart';
import 'providers.dart';

class AuthState {
  AuthState({required this.token, required this.user});
  final String? token;
  final User? user;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  AuthState copyWith({String? token, User? user, bool clear = false}) => AuthState(
        token: clear ? null : (token ?? this.token),
        user: clear ? null : (user ?? this.user),
      );
}

/// 对齐 stores/auth.ts — token / user + 持久化 + 1401 监听踢回登录。
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState(token: null, user: null);
  }

  Future<void> hydrate() async {
    final p = await Prefs.getInstance();
    state = state.copyWith(token: p.token);
    // 注册 1401 监听器(只注册一次)。
    final api = ref.read(apiClientProvider);
    api.onAuthInvalid(_onAuthInvalid);
  }

  Future<void> login(String username, String password) async {
    final api = ref.read(authApiProvider);
    final res = await api.login(Credentials(username: username, password: password));
    final p = await Prefs.getInstance();
    await p.setToken(res.token);
    await p.setLastUsername(username);
    state = state.copyWith(token: res.token, user: res.user);
  }

  Future<void> me() async {
    final api = ref.read(authApiProvider);
    final u = await api.me();
    state = state.copyWith(user: u);
  }

  /// 上次登录用户名(用于登录页预填),从 Prefs 读取。
  Future<String?> getLastUsername() async {
    final p = await Prefs.getInstance();
    return p.lastUsername;
  }

  Future<void> logout() async {
    final api = ref.read(authApiProvider);
    try {
      await api.logout();
    } catch (_) {/* 容忍 */}
    final p = await Prefs.getInstance();
    await p.setToken(null);
    state = state.copyWith(clear: true);
  }

  void _onAuthInvalid() {
    // 1401 触发:只清 token + user,实际跳转由 router 监听。
    final p = Prefs.getInstance();
    p.then((prefs) => prefs.setToken(null));
    state = AuthState(token: null, user: null);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
