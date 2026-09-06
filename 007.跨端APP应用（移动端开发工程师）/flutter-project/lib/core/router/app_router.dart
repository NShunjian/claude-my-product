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
import '../../features/records/record_expense_screen.dart';
import '../../features/records/record_income_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shared/auth_controller.dart';
import '../../features/shared/quick_add_controller.dart';
import '../../features/transactions/transactions_screen.dart';
import '../i18n/locale_provider.dart';
import '../utils/modal_state.dart';

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

    // QuickAdd / 通用 modal 打开时,隐藏底部 tabBar。
    final quickAddOpen = ref.watch(
      quickAddControllerProvider.select((s) => s.show),
    );
    final genericModalOpen = ref.watch(modalOpenProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: (quickAddOpen || genericModalOpen)
          ? const SizedBox.shrink()
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: lang.t('tabbar.home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.list_alt_outlined),
                  selectedIcon: const Icon(Icons.list_alt),
                  label: lang.t('tabbar.transactions'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  selectedIcon: const Icon(Icons.bar_chart),
                  label: lang.t('tabbar.reports'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: const Icon(Icons.account_balance_wallet),
                  label: lang.t('tabbar.accounts'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: lang.t('tabbar.settings'),
                ),
              ],
            ),
    );
  }
}
