import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/material_stock_models.dart';
import '../config/api_config.dart';

class MaterialService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Get material stock with current stock information
  static Future<List<MaterialStok>> getMaterialStock() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stok_material.php?action=get_stock'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<MaterialStok> materials = [];
          for (var item in data['data']) {
            materials.add(MaterialStok.fromJson(item));
          }
          return materials;
        } else {
          throw Exception(data['message'] ?? 'Failed to load material stock');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all categories
  static Future<List<Category>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stok_material.php?action=get_categories'),
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
          throw Exception(data['message'] ?? 'Failed to load categories');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Search materials by name or code
  static Future<List<MaterialStok>> searchMaterials(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stok_material.php?action=search&query=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<MaterialStok> materials = [];
          for (var item in data['data']) {
            materials.add(MaterialStok.fromJson(item));
          }
          return materials;
        } else {
          throw Exception(data['message'] ?? 'Failed to search materials');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Filter materials by category and status
  static Future<List<MaterialStok>> filterMaterials({
    String? category,
    String? status,
    String? search,
  }) async {
    try {
      String url = '$baseUrl/stok_material.php?action=filter';
      
      if (category != null && category.isNotEmpty) {
        url += '&category=${Uri.encodeComponent(category)}';
      }
      if (status != null && status.isNotEmpty) {
        url += '&status=${Uri.encodeComponent(status)}';
      }
      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<MaterialStok> materials = [];
          for (var item in data['data']) {
            materials.add(MaterialStok.fromJson(item));
          }
          return materials;
        } else {
          throw Exception(data['message'] ?? 'Failed to filter materials');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get material transactions
  static Future<List<MaterialTransaction>> getMaterialTransactions(int materialId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stok_material.php?action=get_transactions&material_id=$materialId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<MaterialTransaction> transactions = [];
          for (var item in data['data']) {
            transactions.add(MaterialTransaction.fromJson(item));
          }
          return transactions;
        } else {
          throw Exception(data['message'] ?? 'Failed to load transactions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update material stock
  static Future<bool> updateMaterialStock({
    required int materialId,
    required int newStock,
    required String transactionType,
    required String notes,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stok_material.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'update_stock',
          'material_id': materialId,
          'new_stock': newStock,
          'transaction_type': transactionType,
          'notes': notes,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Export stock data to PDF (placeholder for now)
  static Future<String> exportStockToPDF() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stok_material.php?action=export_pdf'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['file_url'] ?? '';
        } else {
          throw Exception(data['message'] ?? 'Failed to export PDF');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}