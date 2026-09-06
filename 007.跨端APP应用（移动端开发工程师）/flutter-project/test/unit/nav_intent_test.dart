import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhang_app/core/router/nav_intent.dart';

void main() {
  test('setPendingMonth + consumePendingMonth round-trip', () {
    setPendingMonth('2026-09');
    expect(consumePendingMonth(), '2026-09');
    expect(consumePendingMonth(), isNull);
  });

  test('overwrite wins', () {
    setPendingMonth('2026-09');
    setPendingMonth('2026-10');
    expect(consumePendingMonth(), '2026-10');
  });
}