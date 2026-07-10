// lib/core/services/push_notification_service.dart
// Fixed: notification tap now routes to the correct in-app screen instead
// of doing nothing (previously _handleNotificationTap was a no-op).
// Routing is role-aware: rider → /rider/notifications,
//                         lender → /lender/alerts,
//                         hm/emp → /hm/notifications or /emp/notifications

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../network/dio_client.dart';
import '../network/api_endpoints.dart';
import '../constants/route_constants.dart';

/// Wraps Firebase Cloud Messaging setup for the Jireta Loans app.
///
/// IMPORTANT: This service degrades gracefully when Firebase has not been
/// configured for this project yet (no `firebase_options.dart`, no
/// `google-services.json` / `GoogleService-Info.plist`). Push notifications
/// simply won't be delivered until the project owner runs
/// `flutterfire configure` and adds the platform config files — see
/// SETUP_THIRD_PARTY.md at the project root for the exact steps.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  bool get isAvailable => _initialized;

  /// Optional router reference set by the app so notification taps can
  /// navigate without a BuildContext.
  GoRouter? _router;

  /// Call once from main() or from the root widget after router is created.
  void setRouter(GoRouter router) {
    _router = router;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint(
        '[PushNotificationService] Firebase not configured yet — '
        'push notifications disabled. Run `flutterfire configure` and add '
        'google-services.json / GoogleService-Info.plist. Error: $e',
      );
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[PushNotificationService] User denied notification permission');
        return;
      }

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      // FIX: Properly route notification taps to notifications screen
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app was completely terminated
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[PushNotificationService] Initialization error: $e');
    }
  }

  /// Call after a successful login to register this device's token with the
  /// auth-profile/fcm-register Edge Function (via Dio — never direct FCM
  /// calls from the client; token storage and delivery logic both live
  /// server-side).
  Future<void> registerToken() async {
    if (!_initialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final platform = _currentPlatform();

      await DioClient.instance.post(
        ApiEndpoints.fcmRegister,
        data: {'token': token, 'platform': platform},
      );

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await DioClient.instance.post(
            ApiEndpoints.fcmRegister,
            data: {'token': newToken, 'platform': platform},
          );
        } catch (e) {
          debugPrint('[PushNotificationService] Token refresh registration failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[PushNotificationService] Token registration failed: $e');
    }
  }

  /// Call on sign-out to stop this device from receiving notifications
  /// intended for the now-logged-out user.
  Future<void> unregisterToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await DioClient.instance.post(
        ApiEndpoints.fcmUnregister,
        data: {if (token != null) 'token': token},
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Token unregistration failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '[PushNotificationService] Foreground message: '
      '${message.notification?.title} — ${message.notification?.body}',
    );
    // In-app toast/snackbar presentation is left to the screen-level
    // notification providers (hmNotificationsProvider, lenderNotificationsProvider,
    // etc.) which already poll/refresh from the notifications table.
  }

  /// FIX #6: Routes rider taps on the notification bell/push notification
  /// to the correct notifications screen based on the role embedded in
  /// the FCM data payload, or falls back to the current tab's notifications.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[PushNotificationService] Notification tapped: ${message.data}');

    final router = _router;
    if (router == null) return;

    final role = message.data['role'] as String?;
    final type = message.data['type'] as String?;

    // Deep-link to specific content when type is provided
    if (type == 'loan' && message.data['loan_id'] != null) {
      final loanId = message.data['loan_id'] as String;
      if (role == 'lender') {
        router.go('/lender/loans/$loanId');
        return;
      }
    }
    if (type == 'assignment' && message.data['assignment_id'] != null) {
      final assignId = message.data['assignment_id'] as String;
      router.go('/rider/assignments/$assignId');
      return;
    }

    // Default: navigate to role-specific notification screen
    switch (role) {
      case 'rider':
        router.go(RouteConstants.riderNotifications);
        break;
      case 'lender':
        router.go(RouteConstants.lenderAlerts);
        break;
      case 'head_manager':
        router.go(RouteConstants.hmNotifications);
        break;
      case 'employee':
        router.go(RouteConstants.empNotifications);
        break;
      default:
        // Unknown role — try to go to notifications based on current path
        final current = router.routerDelegate.currentConfiguration.uri.path;
        if (current.startsWith('/rider')) {
          router.go(RouteConstants.riderNotifications);
        } else if (current.startsWith('/lender')) {
          router.go(RouteConstants.lenderAlerts);
        } else if (current.startsWith('/hm')) {
          router.go(RouteConstants.hmNotifications);
        } else if (current.startsWith('/emp')) {
          router.go(RouteConstants.empNotifications);
        }
    }
  }

  String _currentPlatform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}