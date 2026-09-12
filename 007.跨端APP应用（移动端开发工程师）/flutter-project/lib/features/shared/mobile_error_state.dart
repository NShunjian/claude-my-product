import 'package:flutter/material.dart';

import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';

/// ponytail: 2026-09-12 — mobile 端数据加载失败统一展示:cloud_off icon +
///          友好文案(i18n key,跟原有 loadErrorPrefix 一致)+ 重试按钮。
///          替代原来 `Text('$errorPrefix${snap.error}')` 的红字裸 Dio 文本
///          (用户反馈体验感差,错误堆栈 / DioException toString 全展给用户)。
///
/// 跨端策略:web 端 `kIsWeb == true`,仍保留原 `Text` 红字展示(开发/排错
///          友好);只有 mobile 端走这个 widget(用 `kIsWeb` 守卫)。
///
/// 模板:home_screen.dart:156-214 原 inline 错误 UI 抽出来 — 那段已存在
///        一段时间,UI OK;抽出来让 transactions/reports/accounts 复用。
///        home_screen 暂时保留原 inline(避免改错现状),后续如果想视觉
///        完全一致可换成 widget。
class MobileErrorState extends StatelessWidget {
  const MobileErrorState({
    super.key,
    required this.errorKey,
    required this.retryKey,
    required this.onRetry,
  });

  /// i18n key,如 `'transactions.loadErrorPrefix'`。值是"加载失败:"前缀
  /// 文案,统一 3 语言都在 [lib/core/i18n/dict.dart] 已存在。
  final String errorKey;

  /// i18n key,如 `'common.retry'`。
  final String retryKey;

  /// 点击重试按钮触发。调用方负责重新拉 future + setState。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    // 用 ListView 不是 Center:ListView 让 RefreshIndicator 下拉手势能
    // 触发(页面有滚动内容 RefreshIndicator 才挂载)。Center 直接撑满
    // 父容器时,外层 RefreshIndicator 因 child 不可滚而下拉失效。
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 80),
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: c.textVariant),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  lang.t(errorKey),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.error, fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.divider),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(120, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: Text(
                  lang.t(retryKey),
                  style: TextStyle(color: c.text, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}