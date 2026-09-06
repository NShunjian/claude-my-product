import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 封装 — 对齐 uniapp 中 6 个 storage key:
///   qz_token / qz_last_username / qz_theme_mode / qz_lang / qz_current_book_uuid
/// 不变 key 字符串,方便日后与 H5 兼容。
class Prefs {
  Prefs._(this._sp);

  final SharedPreferences _sp;

  static Prefs? _instance;
  static Future<Prefs> getInstance() async {
    if (_instance != null) return _instance!;
    final sp = await SharedPreferences.getInstance();
    _instance = Prefs._(sp);
    return _instance!;
  }

  // ===== token =====
  static const _kToken = 'qz_token';
  String? get token => _sp.getString(_kToken);
  Future<void> setToken(String? v) async {
    if (v == null) {
      await _sp.remove(_kToken);
    } else {
      await _sp.setString(_kToken, v);
    }
  }

  // ===== last username =====
  static const _kLastUsername = 'qz_last_username';
  String? get lastUsername => _sp.getString(_kLastUsername);
  Future<void> setLastUsername(String v) => _sp.setString(_kLastUsername, v);

  // ===== theme mode =====
  static const _kThemeMode = 'qz_theme_mode';
  String? get themeMode => _sp.getString(_kThemeMode);
  Future<void> setThemeMode(String v) => _sp.setString(_kThemeMode, v);

  // ===== lang =====
  static const _kLang = 'qz_lang';
  String? get lang => _sp.getString(_kLang);
  Future<void> setLang(String v) => _sp.setString(_kLang, v);

  // ===== current book uuid =====
  static const _kCurrentBook = 'qz_current_book_uuid';
  String? get currentBookUuid => _sp.getString(_kCurrentBook);
  Future<void> setCurrentBookUuid(String? v) async {
    if (v == null) {
      await _sp.remove(_kCurrentBook);
    } else {
      await _sp.setString(_kCurrentBook, v);
    }
  }
}
