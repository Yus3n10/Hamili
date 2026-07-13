import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/budgets/presentation/budgets_page.dart';
import '../../features/chat/presentation/hami_chat_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/profile/presentation/more_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/recurring/presentation/recurring_page.dart';
import '../../features/transactions/presentation/transactions_page.dart';
import '../../shared/widgets/main_shell.dart';


class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AsyncValue<dynamic>>(currentUserProvider, (_, __) => notifyListeners());
  }
}


final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authState = ref.read(currentUserProvider);
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute && !authState.isLoading) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', pageBuilder: (c, s) => _fade(const LoginPage(), s)),
      GoRoute(path: '/register', pageBuilder: (c, s) => _fade(const RegisterPage(), s)),
      GoRoute(path: '/onboarding', pageBuilder: (c, s) => _fade(const OnboardingPage(), s)),
      GoRoute(path: '/budgets', pageBuilder: (c, s) => _slideFade(const BudgetsPage(), s)),
      GoRoute(path: '/goals', pageBuilder: (c, s) => _slideFade(const GoalsPage(), s)),
      GoRoute(path: '/recurring', pageBuilder: (c, s) => _slideFade(const RecurringPage(), s)),
      GoRoute(path: '/profile', pageBuilder: (c, s) => _slideFade(const ProfilePage(), s)),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/transactions', builder: (context, state) => const TransactionsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (context, state) => const HamiChatPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/more', builder: (context, state) => const MorePage()),
          ]),
        ],
      ),
    ],
  );
});


CustomTransitionPage<void> _slideFade(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}


CustomTransitionPage<void> _fade(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}
