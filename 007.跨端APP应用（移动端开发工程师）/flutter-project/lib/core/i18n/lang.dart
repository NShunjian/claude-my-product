/// i18n 语言枚举 — 对齐 i18n/dict.ts 的 Lang。
enum Lang { zhCN, en, zhTW }

extension LangCode on Lang {
  String get code => switch (this) {
        Lang.zhCN => 'zh-CN',
        Lang.en => 'en',
        Lang.zhTW => 'zh-TW',
      };

  String get label => switch (this) {
        Lang.zhCN => '简体中文',
        Lang.en => 'English',
        Lang.zhTW => '繁體中文',
      };
}

class LangInfo {
  const LangInfo(this.code, this.label);
  final String code;
  final String label;
}

const List<LangInfo> LANGS = [
  LangInfo('zh-CN', '简体中文'),
  LangInfo('en', 'English'),
  LangInfo('zh-TW', '繁體中文'),
];

Lang langFromCode(String? code) {
  switch (code) {
    case 'en':
      return Lang.en;
    case 'zh-TW':
      return Lang.zhTW;
    case 'zh-CN':
    default:
      return Lang.zhCN;
  }
}
