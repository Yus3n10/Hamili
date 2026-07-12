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

/// Bridges Riverpod's currentUserProvider to GoRouter's refreshListenable.
/// Without this, GoRouter only re-evaluates its redirect logic when
/// navigation happens — so logging out from a screen like "More" (which
/// doesn't itself navigate anywhere) would leave you stranded there
/// until you happened to tap a different tab. This makes login/logout
/// redirect immediately, the moment auth state changes.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AsyncValue<dynamic>>(currentUserProvider, (_, __) => notifyListeners());
  }
}

/// Route config lives in one file so the navigation graph is visible at a
/// glance. Each bottom-nav tab is its own StatefulShellBranch, which
/// preserves scroll position / state when switching tabs.
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
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingPage()),
      GoRoute(path: '/budgets', builder: (context, state) => const BudgetsPage()),
      GoRoute(path: '/goals', builder: (context, state) => const GoalsPage()),
      GoRoute(path: '/recurring', builder: (context, state) => const RecurringPage()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
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
