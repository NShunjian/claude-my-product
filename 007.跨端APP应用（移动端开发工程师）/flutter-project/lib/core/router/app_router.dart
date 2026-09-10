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

    // ponytail: 纯 Stack 重构 — navigationShell 占全屏永远在底层,nav bar
    //          用 Positioned 钉底永远在第二层,QuickAddModal 用 Positioned.fill
    //          在第三层(顶层)。QuickAddModal 关闭时(内部 AnimatedSwitcher
    //          SizedBox.shrink)不占任何空间,nav bar 自然可见;打开时 navy
    //          全屏覆盖 nav bar + body。Stack children 互不影响 layout,所以
    //          弹窗弹起时 navigationShell 高度恒定,ListView 视口不变,无
    //          "页面上滑"。picker / showDialog 是 modal route,在 Navigator
    //          之上自动覆盖一切(包括 nav bar)。
    return Stack(
      fit: StackFit.expand,
      children: [
        navigationShell,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // ponytail: NavigationBarTheme.elevation = 0 是关键 — M3 NavigationBar
          //          的 elevation 是 scroll-aware 的(由 NavigationBarThemeData
          //          提供),滚动离开顶部时自动从 0 涨到 3 + 加 surface tint,
          //          表现为底色变深。强制 elevation: 0 + transparent tint →
          //          滚动时 nav bar 视觉完全静止。同时把所有视觉属性放到
          //          NavigationBarTheme,内层 NavigationBar 不再重复声明。
          child: SafeArea(
            top: false,
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
                child: NavigationBarTheme(
              data: NavigationBarThemeData(
                elevation: 0,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              ),
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (i) {
                  // ponytail: 切 tabbar 触发对应页重拉。page 端 initState 用
                  //          ref.listenManual 监听自己 index 的 provider,next>prev
                  //          时调 _load()。初始 0 不触发,首次切换 +1 才重拉。
                  ref.read(tabRefreshSignalProvider(i).notifier).state++;
                  navigationShell.goBranch(
                    i,
                    initialLocation: i == navigationShell.currentIndex,
                  );
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(
                      Icons.home_outlined,
                      color: Color(0xFF5F6368),
                    ),
                    selectedIcon: const Icon(
                      Icons.home,
                      color: Color(0xFF2E7DE6),
                    ),
                    label: lang.t('tabbar.home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(
                      Icons.list_alt_outlined,
                      color: Color(0xFF5F6368),
                    ),
                    selectedIcon: const Icon(
                      Icons.list_alt,
                      color: Color(0xFF2E7DE6),
                    ),
                    label: lang.t('tabbar.transactions'),
                  ),
                  NavigationDestination(
                    icon: const Icon(
                      Icons.bar_chart_outlined,
                      color: Color(0xFF5F6368),
                    ),
                    selectedIcon: const Icon(
                      Icons.bar_chart,
                      color: Color(0xFF2E7DE6),
                    ),
                    label: lang.t('tabbar.reports'),
                  ),
                  NavigationDestination(
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF5F6368),
                    ),
                    selectedIcon: const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFF2E7DE6),
                    ),
                    label: lang.t('tabbar.accounts'),
                  ),
                  NavigationDestination(
                    icon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF5F6368),
                    ),
                    selectedIcon: const Icon(
                      Icons.person,
                      color: Color(0xFF2E7DE6),
                    ),
                    label: lang.t('tabbar.settings'),
                  ),
                ],
              ),
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
