import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';
import 'dict.dart';
import 'lang.dart';

/// 给 Lang 加 .t() 便捷访问 — 在 widgets 中 `final lang = I18n.of(context); lang.t('key')`。
extension LangT on Lang {
  String t(String key, [Map<String, Object?>? params]) => _t(this, key, params);
}

/// 当前语言 — 对齐 stores/language.ts 的 lang state + 持久化 qz_lang。
class LanguageController extends Notifier<Lang> {
  @override
  Lang build() {
    // 同步从 prefs 读取初值(build 是 sync,先用 null-safe 初始化,hydrate 后再覆盖)。
    return Lang.zhCN;
  }

  /// 在 main 启动时调用一次,从 prefs 读真实值。
  void hydrate(Lang initial) {
    state = initial;
  }

  Future<void> setLang(Lang l) async {
    state = l;
    await Prefs.getInstance().then((p) => p.setLang(l.code));
  }
}

final languageProvider =
    NotifierProvider<LanguageController, Lang>(LanguageController.new);

/// 全局 Locale — 给 MaterialApp.router 的 locale 参数。
final Locale Function(Lang lang) localeOf = (lang) => switch (lang) {
      Lang.zhCN => const Locale('zh', 'CN'),
      Lang.en => const Locale('en', 'US'),
      Lang.zhTW => const Locale('zh', 'TW'),
    };

/// i18n t() 的便捷访问 — 通过 InheritedWidget 注入,UI 直接 context.t('key')。
class I18n extends InheritedWidget {
  const I18n({super.key, required this.lang, required super.child});

  final Lang lang;

  static Lang of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<I18n>();
    return w?.lang ?? Lang.zhCN;
  }

  String t(String key, [Map<String, Object?>? params]) =>
      _t(this.lang, key, params);

  @override
  bool updateShouldNotify(I18n oldWidget) => oldWidget.lang != lang;
}

String _t(Lang lang, String key, [Map<String, Object?>? params]) =>
    t(lang, key, params);
