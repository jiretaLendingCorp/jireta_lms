// lib/main.dart

import 'package:flutter/material.dart';
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

  await Supabase.initialize(
    url: SupabaseConstants.projectUrl,
    publishableKey: SupabaseConstants.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Degrades gracefully if Firebase hasn't been configured yet — see
  // SETUP_THIRD_PARTY.md for the flutterfire configure steps.
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
    if (role == UserRole.rider) return MobileTheme.rider();
    if (role == UserRole.lender) return MobileTheme.lender();
    return WebTheme.light();
  }

  ThemeData _darkTheme(UserRole? role) {
    if (role == UserRole.rider) return MobileTheme.rider();
    if (role == UserRole.lender) return MobileTheme.lender();
    return WebTheme.dark();
  }
}