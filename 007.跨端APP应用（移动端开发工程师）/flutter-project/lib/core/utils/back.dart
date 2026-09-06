import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 对齐 utils/back.ts — History-aware 导航返回。
/// Flutter 端通过 Navigator.canPop 判断:能 pop 就 pop,否则跳到 fallbackTab 路由。
void goBack(BuildContext context, {String fallbackTab = '/settings'}) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallbackTab);
  }
}
