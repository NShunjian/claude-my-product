import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhang_app/core/api/models.dart';
import 'package:qingzhang_app/core/utils/category_presentation.dart';

Category _cat(String id, String name, {String color = '#FF0000'}) {
  return Category(
    id: id,
    type: CategoryType.expense,
    name: name,
    icon: '',
    color: color,
    sortOrder: 0,
    isPreset: false,
  );
}

void main() {
  test('preset expense 餐饮 → 🍔', () {
    final p = presentCategory(_cat('preset-expense-餐饮', '餐饮'));
    expect(p.icon, '🍔');
  });

  test('preset income 工资 → 💼', () {
    final p = presentCategory(
      _cat('preset-income-工资', '工资', color: '#388E3C'),
    );
    expect(p.icon, '💼');
  });

  test('unknown id falls back to non-empty emoji', () {
    final p = presentCategory(_cat('custom-1', '我的类'));
    expect(p.icon, isNotEmpty);
  });
}