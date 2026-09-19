import '../api/models.dart';

/// 对齐 utils/category-presentation.ts — 分类显示辅助。
///
/// 所有分类的颜色 + 图标全部走后端存的 `c.color` / `c.icon`,前端不再维护预设表。
/// 这样所有端(uniapp / Harmony / Flutter)都用同一份后端数据,
/// 保证一处改色,各端跟随。
class CategoryPresentation {
  const CategoryPresentation({required this.icon, required this.color});
  final String icon;
  final String color;
}

const _FALLBACK_ICON = '⋯';
const _FALLBACK_COLOR = '#727782';

bool _isProbablyMsLigatureName(String s) {
  // 老分类用 MS 字体 ligature(如 'home')写 icon,跨端表现不一,fallback 到 emoji。
  return RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(s);
}

CategoryPresentation presentCategory(Category c) {
  var icon = c.icon.trim();
  if (icon.isEmpty || _isProbablyMsLigatureName(icon)) {
    icon = _FALLBACK_ICON;
  }
  final color = c.color.isEmpty ? _FALLBACK_COLOR : c.color;
  return CategoryPresentation(icon: icon, color: color);
}

String categoryMaterialIcon(Category c) => presentCategory(c).icon;
