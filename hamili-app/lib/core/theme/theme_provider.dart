import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';


class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _boxName = 'app_settings';
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {

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
      case 'system':
        return ThemeMode.system;


      default:
        return ThemeMode.dark;
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
