import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/account_new_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/profile_edit_screen.dart';
import '../../features/books/book_members_screen.dart';
import '../../features/books/books_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/quick_add_modal.dart';
import '../../features/records/record_expense_screen.dart';
import '../../features/records/record_income_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shared/auth_controller.dart';
import '../../features/shared/custom_tab_bar.dart';
import '../../features/transactions/transactions_screen.dart';
import '../i18n/locale_provider.dart';
import '../utils/modal_state.dart';
import '../utils/tab_refresh_signal.dart';

/// 路由表 — 对齐 pages.json + 5 tabBar + 7 stack 路由。
class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const transactions = '/transactions';
  static const reports = '/reports';
  static const accounts = '/accounts';
  static const settings = '/settings';
  static const recordExpense = '/record/expense';
  static const recordIncome = '/record/income';
  static const accountNew = '/accounts/new';
  static const books = '/books';
  static const bookMembers = '/books/members';
  static const profileEdit = '/profile/edit';
}

/// 全局 NavigatorKey — QuickAddModal 用 showDialog 弹出。
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// router 单例。
final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggedIn = auth.isLoggedIn;
      final goingToLogin = state.matchedLocation == AppRoutes.login;
      if (!loggedIn && !goingToLogin) return AppRoutes.login;
      if (loggedIn && goingToLogin) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.recordExpense,
        builder: (context, state) => const RecordExpenseScreen(),
      ),
      GoRoute(
        path: AppRoutes.recordIncome,
        builder: (context, state) => const RecordIncomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountNew,
        builder: (context, state) => const AccountNewScreen(),
      ),
      GoRoute(
        path: AppRoutes.books,
        builder: (context, state) => const BooksScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookMembers,
        builder: (context, state) {
          final uuid = state.uri.queryParameters['id'] ?? '';
          return BookMembersScreen(bookUuid: uuid);
        },
      ),
      // ===== 5 个 tabBar 路由(用 ShellRoute 共享 BottomNav) =====
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _TabScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.transactions,
              builder: (context, state) => const TransactionsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.reports,
              builder: (context, state) => const ReportsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.accounts,
              builder: (context, state) => const AccountsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

class _TabScaffold extends ConsumerWidget {
  const _TabScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = I18n.of(context);
    // ponytail: 弹窗弹起时把 nav bar 隐藏(opacity 0 + IgnorePointer),让
    //          35% picker 视觉上贴底不"悬空"。modalOpenProvider 在
    //          _showOptionSheet 入口设 true,finally 设 false 保证恢复。
    final modalOpen = ref.watch(modalOpenProvider);

    // ponytail: 三端区分 — mobile 端 tab bar content = 57dp(总视觉高
    //          = 57 + 34 safeArea = 91dp,用户 2026-09-12 指定);
    //          desktop/web 维持 80。
    //          参见 [[three-platform-must-specify-target]]。
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final tabBarHeight = isMobile ? 57.0 : 80.0;

    // ponytail: tab bar 背景色统一白色(用户撤销了 iOS 端红色)。
    const tabBarBgColor = Colors.white;

