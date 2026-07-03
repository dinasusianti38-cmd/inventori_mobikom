import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminStokService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> getStokData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_stok_data.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to load stok data'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_categories.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to load categories'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> updateStok(int materialId, int newStok, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_stok.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'material_id': materialId,
          'new_stok': newStok,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to update stok'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> exportToPdf() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/export_stok_pdf.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {
          'status': 'success',
          'message': 'PDF export ready'
        };
      } else {
        return {
          'status': 'error',
          'message': 'Failed to export PDF'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> getStokHistory(int materialId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_stok_history.php?material_id=$materialId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to load stok history'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e'
      };
    }
  }

  static deleteMaterial(int materialId) {}
}