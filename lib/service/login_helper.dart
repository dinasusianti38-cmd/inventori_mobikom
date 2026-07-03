import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LoginHelper {

  static Future<Map<String, dynamic>> login(
      String username,
      String password) async {

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login.php'),
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      return {
        'status': 'error'
      };

    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }
}