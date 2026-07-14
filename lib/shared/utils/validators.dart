// lib/shared/utils/validators.dart
//
// Comprehensive form validators used across the app.
// All validators return null when valid, or an error string when invalid.
// Designed to be passed directly to TextFormField.validator.

class Validators {
  // ── Generic ────────────────────────────────────────────────────────────────

  static String? required(String? value, {String? label}) {
    if (value == null || value.trim().isEmpty) {
      return '${label ?? 'This field'} is required';
    }
    return null;
  }

  static String? requiredSelection<T>(T? value, {String? label}) {
    if (value == null) {
      return 'Please select ${label ?? 'an option'}';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String? label}) {
    if (value == null || value.trim().isEmpty) {
      return '${label ?? 'This field'} is required';
    }
    if (value.trim().length < min) {
      return '${label ?? 'This field'} must be at least $min characters';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String? label}) {
    if (value == null || value.isEmpty) return null;
    if (value.length > max) {
      return '${label ?? 'This field'} must be at most $max characters';
    }
    return null;
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Optional email — only validates format if user typed something.
  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return email(value);
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (value.length > 128) return 'Password is too long';
    return null;
  }

  /// Strong password — at least 8 chars, 1 letter, 1 number.
  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'Password must contain at least one letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != original) return 'Passwords do not match';
    return null;
  }

  // ── Phone / GCash ──────────────────────────────────────────────────────────

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(' ', '').replaceAll('-', '');
    if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(cleaned)) {
      return 'Enter a valid PH phone number (09XXXXXXXXX)';
    }
    return null;
  }

  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return phone(value);
  }

  static String? gcashNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'GCash number is required';
    }
    final cleaned = value.replaceAll(' ', '').replaceAll('-', '');
    if (!RegExp(r'^09\d{9}$').hasMatch(cleaned)) {
      return 'Enter a valid GCash number (09XXXXXXXXX)';
    }
    return null;
  }

  static String? gcashName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'GCash account name is required';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
    }
    if (!RegExp(r'^[A-Za-z .,\-]+$').hasMatch(value.trim())) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  // ── Names ──────────────────────────────────────────────────────────────────

  static String? name(String? value, {String? label}) {
    final l = label ?? 'Name';
    if (value == null || value.trim().isEmpty) {
      return '$l is required';
    }
    if (value.trim().length < 2) {
      return '$l must be at least 2 characters';
    }
    if (!RegExp(r"^[A-Za-z .,\-']+$").hasMatch(value.trim())) {
      return '$l contains invalid characters';
    }
    return null;
  }

  static String? firstName(String? value) => name(value, label: 'First name');
  static String? lastName(String? value) => name(value, label: 'Last name');
  static String? middleName(String? value) {
    // Optional but if provided must be valid
    if (value == null || value.trim().isEmpty) return null;
    return name(value, label: 'Middle name');
  }

  // ── Dates ──────────────────────────────────────────────────────────────────

  static String? birthday(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Birthday is required';
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid date';
    }
    final now = DateTime.now();
    final age = now.year - parsed.year;
    if (age < 18) {
      return 'You must be at least 18 years old';
    }
    if (age > 100) {
      return 'Please enter a valid birthday';
    }
    return null;
  }

  static String? futureDate(String? value, {String? label}) {
    if (value == null || value.trim().isEmpty) {
      return '${label ?? 'Date'} is required';
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid date';
    }
    if (!parsed.isAfter(DateTime.now())) {
      return '${label ?? 'Date'} must be in the future';
    }
    return null;
  }

  // ── Loan / Money ───────────────────────────────────────────────────────────

  static String? loanAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Loan amount is required';
    }
    final amount =
        double.tryParse(value.replaceAll(',', '').replaceAll('₱', ''));
    if (amount == null) return 'Enter a valid amount';
    if (amount < 3000) return 'Minimum loan amount is ₱3,000';
    if (amount > 500000) return 'Maximum loan amount is ₱500,000';
    return null;
  }

  static String? paymentAmount(String? value, {double? outstanding}) {
    if (value == null || value.trim().isEmpty) {
      return 'Payment amount is required';
    }
    final amount =
        double.tryParse(value.replaceAll(',', '').replaceAll('₱', ''));
    if (amount == null) return 'Enter a valid amount';
    if (amount <= 0) return 'Amount must be greater than zero';
    if (outstanding != null && amount > outstanding) {
      return 'Amount cannot exceed outstanding balance (₱${outstanding.toStringAsFixed(2)})';
    }
    return null;
  }

  static String? termDays(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Term days is required';
    }
    final days = int.tryParse(value);
    if (days == null || days < 1) return 'Enter valid term days';
    if (days > 365) return 'Maximum term is 365 days';
    return null;
  }

  static String? amount(String? value,
      {String? label, double? min, double? max}) {
    final l = label ?? 'Amount';
    if (value == null || value.trim().isEmpty) {
      return '$l is required';
    }
    final amount =
        double.tryParse(value.replaceAll(',', '').replaceAll('₱', ''));
    if (amount == null) return 'Enter a valid amount';
    if (min != null && amount < min)
      return '$l must be at least ₱${min.toStringAsFixed(0)}';
    if (max != null && amount > max)
      return '$l must not exceed ₱${max.toStringAsFixed(0)}';
    return null;
  }

  // ── OTP / Codes ────────────────────────────────────────────────────────────

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter the verification code';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Code must be 6 digits';
    }
    return null;
  }

  static String? numericCode(String? value, int length, {String? label}) {
    final l = label ?? 'Code';
    if (value == null || value.trim().isEmpty) {
      return '$l is required';
    }
    if (!RegExp(r'^\d{$length}$').hasMatch(value.trim())) {
      return '$l must be $length digits';
    }
    return null;
  }

  // ── Address / Text ─────────────────────────────────────────────────────────

  static String? address(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }
    if (value.trim().length < 10) {
      return 'Please enter a complete address';
    }
    return null;
  }

  static String? multilineText(String? value,
      {String? label, int min = 10, int max = 500}) {
    final l = label ?? 'This field';
    if (value == null || value.trim().isEmpty) {
      return '$l is required';
    }
    if (value.trim().length < min) {
      return '$l must be at least $min characters';
    }
    if (value.trim().length > max) {
      return '$l must not exceed $max characters';
    }
    return null;
  }

  // ── ID / Reference ─────────────────────────────────────────────────────────

  static String? idNumber(String? value, {String? label}) {
    final l = label ?? 'ID number';
    if (value == null || value.trim().isEmpty) {
      return '$l is required';
    }
    if (value.trim().length < 4) {
      return '$l must be at least 4 characters';
    }
    return null;
  }

  static String? referenceNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Reference number is required';
    }
    if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(value.trim())) {
      return 'Reference number contains invalid characters';
    }
    if (value.trim().length < 4) {
      return 'Reference number is too short';
    }
    return null;
  }

  // ── Boolean / Agreement ────────────────────────────────────────────────────

  static String? agreeToTerms(bool? value) {
    if (value != true) {
      return 'You must accept the Terms & Conditions';
    }
    return null;
  }

  // ── Compose ────────────────────────────────────────────────────────────────

  /// Run multiple validators; return the first error.
  static String? compose(
      String? value, List<String? Function(String?)> validators) {
    for (final v in validators) {
      final err = v(value);
      if (err != null) return err;
    }
    return null;
  }
}
