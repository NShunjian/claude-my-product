import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/modal_state.dart';
import 'quick_add_controller.dart';

/// 对齐 components/AppHeader.vue — title + 可选返回按钮。
/// modalOpen 开启时自身隐藏(对齐 iOS WKWebView sticky z-index workaround,Flutter 无此 bug
/// 但保留同一接口语义)。
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({super.key, required this.title, this.back = false});

  final String title;
  final bool back;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modalOpen = ref.watch(modalOpenProvider);
    final quickAddShow = ref.watch(quickAddControllerProvider.select((s) => s.show));
    if (modalOpen || quickAddShow) return const SizedBox.shrink();

    return AppBar(
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
    );
  }
}