import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

/// 对齐 components/AppHeader.vue — title + 可选返回按钮 + 底部 1px 分隔线。
///
/// 用 AppBar 的 `bottom` 槽位放 1px divider 而不是外层 Column 包 AppBar —
/// 之前那种 Column(mainAxisSize.min, children: [AppBar, Divider]) 在
/// Flutter web 上偶尔触发 "RenderFlex overflowed by N px" assertion
/// (Scaffold 在 intrinsic 测量阶段给 AppBar 极小约束 1×1,Column 报溢出)。
/// 走 `bottom: PreferredSize` 是 Flutter 官方推荐方式,没有这个问题。
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.divider),
      ),
    );
  }
}