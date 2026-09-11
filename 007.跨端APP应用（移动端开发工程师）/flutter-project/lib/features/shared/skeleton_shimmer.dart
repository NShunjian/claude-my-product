import 'package:flutter/material.dart';

/// 骨架屏闪烁容器 —— 把任意 child 包进来,内置 0.4↔0.8 opacity 1.2s 循环。
///
/// ponytail: 复用骨架 widget,直接 _Shimmer(child: ...) 替代 ListView 根节点。
///          4 个骨架页(home/transactions/accounts/reports/settings cat-grid)
///          全部用这一个。底层用 AnimationController + TickerProviderStateMixin,
///          initState 启动 + dispose 释放,不会泄漏。
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: 0.4 + _ctrl.value * 0.4, // 0.4 → 0.8 → 0.4 循环
        child: child,
      ),
      child: widget.child,
    );
  }
}
