/// Base exception used across the app so UI layers can handle failures
/// uniformly regardless of where they originated.
class AppException implements Exception {
  final String message;
  final int? statusCode;

  /// The API's machine code for the failure, when it sends one. E.g.
  /// `INSUFFICIENT_POINTS`. So a screen can react to the reason rather than
  /// parse the message.
  final String? code;

  /// Whatever else the API sent with the failure (points required, when a
  /// limit resets…).
  final Map<String, dynamic> details;

  const AppException(
    this.message, {
    this.statusCode,
    this.code,
    this.details = const {},
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error. Please try again.']);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Session expired. Please sign in again.'])
      : super(statusCode: 401);
}
