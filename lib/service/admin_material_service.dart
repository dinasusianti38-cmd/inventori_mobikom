import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/material_models.dart';
import '../config/api_config.dart';

class MaterialService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Get all materials with category names
  static Future<List<Material>> getAllMaterials() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/material.php?action=getAll"),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<Material> materials = [];
          for (var item in data['data']) {
            materials.add(Material.fromJson(item));
          }
          return materials;
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load materials');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get all active categories
  static Future<List<Category>> getAllCategories() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/material.php?action=getCategories"),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<Category> categories = [];
          for (var item in data['data']) {
            categories.add(Category.fromJson(item));
          }
          return categories;
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Add new material
  static Future<Map<String, dynamic>> addMaterial(Material material) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/material.php?action=add"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(material.toJson()),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add material');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Update material
  static Future<Map<String, dynamic>> updateMaterial(Material material) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/material.php?action=update"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(material.toJson()),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update material');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Delete material
  static Future<Map<String, dynamic>> deleteMaterial(int id) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/material.php?action=delete"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_m': id}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        // Handle specific error cases and convert to user-friendly messages
        if (result['status'] == 'error') {
          String errorMessage =
              result['message'] ?? 'Terjadi kesalahan saat menghapus material';

          // Convert technical error messages to user-friendly ones
          if (errorMessage.contains('foreign key constraint') ||
              errorMessage.contains('FOREIGN KEY') ||
              errorMessage.contains('Cannot delete or update a parent row') ||
              errorMessage.contains('product_materials')) {
            errorMessage =
                'Material ini sedang digunakan dan tidak dapat dihapus. Hapus terlebih dahulu data yang menggunakan material ini.';
          }

          return {'status': 'error', 'message': errorMessage};
        }

        return result;
      } else {
        throw Exception('Gagal menghapus material. Silakan coba lagi.');
      }
    } catch (e) {
      String errorMessage = e.toString();

      // Handle network and other errors
      if (errorMessage.contains('Connection timeout') ||
          errorMessage.contains('SocketException')) {
        errorMessage =
            'Koneksi timeout. Periksa koneksi internet Anda dan coba lagi.';
      } else if (errorMessage.contains('HTTP') ||
          errorMessage.contains('Server')) {
        errorMessage = 'Terjadi kesalahan server. Silakan coba lagi nanti.';
      } else if (errorMessage.contains('foreign key') ||
          errorMessage.contains('constraint')) {
        errorMessage = 'Material ini sedang digunakan dan tidak dapat dihapus.';
      } else {
        errorMessage = 'Terjadi kesalahan: $errorMessage';
      }

      return {'status': 'error', 'message': errorMessage};
    }
  }

  // Optional: Get delete preview (what will be deleted)
  static Future<Map<String, dynamic>> getDeletePreview(int id) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/material.php?action=delete_preview"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_m': id}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get delete preview');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Enhanced delete function with preview
  static Future<Map<String, dynamic>> deleteWithPreview(int id) async {
    try {
      // First get preview
      final preview = await getDeletePreview(id);

      if (preview['status'] != 'success') {
        throw Exception(preview['message'] ?? 'Failed to get delete preview');
      }

      // Return preview data for confirmation
      return {
        'status': 'preview',
        'data': preview['data'],
        'confirm_delete': () => deleteMaterial(id),
      };
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get material by ID
  static Future<Material?> getMaterialById(int id) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/material.php?action=getById&id=$id"),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return Material.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