    // ponytail: 纯 Stack 重构 — navigationShell 占全屏永远在底层,nav bar
    //          用 Positioned 钉底永远在第二层,QuickAddModal 用 Positioned.fill
    //          在第三层(顶层)。QuickAddModal 关闭时(内部 AnimatedSwitcher
    //          SizedBox.shrink)不占任何空间,nav bar 自然可见;打开时 navy
    //          全屏覆盖 nav bar + body。Stack children 互不影响 layout,所以
    //          弹窗弹起时 navigationShell 高度恒定,ListView 视口不变,无
    //          "页面上滑"。picker / showDialog 是 modal route,在 Navigator
    //          之上自动覆盖一切(包括 nav bar)。
    //
    // ponytail: 纯 Stack 重构 — navigationShell 占全屏永远在底层,nav bar
    //          用 Positioned 钉底永远在第二层,QuickAddModal 用 Positioned.fill
    //          在第三层(顶层)。QuickAddModal 关闭时(内部 AnimatedSwitcher
    //          SizedBox.shrink)不占任何空间,nav bar 自然可见;打开时 navy
    //          全屏覆盖 nav bar + body。Stack children 互不影响 layout,所以
    //          弹窗弹起时 navigationShell 高度恒定,ListView 视口不变,无
    //          "页面上滑"。picker / showDialog 是 modal route,在 Navigator
    //          之上自动覆盖一切(包括 nav bar)。
    //
    // ponytail: NavigationBar 自己吃 MediaQuery.padding.bottom(iOS home
    //          indicator 区)然后把 backgroundColor 画到 safeArea 底 — 这是
    //          Material spec,不要外面再包 SafeArea。所以 tab bar 视觉区总
    //          高度 = tabBarHeight + safeArea.bottom,Padding bottom 也用
    //          tabBarHeight + safeArea.bottom(否则 navigationShell 内容底部
    //          会被 NavigationBar 遮挡)。
    //          注意:这里和 NavigationBar 内部的 safeArea 处理**没有重复计算**
    //          —— Padding 是 navigationShell 自己要留的 layout 区(避遮挡),
    //          NavigationBar 内部 SafeArea 是它自己绘制时吃的(画到屏幕底)。
    return Stack(
      fit: StackFit.expand,
      children: [
        // ponytail: navigationShell 用 Padding 留出 tab bar 区 — tabBarHeight
        //          + safeArea.bottom(因为 NavigationBar 内部 SafeArea 让
        //          NavigationBar 画到 home indicator 底部,所以留白也要
        //          等高,否则 content 被遮挡)。
        Padding(
          padding: EdgeInsets.only(
            bottom: tabBarHeight + MediaQuery.of(context).padding.bottom,
          ),
          child: navigationShell,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // ponytail: SafeArea 放到 NavigationBarTheme 内部 — 这样
          //          NavigationBar 的 backgroundColor(白)会跟着 safeArea
          //          一起画到屏幕底部,home indicator 区域也是白的。
          //          如果 SafeArea 放在外层包 NavigationBar,外层 SafeArea
          //          的留白区在 Stack 里是透出 Cupertino 黑底,iOS 真机
          //          底部 home indicator 区会出现一条黑色横条。
          child: AnimatedOpacity(
            // ponytail: 弹窗弹起时把 nav bar 隐藏(opacity 0 + IgnorePointer),
            //          让 35% picker 视觉上贴底不"悬空"。modalOpenProvider
            //          在 _showOptionSheet 入口设 true,finally 设 false
            //          保证 dismiss 后 nav bar 恢复。150ms 跟 modal 弹起的
            //          默认动画对齐,用户感觉不到过渡。
            opacity: modalOpen ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: modalOpen,
              // ponytail: 三端区分 — mobile (iOS/Android) 用自定 MobileTabBar
              //          (见 [[custom_tab_bar.dart]]);Web / Desktop 继续用
              //          Material NavigationBar(80dp)。参见 [[three-platform-must-specify-target]]。
              child: isMobile
                  ? MobileTabBar(
                      currentIndex: navigationShell.currentIndex,
                      onTap: (i) {
                        // ponytail: 切 tabbar 触发对应页重拉。page 端 initState 用
                        //          ref.listenManual 监听自己 index 的 provider,next>prev
                        //          时调 _load()。初始 0 不触发,首次切换 +1 才重拉。
                        ref.read(tabRefreshSignalProvider(i).notifier).state++;
                        navigationShell.goBranch(
                          i,
                          initialLocation: i == navigationShell.currentIndex,
                        );
                      },
                    )
                  : NavigationBarTheme(
                      data: NavigationBarThemeData(
                        height: tabBarHeight,
                        elevation: 0,
                        backgroundColor: tabBarBgColor,
                        surfaceTintColor: Colors.transparent,
                        indicatorColor: Colors.transparent,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                      ),
                      child: NavigationBar(
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: (i) {
                          ref.read(tabRefreshSignalProvider(i).notifier).state++;
                          navigationShell.goBranch(
                            i,
                            initialLocation: i == navigationShell.currentIndex,
                          );
                        },
                        destinations: [
                          // ponytail: tabbar 图标用 uniapp 那套 PNG(对齐 1:1)。
                          // Material Icons 风格跟 uniapp 自定义 PNG 视觉差太多,
                          // uniapp 截图里是线条房子 / 清单 / 报表 / 账户 / 小人,
                          // Flutter 之前 home/list_alt 跟它不像。直接 asset tab PNG。
                          NavigationDestination(
                            icon: Image.asset(
                              'assets/tabbar/home.png',
                              width: 24,
                              height: 24,
                            ),
                            selectedIcon: Image.asset(
                              'assets/tabbar/home_active.png',
                              width: 24,
                              height: 24,
                            ),
                            label: lang.t('tabbar.home'),
                          ),
                          NavigationDestination(
                            icon: Image.asset(
                              'assets/tabbar/transactions.png',
                              width: 24,
                              height: 24,
                            ),
                            selectedIcon: Image.asset(
                              'assets/tabbar/transactions_active.png',
                              width: 24,
                              height: 24,
                            ),
                            label: lang.t('tabbar.transactions'),
                          ),
                          NavigationDestination(
                            icon: Image.asset(
                              'assets/tabbar/reports.png',
                              width: 24,
                              height: 24,
                            ),
                            selectedIcon: Image.asset(
                              'assets/tabbar/reports_active.png',
                              width: 24,
                              height: 24,
                            ),
                            label: lang.t('tabbar.reports'),
                          ),
                          NavigationDestination(
                            icon: Image.asset(
                              'assets/tabbar/accounts.png',
                              width: 24,
                              height: 24,
                            ),
                            selectedIcon: Image.asset(
                              'assets/tabbar/accounts_active.png',
                              width: 24,
                              height: 24,
                            ),
                            label: lang.t('tabbar.accounts'),
                          ),
                          NavigationDestination(
                            icon: Image.asset(
                              'assets/tabbar/settings.png',
                              width: 24,
                              height: 24,
                            ),
                            selectedIcon: Image.asset(
                              'assets/tabbar/settings_active.png',
                              width: 24,
                              height: 24,
                            ),
                            label: lang.t('tabbar.settings'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const Positioned.fill(child: QuickAddModal()),
      ],
    );
  }
}
