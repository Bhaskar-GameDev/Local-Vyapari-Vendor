import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SmsConfig {
  /// Toggle between 'twilio', 'fast2sms', or 'mock'
  static const String gateway = 'mock'; // Set to 'twilio' or 'fast2sms' to use real SMS

  /// Twilio Credentials (Global Standard)
  /// Replace with your actual credentials to send real SMS.
  static const String twilioAccountSid = 'ACYOUR_ACCOUNT_SID_HERE'; 
  static const String twilioAuthToken = 'YOUR_AUTH_TOKEN_HERE';
  static const String twilioFromNumber = '+18XXXXXXXXX'; // Your Twilio phone number

  /// Fast2SMS Credentials (India)
  /// Replace with your actual key to send real SMS in India.
  static const String fast2smsApiKey = 'YOUR_FAST2SMS_API_KEY_HERE';
}

class SmsService {
  static final Dio _dio = Dio();

  /// Send an OTP code via the configured SMS Gateway
  static Future<bool> sendOtp(String phoneNumber, String otpCode) async {
    final gateway = SmsConfig.gateway.toLowerCase();

    // Check if configuration placeholders are still unmodified
    final isTwilioConfigured = SmsConfig.twilioAccountSid.startsWith('AC') && 
        SmsConfig.twilioAccountSid != 'ACYOUR_ACCOUNT_SID_HERE' &&
        SmsConfig.twilioAuthToken != 'YOUR_AUTH_TOKEN_HERE';

    final isFast2SmsConfigured = SmsConfig.fast2smsApiKey != 'YOUR_FAST2SMS_API_KEY_HERE';

    if (gateway == 'twilio') {
      if (!isTwilioConfigured) {
        debugPrint('⚠️ [SmsService] Twilio credentials not configured. SMS not sent to $phoneNumber.');
        return false;
      }
      return await _sendTwilioSms(phoneNumber, otpCode);
    } else if (gateway == 'fast2sms') {
      if (!isFast2SmsConfigured) {
        debugPrint('⚠️ [SmsService] Fast2SMS API key not configured. SMS not sent to $phoneNumber.');
        return false;
      }
      return await _sendFast2Sms(phoneNumber, otpCode);
    } else {
      debugPrint('ℹ️ [SmsService] Mock Gateway active. OTP: $otpCode for $phoneNumber.');
      return true; // Mock mode returns true
    }
  }

  static Future<bool> _sendTwilioSms(String phoneNumber, String otpCode) async {
    final accountSid = SmsConfig.twilioAccountSid;
    final authToken = SmsConfig.twilioAuthToken;
    final fromNumber = SmsConfig.twilioFromNumber;

    final url = 'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json';
    final credentials = '$accountSid:$authToken';
    final bytes = utf8.encode(credentials);
    final base64Credentials = base64.encode(bytes);

    try {
      final response = await _dio.post(
        url,
        data: {
          'To': phoneNumber,
          'From': fromNumber,
          'Body': 'Your Local Vyapari verification OTP code is: $otpCode. Valid for 2 minutes.',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Authorization': 'Basic $base64Credentials',
          },
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Twilio SMS sent successfully to $phoneNumber');
        return true;
      } else {
        debugPrint('❌ Twilio SMS failed with status: ${response.statusCode}, response: ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Exception while sending Twilio SMS: $e');
      return false;
    }
  }

  static Future<bool> _sendFast2Sms(String phoneNumber, String otpCode) async {
    // Fast2SMS expects India numbers without +91 prefix (10 digits)
    var cleanedPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanedPhone.startsWith('91') && cleanedPhone.length == 12) {
      cleanedPhone = cleanedPhone.substring(2);
    }

    final apiKey = SmsConfig.fast2smsApiKey;
    final url = 'https://www.fast2sms.com/dev/bulkV2';

    try {
      final response = await _dio.get(
        url,
        queryParameters: {
          'authorization': apiKey,
          'variables_values': otpCode,
          'route': 'otp',
          'numbers': cleanedPhone,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['return'] == true) {
          debugPrint('✅ Fast2SMS SMS sent successfully to $phoneNumber');
          return true;
        } else {
          debugPrint('❌ Fast2SMS failed: ${data?["message"] ?? "Unknown error"}');
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Exception while sending Fast2SMS SMS: $e');
      return false;
    }
  }
}
