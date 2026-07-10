// lib/main.dart
// Fixed: dark mode now works for lender and rider mobile roles.
// Fixed: PushNotificationService router is wired up after router creation
//        so notification taps navigate correctly to notifications screen.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/web_theme.dart';
import 'core/theme/mobile_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/services/push_notification_service.dart';
import 'shared/models/app_user.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: SupabaseConstants.projectUrl,
    publishableKey: SupabaseConstants.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await PushNotificationService.instance.initialize();

  runApp(const ProviderScope(child: JiretaApp()));
}

class JiretaApp extends ConsumerWidget {
  const JiretaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authProvider);
    final role = authState.role;

    // FIX: Wire router into PushNotificationService so notification taps can
    // navigate without a BuildContext (singleton service has no access to context).
    PushNotificationService.instance.setRouter(router);

    return MaterialApp.router(
      title: 'Jireta Loans',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme(role),
      darkTheme: _darkTheme(role),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  ThemeData _lightTheme(UserRole? role) {
    if (role == UserRole.rider) return MobileTheme.riderLight();
    if (role == UserRole.lender) return MobileTheme.lenderLight();
    return WebTheme.light();
  }

  ThemeData _darkTheme(UserRole? role) {
    if (role == UserRole.rider) return MobileTheme.riderDark();
    if (role == UserRole.lender) return MobileTheme.lenderDark();
    return WebTheme.dark();
  }
}