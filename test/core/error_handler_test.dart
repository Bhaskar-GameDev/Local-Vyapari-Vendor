import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vyapari_vendor/core/exceptions/app_exception.dart';
import 'package:local_vyapari_vendor/core/exceptions/error_handler.dart';

// Pure unit tests for ErrorHandler.getMessage — the single place that turns any
// thrown object into user-facing copy. No Firebase init required; every input is
// constructed directly. This is the highest-value zero-dependency suite because
// every provider/repository funnels failures through here.

void main() {
  group('ErrorHandler.getMessage', () {
    test('AppException returns its own message verbatim', () {
      expect(
        ErrorHandler.getMessage(const ValidationException('Name is required')),
        'Name is required',
      );
      expect(
        ErrorHandler.getMessage(const NetworkException('Offline')),
        'Offline',
      );
    });

    group('FirebaseAuthException mapping', () {
      // Each known code must map to a stable, user-friendly string. If these
      // strings change intentionally, update the test — that is the point.
      final cases = <String, String>{
        'user-not-found': 'No account found with this email.',
        'wrong-password': 'Incorrect password. Please try again.',
        'invalid-credential': 'Invalid email or password.',
        'user-disabled': 'This account has been disabled.',
        'weak-password': 'Password must be at least 6 characters.',
        'invalid-email': 'Please enter a valid email address.',
        'too-many-requests': 'Too many attempts. Please try again later.',
      };

      cases.forEach((code, expected) {
        test('$code -> "$expected"', () {
          expect(
            ErrorHandler.getMessage(FirebaseAuthException(code: code)),
            expected,
          );
        });
      });

      test('email-already-in-use explains the customer-upgrade path', () {
        final msg = ErrorHandler.getMessage(
          FirebaseAuthException(code: 'email-already-in-use'),
        );
        expect(msg, contains('already registered'));
        expect(msg, contains('merchant'));
      });

      test('unknown code falls back to the exception message', () {
        final msg = ErrorHandler.getMessage(
          FirebaseAuthException(code: 'some-new-code', message: 'Boom'),
        );
        expect(msg, 'Boom');
      });

      test('unknown code with no message uses the generic auth fallback', () {
        final msg = ErrorHandler.getMessage(
          FirebaseAuthException(code: 'some-new-code'),
        );
        expect(msg, 'Authentication error. Please try again.');
      });
    });

    group('DioException mapping', () {
      final req = RequestOptions(path: '/x');

      test('timeouts collapse to one connection message', () {
        for (final type in [
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
        ]) {
          final msg = ErrorHandler.getMessage(
            DioException(requestOptions: req, type: type),
          );
          expect(msg, 'Request timed out. Please check your connection and try again.');
        }
      });

      test('connectionError surfaces an offline message', () {
        final msg = ErrorHandler.getMessage(DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
        ));
        expect(msg, 'No internet connection. Please try again.');
      });

      test('401 tells the user the session expired', () {
        final msg = ErrorHandler.getMessage(DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req, statusCode: 401),
        ));
        expect(msg, 'Your session has expired. Please log in again.');
      });

      test('5xx maps to a generic server error', () {
        final msg = ErrorHandler.getMessage(DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req, statusCode: 503),
        ));
        expect(msg, 'Server error. Please try again later.');
      });

      test('unexpected status echoes the code', () {
        final msg = ErrorHandler.getMessage(DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req, statusCode: 418),
        ));
        expect(msg, contains('418'));
      });
    });

    group('plain exceptions', () {
      test('strips the "Exception: " prefix Dart adds', () {
        expect(
          ErrorHandler.getMessage(Exception('Something broke')),
          'Something broke',
        );
      });

      test('passes through an arbitrary object string', () {
        expect(ErrorHandler.getMessage('raw string error'), 'raw string error');
      });
    });
  });
}
