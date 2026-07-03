import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class UserDashboardService {
  static const String _baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard_api.php'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Terjadi kesalahan');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Gagal memuat data dashboard: $e');
    }
  }
}
