import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhang_app/core/api/models.dart';
import 'package:qingzhang_app/features/shared/quick_add_controller.dart';

void main() {
  test('default state hidden + expense kind', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(quickAddControllerProvider);
    expect(state.show, isFalse);
    expect(state.kind, RecordType.expense);
  });

  test('open then close toggles show', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(quickAddControllerProvider.notifier).open(RecordType.income);
    expect(container.read(quickAddControllerProvider).show, isTrue);
    expect(container.read(quickAddControllerProvider).kind, RecordType.income);
    container.read(quickAddControllerProvider.notifier).close();
    expect(container.read(quickAddControllerProvider).show, isFalse);
  });

  test('notifySaved increments savedAt', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container.read(quickAddControllerProvider).savedAt;
    container.read(quickAddControllerProvider.notifier).notifySaved();
    final after = container.read(quickAddControllerProvider).savedAt;
    expect(after, greaterThan(before));
  });
}