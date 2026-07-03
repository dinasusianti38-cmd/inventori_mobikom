import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/material_transaksi_model.dart';
import '../config/api_config.dart';

class AdminTransaksiMaterialService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Get all materials for dropdown
  static Future<List<MaterialModel>> getMaterials() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transaksi_material.php?action=get_materials'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          List<MaterialModel> materials = [];
          for (var item in jsonData['data']) {
            materials.add(MaterialModel.fromJson(item));
          }
          return materials;
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to fetch materials');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create new material transaction
  static Future<Map<String, dynamic>> createTransaction({
    required int materialId,
    required String transactionType,
    required int jumlah,
    required String transactionDate,
    required String notes,
    required int createdBy,
    String? transactionCode,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'action': 'create_transaction',
        'material_id': materialId,
        'transaction_type': transactionType,
        'jumlah': jumlah,
        'transaction_date': transactionDate,
        'notes': notes,
        'created_by': createdBy,
        'transaction_code': transactionCode ?? generateTransactionCode(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/transaksi_material.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all material transactions
  static Future<List<MaterialTransaksiModel>> getTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transaksi_material.php?action=get_transactions'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          List<MaterialTransaksiModel> transactions = [];
          for (var item in jsonData['data']) {
            transactions.add(MaterialTransaksiModel.fromJson(item));
          }
          return transactions;
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to fetch transactions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get single transaction by ID
  static Future<MaterialTransaksiModel> getTransactionById(int idTm) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transaksi_material.php?action=get_transaction&id=$idTm'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          return MaterialTransaksiModel.fromJson(jsonData['data']);
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to fetch transaction');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // FIXED: Update transaction function
  static Future<Map<String, dynamic>> updateTransaction({
    required int idTm,
    required int materialId,
    required String transactionType,
    required int jumlah,
    required String transactionDate,
    required String notes,
    required int createdBy,
    required String transactionCode,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'action': 'update_transaction',
        'id_tm': idTm,
        'material_id': materialId,
        'transaction_type': transactionType,
        'jumlah': jumlah,
        'transaction_date': transactionDate,
        'notes': notes,
        'created_by': createdBy,
        'transaction_code': transactionCode,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/transaksi_material.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Delete transaction
  static Future<Map<String, dynamic>> deleteTransaction(int idTm) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/transaksi_material.php?action=delete_transaction&id=$idTm'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generate transaction code
  static String generateTransactionCode() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7);
    return 'TM${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$timestamp';
  }

  // REMOVED: editTransaction function (use updateTransaction instead)
  // The editTransaction was redundant and causing confusion
}