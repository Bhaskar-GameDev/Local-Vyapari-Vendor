import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'app_exception.dart';

/// Single place that converts any thrown object into a user-readable string.
///
/// Add new exception types here as the app grows rather than scattering
/// switch-on-type logic across providers and repositories.
class ErrorHandler {
  ErrorHandler._();

  /// Returns a human-readable message for any exception type.
  static String getMessage(Object error) {
    if (error is AppException) return error.message;
    if (error is FirebaseAuthException) return _fromFirebaseAuth(error);
    if (error is FirebaseFunctionsException) return _fromFirebaseFunctions(error);
    if (error is DioException) return _fromDio(error);
    if (error is FirebaseException) {
      return error.message ?? 'A Firebase error occurred. Please try again.';
    }
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }

  /// Logs [error] and [stack] in debug builds. No-op in release.
  static void log(Object error, [StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[ErrorHandler] $error');
      if (stack != null) debugPrint(stack.toString());
    }
  }

  // ─── Private mappers ────────────────────────────────────────────────────────

  static String _fromFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'This email address is already registered. '
            'If it is registered as a customer, please sign in with your '
            'password to upgrade to a merchant account.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'provider-already-linked':
        return 'This phone number is already linked to your account.';
      case 'credential-already-in-use':
        return 'This phone number is already registered to another account.';
      case 'user-mismatch':
        return 'This code was sent to a different number than the one on your account.';
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please try again.';
      case 'invalid-verification-id':
      case 'session-expired':
      case 'code-expired':
        return 'The code has expired. Please request a new one.';
      default:
        return e.message ?? 'Authentication error. Please try again.';
    }
  }

  static String _fromFirebaseFunctions(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'invalid-argument':
        return e.message ?? 'Invalid request.';
      case 'resource-exhausted':
        return e.message ?? 'Too many attempts. Please try again later.';
      case 'not-found':
        return e.message ?? 'Requested record was not found.';
      case 'failed-precondition':
        return e.message ?? 'This action cannot be completed right now.';
      case 'unavailable':
        return e.message ?? 'Service unavailable. Please try again later.';
      case 'internal':
        return e.message ?? 'An internal error occurred. Please try again later.';
      case 'permission-denied':
        return e.message ?? 'Access denied for this account.';
      default:
        return e.message ?? 'Request failed. Please try again.';
    }
  }

  static String _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please try again.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) return 'Your session has expired. Please log in again.';
        if (status == 403) return 'Access denied.';
        if (status == 404) return 'The requested resource was not found.';
        if (status != null && status >= 500) return 'Server error. Please try again later.';
        return 'Server returned an error (${status ?? 'unknown'}).';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Network error. Please try again.';
    }
  }
}
