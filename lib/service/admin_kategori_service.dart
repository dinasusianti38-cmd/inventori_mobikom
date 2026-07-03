import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminKategoriService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // Get all categories with pagination and search
  Future<Map<String, dynamic>> getCategories({
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    try {
      final Uri url = Uri.parse('$_baseUrl/kategori.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_categories',
          'page': page,
          'limit': limit,
          'search': search,
        }),
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
        'message': 'Connection error: $e'
      };
    }
  }

// Update untuk AdminKategoriService

Future<Map<String, dynamic>> addCategory({
  required String nama,
  required String description,
  required bool isActive,
}) async {
  try {
    final Uri url = Uri.parse('$_baseUrl/kategori.php');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'add_category',
        'nama_c': nama,
        'description': description,
        'is_active': isActive ? 1 : 0,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'status': 'error',
        'message': 'Failed to add category'
      };
    }
  } catch (e) {
    return {
      'status': 'error',
      'message': 'Connection error: $e'
    };
  }
}

Future<Map<String, dynamic>> updateCategory({
  required int id,
  required String nama,
  required String description,
  required bool isActive,
}) async {
  try {
    final Uri url = Uri.parse('$_baseUrl/kategori.php');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'update_category',
        'id_c': id,
        'nama_c': nama,
        'description': description,
        'is_active': isActive ? 1 : 0,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'status': 'error',
        'message': 'Failed to update category'
      };
    }
  } catch (e) {
    return {
      'status': 'error',
      'message': 'Connection error: $e'
    };
  }
}

  // Delete category
  Future<Map<String, dynamic>> deleteCategory(int id) async {
    try {
      final Uri url = Uri.parse('$_baseUrl/kategori.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'delete_category',
          'id_c': id,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to delete category'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Connection error: $e'
      };
    }
  }

  // Toggle category status
  Future<Map<String, dynamic>> toggleCategoryStatus(int id) async {
    try {
      final Uri url = Uri.parse('$_baseUrl/kategori.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'toggle_status',
          'id_c': id,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to toggle category status'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Connection error: $e'
      };
    }
  }
}