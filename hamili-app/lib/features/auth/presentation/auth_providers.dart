import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../recurring/presentation/recurring_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());


class CurrentUserNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final repo = ref.read(authRepositoryProvider);
    if (!await repo.hasStoredSession()) return null;
    try {
      return await repo.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    await repo.login(email: email, password: password);
    state = AsyncData(await repo.getCurrentUser());
    _startNewSession();
  }


  Future<void> updateProfile({
    String? preferredName,
    String? preferredCurrency,
    String? financialGoalText,
  }) async {
    final updated = await ref.read(authRepositoryProvider).updateProfile(
          preferredName: preferredName,
          preferredCurrency: preferredCurrency,
          financialGoalText: financialGoalText,
        );
    state = AsyncData(updated);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();


    await ref.read(transactionRepositoryProvider).clearCache();
    await ref.read(recurringRepositoryProvider).clearCache();
    await ref.read(budgetRepositoryProvider).clearCache();
    await ref.read(goalRepositoryProvider).clearCache();
    state = const AsyncData(null);
    _startNewSession();
  }


  void _startNewSession() {
    ref.read(sessionIdProvider.notifier).state++;
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, AppUser?>(
  CurrentUserNotifier.new,
);
