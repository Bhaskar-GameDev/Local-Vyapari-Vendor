import re
import os

path = r'c:\Users\naidu\OneDrive\Desktop\Local-Vyapari\lib\domain\providers\auth_provider.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace login method
new_login = """
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = await _repository.login(email, password);
      
      final idTokenResult = await credential.user?.getIdTokenResult(true);
      final role = idTokenResult?.claims?['role'] as String?;
      
      if (role != 'merchant') {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: This account is registered as a customer.',
        );
        return false;
      }

      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
"""
content = re.sub(r'  Future<bool> login\(String email, String password\) async \{.*?(?=  Future<bool> register)', new_login, content, flags=re.DOTALL)

# Add finally to register
content = re.sub(r'  Future<bool> register\(.*?\).*?catch \(e\) \{.*?\n      return false;\n    \}', r'\g<0>\n    finally {\n      state = state.copyWith(isLoading: false);\n    }', content, flags=re.DOTALL)

# Add finally to loginWithPhoneAndPassword (and remove role writing)
new_loginPhone = """
  Future<bool> loginWithPhoneAndPassword(String phone, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final formattedPhone = phone.trim();
      
      final phoneSnapshot = await FirebaseDatabase.instance.ref('phones').child(formattedPhone).get();
      if (!phoneSnapshot.exists || phoneSnapshot.value == null) {
        state = const AuthNotifierState(error: 'This phone number is not registered');
        return false;
      }
      
      final uid = phoneSnapshot.value as String;

      final emailSnapshot = await FirebaseDatabase.instance.ref('users').child(uid).child('email').get();
      if (!emailSnapshot.exists || emailSnapshot.value == null) {
        state = const AuthNotifierState(error: 'No email found linked to this phone number');
        return false;
      }
      
      final realEmail = emailSnapshot.value as String;
      
      final credential = await _repository.login(realEmail, password);
      
      final idTokenResult = await credential.user?.getIdTokenResult(true);
      final role = idTokenResult?.claims?['role'] as String?;
      
      if (role != 'merchant') {
        await _repository.logout();
        state = const AuthNotifierState(
          error: 'Access Denied: This account is registered as a customer.',
        );
        return false;
      }
      
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
"""
content = re.sub(r'  Future<bool> loginWithPhoneAndPassword\(String phone, String password\) async \{.*?(?=  Future<bool> registerWithPhoneAndPassword)', new_loginPhone, content, flags=re.DOTALL)

# Add finally to registerWithPhoneAndPassword
content = re.sub(r'  Future<bool> registerWithPhoneAndPassword\(.*?\).*?catch \(e\) \{.*?\n      return false;\n    \}', r'\g<0>\n    finally {\n      state = state.copyWith(isLoading: false);\n    }', content, flags=re.DOTALL)

# Replace verifyAndSubmit
new_verifyAndSubmit = """
  Future<bool> verifyAndSubmit({
    required String phone,
    required String code,
    required bool isRegistered,
    String? shopName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final customToken = await _repository.verifyOtp(phone, code);
      if (customToken == null) {
        state = const AuthNotifierState(error: 'Invalid or expired OTP');
        return false;
      }
      
      if (isRegistered) {
        await _repository.loginWithCustomToken(customToken);
      } else {
        await _repository.registerWithPhone(phone, shopName: shopName);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthNotifierState(error: _repository.mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
"""
content = re.sub(r'  Future<bool> verifyAndSubmit\(.*?\).*?(?=  Future<bool> bindEmail)', new_verifyAndSubmit, content, flags=re.DOTALL)

# Add finally to rest of the methods
for method in ['checkPhone', 'requestOtp', 'bindEmail', 'requestBindPhoneOtp', 'requestPasswordResetOtp', 'verifyAndBindPhone', 'verifyOtpOnly']:
    content = re.sub(r'(  Future<.*?> ' + method + r'\(.*?\).*?catch \(e\) \{.*?\n      return (?:false|null);\n    \})', r'\g<1>\n    finally {\n      state = state.copyWith(isLoading: false);\n    }', content, flags=re.DOTALL)

# Replace resetPasswordWithOtp
new_reset = """
  Future<bool> resetPasswordWithOtp({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('resetPasswordWithOtp');
      await callable.call({
        'phone': phone.trim(),
        'code': otp.trim(),
        'newPassword': newPassword.trim(),
      });
      return true;
    } catch (e) {
      state = AuthNotifierState(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
"""
content = re.sub(r'  Future<bool> resetPasswordWithOtp\(.*?\).*?(?=  Future<void> logout)', new_reset, content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
