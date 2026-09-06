import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs.dart';

enum ThemeChoice { system, light, dark }

ThemeMode themeModeOf(ThemeChoice c) => switch (c) {
      ThemeChoice.system => ThemeMode.system,
      ThemeChoice.light => ThemeMode.light,
      ThemeChoice.dark => ThemeMode.dark,
    };

class ThemeController extends Notifier<ThemeChoice> {
  @override
  ThemeChoice build() => ThemeChoice.system;

  Future<void> hydrate() async {
    final p = await Prefs.getInstance();
    final v = p.themeMode;
    state = switch (v) {
      'light' => ThemeChoice.light,
      'dark' => ThemeChoice.dark,
      _ => ThemeChoice.system,
    };
  }

  Future<void> setMode(ThemeChoice c) async {
    state = c;
    final p = await Prefs.getInstance();
    await p.setThemeMode(c.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeChoice>(ThemeController.new);
