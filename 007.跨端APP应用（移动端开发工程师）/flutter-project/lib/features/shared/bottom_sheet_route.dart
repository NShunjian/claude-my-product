// ponytail: 2026-09-12 — 抽出"打开一个贴屏底的全屏 sheet"流程。Flutter 内
//          部 showModalBottomSheet 会自动给 sheet 加 viewPadding.bottom
//          padding(~34dp iOS home indicator),导致 sheet 底部永远到不了
//          屏幕底部。这里 Navigator.push + 自定 PageRoute + 自定 barrier
//          + Stack > Positioned(bottom: 0),调用方只需要提供 sheet 内容。
//
// 用途:
//   - year_picker.dart    — 年份滚轮
//   - transactions_screen.dart — 流水页分类/账户 picker
//
// 复用到别的屏底 sheet picker 也走这个 helper。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/modal_state.dart';

/// 公开 API:弹一个贴屏底的 sheet,wheel/内容底部 = 屏幕底部。
///
/// 用法:
/// ```dart
/// final picked = await showAppBottomSheet<int>(
///   context,
///   ref: ref,                        // 可选;传了会自动开/关 modalOpenProvider
///   builder: (_) => YearWheelSheet(years: years, initialYear: initialYear),
/// );
/// ```
///
/// sheet 内部必须用 `SizedBox.expand > Stack > Positioned(bottom: 0)`
/// 锚屏底,否则这个 helper 帮不了你。
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  WidgetRef? ref,
  required WidgetBuilder builder,
}) async {
  // ponytail: modalOpenProvider → _TabScaffold 把 bottomNavigationBar 换
  //          成 SizedBox.shrink(),tab bar 真正消失 → picker 任何高度都能
  //          盖到屏幕底。
  ref?.read(modalOpenProvider.notifier).state = true;
  try {
    return await Navigator.of(context, rootNavigator: true).push<T>(
      _BottomSheetRoute<T>(builder: builder),
    );
  } finally {
    if (context.mounted) {
      ref?.read(modalOpenProvider.notifier).state = false;
    }
  }
}

/// 自定 PageRoute:全屏 barrier + slide-up + sheet 内容。
class _BottomSheetRoute<T> extends PageRoute<T> {
  _BottomSheetRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => const Color(0x8A000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final tween = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));
    return SlideTransition(position: animation.drive(tween), child: child);
  }
}