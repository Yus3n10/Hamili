import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'accent_palette.dart';


class AccentNotifier extends Notifier<AppAccent> {
  static const _boxName = 'app_settings';
  static const _key = 'accent';

  @override
  AppAccent build() {
    final name = Hive.box<String>(_boxName).get(_key);
    return appAccents.firstWhere((a) => a.name == name, orElse: () => defaultAccent);
  }

  void setAccent(AppAccent accent) {
    state = accent;
    Hive.box<String>(_boxName).put(_key, accent.name);
  }
}

final accentProvider = NotifierProvider<AccentNotifier, AppAccent>(AccentNotifier.new);
