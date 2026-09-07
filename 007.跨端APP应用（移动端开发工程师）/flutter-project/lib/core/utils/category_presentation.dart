import '../api/models.dart';

/// 对齐 utils/category-presentation.ts — 分类显示辅助:emoji + 颜色 token。
/// 查找键统一用 `${type}-${name}`(后端 ID 形如 'preset-expense-餐饮'
/// 也兼容,通过 _lookupKey 去掉 'preset-' 前缀)。
class CategoryPresentation {
  const CategoryPresentation({required this.icon, required this.color});
  final String icon;
  final String color;
}

/// token → 实际色值,与 uniapp COLOR_HEX 完全一致。
const _COLOR_HEX = <String, String>{
  'pink': '#ED64A6',
  'blue': '#4299E1',
  'purple': '#805AD5',
  'teal': '#319795',
  'brown': '#8B6E4E',
  'orange': '#F59E0B',
  'cyan': '#06B6D4',
  'indigo': '#6366F1',
  'green': '#10b981',
  'outline': '#727782',
};

const _TABLE = <String, CategoryPresentation>{
  // expense 预设
  'expense-餐饮': CategoryPresentation(icon: '🍽️', color: '#4299E1'),
  'expense-交通': CategoryPresentation(icon: '🚌', color: '#06B6D4'),
  'expense-购物': CategoryPresentation(icon: '🛍️', color: '#ED64A6'),
  'expense-娱乐': CategoryPresentation(icon: '🎮', color: '#805AD5'),
  'expense-居住': CategoryPresentation(icon: '🏠', color: '#8B6E4E'),
  'expense-医疗': CategoryPresentation(icon: '🏥', color: '#319795'),
  'expense-教育': CategoryPresentation(icon: '🎓', color: '#F59E0B'),
  'expense-通讯': CategoryPresentation(icon: '📱', color: '#6366F1'),
  'expense-其他': CategoryPresentation(icon: '🗂️', color: '#727782'),
  // income 预设
  'income-工资': CategoryPresentation(icon: '💵', color: '#10b981'),
  'income-兼职': CategoryPresentation(icon: '💼', color: '#06B6D4'),
  'income-理财': CategoryPresentation(icon: '📈', color: '#6366F1'),
  'income-红包': CategoryPresentation(icon: '🧧', color: '#ED64A6'),
  'income-其他': CategoryPresentation(icon: '🗂️', color: '#727782'),
};

const _FALLBACK_ICON = '⋯';
const _FALLBACK_COLOR = '#727782';

bool _isProbablyMsLigatureName(String s) {
  // 老分类用 MS 字体 ligature(如 'home')写 icon,跨端表现不一,fallback 到 emoji。
  return RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(s);
}

/// 优先用 id 去 preset- 前缀;再退回 `${type}-${name}` 兜底。
String _lookupKey(Category c) {
  final stripped = c.id.replaceFirst('preset-', '');
  if (_TABLE.containsKey(stripped)) return stripped;
  return '${c.type}-${c.name}';
}

CategoryPresentation presentCategory(Category c) {
  final hit = _TABLE[_lookupKey(c)];
  if (hit != null) return hit;

  // 自定义分类:emoji 来自后端 icon 字段;若疑似 MS ligature → fallback。
  var icon = c.icon.trim();
  if (icon.isEmpty || _isProbablyMsLigatureName(icon)) {
    icon = _FALLBACK_ICON;
  }
  // 自定义分类 color 是 hex 直接用;token 名(老数据)再走 _COLOR_HEX 兜底。
  final color = (c.color.isEmpty) ? _FALLBACK_COLOR : (_COLOR_HEX[c.color] ?? c.color);
  return CategoryPresentation(icon: icon, color: color);
}

String categoryMaterialIcon(Category c) => presentCategory(c).icon;
