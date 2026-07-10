// lib/shared/utils/validators.dart

class Validators {
  static String? required(String? value, {String? label}) {
    if (value == null || value.trim().isEmpty) {
      return '${label ?? 'This field'} is required';
    }
    return null;
  }

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

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != original) return 'Passwords do not match';
    return null;
  }

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

  static String? termDays(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Term days is required';
    }
    final days = int.tryParse(value);
    if (days == null || days < 1) return 'Enter valid term days';
    if (days > 365) return 'Maximum term is 365 days';
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
}