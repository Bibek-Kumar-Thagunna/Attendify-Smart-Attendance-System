import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/logger.dart';
import '../constants/email_constants.dart';

class EmailService {
  static Future<bool> sendEmail({
    required String templateId,
    required Map<String, dynamic> templateParams,
  }) async {
    if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
      appLogger.w('EmailJS keys not configured');
      return false;
    }

    try {
      final url = Uri.parse(EmailConstants.apiUrl);
      final body = json.encode({
        'service_id': EmailConstants.serviceId,
        'template_id': templateId,
        'user_id': EmailConstants.publicKey,
        'template_params': templateParams,
      });

      appLogger.d('📧 [EmailService] Sending payload: $body');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        appLogger.i('✅ [EmailService] Email sent successfully');
        return true;
      } else {
        appLogger.e(
          '❌ [EmailService] Failed: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      appLogger.e('❌ [EmailService] Error: $e');
      return false;
    }
  }
}
