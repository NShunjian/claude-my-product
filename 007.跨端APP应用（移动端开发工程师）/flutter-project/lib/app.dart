import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/home/quick_add_modal.dart';
import 'features/shared/theme_controller.dart';
import 'features/shared/toast.dart';

class QingZhangApp extends ConsumerWidget {
  const QingZhangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeChoice = ref.watch(themeControllerProvider);
    final lang = ref.watch(languageProvider);

    return MaterialApp.router(
      title: 'QingZhang',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeOf(themeChoice),
      routerConfig: router,
      locale: localeOf(lang),
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('zh', 'TW')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            const Positioned.fill(child: QuickAddModal()),
            const Positioned.fill(child: IgnorePointer(child: ToastHost())),
          ],
        );
      },
    );
  }
}