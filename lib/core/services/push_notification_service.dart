// lib/core/services/push_notification_service.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import '../network/api_endpoints.dart';

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
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

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

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[PushNotificationService] Notification tapped: ${message.data}');
    // Deep-link routing based on message.data['type'] and reference ids can be
    // wired into go_router here once specific in-app destinations are required.
  }

  String _currentPlatform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}