import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Holds the user's theme preference (System / Light / Dark), persisted in
/// the `app_settings` Hive box so it survives app restarts. This is a
/// device-level UI preference — deliberately NOT account-scoped, so it is
/// not cleared on logout/session reset.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _boxName = 'app_settings';
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    // The box is opened in main() before runApp, so this read is synchronous.
    return _decode(Hive.box<String>(_boxName).get(_key));
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    Hive.box<String>(_boxName).put(_key, _encode(mode));
  }

  ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
