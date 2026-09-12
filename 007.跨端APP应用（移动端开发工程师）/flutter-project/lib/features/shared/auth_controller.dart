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
    // 对齐 uniapp App.vue:95 onLaunch —— 冷启动 token 还在时异步拉一次 /me 拿 user。
    // 不调的话,settings 等页会拿到 token 有但 user=null 的半态,5 行 info 全走 fallback。
    // 401 由已注册的 _onAuthInvalid 接管(清 token + router 跳 login);网络错误容忍。
    final t = p.token;
    if (t != null && t.isNotEmpty) {
      try {
        // ponytail: 2026-09-12 — 拿 raw envelope log 一遍,mobile 没拿到
        //          avatar 但 web 拿到了,差异点要后端 /me 返回的 UserDTO
        //          是否含 avatar 字段。包 envelope 看 code/message/data
        //          整体,定位是 data 缺字段、envelope 解包错、还是别处。
        final env = await api.request<Map<String, dynamic>>(
          '/api/auth/me',
          method: 'GET',
        );
        // ignore: avoid_print
        print('[hydrate] /me raw data keys=${env.keys} avatar=${env['avatar']}');
        final u = User.fromJson(env);
        state = state.copyWith(user: u);
      } catch (e) {
        // ignore: avoid_print
        print('[hydrate] /me failed: $e');
        // 容忍 — 401 已注册 listener 接管
      }
    }
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
