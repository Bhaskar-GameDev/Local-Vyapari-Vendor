abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

/// HTTP / connectivity failures from the Dio API client.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

/// Firebase Auth or OTP verification failures.
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

/// Firebase Realtime Database / Firestore read-write failures.
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code});
}

/// Cloud Functions or backend server errors.
class ServerException extends AppException {
  const ServerException(super.message, {super.code});
}

/// Input that fails business-rule validation before hitting a service.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}
