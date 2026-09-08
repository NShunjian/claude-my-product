import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/api_base_url.dart';
import 'core/api/api_client.dart';
import 'core/i18n/lang.dart';
import 'core/i18n/locale_provider.dart';
import 'core/storage/prefs.dart';
import 'features/shared/auth_controller.dart';
import 'features/shared/book_controller.dart';
import 'features/shared/providers.dart';
import 'features/shared/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await Prefs.getInstance();
  // Web 上从 window.location.hostname 推 baseUrl,保证手机走 LAN IP 时也能命中后端。
  final apiBaseUrl = resolveApiBaseUrl('http://localhost:4001');
  final apiClient = ApiClient(baseUrl: apiBaseUrl, prefs: prefs);

  // 从 prefs 初始化 Lang 起始值(避免 build() 里的固定初值被冲掉)。
  final initialLang = langFromCode(prefs.lang);

  runApp(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      prefsProvider.overrideWithValue(prefs),
    ],
    child: _Bootstrap(initialLang: initialLang),
  ));
}

class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap({required this.initialLang});
  final Lang initialLang;

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(languageProvider.notifier).hydrate(widget.initialLang);
      await ref.read(themeControllerProvider.notifier).hydrate();
      await ref.read(authControllerProvider.notifier).hydrate();
      await ref.read(bookControllerProvider.notifier).hydrate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const QingZhangApp();
  }
}