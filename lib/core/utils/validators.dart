/// Pure form validators (return an error string, or null when valid).
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _ukPhone = RegExp(r'^(?:\+44|0)7\d{9}$|^(?:\+44|0)\d{9,10}$');

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    return _email.hasMatch(v.trim()) ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(
    String Function() original,
  ) =>
      (v) => (v == null || v.isEmpty)
      ? 'Confirm your password'
      : (v == original() ? null : 'Passwords do not match');

  static String? fullName(String? v) {
    if (v == null || v.trim().length < 2) return 'Enter your full name';
    return v.trim().length > 100 ? 'That name is too long' : null;
  }

  /// Optional UK mobile/landline. Empty is valid.
  static String? optionalPhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final cleaned = v.replaceAll(RegExp(r'[\s\-()]'), '');
    return _ukPhone.hasMatch(cleaned) ? null : 'Enter a valid UK phone number';
  }

  static String? Function(String?) minLength(int n, String field) =>
      (v) => (v == null || v.trim().length < n)
      ? '$field must be at least $n characters'
      : null;
}
