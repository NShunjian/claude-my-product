import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import 'toast_controller.dart';

/// 对齐 components/Toast.vue — 固定顶部、半透明胶囊形、自动消失。
///
/// ponytail: 加 maxLines/overflow/maxWidth 三件套。后端 message 偶尔超长(尤其
///          校验失败堆栈 / Dio 兼容期的错误信息),没有宽度约束的 Text 在
///          Column 里会撑爆屏幕,出现 RenderFlex 黄色溢出条,用户以为是
///          banner。现在单条 toast 最长 6 行 / 80% 屏宽,多余省略号截掉。
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(toastControllerProvider);
    final maxWidth = MediaQuery.of(context).size.width * 0.8;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          item.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}