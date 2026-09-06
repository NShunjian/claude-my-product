import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import 'record_form.dart';

/// 对齐 pages/record/income.vue — 记收入。
class RecordIncomeScreen extends ConsumerWidget {
  const RecordIncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('pageTitle.recordIncome')),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: const RecordForm(kind: RecordType.income),
    );
  }
}