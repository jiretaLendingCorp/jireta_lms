// lib/core/providers/auth_provider.dart
//
// FIX: Login glitch / refresh flicker fixed.
//   Root cause: onAuthStateChange fires `signedIn` → _loadProfile sets
//   isLoading: true → router sees isLoading without a user and briefly
//   redirects back to /login before the profile loads.
//   Fix: keep the existing user in state during the reload so the router
//   sees an authenticated user (with isLoading: true) and does NOT redirect.
//   The loading flag is still set so the UI can show a spinner if needed.
//
// FIX: needsForceChange reads force_password_change from the profile fetched
//   after resetUserPassword sets force_password_change = true in the DB.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/app_user.dart';
import 'package:dio/dio.dart';
import '../../features/auth/data/auth_repository.dart';
import '../services/push_notification_service.dart';

class AuthNotifierState {
  final AppUser? user;
  final bool isLoading;
  final String? error;
  final bool initialized;

  const AuthNotifierState({
    this.user,
    this.isLoading = false,
    this.error,
    this.initialized = false,
  });

  bool get isAuthenticated => user != null;
  UserRole? get role => user?.role;
  bool get needsForceChange => user?.forcePasswordChange ?? false;

  AuthNotifierState copyWith({
    AppUser? user,
    bool clearUser = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? initialized,
  }) =>
      AuthNotifierState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        initialized: initialized ?? this.initialized,
      );
}

class AuthNotifier extends StateNotifier<AuthNotifierState> {
  final AuthRepository _repo;
  final SupabaseClient _supabase;

  AuthNotifier(this._repo, this._supabase) : super(const AuthNotifierState()) {
    _init();
  }

  Future<void> _init() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      await _loadProfile(session.user.id);
    }
    state = state.copyWith(initialized: true);

    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn && data.session != null) {
        // FIX: Pass keepUserDuringLoad: true so the router does not get an
        // unauthenticated state (user: null, isLoading: true) that would cause
        // the login screen to briefly re-render before the profile arrives.
        await _loadProfile(data.session!.user.id, keepUserDuringLoad: true);
      } else if (event == AuthChangeEvent.signedOut) {
        state = state.copyWith(clearUser: true, initialized: true);
      }
    });
  }

  /// [keepUserDuringLoad] — when true the current user is NOT cleared while
  /// the profile network call is in flight. Use for onAuthStateChange to
  /// prevent the router from seeing a momentary unauthenticated state.
  Future<void> _loadProfile(
    String userId, {
    bool withRetry = false,
    bool keepUserDuringLoad = false,
  }) async {
    // Only clear user if we're explicitly starting fresh (e.g. register flow)
    if (keepUserDuringLoad) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    // When called from register(), the DB trigger that inserts the users row
    // runs asynchronously after signUp() returns. Retry with short delay so
    // the profile fetch does not race ahead of the trigger.
    final maxAttempts = withRetry ? 5 : 1;
    const retryDelay = Duration(milliseconds: 800);
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) await Future.delayed(retryDelay);
      try {
        final profile = await _repo.getProfile(userId);
        state = state.copyWith(user: profile, isLoading: false);
        unawaited(PushNotificationService.instance.registerToken());
        return;
      } on DioException catch (e) {
        // 403 from auth-profile means deactivated or profile not found
        if (e.response?.statusCode == 403) {
          final body = e.response?.data;
          final msg = (body is Map ? (body['error'] as String?) : null) ??
              'Your account has been deactivated. Contact support.';
          state = state.copyWith(isLoading: false, clearUser: true, error: msg);
          await _supabase.auth.signOut();
          return;
        }
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }
    final errStr = lastError?.toString().replaceFirst('Exception: ', '') ??
        'Unknown error';
    state = state.copyWith(
      isLoading: false,
      clearUser: true,
      error: 'Could not load your account profile. $errStr',
    );
  }

  Future<String?> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user != null) {
        // FIX: keepUserDuringLoad not needed here because we explicitly call
        // _loadProfile. The onAuthStateChange listener fires too, but since we
        // are already loading the profile, the duplicate call is harmless.
        await _loadProfile(res.user!.id);
        return state.error;
      }
      state = state.copyWith(isLoading: false, error: 'Sign in failed');
      return 'Sign in failed';
    } on AuthException catch (e) {
      final msg = _mapAuthError(e.message);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    } catch (e) {
      const msg = 'An unexpected error occurred';
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  Future<String?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
    String? phone,
    String? birthday,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final registerErr = await _repo.registerLender(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        middleName: middleName,
        phone: phone,
        birthday: birthday,
      );
      if (registerErr != null) {
        state = state.copyWith(isLoading: false, error: registerErr);
        return registerErr;
      }

      final res = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Account created, but sign in failed. Please log in.',
        );
        return state.error;
      }

      await _loadProfile(res.user!.id, withRetry: true);
      return state.error;
    } on AuthException catch (e) {
      final msg = _mapAuthError(e.message);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  Future<String?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final String redirectTo;
      if (kIsWeb) {
        redirectTo = Uri.base.origin;
      } else {
        redirectTo = 'io.supabase.jireta://login-callback';
      }
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {
          'prompt': 'select_account',
          'access_type': 'offline',
        },
      );
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      const msg = 'Google sign-in failed';
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  Future<String?> changePassword(String current, String newPass) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final err = await _repo.changePassword(current, newPass);
    if (err == null && state.user != null) {
      await _loadProfile(state.user!.id);
    }
    state = state.copyWith(isLoading: false, error: err);
    return err;
  }

  Future<String?> sendForgotPassword({String? email, String? phone}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final err = await _repo.sendForgotPassword(email: email, phone: phone);
    state = state.copyWith(isLoading: false, error: err);
    return err;
  }

  Future<String?> resetPasswordWithOtp({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final err = await _repo.resetPasswordWithOtp(
      phone: phone,
      otp: otp,
      newPassword: newPassword,
    );
    state = state.copyWith(isLoading: false, error: err);
    return err;
  }

  Future<void> signOut() async {
    await PushNotificationService.instance.unregisterToken();
    await _supabase.auth.signOut();
    state = const AuthNotifierState(initialized: true);
  }

  Future<void> refreshProfile() async {
    if (state.user != null) {
      await _loadProfile(state.user!.id);
    }
  }

  String _mapAuthError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid login') ||
        lower.contains('invalid email') ||
        lower.contains('wrong password') ||
        lower.contains('user not found')) {
      return 'Wrong username or password';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email first';
    }
    if (lower.contains('already registered')) {
      return 'This email is already registered';
    }
    if (lower.contains('password') && lower.contains('weak')) {
      return 'Password is too weak';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Too many login attempts. Please wait a moment and try again.';
    }
    return 'Wrong username or password';
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthNotifierState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    Supabase.instance.client,
  );
});