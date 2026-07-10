// lib/core/constants/supabase_constants.dart
// Credentials are loaded from .env at runtime — never hardcode secrets here.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  static String get projectUrl =>
      dotenv.env['SUPABASE_URL'] ??
      (throw Exception('SUPABASE_URL not found in .env'));

  static String get anonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      (throw Exception('SUPABASE_ANON_KEY not found in .env'));

  static String get functionsBaseUrl => '$projectUrl/functions/v1';

  static String get storageBaseUrl =>
      '$projectUrl/storage/v1/object/public';

  static const String avatarBucket = 'avatars';
  static const String documentsBucket = 'kyc-documents';
  static const String receiptsBucket = 'receipts';
  static const String signaturesBucket = 'signatures';
}