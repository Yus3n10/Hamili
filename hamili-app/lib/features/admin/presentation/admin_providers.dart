import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

// autoDispose throughout: tester details are dropped from memory as soon as
// the console is closed, and nothing here is cached to disk.
final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository());

final adminOverviewProvider = FutureProvider.autoDispose<AdminOverview>(
  (ref) => ref.read(adminRepositoryProvider).overview(),
);

final adminSearchProvider = StateProvider.autoDispose<String>((ref) => '');

const adminSorts = {
  'last_active': 'Last active',
  'joined': 'Newest',
  'hami_tokens': 'Most Hami use',
  'name': 'Name',
};

final adminSortProvider = StateProvider.autoDispose<String>((ref) => 'last_active');

final adminTestersProvider = FutureProvider.autoDispose<AdminTesterPage>((ref) {
  final search = ref.watch(adminSearchProvider);
  final sort = ref.watch(adminSortProvider);
  return ref.read(adminRepositoryProvider).testers(search: search, sort: sort);
});

final adminAccessLogProvider = FutureProvider.autoDispose<List<AdminAccessEntry>>(
  (ref) => ref.read(adminRepositoryProvider).accessLog(),
);
