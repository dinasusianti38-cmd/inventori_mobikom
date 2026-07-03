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

static Future<Map<String, dynamic>> deleteMaterial(int materialId) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/delete_material.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'material_id': materialId,
      }),
    );
    
    print('Delete response status: ${response.statusCode}');
    print('Delete response body: ${response.body}');
    
    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          final responseData = json.decode(response.body);
          
          // Pastikan response adalah Map
          if (responseData is Map<String, dynamic>) {
            return responseData;
          } else {
            return {
              'status': 'error',
              'message': 'Format response dari server tidak valid.',
            };
          }
        } catch (jsonError) {
          print('JSON decode error: $jsonError');
          return {
            'status': 'error',
            'message': 'Error parsing response: ${response.body}',
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Response kosong dari server.',
        };
      }
    } else {
      // Handle different HTTP status codes
      String errorMessage = 'Gagal menghapus material.';
      
      if (response.statusCode == 409) {
        errorMessage = 'Material sedang digunakan dan tidak dapat dihapus.';
      } else if (response.statusCode == 404) {
        errorMessage = 'Material tidak ditemukan.';
      } else if (response.statusCode >= 500) {
        errorMessage = 'Terjadi kesalahan pada server. Silakan coba lagi.';
      }
      
      return {
        'status': 'error',
        'message': '$errorMessage Status code: ${response.statusCode}',
      };
    }
  } catch (e) {
    print('Delete error: $e');
    
    // Handle specific error types
    String errorMessage = 'Terjadi kesalahan jaringan.';
    
    if (e.toString().contains('SocketException')) {
      errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    } else if (e.toString().contains('TimeoutException')) {
      errorMessage = 'Permintaan timeout. Silakan coba lagi.';
    }
    
    return {
      'status': 'error',
      'message': errorMessage,
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
}