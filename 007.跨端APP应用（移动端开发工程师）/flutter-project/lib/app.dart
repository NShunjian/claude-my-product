import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/theme_controller.dart';
import 'features/shared/toast.dart';

class QingZhangApp extends ConsumerWidget {
  const QingZhangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeChoice = ref.watch(themeControllerProvider);
    final lang = ref.watch(languageProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // ponytail: 2026-09-12 — Android 系统手势导航背板默认黑色,在 MobileTabBar
      //   下方露出 ~30dp 黑条。改成白色 + 图标深色,白底跟 tabbar 连成一片,
      //   黑条消失。`systemNavigationBar*` 字段 Android only,iOS / Web / Desktop
      //   运行时零变化(Apple home indicator 透明 + 无背板,Web/Desktop 没系统导航)。
      //   状态栏顺便设 transparent + 深色图标,跟 Light 主题一致。
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp.router(
        title: 'QingZhang',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeModeOf(themeChoice),
        routerConfig: router,
        locale: localeOf(lang),
        supportedLocales: const [Locale('en'), Locale('zh'), Locale('zh', 'TW')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // ponytail: 2026-09-12 — 关掉 Android 的过滚动"拉伸 + 边缘 glow"。
        //   原理:MaterialApp.scrollBehavior 是 Flutter 3.16+ 官方给 ScrollBehavior
        //          的全局注入入口,**不**包 Navigator、不动 widget 树、不动数据通路
        //          (之前 builder 里包 ScrollConfiguration 把首页搞空白就是因为
        //          切断了 Navigator/Overlay 的 inherited widget 路径)。
        //   只覆盖 buildOverscrollIndicator 把 glow 节点直接返回 child 本体,
        //          physics 沿用 MaterialScrollBehavior 的平台默认 —— Android =
        //          ClampingScrollPhysics(不弹回、不拉伸内容),iOS = BouncingScrollPhysics
        //          (回弹,无 glow)。
        scrollBehavior: const _NoOverscrollMaterialBehavior(),
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (child != null) child,
              // QuickAddModal 必须放进路由 Navigator 之内(_TabScaffold.body Stack),
              // 否则它和 child 平级、Navigator 在 child 里,showDatePicker
              // 弹的对话框会被 Modal 盖住看不见 — 见 app_router.dart 里 _TabScaffold。
              const Positioned.fill(child: IgnorePointer(child: ToastHost())),
            ],
          );
        },
      ),
    );
  }
}

// ponytail: 2026-09-12 — 关掉 Android 上的过滚动效果。
//   buildOverscrollIndicator 默认在边界拖动时会包一层 GlowingOverscrollIndicator
//   (Android 平台才是),返回 child 直接吃掉这一层,等于"光过滚动效果消失"。
//   物理沿用父类:Android = ClampingScrollPhysics(到边界立刻钳住,无弹性);
//               iOS = BouncingScrollPhysics(回弹),但 iOS 用 CupertinoScrollBehavior
//               不会被这里覆盖。
class _NoOverscrollMaterialBehavior extends MaterialScrollBehavior {
  const _NoOverscrollMaterialBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}