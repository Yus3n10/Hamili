import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/session/session_provider.dart';
import '../../auth/presentation/auth_providers.dart';

/// The current account's profile picture as a base64 PNG (or null). Stored
/// per-account in the 'avatars' Hive box — a lightweight, device-local
/// avatar (no backend image storage needed). Keyed by user id so multiple
/// accounts on one device keep separate pictures.
class AvatarNotifier extends Notifier<String?> {
  static const _boxName = 'avatars';

  String _keyFor(int userId) => 'u$userId';

  @override
  String? build() {
    ref.watch(sessionIdProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return null;
    return Hive.box<String>(_boxName).get(_keyFor(user.id));
  }

  Future<void> setAvatar(String base64Png) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    await Hive.box<String>(_boxName).put(_keyFor(user.id), base64Png);
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    await Hive.box<String>(_boxName).delete(_keyFor(user.id));
    ref.invalidateSelf();
  }
}

final avatarProvider = NotifierProvider<AvatarNotifier, String?>(AvatarNotifier.new);
