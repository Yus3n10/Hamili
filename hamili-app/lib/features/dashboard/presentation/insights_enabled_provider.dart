import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Whether the dashboard's AI insights card is shown and fetched. Device-level
/// (stored in `app_settings` like the theme preference), so it survives logout
/// and is deliberately not account-scoped. When off, no insight Gemini call is
/// made. Defaults to on.
class InsightsEnabledNotifier extends Notifier<bool> {
  static const _boxName = 'app_settings';
  static const _key = 'insights_enabled';

  @override
  bool build() {
    // Box is opened in main() before runApp — synchronous read.
    return Hive.box<String>(_boxName).get(_key) != 'off';
  }

  void setEnabled(bool enabled) {
    state = enabled;
    Hive.box<String>(_boxName).put(_key, enabled ? 'on' : 'off');
  }
}

final insightsEnabledProvider =
    NotifierProvider<InsightsEnabledNotifier, bool>(InsightsEnabledNotifier.new);
