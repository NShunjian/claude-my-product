import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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

  // ponytail: 三端区分 — mobile 端 toolbarHeight = 44(iOS HIG NavigationBar
  //          标准值,用户指定);desktop 端走 kToolbarHeight = 56(M3 默认)。
  //          preferredSize 必须是 const getter,但 Flutter 允许带 context 的
  //          dynamic getter(不会被 cached 测量),改用 platform 检查。
  //          参见 [[three-platform-must-specify-target]]。
  @override
  Size get preferredSize {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final h = isMobile ? 44.0 : kToolbarHeight;
    return Size.fromHeight(h + 1); // +1 是底部分隔线
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    return AppBar(
      toolbarHeight: isMobile ? 44.0 : kToolbarHeight,
      title: Text(
        title,
        // ponytail: mobile 端 title 字号 16(用户指定);desktop 端走 ThemeData 默认。
        style: isMobile ? const TextStyle(fontSize: 16) : null,
      ),
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