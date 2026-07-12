import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/data/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter(); // local/offline cache — boxes registered per-feature as they're added

  // Security: never auto-resume a previous session. Every cold start of
  // the app (including a web page refresh) clears any stored token so the
  // user always begins at the login screen and must re-authenticate.
  await AuthRepository().clearStoredSession();

  runApp(const ProviderScope(child: HamiliApp()));
}

class HamiliApp extends ConsumerWidget {
  const HamiliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Hamili',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
