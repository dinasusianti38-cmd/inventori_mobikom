import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/export_laporan_models.dart';
import '../config/api_config.dart';

class AdminExportLaporanService {
  static const String baseUrl = ApiConfig.baseUrl; // Sesuaikan dengan URL API Anda
  
  // Headers untuk request
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Get all materials for dropdown filter
  Future<List<Material>> getMaterials() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/export_laporan.php?action=get_materials'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          final List<dynamic> materialsJson = jsonData['data'];
          return materialsJson.map((json) => Material.fromJson(json)).toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load materials');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading materials: $e');
    }
  }

  // Get transactions with filters
  Future<List<MaterialTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? materialId,
    String? transactionType,
  }) async {
    try {
      // Build query parameters
      Map<String, String> queryParams = {
        'action': 'get_transactions',
      };

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (materialId != null && materialId.isNotEmpty) {
        queryParams['material_id'] = materialId;
      }
      if (transactionType != null && transactionType.isNotEmpty) {
        queryParams['transaction_type'] = transactionType;
      }

      final uri = Uri.parse('$baseUrl/export_laporan.php').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          final List<dynamic> transactionsJson = jsonData['data'];
          return transactionsJson.map((json) => MaterialTransaction.fromJson(json)).toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load transactions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading transactions: $e');
    }
  }

  // Get transaction summary
  Future<TransactionSummary> getTransactionSummary({
    DateTime? startDate,
    DateTime? endDate,
    String? materialId,
    String? transactionType,
  }) async {
    try {
      // Build query parameters
      Map<String, String> queryParams = {
        'action': 'get_summary',
      };

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (materialId != null && materialId.isNotEmpty) {
        queryParams['material_id'] = materialId;
      }
      if (transactionType != null && transactionType.isNotEmpty) {
        queryParams['transaction_type'] = transactionType;
      }

      final uri = Uri.parse('$baseUrl/export_laporan.php').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          return TransactionSummary.fromJson(jsonData['data']);
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load summary');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading summary: $e');
    }
  }

  // Export transactions to CSV/Excel (placeholder for future implementation)
  Future<String> exportTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? materialId,
    String? transactionType,
    String format = 'csv',
  }) async {
    try {
      // Build query parameters
      Map<String, String> queryParams = {
        'action': 'export',
        'format': format,
      };

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (materialId != null && materialId.isNotEmpty) {
        queryParams['material_id'] = materialId;
      }
      if (transactionType != null && transactionType.isNotEmpty) {
        queryParams['transaction_type'] = transactionType;
      }

      final uri = Uri.parse('$baseUrl/export_laporan.php').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          return jsonData['file_url'] ?? '';
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to export data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error exporting data: $e');
    }
  }
}