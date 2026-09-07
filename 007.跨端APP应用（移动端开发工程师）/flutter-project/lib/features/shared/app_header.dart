import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/modal_state.dart';
import 'quick_add_controller.dart';

/// 对齐 components/AppHeader.vue — title + 可选返回按钮 + 底部 1px 分隔线。
/// modalOpen 开启时自身隐藏(对齐 iOS WKWebView sticky z-index workaround,Flutter 无此 bug
/// 但保留同一接口语义)。
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({super.key, required this.title, this.back = false});

  final String title;
  final bool back;

  // 高度 = kToolbarHeight(56) + 1px 底边,uniapp .app-header { border-bottom: 1px }。
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modalOpen = ref.watch(modalOpenProvider);
    final quickAddShow = ref.watch(quickAddControllerProvider.select((s) => s.show));
    if (modalOpen || quickAddShow) return const SizedBox.shrink();

    final c = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          title: Text(title),
          centerTitle: true,
          leading: back
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                )
              : null,
        ),
        Container(height: 1, color: c.divider),
      ],
    );
  }
}