import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped on every login and logout. Every provider that holds
/// account-specific data (transactions, budgets, goals, chat, and any
/// future feature) should `ref.watch(sessionIdProvider)` as the first
/// line of its build — that single dependency means changing accounts
/// automatically tears down and refetches ALL of them, without needing
/// a manually maintained "don't forget to invalidate this" list that's
/// easy to leave a provider off of as the app grows.
final sessionIdProvider = StateProvider<int>((ref) => 0);
