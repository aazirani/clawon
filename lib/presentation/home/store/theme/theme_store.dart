import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_store.g.dart';

class ThemeStore = _ThemeStore with _$ThemeStore;

abstract class _ThemeStore with Store {
  static const String _themeModeKey = 'theme_mode';

  final SharedPreferences _prefs;

  _ThemeStore(this._prefs) {
    _loadThemeMode();
  }

  @observable
  ThemeMode themeMode = ThemeMode.system;

  @action
  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs.setString(_themeModeKey, mode.name);
  }

  void _loadThemeMode() {
    final stored = _prefs.getString(_themeModeKey);
    if (stored != null) {
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
    }
  }
}
