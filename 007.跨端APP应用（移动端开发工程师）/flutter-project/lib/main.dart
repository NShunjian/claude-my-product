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
  ),);
}

class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap({required this.initialLang});
  final Lang initialLang;

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        ref.read(languageProvider.notifier).hydrate(widget.initialLang);
        await ref.read(themeControllerProvider.notifier).hydrate();
        await ref.read(authControllerProvider.notifier).hydrate();
        await ref.read(bookControllerProvider.notifier).hydrate();
      } catch (_) {
        // ponytail: 即使 hydrate 失败也放行 UI,否则 splash 永远转圈、
        //          用户连登录页都进不去。
      }
      if (mounted) setState(() => _hydrated = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ponytail: 启动期 auth state 还没就绪时,不能挂路由 —— router 的 redirect
    //          读到的 isLoggedIn 是默认值 false,会先渲染 LoginScreen 再被
    //          hydrate 后的 _AuthListenable 推回去,导致"闪一下登录页"。
    //          用一个最小 splash 占位,hydrate 完成再切到 QingZhangApp。
    if (!_hydrated) {
      // ponytail: 启动页 —— brand 色背景 + wallet 图标 + app 名 + 小转圈,
      //          hydrate 完成前占位,避免默认白底 + 之后被 QingZhangApp 主题色替换时
      //          看起来"白屏闪一下"。色值用 AppColors.light.primary 同源,不要
      //          再 import tokens(保持 splash 自包含,hydrate 完就 unmount)。
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF2E7DE6),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x33FFFFFF), // 18% 白
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'QingZhang',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const QingZhangApp();
  }
}
