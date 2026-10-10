import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/config/app_config_provider.dart';
import '../core/storage/local_store.dart';
import '../features/notifications/application/diary_reminder_controller.dart';
import '../firebase_options.dart';
import '../theme/app_theme.dart';
import 'router/app_router.dart';

/// Boots the app with the given [config] (the flavor seam). `main.dart` passes
/// [AppConfig.dev]; `main_prod.dart` passes [AppConfig.prod].
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        localStoreProvider.overrideWithValue(LocalStore(prefs)),
      ],
      child: const OddoApp(),
    ),
  );
}

/// Root widget: wires the router + theme into [MaterialApp.router].
class OddoApp extends ConsumerStatefulWidget {
  const OddoApp({super.key});

  @override
  ConsumerState<OddoApp> createState() => _OddoAppState();
}

class _OddoAppState extends ConsumerState<OddoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !ref.read(diaryReminderControllerProvider).busy) {
      ref.invalidate(diaryReminderControllerProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final config = ref.watch(appConfigProvider);
    ref.watch(diaryReminderControllerProvider);

    return MaterialApp.router(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
