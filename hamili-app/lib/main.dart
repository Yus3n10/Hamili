import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/network/offline_queue.dart';
import 'core/routing/app_router.dart';
import 'core/theme/accent_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('app_settings');
  await Hive.openBox<String>('avatars');
  await OfflineQueue.instance.init();

  runApp(const ProviderScope(child: HamiliApp()));
}

class HamiliApp extends ConsumerWidget {
  const HamiliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentProvider);

    return MaterialApp.router(
      title: 'Hamili',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
