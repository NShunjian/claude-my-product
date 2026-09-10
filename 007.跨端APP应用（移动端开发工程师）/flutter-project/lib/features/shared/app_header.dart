import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

/// 对齐 components/AppHeader.vue — title + 可选返回按钮 + 底部 1px 分隔线。
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key, required this.title, this.back = false});

  final String title;
  final bool back;

  // 高度 = kToolbarHeight(56) + 1px 底边,uniapp .app-header { border-bottom: 1px }。
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
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