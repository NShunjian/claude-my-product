import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhang_app/core/api/models.dart';
import 'package:qingzhang_app/core/utils/finance.dart';

void main() {
  group('formatAmount', () {
    test('formats with two decimals', () {
      expect(formatAmount(12.34), '12.34');
    });

    test('zero', () {
      expect(formatAmount(0), '0.00');
    });

    test('withSymbol adds ¥', () {
      expect(formatAmount(1.5, withSymbol: true), startsWith('¥'));
    });
  });

  group('typeOfAccount', () {
    test('cash returns non-empty', () {
      expect(typeOfAccount(AccountType.cash), isNotEmpty);
    });
  });

  group('balanceSign', () {
    test('negative returns -1', () {
      expect(balanceSign(-100), -1);
    });
    test('positive returns 1', () {
      expect(balanceSign(100), 1);
    });
    test('zero returns 0', () {
      expect(balanceSign(0), 0);
    });
  });
}