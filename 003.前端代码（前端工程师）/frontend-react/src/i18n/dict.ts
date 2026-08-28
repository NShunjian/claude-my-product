/**
 * 最小可工作版翻译字典:
 *   - 覆盖 Settings.tsx 自身 + 顶部导航标题作为示范
 *   - 其它页面留作后续 i18n 单独工程
 *
 * 命名规范: '<页面>.<意图>'  例如 'settings.theme.label'
 * 缺翻译时 t() 回落到 zh-CN,再缺回落 key 本身。
 */

export type Lang = 'zh-CN' | 'en' | 'zh-TW'

export const LANGS: { code: Lang; label: string }[] = [
  { code: 'zh-CN', label: '简体中文' },
  { code: 'en', label: 'English' },
  { code: 'zh-TW', label: '繁體中文' },
]

type Dict = Record<string, string>

const zh_CN: Dict = {
  // Settings 页
  'settings.heading': '管理您的账户偏好与系统设置',
  'settings.userCard.editProfile': '编辑资料',
  'settings.userCard.freeVersion': '免费版用户',
  'settings.userCard.accountLabel': '账号',
  'settings.userCard.genderLabel': '性别',
  'settings.userCard.ageLabel': '年龄',
  'settings.userCard.gender.male': '男',
  'settings.userCard.gender.female': '女',
  'settings.userCard.gender.other': '其他',
  'settings.userCard.gender.none': '未设置',
  'settings.userCard.age.none': '未设置',
  'settings.prefs.title': '系统偏好',
  'settings.prefs.theme.label': '深色模式',
  'settings.prefs.theme.desc': '跟随系统或手动切换',
  'settings.prefs.theme.system': '跟随系统',
  'settings.prefs.theme.light': '浅色',
  'settings.prefs.theme.dark': '深色',
  'settings.prefs.lang.label': '语言 / Language',
  'settings.prefs.lang.desc': '选择应用显示语言',
  // 顶部 PageTitle
  'pageTitle.settings': '设置',
}

const en: Dict = {
  'settings.heading': 'Manage your account preferences and system settings',
  'settings.userCard.editProfile': 'Edit profile',
  'settings.userCard.freeVersion': 'Free plan',
  'settings.userCard.accountLabel': 'Account',
  'settings.userCard.genderLabel': 'Gender',
  'settings.userCard.ageLabel': 'Age',
  'settings.userCard.gender.male': 'Male',
  'settings.userCard.gender.female': 'Female',
  'settings.userCard.gender.other': 'Other',
  'settings.userCard.gender.none': 'Not set',
  'settings.userCard.age.none': 'Not set',
  'settings.prefs.title': 'Preferences',
  'settings.prefs.theme.label': 'Dark mode',
  'settings.prefs.theme.desc': 'Follow system or switch manually',
  'settings.prefs.theme.system': 'System',
  'settings.prefs.theme.light': 'Light',
  'settings.prefs.theme.dark': 'Dark',
  'settings.prefs.lang.label': 'Language',
  'settings.prefs.lang.desc': 'Choose the display language',
  'pageTitle.settings': 'Settings',
}

const zh_TW: Dict = {
  'settings.heading': '管理您的帳戶偏好與系統設定',
  'settings.userCard.editProfile': '編輯資料',
  'settings.userCard.freeVersion': '免費版用戶',
  'settings.userCard.accountLabel': '帳號',
  'settings.userCard.genderLabel': '性別',
  'settings.userCard.ageLabel': '年齡',
  'settings.userCard.gender.male': '男',
  'settings.userCard.gender.female': '女',
  'settings.userCard.gender.other': '其他',
  'settings.userCard.gender.none': '未設定',
  'settings.userCard.age.none': '未設定',
  'settings.prefs.title': '系統偏好',
  'settings.prefs.theme.label': '深色模式',
  'settings.prefs.theme.desc': '跟隨系統或手動切換',
  'settings.prefs.theme.system': '跟隨系統',
  'settings.prefs.theme.light': '淺色',
  'settings.prefs.theme.dark': '深色',
  'settings.prefs.lang.label': '語言 / Language',
  'settings.prefs.lang.desc': '選擇應用顯示語言',
  'pageTitle.settings': '設定',
}

export const DICTS: Record<Lang, Dict> = {
  'zh-CN': zh_CN,
  en,
  'zh-TW': zh_TW,
}

export function translate(lang: Lang, key: string): string {
  return DICTS[lang][key] ?? DICTS['zh-CN'][key] ?? key
}