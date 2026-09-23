/// Structured error surfaced to the UI — never exposes raw HTTP details.
class ApiException implements Exception {
  const ApiException({required this.message, this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';

  /// Human-readable messages for known error codes from the backend.
  static String friendlyMessage(Object? error) {
    if (error is ApiException) {
      return switch (error.code) {
        'EMAIL_ALREADY_EXISTS' => 'An account with this email already exists.',
        'STUDENT_ID_ALREADY_EXISTS' =>
          'An account with this student ID already exists.',
        'INVALID_CREDENTIALS' => 'Incorrect email or password. Please try again.',
        'ACCOUNT_DISABLED' => 'Your account is not active. Contact support.',
        'ACCOUNT_LOCKED' => 'Your account has been suspended. Contact support.',
        'TOKEN_EXPIRED' => 'Your session has expired. Please log in again.',
        'VALIDATION_ERROR' => error.message,
        'RATE_LIMIT_EXCEEDED' =>
          'Too many attempts. Please wait a minute and try again.',
        _ => error.message,
      };
    }
    return 'Something went wrong. Please try again.';
  }
}
