import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_queue.dart';
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
    AppUser? user;
    try {
      user = await repo.getCurrentUser();
      await repo.cacheUser(user);
    } on DioException catch (e) {
      // A 401 here means the refresh token was refused too. Anything else
      // (offline, timeout, 5xx cold start) resumes the last signed-in user.
      if (e.response?.statusCode == 401) {
        await repo.clearCachedUser();
        return null;
      }
      user = await repo.cachedUser();
    } catch (_) {
      user = await repo.cachedUser();
    }
    if (user != null) {
      await OfflineQueue.instance.beginSession(user.id, restored: true);
    }
    return user;
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    OfflineQueue.instance.suspend();
    final repo = ref.read(authRepositoryProvider);
    await repo.login(email: email, password: password);
    final user = await repo.getCurrentUser();
    await repo.cacheUser(user);
    await OfflineQueue.instance.beginSession(user.id, restored: false);
    state = AsyncData(user);
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
    await ref.read(authRepositoryProvider).cacheUser(updated);
    state = AsyncData(updated);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    await ref.read(authRepositoryProvider).clearCachedUser();
    await OfflineQueue.instance.endSession();


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
