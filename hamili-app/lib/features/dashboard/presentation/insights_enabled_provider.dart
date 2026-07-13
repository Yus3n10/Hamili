import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';


class InsightsEnabledNotifier extends Notifier<bool> {
  static const _boxName = 'app_settings';
  static const _key = 'insights_enabled';

  @override
  bool build() {

    return Hive.box<String>(_boxName).get(_key) != 'off';
  }

  void setEnabled(bool enabled) {
    state = enabled;
    Hive.box<String>(_boxName).put(_key, enabled ? 'on' : 'off');
  }
}

final insightsEnabledProvider =
    NotifierProvider<InsightsEnabledNotifier, bool>(InsightsEnabledNotifier.new);
