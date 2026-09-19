import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhang_app/core/api/models.dart';
import 'package:qingzhang_app/core/utils/category_presentation.dart';

Category _cat(String id, String name, {String color = '#FF0000', String icon = ''}) {
  return Category(
    id: id,
    type: CategoryType.expense,
    name: name,
    icon: icon,
    color: color,
    sortOrder: 0,
    isPreset: false,
  );
}

void main() {
  test('preset expense 餐饮 → 后端 V2 emoji 🍜', () {
    // emoji/color 全部走后端,测试也得传后端值;不再从前端 _TABLE 取
    final p = presentCategory(_cat('preset-expense-餐饮', '餐饮', icon: '🍜', color: '#4299E1'));
    expect(p.icon, '🍜');
    expect(p.color, '#4299E1');
  });

  test('preset income 工资 → 后端 V2 emoji 💰', () {
    final p = presentCategory(_cat(
      'preset-income-工资',
      '工资',
      icon: '💰',
      color: '#10b981',
    ),);
    expect(p.icon, '💰');
    expect(p.color, '#10b981');
  });

  test('unknown id falls back to non-empty emoji', () {
    final p = presentCategory(_cat('custom-1', '我的类'));
    expect(p.icon, isNotEmpty);
  });

  test('empty icon → FALLBACK_ICON', () {
    final p = presentCategory(_cat('custom-2', '空图标', icon: '', color: '#abc'));
    expect(p.icon, '⋯');
  });

  test('empty color → FALLBACK_COLOR', () {
    final p = presentCategory(_cat('custom-3', '空颜色', icon: '🎯', color: ''));
    expect(p.color, '#727782');
  });

  test('MS ligature icon → FALLBACK_ICON(避免跨端显示字面文字)', () {
    final p = presentCategory(_cat('custom-4', '老 ligature', icon: 'restaurant', color: '#fff'));
    expect(p.icon, '⋯');
  });
}
