import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_queue.dart';

// Watched by user-data providers so they refetch once queued writes sync.
final offlineSyncProvider = Provider<int>((ref) {
  final revision = OfflineQueue.instance.syncRevision;
  void onSync() => ref.invalidateSelf();
  revision.addListener(onSync);
  ref.onDispose(() => revision.removeListener(onSync));
  return revision.value;
});
