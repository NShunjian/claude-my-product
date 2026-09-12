import 'package:flutter/material.dart';

/// ponytail: 2026-09-12 — 自定义下拉刷新 widget。
///
///   替代 Flutter 内置 [RefreshIndicator]:
///   1. RefreshIndicator 阈值太灵敏(~40px),"轻轻一滑"就触发刷新圈。
///   2. RefreshIndicator 依赖 [OverscrollNotification],在不同 [ScrollPhysics]
///      下行为不一致:Android ClampingScrollPhysics 触发条件只有"内容短
///      顶部 drag DOWN"(overscroll < 0 past end 的"假信号"),AlwaysScrollable
///      在某些页面下又不触发 —— 实测首页能下拉、流水/账户/我的页不能,
///      根因正是 [OverscrollNotification] 的歧义性。
///
///   本组件直接监听原始手指位移([Listener]),把"下拉"定义为:
///     - 起点必须在顶部([ScrollMetrics.pixels] <= 0)
///     - 手指向下位移 ≥ [threshold]
///     - 起点到释放之间,pixels 始终保持 <= 0(一旦内容开始往下滚就清零,
///       避免快速 flick 误触发)
///
///   不依赖 [OverscrollNotification],所以任何 [ScrollPhysics] 都一致工作。
class PullToRefresh extends StatefulWidget {
  const PullToRefresh({
    required this.onRefresh,
    required this.child,
    this.threshold = 100.0,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double threshold;

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> {
  double _pullDistance = 0;
  bool _refreshing = false;

  // 跟踪本次手指手势是否在"下拉刷新"模式:
  // - _atTop = 当前 scroll position 是否 <= 0(由 ScrollUpdate 实时更新)
  // - _trackingPull = pointer down 后是否曾向下位移(确认是下拉而非 tap/侧滑)
  // - _activePointer = 当前追踪的指针 id,只跟踪首根手指避免多指干扰
  bool _atTop = true;
  bool _trackingPull = false;
  int? _activePointer;
  double _startY = 0;

  void _onPointerDown(PointerDownEvent e) {
    if (_refreshing) return;
    // 只跟踪第一根手指,后续手指忽略 —— 多指触屏(iPad 等)不应触发刷新。
    if (_activePointer != null) return;
    _activePointer = e.pointer;
    _startY = e.position.dy;
    _trackingPull = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_refreshing || _activePointer != e.pointer) return;

    // 已离开顶部 → 本次手势是普通滚动,清掉累加,后续 pointer up 不再触发。
    if (!_atTop) {
      if (_pullDistance > 0) setState(() => _pullDistance = 0);
      return;
    }

    final dy = e.position.dy - _startY;
    if (dy > 0) {
      _trackingPull = true;
      setState(() {
        _pullDistance = dy.clamp(0.0, widget.threshold * 1.5);
      });
    } else if (dy < -8) {
      // 手指显著反向上滑(不是抖动),清零。
      _trackingPull = false;
      if (_pullDistance > 0) setState(() => _pullDistance = 0);
    }
  }

  void _onPointerEnd(PointerEvent e) {
    if (_activePointer != e.pointer) return;
    final wasTracking = _trackingPull;
    _activePointer = null;
    _trackingPull = false;

    if (_refreshing) {
      setState(() => _pullDistance = 0);
      return;
    }
    // 没真正"下拉"过(tap / 侧滑 / 已在中间位置) → 静默归零,不触发。
    if (!wasTracking) {
      if (_pullDistance > 0) setState(() => _pullDistance = 0);
      return;
    }
    if (_pullDistance >= widget.threshold) {
      _triggerRefresh();
    } else {
      setState(() => _pullDistance = 0);
    }
  }

  bool _handleScroll(ScrollNotification n) {
    if (_refreshing) return false;
    // 只看 ScrollUpdate / ScrollStart,记录是否在顶部。
    if (n is ScrollUpdateNotification || n is ScrollStartNotification) {
      final wasAtTop = _atTop;
      _atTop = n.metrics.pixels <= 0;
      // 已经在"下拉"过程中滚离了顶部 → 视为滚动,清掉累加,避免松开误触发。
      if (wasAtTop && !_atTop && _pullDistance > 0) {
        setState(() => _pullDistance = 0);
        _trackingPull = false;
      }
    }
    return false;
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _refreshing = true;
      // 锁定到阈值位置,显示"刷新中"图标。
      _pullDistance = widget.threshold;
    });
    // ponytail: 2026-09-12 — iOS UIRefreshControl 标配最短 ~400ms 可见时间。
    //   本地缓存命中时 onRefresh 几乎立即返回(<50ms),spinner 一帧就消失
    //   感官上"没刷新"。统一拉到 400ms,首页(慢)和其它页(快)行为一致。
    final start = DateTime.now();
    try {
      await widget.onRefresh();
    } finally {
      final elapsed = DateTime.now().difference(start);
      const minVisible = Duration(milliseconds: 400);
      if (elapsed < minVisible) {
        await Future.delayed(minVisible - elapsed);
      }
      if (mounted) {
        setState(() {
          _pullDistance = 0;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final progress = (_pullDistance / widget.threshold).clamp(0.0, 1.0);
    return Listener(
      // ponytail: Listener 不消费手势,只观察 —— inner Scrollable 的
      //          drag/scroll 仍正常,我的 Listener 平行读指针事件算位移。
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: Stack(
          children: [
            widget.child,
            // ponytail: IgnorePointer 包外层,Positioned widget 不挡手势。
            if (_pullDistance > 0 || _refreshing)
              Positioned(
                // ponytail: 2026-09-12 — pull 期间转圈跟手(_pullDistance - 24),
                //   refresh 开始后定在 page header 下方(top: 16 ≈ AppHeader
                //   divider + 16dp),落在红框位置。`threshold - 24 = 76` 落在
                //   page 中部(总览/日期选择器那行)遮挡内容,改成 16 后跟
                //   page header 平齐,不遮挡。
                top: _refreshing ? 16 : _pullDistance - 24,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _refreshing ? 1.0 : progress,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: _refreshing
                            ? CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(color),
                              )
                            : Icon(Icons.refresh, size: 24, color: color),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}