import '../api/models.dart';

/// 对齐 utils/category-presentation.ts — 分类显示辅助:emoji + 颜色。
/// TABLE 覆盖预设分类;COLOR_HEX 是 token 名 → 实际色值的映射。
class CategoryPresentation {
  const CategoryPresentation({required this.icon, required this.color});
  final String icon;
  final String color;
}

const _COLOR_HEX = <String, String>{
  'blue': '#2E7DE6',
  'pink': '#EC4899',
  'green': '#388E3C',
  'orange': '#F97316',
  'purple': '#7B1FA2',
  'red': '#BA1A1A',
  'amber': '#FFA000',
  'teal': '#0D9488',
  'gray': '#727782',
};

const _TABLE = <String, CategoryPresentation>{
  // expense 预设
  'preset-expense-餐饮': CategoryPresentation(icon: '🍔', color: '#F97316'),
  'preset-expense-交通': CategoryPresentation(icon: '🚇', color: '#2E7DE6'),
  'preset-expense-购物': CategoryPresentation(icon: '🛍️', color: '#EC4899'),
  'preset-expense-日用': CategoryPresentation(icon: '🧴', color: '#0D9488'),
  'preset-expense-娱乐': CategoryPresentation(icon: '🎮', color: '#7B1FA2'),
  'preset-expense-居家': CategoryPresentation(icon: '🏠', color: '#FFA000'),
  'preset-expense-通讯': CategoryPresentation(icon: '📱', color: '#388E3C'),
  'preset-expense-医疗': CategoryPresentation(icon: '💊', color: '#BA1A1A'),
  'preset-expense-教育': CategoryPresentation(icon: '📚', color: '#2E7DE6'),
  'preset-expense-其他': CategoryPresentation(icon: '⋯', color: '#727782'),
  // income 预设
  'preset-income-工资': CategoryPresentation(icon: '💼', color: '#388E3C'),
  'preset-income-奖金': CategoryPresentation(icon: '🎁', color: '#EC4899'),
  'preset-income-投资': CategoryPresentation(icon: '📈', color: '#2E7DE6'),
  'preset-income-兼职': CategoryPresentation(icon: '🛠️', color: '#FFA000'),
  'preset-income-其他': CategoryPresentation(icon: '⋯', color: '#727782'),
};

const _FALLBACK_ICON = '⋯';
const _FALLBACK_COLOR = '#727782';

bool _isProbablyMsLigatureName(String s) {
  // 老分类用 MS 字体 ligature(如 'home')写 icon,跨端表现不一,fallback 到 emoji。
  return RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(s);
}

String _lookupKey(Category c) {
  final id = c.id;
  if (id.startsWith('preset-')) return id;
  return id;
}

CategoryPresentation presentCategory(Category c) {
  final hit = _TABLE[_lookupKey(c)];
  if (hit != null) return hit;

  // 自定义分类:emoji 来自后端 icon 字段;若疑似 MS ligature → fallback。
  var icon = c.icon.trim();
  if (icon.isEmpty || _isProbablyMsLigatureName(icon)) {
    icon = _FALLBACK_ICON;
  }
  final colorHex = _COLOR_HEX[c.color] ?? c.color;
  final color = colorHex.isEmpty ? _FALLBACK_COLOR : colorHex;
  return CategoryPresentation(icon: icon, color: color);
}

String categoryMaterialIcon(Category c) => presentCategory(c).icon;
