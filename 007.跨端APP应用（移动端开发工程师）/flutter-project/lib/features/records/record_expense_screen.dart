import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import 'record_form.dart';

/// 对齐 pages/record/expense.vue — 记支出。
class RecordExpenseScreen extends ConsumerWidget {
  const RecordExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('pageTitle.recordExpense')),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: const RecordForm(kind: RecordType.expense),
    );
  }
}