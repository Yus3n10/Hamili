import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Holds the logged-in user (or null). Every screen that needs
/// personalization — dashboard greeting, chat context, profile — reads
/// this instead of re-fetching /auth/me itself.
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

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    // Offline cache is keyed globally, not per-account — clear it so a
    // second account on the same device can't see the first account's
    // cached transactions before its own first successful fetch.
    await ref.read(transactionRepositoryProvider).clearCache();
    state = const AsyncData(null);
    _startNewSession();
  }

  /// Bumping this single value is the ONLY reset step needed — every
  /// user-scoped provider (transactions, budgets, goals, chat, and
  /// anything added later) watches sessionIdProvider as the first line
  /// of its build, so this one increment tears down and refetches all
  /// of them. This replaces a manually maintained list of providers to
  /// invalidate, which is easy to leave one off of as the app grows.
  void _startNewSession() {
    ref.read(sessionIdProvider.notifier).state++;
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, AppUser?>(
  CurrentUserNotifier.new,
);
