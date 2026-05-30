import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps Firebase Authentication's TOTP (authenticator-app) multi-factor API.
///
/// TOTP is used instead of SMS as the second factor: it costs nothing per use
/// and works offline. Requires the project to be on Identity Platform with TOTP
/// MFA enabled in the console.
class MfaService {
  MfaService(this._auth);

  final FirebaseAuth _auth;

  /// Begins enrollment: returns the shared secret and an `otpauth://` URL the
  /// user can scan as a QR code or add manually to their authenticator app.
  Future<TotpEnrollment> startTotpEnrollment() async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');

    final session = await user.multiFactor.getSession();
    final secret = await TotpMultiFactorGenerator.generateSecret(session);
    final url = await secret.generateQrCodeUrl(
      accountName: user.email ?? user.phoneNumber ?? user.uid,
      issuer: 'Local Vyapari',
    );
    return TotpEnrollment(secret: secret, qrCodeUrl: url, sharedSecretKey: secret.secretKey);
  }

  /// Finishes enrollment by verifying the first code from the user's app.
  Future<void> finalizeTotpEnrollment({
    required TotpSecret secret,
    required String code,
    String displayName = 'Authenticator app',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');

    final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
      secret,
      code.trim(),
    );
    await user.multiFactor.enroll(assertion, displayName: displayName);
  }

  /// Lists the user's currently enrolled second factors.
  Future<List<MultiFactorInfo>> enrolledFactors() async {
    final user = _auth.currentUser;
    if (user == null) return const [];
    return user.multiFactor.getEnrolledFactors();
  }

  /// Removes an enrolled factor. Firebase requires a recent login, so callers
  /// should step-up (reauthenticate) right before this.
  Future<void> unenroll(String factorUid) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.multiFactor.unenroll(factorUid: factorUid);
  }

  /// Resolves a sign-in that was interrupted by an MFA challenge.
  /// Call from the `FirebaseAuthMultiFactorException` catch site.
  Future<UserCredential> resolveTotpSignIn({
    required MultiFactorResolver resolver,
    required String code,
  }) async {
    // Use the first TOTP hint (this app only enrolls TOTP factors).
    // 'totp' is Firebase's factor id for authenticator-app factors.
    final hint = resolver.hints.firstWhere(
      (h) => h.factorId == 'totp',
      orElse: () => resolver.hints.first,
    );
    final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
      hint.uid,
      code.trim(),
    );
    return resolver.resolveSignIn(assertion);
  }
}

class TotpEnrollment {
  TotpEnrollment({
    required this.secret,
    required this.qrCodeUrl,
    required this.sharedSecretKey,
  });

  /// Opaque secret handle needed to finalize enrollment.
  final TotpSecret secret;

  /// `otpauth://` URL — render as a QR code.
  final String qrCodeUrl;

  /// Human-readable key for manual entry into an authenticator app.
  final String sharedSecretKey;
}

final mfaServiceProvider =
    Provider<MfaService>((ref) => MfaService(FirebaseAuth.instance));
